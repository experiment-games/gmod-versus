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
  self:SetModel("models/editor/playerstart.mdl")
  self:SetMoveType(MOVETYPE_NONE)
  self:SetSolid(SOLID_NONE)
  self:SetNotSolid(true)

  self:DrawShadow(false)
end
