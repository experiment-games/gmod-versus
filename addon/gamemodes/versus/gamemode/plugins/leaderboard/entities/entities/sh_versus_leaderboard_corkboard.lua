local ENT           = ENT

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Leaderboard"
ENT.Author          = ""
ENT.Spawnable       = false
ENT.AdminOnly       = true
ENT.Model           = "models/props/cs_office/offcorkboarda.mdl"
ENT.PhysgunDisabled = true

if CLIENT then
  ENT.RenderGroup = RENDERGROUP_BOTH

  function ENT:Draw()
    self:DrawModel()

    local boardTitle = "Leaderboard"
    local min, max = self:GetRenderBounds()
    local pos = self:GetPos() + self:GetUp() * (max.z + 2)
    local ang = self:GetAngles()

    -- Nudge slightly forward so text sits in front of the wall
    pos = pos + ang:Forward() * 1

    ang:RotateAroundAxis(ang:Up(), 180)
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
  if versus.util.throttled("leaderboard_corkboard_use", 1, activator) then
    return
  end

  if not IsValid(activator) or not activator:IsPlayer() then
    return
  end

  self:EmitSound("physics/cardboard/cardboard_box_impact_soft4.wav")

  net.Start("versus.leaderboard.open")
  net.Send(activator)
end
