local PLUGIN = PLUGIN

PLUGIN.name = "Contracts System"
PLUGIN.description =
"Contracts for players to complete objectives for rewards. Interacts with the extraction plugin and rewards plugin."

PLUGIN.setupTimeInSeconds = 10
PLUGIN.convarCombatServers = CreateConVar(
  "versus_combat_servers",
  "",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "Comma-separated list of combat servers to advertise on the contract board. Each entry should be in the format ip:port"
)

PLUGIN.bitCountContractAmount = 5
PLUGIN.bitCountContractID = 32

-- Enemy location enumerations
PLUGIN.ENEMY_NEAR_SPAWN = 0
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR = 1
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE = 2
PLUGIN.ENEMY_NEAR_EXTRACTION = 3

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("sv_new.lua")

-- These must come after sv_new since that contains our new contract system functions.
versus.includeDirectory(PLUGIN.fullPath .. "/contracts")
versus.includeDirectory(PLUGIN.fullPath .. "/handlers")
