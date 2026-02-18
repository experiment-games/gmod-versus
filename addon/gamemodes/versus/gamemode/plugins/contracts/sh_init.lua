local PLUGIN = PLUGIN

PLUGIN.name = "Contracts System"
PLUGIN.libraryKey = "contracts"
PLUGIN.description =
"Contracts for players to complete objectives for rewards. Interacts with the extraction plugin and rewards plugin."

PLUGIN.convarCombatServers = CreateConVar(
  "versus_combat_servers",
  "",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "Comma-separated list of combat servers to advertise on the contract board. Each entry should be in the format ip:port"
)

-- Seconds before the player can select a new contract
PLUGIN.respawnDelay = 10

PLUGIN.bitCountContractAmount = 5
PLUGIN.bitCountContractID = 32

-- Number of contracts shown at a time on the selection screen
PLUGIN.displayContractCount = 5

-- Enemy location enumerations
PLUGIN.ENEMY_NEAR_SPAWN = 0
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR = 1
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE = 2
PLUGIN.ENEMY_NEAR_EXTRACTION = 3

PLUGIN.DIFFICULTY_EASY = 1
PLUGIN.DIFFICULTY_MEDIUM = 2
PLUGIN.DIFFICULTY_HARD = 3

PLUGIN.REWARD_LOW = 1
PLUGIN.REWARD_MEDIUM = 2
PLUGIN.REWARD_HIGH = 3

PLUGIN.COMBAT_STYLE_PVE = 1
PLUGIN.COMBAT_STYLE_PVP = 2
PLUGIN.COMBAT_STYLE_MIXED = 3

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")
