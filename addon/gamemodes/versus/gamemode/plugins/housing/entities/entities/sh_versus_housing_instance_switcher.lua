local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Housing Instance Switcher"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Model = "models/props_lab/eyescanner.mdl"
ENT.PhysgunDisabled = true

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "InstanceTargetName")
  self:NetworkVar("String", 1, "InstanceName")
end

if not SERVER then
  function ENT:Draw()
    self:DrawModel()

    local instanceName = self:GetInstanceName()
    if (instanceName and instanceName ~= "") then
      local min, max = self:GetRenderBounds()
      local pos = self:GetPos() + Vector(0, 0, max.z + 2)
      local ang = self:GetAngles()
      ang:RotateAroundAxis(ang:Up(), 90)
      ang:RotateAroundAxis(ang:Forward(), 90)

      cam.Start3D2D(pos, ang, 0.1)
      draw.SimpleText(instanceName, "VersusHeading2", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
      cam.End3D2D()
    end
  end

  return
end

function ENT:KeyValue(key, value)
  key = key:lower()

  if (key == "instancetargetname") then
    self:SetInstanceTargetName(value)
  end

  if (key == "instancename") then
    self:SetInstanceName(value)
  end
end

function ENT:Initialize()
  self:SetModel(self.Model)
  self:SetSolid(SOLID_BBOX) -- Must use SOLID_BBOX as the eyescanner has no physics model
  self:SetMoveType(MOVETYPE_NONE)
  self:SetUseType(SIMPLE_USE)

  local phys = self:GetPhysicsObject()
  if IsValid(phys) then
    phys:EnableMotion(false)
  end
end

function ENT:Use(activator, caller)
  self:EmitSound("buttons/button19.wav")

  if not IsValid(activator) or not activator:IsPlayer() then
    return
  end

  local connectedTarget = ents.FindByName(self:GetInstanceTargetName())
  local instanceTarget = connectedTarget[1]

  if (#connectedTarget == 0 or not IsValid(instanceTarget)) then
    error("No valid entity found with name: " .. self:GetInstanceTargetName())
    return
  end

  if (#connectedTarget > 1) then
    ErrorNoHalt("Multiple entities found with name: " .. self:GetInstanceTargetName() .. ". Using first one found.")
  end

  -- Move the player to the target's position and angles
  activator:SetPos(instanceTarget:GetPos())
  activator:SetEyeAngles(instanceTarget:GetAngles())

  -- Set instance to a variant of the one specified on the target, so each player in the same room has their own instance.
  -- TODO: Add invite system later so players can choose to be in the same instance if they want
  local instanceID = instanceTarget:GetInstanceID()

  -- If the instance ID is empty then we are going back to the main world, so we remove them from their instance.
  if (instanceID == "") then
    versus.instance.removePlayer(activator)
    return
  end

  local uniqueInstanceID = instanceID .. "_" .. tostring(activator:SteamID())

  versus.instance.addPlayer(activator, uniqueInstanceID)
end
