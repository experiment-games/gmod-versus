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

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

if (not SERVER) then
  function ENT:Draw()
    if (GetConVar("developer"):GetInt() == 0) then
      return
    end

    self:DrawModel()
  end

  return
end

function ENT:Initialize()
  self:SetModel("models/props_junk/PopCan01a.mdl")
  self:SetMoveType(MOVETYPE_NONE)
  self:SetSolid(SOLID_NONE)
  self:SetNotSolid(true)

  -- Make it invisible but keep it for debugging in map editor
  self:SetNoDraw(true)
  self:DrawShadow(false)
end
