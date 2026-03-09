local PLUGIN = PLUGIN

PLUGIN.name = "Stamina"
PLUGIN.libraryKey = "stamina"
PLUGIN.description = "Stamina system that drains while running and blocks sprinting when empty."

-- Resource key used with the draining_resource unit
PLUGIN.resourceKey = "stamina"

-- Stamina drained per second while running
PLUGIN.drainRate = 20

-- Speed above which a player is considered to be running (in units/s)
-- Using a fraction of the configured run speed so a slow walk does not drain stamina.
PLUGIN.runThreshold = 0.75

-- Define the stamina resource (units are fully loaded before plugins run).
versus.resource.define(PLUGIN.resourceKey, {
  max = 100,
  rechargeRate = 12,
  rechargeDelay = 1.5,
})

versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("cl_hooks.lua")
