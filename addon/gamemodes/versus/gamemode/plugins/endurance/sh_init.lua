local PLUGIN = PLUGIN

PLUGIN.name = "Endurance"
PLUGIN.libraryKey = "endurance"
PLUGIN.description = "Endurance mode: players hold out against waves of enemies for as long as they can."

-- Squad size constraints.
PLUGIN.SQUAD_MIN_SIZE = 2
PLUGIN.SQUAD_MAX_SIZE = 4

-- Convar holding the address of the endurance server (shown in the hideout for matchmaking).
PLUGIN.convarEnduranceServer = CreateConVar(
  "versus_endurance_server",
  "",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "Address of the endurance server players are sent to after matchmaking (ip:port)"
)

-- Wave difficulty scaling per wave number.
PLUGIN.WAVE_HEALTH_SCALE = 0.25 -- +25% health per wave
PLUGIN.WAVE_SPEED_SCALE = 0.05  -- +5%  speed  per wave

-- Seconds between waves.
PLUGIN.WAVE_INTERVAL = 30

function PLUGIN.hook:PlayerShouldSelectContract(player)
  -- Don't have contract selection if we're in an endurance map
  if (GetGlobalBool("VersusEnduranceMap", false)) then
    return false
  end
end
