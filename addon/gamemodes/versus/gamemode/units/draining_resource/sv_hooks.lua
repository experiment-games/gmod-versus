local UNIT = UNIT

local TICK = 0.1 -- seconds between resource processing ticks

--- Initialise all defined resources for a player by setting them to their maximum value.
--- @param player Player
function UNIT.initPlayer(player)
  player._VersusResLastDrain = player._VersusResLastDrain or {}

  for key, def in pairs(UNIT.definitions) do
    player:SetNWFloat(UNIT.nwKey(key), def.max)
    player._VersusResLastDrain[key] = 0
  end
end

--- Set the current value of a resource for a player (server authority).
--- @param player Player
--- @param key string
--- @param value number
function UNIT.set(player, key, value)
  local def = UNIT.definitions[key]
  if not def then return end
  player:SetNWFloat(UNIT.nwKey(key), math.Clamp(value, 0, def.max))
end

--- Drain a resource by a given amount and record the drain time (used for recharge delay).
--- @param player Player
--- @param key string
--- @param amount number
--- @return number new value
function UNIT.drain(player, key, amount)
  local current = UNIT.get(player, key)
  local new = math.max(0, current - amount)
  player:SetNWFloat(UNIT.nwKey(key), new)
  player._VersusResLastDrain = player._VersusResLastDrain or {}
  player._VersusResLastDrain[key] = CurTime()
  return new
end

--- Recharge a resource by a given amount, capped at the maximum.
--- @param player Player
--- @param key string
--- @param amount number
--- @return number new value
function UNIT.recharge(player, key, amount)
  local def = UNIT.definitions[key]
  if not def then return 0 end
  local current = UNIT.get(player, key)
  local new = math.min(def.max, current + amount)
  player:SetNWFloat(UNIT.nwKey(key), new)
  return new
end

-- Process automatic recharge for all alive players.
function UNIT.hook:Think()
  if versus.util.throttled("resource_think", TICK) then return end

  local now = CurTime()

  for _, player in player.Iterator() do
    if not player._VersusInitialized then continue end

    local resLastDrain = player._VersusResLastDrain

    if not resLastDrain then continue end

    for key, def in pairs(UNIT.definitions) do
      local lastDrain = resLastDrain[key] or 0
      if now - lastDrain >= def.rechargeDelay then
        local current = UNIT.get(player, key)
        if current < def.max then
          UNIT.recharge(player, key, def.rechargeRate * TICK)
        end
      end
    end
  end
end

-- Initialise resources when a player spawns or first connects.
function UNIT.hook:PlayerSpawn(player)
  UNIT.initPlayer(player)
end

function UNIT.hook:PlayerInitialized(player)
  UNIT.initPlayer(player)
end
