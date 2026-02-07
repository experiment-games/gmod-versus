local PLUGIN = PLUGIN

PLUGIN.name = "Contracts System"
PLUGIN.description =
"Contracts for players to complete objectives for rewards. Interacts with the extraction plugin and rewards plugin."

PLUGIN.bitCountContractAmount = 5
PLUGIN.bitCountContractID = 32

-- Enemy location enumerations
PLUGIN.ENEMY_NEAR_SPAWN = 0
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR = 1
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE = 2
PLUGIN.ENEMY_NEAR_EXTRACTION = 3

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")
