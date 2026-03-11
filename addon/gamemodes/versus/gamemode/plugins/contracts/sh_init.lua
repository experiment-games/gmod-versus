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

-- Seconds a player must wait before they can re-roll their contracts again
PLUGIN.rerollContractTimeout = 60

-- Fee charged to the player for re-rolling their contracts
PLUGIN.rerollFee = 1550

PLUGIN.bitCountContractAmount = 5
PLUGIN.bitCountContractID = 32

-- Number of contracts shown at a time on the selection screen
PLUGIN.displayContractCount = 3

-- Enemy location enumerations
PLUGIN.ENEMY_NEAR_SPAWN = 0
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR = 1
PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE = 2
PLUGIN.ENEMY_NEAR_EXTRACTION = 3


versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

-- Exclude contract items
function PLUGIN.hook:VersusShouldExcludeItemFromPool(item)
  if (item.isContractItem) then
    return true
  end
end
