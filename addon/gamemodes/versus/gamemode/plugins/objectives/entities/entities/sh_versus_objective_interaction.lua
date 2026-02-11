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
    if (not self:GetModel() or self:GetModel() == "") then
      self:SetModel("models/props_combine/breenconsole.mdl")
    end
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
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

    -- Pulsing glow effect
    local pulse = math.sin(CurTime() * 3) * 0.3 + 0.7
    self:SetColor(Color(100 * pulse, 150 * pulse, 255 * pulse))
  end
end

if (SERVER) then
  function ENT:SetInteractionCallback(player, callback)
    self.interactionCallbacks = self.interactionCallbacks or {}
    self.interactionCallbacks[player] = callback
  end

  function ENT:Use(activator, caller)
    if (not IsValid(activator) or not activator:IsPlayer()) then
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
  if (key == "InteractionTime") then
    self:SetInteractionTime(tonumber(value) or 10)
  elseif (key == "InteractionName") then
    self:SetInteractionName(value)
  elseif (key == "InteractionDescription") then
    self:SetInteractionDescription(value)
  end
end

if (CLIENT) then
  function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + self:GetUp() * 65
    local ang = LocalPlayer():EyeAngles()
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
