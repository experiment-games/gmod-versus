local PLUGIN = PLUGIN

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Spawn Point"
ENT.Author = ""
ENT.Category = "Versus"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "SpawnPointName")
  self:NetworkVar("Bool", 0, "Enabled")
end

function ENT:Initialize()
  if (SERVER) then
    self:SetModel("models/props_combine/combine_intmonitor001.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetNotSolid(true)

    -- Make it invisible but keep it for debugging in map editor
    self:SetNoDraw(true)
    self:DrawShadow(false)

    -- Default values
    self:SetSpawnPointName("Spawn Point")
    self:SetEnabled(true)
  end
end

if (SERVER) then
  function ENT:KeyValue(key, value)
    if (key == "SpawnPointName") then
      self:SetSpawnPointName(value)
    elseif (key == "Enabled") then
      self:SetEnabled(tobool(value))
    end
  end

  -- Get spawn position (slightly above entity to prevent stuck in ground)
  function ENT:GetSpawnPosition()
    return self:GetPos() + Vector(0, 0, 10)
  end

  -- Get spawn angles
  function ENT:GetSpawnAngles()
    return self:GetAngles()
  end
end

if (CLIENT) then
  -- Only draw in map editor or with developer mode
  function ENT:Draw()
    if (GetConVar("developer"):GetInt() == 0) then
      return
    end

    self:DrawModel()

    local pos = self:GetPos() + Vector(0, 0, 50)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    local distance = LocalPlayer():GetPos():Distance(self:GetPos())

    if (distance > 1024) then
      return
    end

    cam.Start3D2D(pos, ang, 0.15)
    local color = self:GetEnabled() and Color(100, 255, 100, 255) or Color(255, 100, 100, 255)
    draw.SimpleText(self:GetSpawnPointName(), "DermaLarge", 0, 0, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("[Spawn Point]", "DermaDefault", 0, 40, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()

    -- Draw directional arrow
    local forward = self:GetForward() * 50
    render.DrawLine(self:GetPos(), self:GetPos() + forward, color, true)

    -- Draw sphere at spawn point
    render.DrawWireframeSphere(self:GetPos(), 32, 10, 10, color, true)
  end
end
