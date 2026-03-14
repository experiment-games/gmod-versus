local PLUGIN              = PLUGIN

PLUGIN.name               = "Bounty Board"
PLUGIN.libraryKey         = "bounty_board"
PLUGIN.description        = "Daily bounties players can pick up at the hideout and complete for cash rewards."

-- How many bounties to select for each daily reset
PLUGIN.DAILY_BOUNTY_COUNT = 5

-- Seconds in a day (used to calculate expiry for the next midnight UTC)
PLUGIN.SECONDS_PER_DAY    = 86400

-- Bit sizes used in net messages
PLUGIN.BIT_BOUNTY_DB_ID   = 16
PLUGIN.BIT_PROGRESS       = 24
PLUGIN.BIT_REWARD         = 32

PLUGIN.definitions        = PLUGIN.definitions or {}

--- Registers a bounty definition (template) that can appear on the daily board.
--- Each daily instance rolls a random target count between randomMin and randomMax
--- in steps of randomStep.  A 0–1 scale is derived from where the rolled count
--- falls in that range; the same scale is then multiplied by baseReward (with a
--- small random variance) to produce the final cash reward for that instance.
---
--- Supported types:
---   "kill_npc"       – kill NPCs whose class matches npcClass / npcClasses.
---                      Set requireEndurance = true to restrict to endurance maps.
---   "clear_encounter"– clear encounter camps of type encounterID (encounters plugin).
---
--- @param id   string  Unique base identifier (e.g. "kill_zombies" – no count in the key)
--- @param data table   Fields:
---   name (string), description (string – use %d for the rolled count),
---   type (string), randomMin (number), randomMax (number), randomStep (number),
---   baseReward (number) – reward at scale 1.0,
---   npcClass/npcClasses (kill_npc), encounterID (clear_encounter),
---   requireEndurance (bool, optional)
function PLUGIN.register(id, data)
  data.id = id
  PLUGIN.definitions[id] = data
end

--[[
  Bounty Definitions
--]]

-- Kill bounties – endurance mode

PLUGIN.register("kill_combine_supersoldiers", {
  name             = "Combine Extermination",
  description      = "Kill %d Combine Super Soldiers in Endurance mode.",
  type             = "kill_npc",
  npcClass         = "npc_combine_s",
  requireEndurance = true,
  randomMin        = 20,
  randomMax        = 100,
  randomStep       = 5,
  baseReward       = 600,
})

PLUGIN.register("kill_fast_zombies", {
  name             = "Fast Zombie Slaughter",
  description      = "Slay %d Fast Zombies in Endurance mode.",
  type             = "kill_npc",
  npcClass         = "npc_fastzombie",
  requireEndurance = true,
  randomMin        = 20,
  randomMax        = 100,
  randomStep       = 5,
  baseReward       = 500,
})

PLUGIN.register("kill_antlions", {
  name             = "Antlion Purge",
  description      = "Kill %d Antlions in Endurance mode.",
  type             = "kill_npc",
  npcClass         = "npc_antlion",
  requireEndurance = true,
  randomMin        = 20,
  randomMax        = 80,
  randomStep       = 5,
  baseReward       = 450,
})

PLUGIN.register("kill_headcrabs", {
  name             = "Headcrab Extermination",
  description      = "Kill %d headcrabs (any kind) in Endurance mode.",
  type             = "kill_npc",
  npcClasses       = { "npc_headcrab", "npc_headcrab_fast", "npc_headcrab_black" },
  requireEndurance = true,
  randomMin        = 25,
  randomMax        = 120,
  randomStep       = 5,
  baseReward       = 400,
})

PLUGIN.register("kill_zombies_endurance", {
  name             = "Zombie Purge",
  description      = "Kill %d Zombies (any variant) in Endurance mode.",
  type             = "kill_npc",
  npcClasses       = { "npc_zombie", "npc_zombie_torso", "npc_poisonzombie" },
  requireEndurance = true,
  randomMin        = 20,
  randomMax        = 80,
  randomStep       = 5,
  baseReward       = 450,
})

-- Kill bounties – any mode

PLUGIN.register("kill_soldiers", {
  name        = "Soldier Slayer",
  description = "Eliminate %d Combine Soldiers in any game mode.",
  type        = "kill_npc",
  npcClass    = "npc_combine_s",
  randomMin   = 15,
  randomMax   = 60,
  randomStep  = 5,
  baseReward  = 350,
})

PLUGIN.register("kill_zombies", {
  name        = "Dead Reckoning",
  description = "Kill %d Zombies (any variant) in any game mode.",
  type        = "kill_npc",
  npcClasses  = { "npc_zombie", "npc_zombie_torso", "npc_poisonzombie" },
  randomMin   = 15,
  randomMax   = 60,
  randomStep  = 5,
  baseReward  = 300,
})

-- Encounter clear bounties (encounters plugin)

PLUGIN.register("clear_combine_checkpoint", {
  name        = "Checkpoint Assault",
  description = "Clear %d Combine Checkpoint encounter camps.",
  type        = "clear_encounter",
  encounterID = "combine_checkpoint",
  randomMin   = 1,
  randomMax   = 5,
  randomStep  = 1,
  baseReward  = 900,
})

PLUGIN.register("clear_zombie_horde", {
  name        = "Horde Exterminator",
  description = "Clear %d Zombie Horde encounter camps.",
  type        = "clear_encounter",
  encounterID = "zombie_horde",
  randomMin   = 1,
  randomMax   = 5,
  randomStep  = 1,
  baseReward  = 750,
})

PLUGIN.register("clear_antlion_nest", {
  name        = "Nest Demolisher",
  description = "Clear %d Antlion Nest encounter camps.",
  type        = "clear_encounter",
  encounterID = "antlion_nest",
  randomMin   = 1,
  randomMax   = 4,
  randomStep  = 1,
  baseReward  = 1000,
})

versus.includePrefixed("sv_hooks.lua")
