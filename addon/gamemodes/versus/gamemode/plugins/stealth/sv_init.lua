local PLUGIN = PLUGIN

util.AddNetworkString("versus.stealth.requestToggle")

--- Returns true if the player currently has a Stealth Camo item equipped.
--- @param player Player
--- @return boolean
function PLUGIN.hasStealthCamoEquipped(player)
  local equippedItems = versus.equipment.getEquippedItems(player)

  for _, item in pairs(equippedItems) do
    if (item.itemID == "stealth_camo") then
      return true
    end
  end

  return false
end

--- Returns true if the player currently has a Thermal Vision item equipped.
--- @param player Player
--- @return boolean
function PLUGIN.hasThermalVisionEquipped(player)
  local equippedItems = versus.equipment.getEquippedItems(player)

  for _, item in pairs(equippedItems) do
    if (item.itemID == "thermal_vision") then
      return true
    end
  end

  return false
end

--- Returns true if the player's stealth camouflage is currently active.
--- @param player Player
--- @return boolean
function PLUGIN.isStealthActive(player)
  return player:GetNWBool(PLUGIN.nwKeyStealthActive, false)
end

--- Enables stealth camouflage for a player: makes them invisible and untargetable by NPCs.
--- @param player Player
function PLUGIN.enableStealth(player)
  if (PLUGIN.isStealthActive(player)) then
    return
  end

  player:SetNWBool(PLUGIN.nwKeyStealthActive, true)
  player:SetRenderMode(RENDERMODE_TRANSCOLOR)
  player:SetColor(Color(255, 255, 255, 0))
  player:SetNoTarget(true)
  player:EmitSound("versus/night_vision_on.wav")
end

--- Disables stealth camouflage for a player: restores visibility and NPC targeting.
--- @param player Player
function PLUGIN.disableStealth(player)
  if (not PLUGIN.isStealthActive(player)) then
    return
  end

  player:SetNWBool(PLUGIN.nwKeyStealthActive, false)
  player:SetRenderMode(RENDERMODE_NORMAL)
  player:SetColor(Color(255, 255, 255, 255))
  player:SetNoTarget(false)
  player:EmitSound("versus/night_vision_off.wav")
end

--- Breaks stealth on a player and alerts nearby NPCs to their position via a sound hint.
--- @param player Player
function PLUGIN.breakStealth(player)
  if (not PLUGIN.isStealthActive(player)) then
    return
  end

  PLUGIN.disableStealth(player)

  -- Emit a sound hint at the player's position so nearby NPCs investigate
  sound.EmitHint(SOUND_COMBAT, player:GetPos(), 512, 1.0, player)
end

--[[
  Think: proximity detection for stealthed players
--]]

-- Seconds between each proximity check per player to avoid running FindInSphere every frame
local STEALTH_CHECK_INTERVAL = 0.1
local BATTERY_TICK = 0.1

function PLUGIN.hook:Think()
  for _, player in player.Iterator() do
    if (not player._VersusInitialized) then
      continue
    end

    -- Battery drain for stealth camouflage
    if (PLUGIN.isStealthActive(player)) then
      if (not versus.util.throttled("stealth_battery_drain", BATTERY_TICK, player)) then
        -- Drain battery while stealth is active
        versus.resource.drain(player, PLUGIN.batteryKey, PLUGIN.batteryDrainRateStealth * BATTERY_TICK)

        -- Force-disable stealth when battery runs out
        if (versus.resource.isDepleted(player, PLUGIN.batteryKey)) then
          PLUGIN.breakStealth(player)
        end
      end
    end

    -- Battery drain for thermal vision
    local thermalActive = player:GetNWBool(PLUGIN.nwKeyThermalActive, false)

    if (thermalActive) then
      if (not versus.util.throttled("thermal_battery_drain", BATTERY_TICK, player)) then
        versus.resource.drain(player, PLUGIN.batteryKey, PLUGIN.batteryDrainRateThermal * BATTERY_TICK)

        -- Force-disable thermal vision when battery runs out
        if (versus.resource.isDepleted(player, PLUGIN.batteryKey)) then
          player:SetNWBool(PLUGIN.nwKeyThermalActive, false)
        end
      end
    elseif (not thermalActive and PLUGIN.hasThermalVisionEquipped(player) and
        not versus.resource.isDepleted(player, PLUGIN.batteryKey)) then
      -- Restore thermal vision once battery has recharged and the item is still equipped
      player:SetNWBool(PLUGIN.nwKeyThermalActive, true)
    end

    if (not PLUGIN.isStealthActive(player)) then
      continue
    end

    if (not versus.util.throttled("stealth_check", STEALTH_CHECK_INTERVAL, player)) then
      -- Break stealth when the player is too close to an NPC
      local nearbyNPCs = ents.FindInSphere(player:GetPos(), PLUGIN.detectionRadius)

      for _, npc in ipairs(nearbyNPCs) do
        if (not IsValid(npc) or not npc:IsNPC()) then
          continue
        end

        PLUGIN.breakStealth(player)
        break
      end
    end
  end
end

-- Break stealth when a stealthed player makes a footstep audible to nearby NPCs.
function PLUGIN.hook:PlayerFootstep(player, footstepPos, foot, footstepSound, volume, filter)
  if (not PLUGIN.isStealthActive(player)) then
    return
  end

  local nearbyNPCs = ents.FindInSphere(footstepPos, PLUGIN.noiseDetectionRadius)

  for _, npc in ipairs(nearbyNPCs) do
    if (not IsValid(npc) or not npc:IsNPC()) then
      continue
    end

    PLUGIN.breakStealth(player)
    return
  end
end

--[[
  Clean up stealth state when a player dies or disconnects
--]]

function PLUGIN.hook:PostPlayerDeath(player)
  PLUGIN.disableStealth(player)
end

function PLUGIN.hook:PlayerDisconnected(player)
  PLUGIN.disableStealth(player)
end

--[[
  Net Messages
--]]

-- Client requests to activate or deactivate stealth camo
net.Receive("versus.stealth.requestToggle", function(len, player)
  local activate = net.ReadBool()

  if (activate) then
    if (not PLUGIN.hasStealthCamoEquipped(player)) then
      return
    end

    -- Block activation when battery is empty
    if (versus.resource.isDepleted(player, PLUGIN.batteryKey)) then
      return
    end

    PLUGIN.enableStealth(player)
  else
    PLUGIN.disableStealth(player)
  end
end)
