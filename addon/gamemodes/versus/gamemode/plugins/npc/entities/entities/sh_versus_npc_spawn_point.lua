local UNIT = UNIT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "NPC Spawn Point"
ENT.Author = ""
ENT.Category = "Versus"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Editable = true

ENT.VersusWritesToManifest = true

function ENT:SetupDataTables()
  -- ArenaID: when set, this spawn point belongs exclusively to the named endurance arena
  -- (must match the SpawnID of the versus_squad_spawn for that arena).
  -- Leave empty for normal non-endurance NPC spawn points.
  self:NetworkVar("String", 0, "ArenaID")
  self:SetArenaID("")
end

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

if (not SERVER) then
  function ENT:Draw()
    if (GetConVar("developer"):GetInt() == 0) then
      return
    end

    self:DrawModel()

    local arenaID = self:GetArenaID()

    if arenaID == "" then return end

    local pos = self:GetPos() + Vector(0, 0, 40)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    if LocalPlayer():GetPos():Distance(self:GetPos()) > 1024 then
      return
    end

    cam.Start3D2D(pos, ang, 0.1)

    draw.SimpleText(
      "[Arena: " .. arenaID .. "]",
      "VersusDefaultOutlined",
      0, 0,
      Color(255, 180, 50, 255),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    cam.End3D2D()
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
  if key == "arenaid" then
    self:SetArenaID(value)
  end
end
