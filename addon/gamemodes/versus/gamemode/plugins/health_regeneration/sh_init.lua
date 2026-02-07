local PLUGIN = PLUGIN

PLUGIN.name = "Health Regeneration"
PLUGIN.description = "Gradual health regeneration system that rewards tactical play"

versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("cl_hooks.lua")

-- Time in seconds before regeneration starts after taking damage
PLUGIN.regenDelay = 10

-- Health regenerated per second
PLUGIN.regenRate = 1

-- Maximum health percentage that can be regenerated (0-1)
-- Set to 1.0 to allow full health regen, 0.75 for 75% max, etc.
PLUGIN.maxRegenPercent = 0.6

-- Regeneration sound (set to false to disable)
PLUGIN.regenSound = false -- "items/medshot4.wav"

-- Regeneration sound interval in seconds
PLUGIN.regenSoundInterval = 3
