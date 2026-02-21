local PLUGIN = PLUGIN
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Combat Server Switcher"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Model = "models/versus/corkboard001.mdl"
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "BoardTitle")
end

if not SERVER then
  ENT.RenderGroup = RENDERGROUP_BOTH

  function ENT:Draw()
    self:DrawModel()

    local boardTitle = self:GetBoardTitle()

    if (boardTitle and boardTitle ~= "") then
      local min, max = self:GetRenderBounds()
      local pos = self:GetPos() + self:GetUp() * (max.z + 2) -- Position above the entity
      local ang = self:GetAngles()

      -- Also move it forward a bit, so its not inside the wall
      pos = pos + ang:Forward() * 1

      ang:RotateAroundAxis(ang:Up(), 90)
      ang:RotateAroundAxis(ang:Forward(), 90)


      cam.Start3D2D(pos, ang, 0.1)

      draw.SimpleText(
        boardTitle,
        "VersusHeading2",
        0,
        0,
        Color(220, 230, 240),
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

  if (key == "boardtitle") then
    self:SetBoardTitle(value)
  end
end

function ENT:Initialize()
  self:SetModel(self.Model)
  self:SetSolid(SOLID_OBB) -- Must use SOLID_OBB as the the model has no physics model
  self:SetMoveType(MOVETYPE_NONE)
  self:SetUseType(SIMPLE_USE)
  self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
end

function ENT:Use(activator, caller)
  if (versus.util.throttled("combat_server_switcher_use", 1, activator)) then
    return
  end

  self:EmitSound("physics/cardboard/cardboard_box_impact_soft4.wav")

  if not IsValid(activator) or not activator:IsPlayer() then
    return
  end

  -- Get the list of combat servers from the convar
  local serverListConVar = GetConVar("versus_combat_servers")
  local serverList = serverListConVar and serverListConVar:GetString() or ""

  if (serverList == "") then
    activator:ChatPrint("No combat servers are currently configured.")
    return
  end

  -- Send the server list to the client to show the selection screen
  net.Start("versus.combat.showServerSelectionScreen")
  net.WriteString(serverList)
  net.Send(activator)
end
