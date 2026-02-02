local PLUGIN = PLUGIN

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Extraction Point"
ENT.Author = ""
ENT.Category = "Versus"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Editable = true

function ENT:SetupDataTables()
  self:NetworkVar("Bool", 0, "Locked", {
    KeyName = "Locked",
    Edit = {
      type = "Boolean",
      category = "Extraction Point",
    },
  })
  self:NetworkVar("Float", 0, "ExtractionTime", {
    KeyName = "ExtractionTime",
    Edit = {
      type = "Float",
      min = 1,
      max = 300,
      category = "Extraction Point",
    },
  })
  self:NetworkVar("Float", 1, "MaxDistance", {
    KeyName = "MaxDistance",
    Edit = {
      type = "Float",
      min = 64,
      max = 2000,
      category = "Extraction Point",
    },
  })
  self:NetworkVar("String", 0, "ExtractionName", {
    KeyName = "ExtractionName",
    Edit = {
      type = "String",
      category = "Extraction Point",
    },
  })

  if (SERVER) then
    -- Default values
    self:SetLocked(false)
    self:SetExtractionTime(10)
    self:SetMaxDistance(256)
    self:SetExtractionName("Extraction Point")
  end
end

function ENT:Initialize()
  if (SERVER) then
    self:SetModel("models/props_lab/reciever01b.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if (IsValid(phys)) then
      phys:EnableMotion(false)
    end

    self.requiredConditions = {}
  end

  if (CLIENT) then
    self.nextGlowUpdate = 0
  end
end

function ENT:Think()
  if (CLIENT and CurTime() > self.nextGlowUpdate) then
    self.nextGlowUpdate = CurTime()

    -- Pulsing glow effect
    local locked = self:GetLocked()
    local color = locked and Color(255, 50, 50) or Color(50, 255, 50)
    local pulse = math.sin(CurTime() * 2) * 0.3 + 0.7

    self:SetColor(Color(color.r * pulse, color.g * pulse, color.b * pulse))
  end
end

if (SERVER) then
  function ENT:Use(activator, caller)
    if (not IsValid(activator) or not activator:IsPlayer()) then
      return
    end

    -- Check if locked
    if (self:GetLocked()) then
      versus.message.notify(activator, "This extraction point is locked. Complete the required objectives first.",
        NOTIFY_ERROR)
      return
    end

    -- Start extraction
    PLUGIN:startExtraction(activator, self)
  end

  function ENT:AddRequiredCondition(condition)
    if (not IsValid(condition)) then
      return
    end

    self.requiredConditions[condition] = true

    self:SetLocked(true)
  end

  function ENT:GetRequiredConditions()
    return table.GetKeys(self.requiredConditions or {})
  end

  function ENT:KeyValue(key, value)
    if (key == "ExtractionTime") then
      self:SetExtractionTime(tonumber(value) or 30)
    elseif (key == "MaxDistance") then
      self:SetMaxDistance(tonumber(value) or 256)
    elseif (key == "ExtractionName") then
      self:SetExtractionName(value)
    elseif (key == "Locked") then
      self:SetLocked(tobool(value))
    end
  end
end

if (CLIENT) then
  function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + self:GetUp() * 50
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    local distance = LocalPlayer():GetPos():Distance(self:GetPos())

    if (distance > 512) then
      return
    end

    cam.Start3D2D(pos, ang, 0.1)
    local locked = self:GetLocked()
    local color = locked and Color(255, 100, 100, 255) or Color(100, 255, 100, 255)

    local useText = string.format("[ Press %s to extract ]", versus.message.lookupBinding("use"))


    draw.SimpleText(self:GetExtractionName(), "DermaLarge", 0, 0, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(locked and "[LOCKED]" or useText, "DermaDefault", 0, 40, color, TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER)
    draw.SimpleText("Time: " .. self:GetExtractionTime() .. "s", "DermaDefault", 0, 70, color_white, TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER)
    cam.End3D2D()
  end
end
