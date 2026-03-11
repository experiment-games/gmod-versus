local PLUGIN = PLUGIN

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Extraction Condition"
ENT.Author = ""
ENT.Category = "Versus"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Editable = true

ENT.VersusWritesToManifest = {
  "Tag",
}

if (SERVER) then
  util.AddNetworkString("versus.objectives.openInteractiveEditor")
  util.AddNetworkString("versus.objectives.changeInteractiveEditor")
  util.AddNetworkString("versus.objectives.changeInteractiveEditorBump")
  util.AddNetworkString("versus.objectives.setEntityRelevant")

  concommand.Add("versus_objective_edit", function(player, command, args)
    if (not player:IsAdmin()) then
      return
    end

    local trace = player:GetEyeTraceNoCursor()

    if (not trace or not trace.Entity or not IsValid(trace.Entity) or trace.Entity:GetClass() ~= "versus_objective_interaction") then
      return
    end

    net.Start("versus.objectives.openInteractiveEditor")
    net.WriteEntity(trace.Entity)
    net.Send(player)
  end)

  net.Receive("versus.objectives.changeInteractiveEditor", function(len, player)
    if (not player:IsAdmin()) then
      return
    end

    local entity = net.ReadEntity()
    local model = net.ReadString()
    local skin = net.ReadInt(8)
    local scale = net.ReadFloat()

    if (not IsValid(entity) or entity:GetClass() ~= "versus_objective_interaction") then
      return
    end

    if (model ~= "" and util.IsValidModel(model)) then
      entity:SetModel(model)
    end

    entity:SetSkin(skin)
    entity:SetModelScale(scale)

    versus.message.notify(player, "Updated objective interaction entity")
  end)

  net.Receive("versus.objectives.changeInteractiveEditorBump", function(len, player)
    if (not player:IsAdmin()) then
      return
    end

    local entity = net.ReadEntity()
    local zBump = net.ReadFloat()

    if (not IsValid(entity) or entity:GetClass() ~= "versus_objective_interaction") then
      return
    end

    entity:SetPos(entity:GetPos() + Vector(0, 0, zBump))

    versus.message.notify(player, "Bumped objective interaction entity by " .. zBump .. " units")
  end)
end

function ENT:SetupDataTables()
  self:NetworkVar("Float", "InteractionTime")
  self:NetworkVar("String", "InteractionName")
  self:NetworkVar("String", "InteractionDescription")
  self:NetworkVar("String", "Tag", {
    KeyName = "Tag",
    Edit = {
      type = "String",
      category = "Extraction Condition",
    },
  })

  if (SERVER) then
    -- Default values
    self:SetInteractionTime(2)
    self:SetInteractionName("Objective")
    self:SetInteractionDescription("Complete this objective")
    self:SetTag("")
  end
end

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

function ENT:Initialize()
  if (SERVER) then
    if (not self:GetModel() or self:GetModel() == "models/error.mdl") then
      self:SetModel("models/props_combine/breenconsole.mdl")
    end
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_OBB) -- Must use SOLID_OBB as some models have no physics model
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
      phys:EnableMotion(false)
    end
  end

  if (CLIENT) then
    self.nextGlowUpdate = 0
  end
end

function ENT:Think()
  if (CLIENT and CurTime() > self.nextGlowUpdate) then
    self.nextGlowUpdate = CurTime()

    if (self.isRelevantForLocalPlayer) then
      -- Pulsing glow effect
      local pulse = math.sin(CurTime() * 3) * 0.3 + 0.7
      self:SetColor(Color(100 * pulse, 150 * pulse, 255 * pulse))
    else
      self:SetColor(color_white)
    end
  end
end

if (SERVER) then
  function ENT:SetInteractionCallback(player, callback)
    self.interactionCallbacks = self.interactionCallbacks or {}
    self.interactionCallbacks[player] = callback

    if (IsValid(player)) then
      net.Start("versus.objectives.setEntityRelevant")
      net.WriteEntity(self)
      net.WriteBool(true)
      net.Send(player)
    end
  end

  function ENT:ClearInteractionCallback(player)
    if (self.interactionCallbacks) then
      self.interactionCallbacks[player] = nil
    end

    if (IsValid(player) and IsValid(self)) then
      net.Start("versus.objectives.setEntityRelevant")
      net.WriteEntity(self)
      net.WriteBool(false)
      net.Send(player)
    end
  end

  function ENT:Use(activator, caller)
    if (not IsValid(activator) or not activator:IsPlayer()) then
      return
    end

    if (activator:IsAdmin() and activator:KeyDown(IN_SPEED)) then
      -- Open editor for admins holding +speed (shift by default)
      net.Start("versus.objectives.openInteractiveEditor")
      net.WriteEntity(self)
      net.Send(activator)

      versus.message.notify(activator, "Opened objective interaction editor (SPRINT + USE as admin)")

      return
    end

    if (self.interactionCallbacks and self.interactionCallbacks[activator]) then
      self.interactionCallbacks[activator](self, activator)
    end

    -- Hook for custom behavior
    hook.Run("PlayerObjectiveInteracted", activator, self)
  end
end

function ENT:KeyValue(key, value)
  key = key:lower()

  if (key == "tag") then
    self:SetTag(value)
  elseif (key == "interactiontime") then
    self:SetInteractionTime(tonumber(value) or 10)
  elseif (key == "interactionname") then
    self:SetInteractionName(value)
  elseif (key == "interactiondescription") then
    self:SetInteractionDescription(value)
  end
end

if (CLIENT) then
  local function clearAllRelevance()
    for _, ent in ipairs(ents.FindByClass("versus_objective_interaction")) do
      ent.isRelevantForLocalPlayer = false
    end
  end

  -- When a contract is selected or new contracts are offered, clear all relevance.
  -- Relevance is set by the server via setEntityRelevant when SetInteractionCallback is called.
  hook.Add("PlayerSelectedContract", "versus.objectives.updateInteractionRelevance", function()
    clearAllRelevance()
  end)

  hook.Add("PlayerReceivedContracts", "versus.objectives.clearInteractionRelevance", function()
    clearAllRelevance()
  end)

  net.Receive("versus.objectives.setEntityRelevant", function()
    local entity = net.ReadEntity()
    local relevant = net.ReadBool()

    if (IsValid(entity)) then
      entity.isRelevantForLocalPlayer = relevant
    end
  end)

  function ENT:Draw()
    self:DrawModel()

    if (not self.isRelevantForLocalPlayer) then
      return
    end

    local min, max = self:GetRenderBounds()
    -- Position slightly forward so its not inside the wall or the entity
    local up = self:GetUp() * 16
    local ang = LocalPlayer():EyeAngles()

    if (max.z > 64) then
      up = (self:GetUp() * max.z * .25)
      ang = self:GetAngles()
      ang:RotateAroundAxis(ang:Up(), 180)
    end

    local pos = self:GetPos() + up + self:GetForward() * (max.y)
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    local distance = LocalPlayer():GetPos():Distance(self:GetPos())

    if (distance > 512) then
      return
    end

    cam.Start3D2D(pos, ang, 0.1)
    local color = Color(100, 150, 255, 255)

    local y = 0
    local width, height
    width, height = draw.SimpleText(
      self:GetInteractionName(),
      "VersusHeading1",
      0,
      y,
      color,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
    y = y + height

    local useText = string.format("[ Press %s to interact ]", versus.message.lookupBinding("use"))

    width, height = draw.SimpleText(
      useText,
      "VersusDefaultOutlined",
      0,
      y,
      color,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
    y = y + height

    width, height = draw.SimpleText(
      self:GetInteractionDescription(),
      "VersusDefault",
      0,
      y,
      color_white,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
    y = y + height

    cam.End3D2D()
  end
end
