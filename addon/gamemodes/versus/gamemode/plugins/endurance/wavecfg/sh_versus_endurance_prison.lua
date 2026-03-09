local PLUGIN = PLUGIN

--[[
  versus_endurance_prison
  Nova Prospekt-style prison facility — Combine forces tighten their grip with
  each passing wave, graduating from Civil Protection patrols to full assault
  squads supported by manhack swarms.
--]]
PLUGIN.registerWaveConfig("versus_endurance_prison", {

  -- Waves 1–4: Civil Protection response teams with sidearms.
  {
    fromWave = 0,
    npcs = {
      {
        class                 = "npc_metropolice",
        count                 = 3,
        countIncreasePerWave  = 1,
        baseHealth            = 80,
        healthIncreasePerWave = 1.1,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = { "weapon_pistol" },
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

  -- Waves 5–9: Combine soldiers deployed alongside metro police.
  {
    fromWave = 5,
    npcs = {
      {
        class                 = "npc_metropolice",
        count                 = 3,
        countIncreasePerWave  = 1,
        baseHealth            = 160,
        healthIncreasePerWave = 1.2,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = { "weapon_pistol" },
        loot                  = PLUGIN.defaultLootSpawner,
      },
      {
        class                 = "npc_combine_s",
        count                 = 2,
        countIncreasePerWave  = 1,
        baseHealth            = 120,
        healthIncreasePerWave = 1.2,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = { "weapon_smg1" },
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

  -- Waves 10–19: Elite soldiers and manhacks fill the corridors.
  {
    fromWave = 10,
    npcs = {
      {
        class                 = "npc_combine_s",
        count                 = 4,
        countIncreasePerWave  = 1,
        baseHealth            = 300,
        healthIncreasePerWave = 1.25,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = { "weapon_ar2" },
        loot                  = PLUGIN.defaultLootSpawner,
      },
      {
        class                 = "npc_combine_s",
        count                 = 2,
        countIncreasePerWave  = 1,
        baseHealth            = 250,
        healthIncreasePerWave = 1.25,
        model                 = "models/combine_super_soldier.mdl", -- elite skin
        modelScale            = 1.0,
        weapons               = { "weapon_ar2" },
        loot                  = PLUGIN.defaultLootSpawner,
      },
      {
        class                 = "npc_manhack",
        count                 = 4,
        countIncreasePerWave  = 1,
        baseHealth            = 35,
        healthIncreasePerWave = 1.0, -- fixed: manhacks are harassment, not damage sponges
        model                 = nil,
        modelScale            = 1.0,
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

  -- Wave 20+: Full Nova Prospekt assault; elite squads backed by manhack swarms.
  {
    fromWave = 20,
    npcs = {
      {
        class                 = "npc_combine_s",
        count                 = 5,
        countIncreasePerWave  = 1,
        baseHealth            = 600,
        healthIncreasePerWave = 1.3,
        model                 = nil,
        modelScale            = 1.0,
        weapons               = { "weapon_ar2" },
        loot                  = PLUGIN.defaultLootSpawner,
      },
      {
        class                 = "npc_combine_s",
        count                 = 3,
        countIncreasePerWave  = 1,
        baseHealth            = 500,
        healthIncreasePerWave = 1.3,
        model                 = "models/combine_super_soldier.mdl",
        modelScale            = 1.0,
        weapons               = { "weapon_ar2" },
        loot                  = PLUGIN.defaultLootSpawner,
      },
      {
        class                 = "npc_manhack",
        count                 = 6,
        countIncreasePerWave  = 1,
        baseHealth            = 50,
        healthIncreasePerWave = 1.0,
        model                 = nil,
        modelScale            = 1.5, -- slightly oversized manhacks
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
