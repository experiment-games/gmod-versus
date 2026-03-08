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

-- Seconds between waves.
PLUGIN.WAVE_INTERVAL = 15

-- Base XP rewarded to each surviving member when a wave is cleared.
-- Scales linearly with wave number (XP_PER_WAVE * waveNumber).
PLUGIN.XP_PER_WAVE = 250

-- Seconds after the last squad member dies before all members are redirected to the hideout.
PLUGIN.SQUAD_WIPE_REDIRECT_DELAY = 30

-- Seconds players have to connect to the hideout server after being sent the redirect before
-- they are kicked from the endurance server.
PLUGIN.SQUAD_WIPE_KICK_DELAY = 60

--[[
  Wave configuration table.

  Each entry in PLUGIN.WAVE_CONFIG defines a tier that becomes active starting
  from `fromWave` and stays active until a later tier takes over.  The tier with
  the highest `fromWave` that is still <= the current wave is used.

  Per-tier `npcs` array — each NPC entry supports:
    class                 (string)    NPC class to spawn, e.g. "npc_zombie"
    count                 (number)    Base number of enemies to spawn each wave
    countIncreasePerWave  (number?)   Additional enemies added per wave above fromWave (default 0)
    baseHealth            (number)    Starting health at the beginning of this tier
    healthIncreasePerWave (number)    Health multiplier applied per wave above fromWave
                                      e.g. 1.1 → health × 1.1 each wave; 1.0 → fixed health
    model                 (string?)   Optional custom model path (set before Spawn — visual override)
    modelScale            (number?)   Optional model scale (default 1.0)
    weapons               (table?)    Optional list of weapon classes to give the NPC
    loot                  (fun?)      Optional loot spawner:
                                      function(npc, attacker, inflictor) end

  Per-tier optional `lootCrate` table — when present, a loot crate is dropped
  near the squad spawn every `everyXWaves` waves.  Each successive crate
  multiplies all item chances by the spawn count, capped at 4× so that even
  rare items are guaranteed to appear by the fourth crate.
    everyXWaves           (number)    Spawn a crate once every this many waves
                                      (checked against the absolute wave number)
    items                 (table)     Chance table: { [itemID] = baseChance, ... }
                                      baseChance is in [0, 1]; after n crates the
                                      effective chance is min(baseChance × n, 1)
--]]
-- Loot table shared by all endurance monsters: rare drops to reward players for pushing deeper.
local ENDURANCE_LOOT = {
  ["health_vial"]            = 0.05,
  ["health_kit"]             = 0.03,
  ["raw_furniture_material"] = 0.05,
}

local function enduranceLootSpawner(npc, attacker, inflictor)
  versus.contracts.produceLootAtPosition(npc, attacker, ENDURANCE_LOOT, npc:GetPos())
end

PLUGIN.WAVE_CONFIG = {
  -- Waves 1–4: plain zombies, slow health ramp.
  {
    fromWave = 0,
    npcs = {
      {
        class                 = "npc_zombie",
        count                 = 3,
        countIncreasePerWave  = 1,   -- +1 zombie per wave
        baseHealth            = 50,
        healthIncreasePerWave = 1.1, -- ×1.1 health each wave above wave 0
        model                 = nil,
        modelScale            = 1.0,
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
    },
    -- Drop a loot crate every 3 waves.  By the 4th crate all item chances are 4×.
    lootCrate = {
      everyXWaves = 5,
      items = {
        ["health_vial"]            = 0.4,
        ["health_kit"]             = 0.15,
        ["raw_furniture_material"] = 0.3,
      },
    },
  },

  -- Waves 5–9: fast zombies join the horde, steeper health ramp.
  {
    fromWave = 5,
    npcs = {
      {
        class                 = "npc_zombie",
        count                 = 4,
        countIncreasePerWave  = 1,
        baseHealth            = 120,
        healthIncreasePerWave = 1.2, -- ×1.2 health each wave above wave 5
        model                 = nil,
        modelScale            = 1.0,
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
      {
        class                 = "npc_fastzombie",
        count                 = 2,
        countIncreasePerWave  = 1,
        baseHealth            = 60,
        healthIncreasePerWave = 1.2,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
    },
    lootCrate = {
      everyXWaves = 6,
      items = {
        ["health_vial"]            = 0.5,
        ["health_kit"]             = 0.2,
        ["raw_furniture_material"] = 0.35,
      },
    },
  },

  -- Wave 10+: fast headcrabs added as a relentless swarm; fixed high HP boss zombie.
  {
    fromWave = 10,
    npcs = {
      {
        class                 = "npc_zombie",
        count                 = 5,
        countIncreasePerWave  = 1,
        baseHealth            = 300,
        healthIncreasePerWave = 1.25,
        model                 = nil,
        modelScale            = 1.1,
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
      {
        class                 = "npc_fastzombie",
        count                 = 3,
        countIncreasePerWave  = 1,
        baseHealth            = 150,
        healthIncreasePerWave = 1.25,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
      {
        class                 = "npc_headcrab_fast",
        count                 = 4,
        countIncreasePerWave  = 1,
        baseHealth            = 2000, -- fixed burst health; healthIncreasePerWave = 1.0 means no per-wave scaling
        healthIncreasePerWave = 1.0,
        model                 = nil,
        modelScale            = 5.0, -- giant headcrabs for maximum terror
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
    },
    lootCrate = {
      everyXWaves = 7,
      items = {
        ["health_vial"]            = 0.6,
        ["health_kit"]             = 0.3,
        ["raw_furniture_material"] = 0.4,
      },
    },
  },
  {
    fromWave = 20,
    npcs = {
      {
        class                 = "npc_zombie",
        count                 = 6,
        countIncreasePerWave  = 1,
        baseHealth            = 500,
        healthIncreasePerWave = 1.3,
        model                 = nil,
        modelScale            = 1.2,
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
      {
        class                 = "npc_fastzombie",
        count                 = 4,
        countIncreasePerWave  = 1,
        baseHealth            = 250,
        healthIncreasePerWave = 1.3,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
      {
        class                 = "npc_headcrab_fast",
        count                 = 5,
        countIncreasePerWave  = 1,
        baseHealth            = 3000,
        healthIncreasePerWave = 1.0,
        model                 = nil,
        modelScale            = 5.0, -- giant headcrabs for maximum terror
        weapons               = {},
        loot                  = enduranceLootSpawner,
      },
    },
    lootCrate = {
      everyXWaves = 10,
      items = {
        ["health_vial"]            = 0.7,
        ["health_kit"]             = 0.4,
        ["raw_furniture_material"] = 0.5,
      },
    },
  },
}

function PLUGIN.hook:PlayerShouldSelectContract(player)
  -- Don't have contract selection if we're in an endurance map
  if (GetGlobalBool("VersusEnduranceMap", false)) then
    return false
  end
end
