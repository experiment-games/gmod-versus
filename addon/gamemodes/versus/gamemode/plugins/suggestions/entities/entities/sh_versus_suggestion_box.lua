local ENT           = ENT

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Suggestion Box"
ENT.Author          = ""
ENT.Spawnable       = false
ENT.AdminOnly       = true
ENT.Model           = "models/props/cs_office/file_box.mdl"
ENT.PhysgunDisabled = true

if CLIENT then
  function ENT:Draw()
    self:DrawModel()

    local boardTitle = "Suggestion Box"

    if boardTitle and boardTitle ~= "" then
      local min, max = self:GetRenderBounds()
      local pos = self:GetPos() + self:GetUp() * (max.z + 2)
      local ang = self:GetAngles()

      ang:RotateAroundAxis(ang:Up(), 90)
      ang:RotateAroundAxis(ang:Forward(), 90)

      cam.Start3D2D(pos, ang, 0.1)
      draw.SimpleText(
        boardTitle,
        "VersusHeading2",
        0, 0,
        Color(220, 230, 240),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )
      cam.End3D2D()
    end
  end

  return
end

function ENT:Initialize()
  self:SetModel(self.Model)
  self:SetSolid(SOLID_OBB)
  self:SetMoveType(MOVETYPE_NONE)
  self:SetUseType(SIMPLE_USE)
  self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
end

function ENT:Use(activator, caller)
  if versus.util.throttled("suggestion_box_use", 1, activator) then
    return
  end

  if not IsValid(activator) or not activator:IsPlayer() then
    return
  end

  self:EmitSound("physics/cardboard/cardboard_box_impact_soft4.wav")

  net.Start("versus.suggestions.open")
  net.Send(activator)
end
