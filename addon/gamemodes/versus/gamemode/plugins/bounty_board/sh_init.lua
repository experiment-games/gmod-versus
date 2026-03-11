local PLUGIN = PLUGIN

PLUGIN.name        = "Bounty Board"
PLUGIN.libraryKey  = "bounty_board"
PLUGIN.description = "Daily bounties players can pick up at the hideout and complete for cash rewards."

-- How many bounties to select for each daily reset
PLUGIN.DAILY_BOUNTY_COUNT = 5

-- Seconds in a day (used to calculate expiry for the next midnight UTC)
PLUGIN.SECONDS_PER_DAY = 86400

-- Bit sizes used in net messages
PLUGIN.BIT_BOUNTY_DB_ID = 16
PLUGIN.BIT_PROGRESS     = 24
PLUGIN.BIT_REWARD       = 32

PLUGIN.definitions = PLUGIN.definitions or {}

--- Registers a bounty definition that can appear on the daily board.
--- Supported types:
---   "kill_npc"       – kill `targetCount` NPCs whose class matches `npcClass` (or any in `npcClasses`).
---                      Set `requireEndurance = true` to only track kills on endurance maps.
---   "clear_encounter"– clear `targetCount` camps of type `encounterID` (encounters plugin).
--- @param id   string  Unique identifier for this bounty type
--- @param data table   Bounty definition
function PLUGIN.register(id, data)
  data.id = id
  PLUGIN.definitions[id] = data
end

--[[
  Bounty Definitions
--]]

-- Kill bounties – endurance mode

PLUGIN.register("kill_combine_supersoldiers_50", {
  name             = "Combine Extermination",
  description      = "Kill 50 Combine Super Soldiers in Endurance mode.",
  type             = "kill_npc",
  npcClass         = "npc_combine_s",
  targetCount      = 50,
  requireEndurance = true,
  reward           = 500,
})

PLUGIN.register("kill_fast_zombies_50", {
  name             = "Fast Zombie Slaughter",
  description      = "Slay 50 Fast Zombies in Endurance mode.",
  type             = "kill_npc",
  npcClass         = "npc_fastzombie",
  targetCount      = 50,
  requireEndurance = true,
  reward           = 400,
})

PLUGIN.register("kill_antlions_40", {
  name             = "Antlion Purge",
  description      = "Kill 40 Antlions in Endurance mode.",
  type             = "kill_npc",
  npcClass         = "npc_antlion",
  targetCount      = 40,
  requireEndurance = true,
  reward           = 350,
})

PLUGIN.register("kill_headcrabs_60", {
  name             = "Headcrab Extermination",
  description      = "Kill 60 headcrabs (any kind) in Endurance mode.",
  type             = "kill_npc",
  npcClasses       = { "npc_headcrab", "npc_headcrab_fast", "npc_headcrab_black" },
  targetCount      = 60,
  requireEndurance = true,
  reward           = 300,
})

PLUGIN.register("kill_zombies_any_40", {
  name             = "Zombie Purge",
  description      = "Kill 40 Zombies (any variant) in Endurance mode.",
  type             = "kill_npc",
  npcClasses       = { "npc_zombie", "npc_zombie_torso", "npc_poisonzombie" },
  targetCount      = 40,
  requireEndurance = true,
  reward           = 350,
})

-- Kill bounties – any mode

PLUGIN.register("kill_soldiers_any_30", {
  name        = "Soldier Slayer",
  description = "Eliminate 30 Combine Soldiers in any game mode.",
  type        = "kill_npc",
  npcClass    = "npc_combine_s",
  targetCount = 30,
  reward      = 250,
})

PLUGIN.register("kill_zombies_any_25", {
  name        = "Dead Reckoning",
  description = "Kill 25 Zombies (any variant) in any game mode.",
  type        = "kill_npc",
  npcClasses  = { "npc_zombie", "npc_zombie_torso", "npc_poisonzombie" },
  targetCount = 25,
  reward      = 200,
})

-- Encounter clear bounties (encounters plugin, contract mode)

PLUGIN.register("clear_combine_checkpoint_3", {
  name        = "Checkpoint Assault",
  description = "Clear 3 Combine Checkpoint encounter camps.",
  type        = "clear_encounter",
  encounterID = "combine_checkpoint",
  targetCount = 3,
  reward      = 750,
})

PLUGIN.register("clear_zombie_horde_3", {
  name        = "Horde Exterminator",
  description = "Clear 3 Zombie Horde encounter camps.",
  type        = "clear_encounter",
  encounterID = "zombie_horde",
  targetCount = 3,
  reward      = 600,
})

PLUGIN.register("clear_antlion_nest_2", {
  name        = "Nest Demolisher",
  description = "Clear 2 Antlion Nest encounter camps.",
  type        = "clear_encounter",
  encounterID = "antlion_nest",
  targetCount = 2,
  reward      = 800,
})

versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("cl_hooks.lua")
