local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Versus Radiation Info"
ENT.Author = ""
ENT.Category = "Versus"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.VersusWritesToManifest = true

if not SERVER then
  return
end

function ENT:Initialize()
  self:SetModel("models/editor/playerstart.mdl")
  self:SetSolid(SOLID_NONE)
  self:SetMoveType(MOVETYPE_NONE)
  self:SetNoDraw(true)
  self:DrawShadow(false)

  -- Mark the map as irradiated so all server and client code can query it.
  SetGlobalBool("VersusRadiationMap", true)
end
