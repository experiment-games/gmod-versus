local PLUGIN = PLUGIN
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

function ENT:GetConnectedTarget()
  if (self._CachedInstanceTarget) then
    return self._CachedInstanceTarget
  end

  local targetName = self:GetInstanceTargetName()
  local connectedTarget = {}

  if (SERVER) then
    connectedTarget = ents.FindByName(targetName)
  else
    for _, ent in ipairs(ents.FindByClass("versus_housing_instance_target")) do
      if (ent:GetTargetName() == targetName) then
        table.insert(connectedTarget, ent)
      end
    end
  end

  local instanceTarget = connectedTarget[1]

  if (#connectedTarget == 0 or not IsValid(instanceTarget)) then
    error("No valid entity found with name: " .. targetName)
    return
  end

  if (#connectedTarget > 1) then
    ErrorNoHalt("Multiple entities found with name: " .. targetName .. ". Using first one found.")
  end

  self._CachedInstanceTarget = instanceTarget

  return instanceTarget
end

if not SERVER then
  function ENT:Draw()
    self:DrawModel()

    local instanceName = self:GetInstanceName()
    local target = self:GetConnectedTarget()

    if (instanceName and instanceName ~= "" and IsValid(target)) then
      local min, max = self:GetRenderBounds()
      local pos = self:GetPos() + Vector(0, 0, max.z + 4) -- Position above the entity
      local ang = self:GetAngles()
      ang:RotateAroundAxis(ang:Up(), 90)
      ang:RotateAroundAxis(ang:Forward(), 90)

      local isMainWorld = target:GetInstanceID() == ""
      local owned = isMainWorld or PLUGIN.playerOwnsRoom(target:GetTargetName())
      local color = owned and Color(0, 255, 0) or Color(255, 0, 0)

      cam.Start3D2D(pos, ang, 0.1)

      local y = 0
      local textWidth, textHeight = draw.SimpleText(
        instanceName,
        "VersusHeading2",
        0,
        y,
        color,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )
      y = y + (textHeight * .7)

      if (owned) then
        draw.SimpleText("[Owned]", "VersusDefaultOutlined", 0, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
      else
        local price = target:GetPriceScale() * PLUGIN.baseRoomPrice
        draw.SimpleText(
          "Price: " .. versus.util.formatMoney(price),
          "VersusDefaultOutlined",
          0,
          y,
          color,
          TEXT_ALIGN_CENTER,
          TEXT_ALIGN_CENTER
        )
      end

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
  if (versus.util.throttled("housing_instance_switcher_use", 1, activator)) then
    return
  end

  self:EmitSound("buttons/button18.wav")

  if not IsValid(activator) or not activator:IsPlayer() then
    return
  end

  local instanceTarget = self:GetConnectedTarget()
  local targetName = instanceTarget:GetTargetName()
  local instanceID = instanceTarget:GetInstanceID()
  local isMainWorld = instanceID == ""

  if (not isMainWorld and not PLUGIN.playerOwnsRoom(activator, targetName)) then
    net.Start("versus.housing.showRoomPurchaseScreen")
    net.WriteString(targetName)
    net.WriteFloat(instanceTarget:GetPriceScale())
    net.Send(activator)
    return
  end

  -- Move the player to the target's position and angles
  activator:SetPos(instanceTarget:GetPos())
  activator:SetEyeAngles(instanceTarget:GetAngles())

  activator:EmitSound("buttons/button19.wav")

  -- Set instance to a variant of the one specified on the target, so each player in the same room has their own instance.
  -- TODO: Add invite system later so players can choose to be in the same instance if they want
  -- If the instance ID is empty then we are going back to the main world, so we remove them from their instance.
  if (isMainWorld) then
    versus.instance.removePlayer(activator)

    hook.Run("PlayerSwitchedFromInstance", activator, instanceID)

    return
  end

  local uniqueInstanceID = instanceID .. "_" .. tostring(activator:SteamID64())

  versus.instance.addPlayer(activator, uniqueInstanceID)

  hook.Run("PlayerSwitchedToInstance", activator, uniqueInstanceID, instanceID)
end
