local PLUGIN = PLUGIN

DEFINE_BASECLASS("base_ai")

ENT.PopulateEntityInfo = true

function ENT:Draw()
  self:DrawModel()

  -- Draw the NPC's name above their head
end

function ENT:Think()
  if ((self.nextAnimCheck or 0) < CurTime()) then
    self:SetAnim()
    self.nextAnimCheck = CurTime() + 2
  end

  self:SetNextClientThink(CurTime() + 0.25)

  return true
end

function ENT:OnPopulateEntityInfo(info)
  info:addTitle(self:GetDisplayName())

  local descriptionText = self:GetDescription()

  if (descriptionText ~= "") then
    info:addDescription(self:GetDescription())
  end
end
