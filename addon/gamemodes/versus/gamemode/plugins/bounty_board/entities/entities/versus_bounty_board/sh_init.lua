local ENT           = ENT

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Bounty Board"
ENT.Author          = ""
ENT.Spawnable       = false
ENT.AdminOnly       = true
ENT.Model           = "models/props_lab/corkboard002.mdl"
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "BoardTitle")
end

if CLIENT then
  ENT.RenderGroup = RENDERGROUP_BOTH

  function ENT:Draw()
    self:DrawModel()

    local boardTitle = self:GetBoardTitle()

    if boardTitle and boardTitle ~= "" then
      local min, max = self:GetRenderBounds()
      local pos = self:GetPos() + self:GetUp() * (max.z + 2)
      local ang = self:GetAngles()

      -- Nudge slightly forward so the text floats in front of the board
      pos = pos + ang:Forward() * 1

      ang:RotateAroundAxis(ang:Up(), 180)
      ang:RotateAroundAxis(ang:Forward(), 90)

      cam.Start3D2D(pos, ang, 0.1)
      draw.SimpleText(
        boardTitle,
        "VersusHeading2",
        0, 0,
        Color(220, 200, 140),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )
      cam.End3D2D()
    end
  end

  return
end

function ENT:KeyValue(key, value)
  key = key:lower()

  if key == "boardtitle" then
    self:SetBoardTitle(value)
  end
end

function ENT:Initialize()
  self:SetModel(self.Model)
  self:SetSolid(SOLID_OBB)
  self:SetMoveType(MOVETYPE_NONE)
  self:SetUseType(SIMPLE_USE)
  self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
end

function ENT:Use(activator, caller)
  if versus.util.throttled("bounty_board_use", 1, activator) then
    return
  end

  if not IsValid(activator) or not activator:IsPlayer() then
    return
  end

  self:EmitSound("physics/cardboard/cardboard_box_impact_soft4.wav")

  net.Start("versus.bounty_board.open")
  net.Send(activator)
end
