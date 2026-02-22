local PLUGIN = PLUGIN

PLUGIN.name = "Side Quests"
PLUGIN.libraryKey = "side_quests"
PLUGIN.description = "Spawns monster camps in the world for players to discover and clear for extra rewards."

-- How many monster camps to keep spawned in the world at all times.
PLUGIN.convarWorldCount = CreateConVar(
  "versus_side_quests_world_count",
  "5",
  { FCVAR_NOTIFY, FCVAR_ARCHIVE },
  "Number of monster camps to maintain in the world at all times",
  0,
  20
)

versus.includePrefixed("sv_hooks.lua")
