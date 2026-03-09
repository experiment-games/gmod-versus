local PLUGIN = PLUGIN

local TICK = 0.1 -- seconds between stamina processing ticks

-- Track whether a player's run speed has been overridden due to depletion.
-- key: player entity → true/false
local overriddenSpeeds = {}

--- Apply or remove the run-speed override based on current depletion state.
--- @param player Player
local function applySpeedOverride(player)
  local depleted = versus.resource.isDepleted(player, PLUGIN.resourceKey)
  local wasOverridden = overriddenSpeeds[player]

  if depleted and not wasOverridden then
    player:SetRunSpeed(versus.config["Walk Speed"])
    overriddenSpeeds[player] = true
  elseif not depleted and wasOverridden then
    player:SetRunSpeed(versus.config["Run Speed"])
    overriddenSpeeds[player] = false
  end
end

-- Think: drain stamina while running, and manage speed overrides.
function PLUGIN.hook:Think()
  if versus.util.throttled("stamina_think", TICK) then return end

  local walkSpeed = versus.config["Walk Speed"]
  local runThreshold = walkSpeed * PLUGIN.runThreshold

  for _, player in player.Iterator() do
    if not player._VersusInitialized or not player:Alive() then continue end

    local speed = player:GetVelocity():Length2D()

    -- Drain while moving faster than the threshold (i.e. actually running).
    if speed > runThreshold and not versus.resource.isDepleted(player, PLUGIN.resourceKey) then
      versus.resource.drain(player, PLUGIN.resourceKey, PLUGIN.drainRate * TICK)
    end

    applySpeedOverride(player)
  end
end

-- Clean up override tracking when a player disconnects or dies.
function PLUGIN.hook:PlayerDisconnected(player)
  overriddenSpeeds[player] = nil
end

function PLUGIN.hook:PostPlayerDeath(player)
  overriddenSpeeds[player] = nil
end

-- Restore run speed on spawn (resource unit already sets value to max on spawn).
function PLUGIN.hook:PlayerSpawn(player)
  overriddenSpeeds[player] = nil
  player:SetRunSpeed(versus.config["Run Speed"])
  applySpeedOverride(player)
end
