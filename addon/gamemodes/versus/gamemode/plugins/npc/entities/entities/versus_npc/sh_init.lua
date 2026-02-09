local PLUGIN = PLUGIN

DEFINE_BASECLASS("base_ai")

ENT.Base = "base_ai"
ENT.Type = "ai"
ENT.PrintName = "Versus NPC"
ENT.Author = "Versus"
ENT.Category = "Versus"

ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.IsPassiveNPC = true

function ENT:SetupDataTables()
  self:NetworkVar("String", "DisplayName")
  self:NetworkVar("String", "Description")
  self:NetworkVar("String", "NPCID")
end

function ENT:SetAnim()
  if (self.versusCachedIdleSequence) then
    return self:ResetSequence(self.versusCachedIdleSequence)
  end

  local sequenceList = self:GetSequenceList()

  if (not sequenceList) then
    -- May happen on invalid model
    return
  end

  for k, v in ipairs(self:GetSequenceList()) do
    if (v:lower():find("idle") and v ~= "idlenoise") then
      self.versusCachedIdleSequence = k
      return self:ResetSequence(k)
    end
  end

  if (self:GetSequenceCount() > 1) then
    self:ResetSequence(4)
  end
end
