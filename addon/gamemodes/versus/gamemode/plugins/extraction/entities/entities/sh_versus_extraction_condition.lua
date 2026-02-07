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
  "ConditionName",
  "ConditionDescription",
  "ConditionTime",
  "ExtractionPointName",
}

function ENT:SetupDataTables()
  self:NetworkVar("Float", 0, "ConditionTime", {
    KeyName = "ConditionTime",
    Edit = {
      type = "Float",
      min = 1,
      max = 300,
      category = "Extraction Condition",
    },
  })
  self:NetworkVar("String", 0, "ConditionName", {
    KeyName = "ConditionName",
    Edit = {
      type = "String",
      category = "Extraction Condition",
    },
  })
  self:NetworkVar("String", 1, "ConditionDescription", {
    KeyName = "ConditionDescription",
    Edit = {
      type = "String",
      category = "Extraction Condition",
    },
  })
  self:NetworkVar("String", 2, "ExtractionPointName", {
    KeyName = "ExtractionPointName",
    Edit = {
      type = "String",
      category = "Extraction Condition",
    },
  })

  if (SERVER) then
    self:NetworkVarNotify("ExtractionPointName", function(ent, name, old, new)
      ent:SetupConnectionToExtractionPoint()
    end)

    -- Default values
    self:SetConditionTime(2)
    self:SetConditionName("Objective")
    self:SetConditionDescription("Complete this objective")
    self:SetExtractionPointName("")
  end
end

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

function ENT:Initialize()
  if (SERVER) then
    self:SetModel("models/props_combine/breenconsole.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
      phys:EnableMotion(false)
    end

    self:SetupConnectionToExtractionPoint()
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
  function ENT:Use(activator, caller)
    if (not IsValid(activator) or not activator:IsPlayer()) then
      return
    end

    -- Check if already completed
    if (PLUGIN:hasCompletedCondition(activator, self)) then
      versus.message.notify(activator, "You have already completed this objective!", NOTIFY_ERROR)
      return
    end

    -- Complete the condition
    PLUGIN:completeCondition(activator, self)
  end

  function ENT:OnComplete(player)
    -- Override this in derived entities for custom behavior
    -- This is called when the condition timer completes
  end

  function ENT:SetupConnectionToExtractionPoint()
    if (IsValid(self._linkedExtractionPoint)) then
      self._linkedExtractionPoint:RemoveRequiredCondition(self)
      self._linkedExtractionPoint = nil
    end

    -- Link to extraction point if specified
    if (self:GetExtractionPointName() ~= "") then
      for _, ent in ipairs(ents.FindByClass("versus_extraction_point")) do
        if (IsValid(ent) and ent:GetExtractionName() == self:GetExtractionPointName()) then
          ent:AddRequiredCondition(self)
          self._linkedExtractionPoint = ent

          print("[Extraction] Linked condition '" ..
            self:GetConditionName() .. "' to extraction point '" .. ent:GetExtractionName() .. "'")

          break
        end
      end
    end
  end
end

function ENT:KeyValue(key, value)
  if (key == "ConditionTime") then
    self:SetConditionTime(tonumber(value) or 10)
  elseif (key == "ConditionName") then
    self:SetConditionName(value)
  elseif (key == "ConditionDescription") then
    self:SetConditionDescription(value)
  elseif (key == "ExtractionPointName") then
    self:SetExtractionPointName(value)
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

    -- Check if completed
    local completed = PLUGIN:hasCompletedCondition(LocalPlayer(), self)

    cam.Start3D2D(pos, ang, 0.1)
    local color = completed and Color(100, 100, 100, 255) or Color(100, 150, 255, 255)

    local y = 0
    local width, height
    width, height = draw.SimpleText(
      self:GetConditionName(),
      "VersusHeading1",
      0,
      y,
      color,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
    y = y + height

    if (completed) then
      width, height = draw.SimpleText(
        "[COMPLETED]",
        "VersusDefaultOutlined",
        0,
        y,
        Color(100, 255, 100, 255),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP
      )
      y = y + height
    else
      local useText = string.format("[ Press %s to complete ]", versus.message.lookupBinding("use"))

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
        self:GetConditionDescription(),
        "VersusDefault",
        0,
        y,
        color_white,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP
      )
      y = y + height

      width, height = draw.SimpleText(
        "Time: " .. self:GetConditionTime() .. "s",
        "VersusDefault",
        0,
        y,
        color_white,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP
      )
    end
    cam.End3D2D()
  end
end
