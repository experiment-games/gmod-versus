local PLUGIN = PLUGIN

--[[
  versus_endurance_canals
  An infested canal district — zombies and headcrabs crawl out of the dark.
--]]
PLUGIN.registerWaveConfig("versus_endurance_canals", {

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
        loot                  = PLUGIN.defaultLootSpawner,
      },
    },
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
        loot                  = PLUGIN.defaultLootSpawner,
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
        loot                  = PLUGIN.defaultLootSpawner,
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

  -- Waves 10–19: fast headcrabs added as a relentless swarm.
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
        loot                  = PLUGIN.defaultLootSpawner,
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
        loot                  = PLUGIN.defaultLootSpawner,
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
        loot                  = PLUGIN.defaultLootSpawner,
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

  -- Wave 20+: overwhelming undead flood.
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
        loot                  = PLUGIN.defaultLootSpawner,
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
        loot                  = PLUGIN.defaultLootSpawner,
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
        loot                  = PLUGIN.defaultLootSpawner,
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

})
