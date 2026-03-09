local UNIT = UNIT

UNIT.libraryKey = "resource"
UNIT.definitions = UNIT.definitions or {}

versus.includePrefixed("sv_hooks.lua")

--- Register a drainable resource type. Call this from a plugin/unit sh_init.lua
--- before players connect so that resources are initialised on spawn.
--- @param key string Unique resource identifier (e.g. "stamina", "battery")
--- @param options table Options: max, rechargeRate (per second), rechargeDelay (seconds after last drain)
function UNIT.define(key, options)
  UNIT.definitions[key] = {
    max = options.max or 100,
    rechargeRate = options.rechargeRate or 5,
    rechargeDelay = options.rechargeDelay or 2,
  }
end

--- Returns the NW variable key used to network a resource value on a player.
--- @param key string
--- @return string
function UNIT.nwKey(key)
  return "VersusRes_" .. key
end

--- Returns the definition table for a resource type, or nil if not defined.
--- @param key string
--- @return table|nil
function UNIT.getDefinition(key)
  return UNIT.definitions[key]
end

--- Returns the maximum value for a registered resource.
--- @param key string
--- @return number
function UNIT.getMax(key)
  local def = UNIT.definitions[key]
  return def and def.max or 0
end

--- Returns the current value of a resource for a player.
--- Works on both server and client (reads NW float).
--- @param player Player
--- @param key string
--- @return number
function UNIT.get(player, key)
  local def = UNIT.definitions[key]
  if not def then return 0 end
  return player:GetNWFloat(UNIT.nwKey(key), def.max)
end

--- Returns true when the resource value is at or below zero.
--- @param player Player
--- @param key string
--- @return boolean
function UNIT.isDepleted(player, key)
  return UNIT.get(player, key) <= 0
end

--- Returns true when the resource is at its maximum value.
--- @param player Player
--- @param key string
--- @return boolean
function UNIT.isFull(player, key)
  local def = UNIT.definitions[key]
  if not def then return true end
  return UNIT.get(player, key) >= def.max
end
