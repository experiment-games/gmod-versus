local PLUGIN = PLUGIN
local ENT = ENT

ENT.Type     = "anim"
ENT.Base     = "base_gmodentity"
ENT.PrintName = "Endurance Squad Spawn"
ENT.Author   = ""
ENT.Category = "Versus"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.VersusWritesToManifest = {
  "SpawnID",
}

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "SpawnID")
  self:SetSpawnID("")
end

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

if not SERVER then
  function ENT:Draw()
    if GetConVar("developer"):GetInt() == 0 then
      return
    end

    self:DrawModel()

    local pos = self:GetPos() + Vector(0, 0, 60)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    if LocalPlayer():GetPos():Distance(self:GetPos()) > 1024 then
      return
    end

    cam.Start3D2D(pos, ang, 0.15)

    draw.SimpleText(
      "[Squad Spawn: " .. self:GetSpawnID() .. "]",
      "VersusDefaultOutlined",
      0, 0,
      Color(100, 200, 255, 255),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    cam.End3D2D()

    local forward = self:GetForward() * 50
    render.DrawLine(self:GetPos(), self:GetPos() + forward, Color(100, 200, 255), true)
    render.DrawWireframeSphere(self:GetPos(), 32, 10, 10, Color(100, 200, 255), true)
  end

  return
end

function ENT:Initialize()
  self:SetModel("models/editor/playerstart.mdl")
  self:SetMoveType(MOVETYPE_NONE)
  self:SetSolid(SOLID_NONE)
  self:SetNotSolid(true)
  self:DrawShadow(false)
end

function ENT:KeyValue(key, value)
  if key == "spawnid" then
    self:SetSpawnID(value)
  end
end

--- Returns the position a player should be placed at when spawning here.
--- @return Vector
function ENT:GetSpawnPosition()
  return self:GetPos() + Vector(0, 0, 10)
end

--- Returns the angle a player faces when spawning here.
--- @return Angle
function ENT:GetSpawnAngles()
  return self:GetAngles()
end
