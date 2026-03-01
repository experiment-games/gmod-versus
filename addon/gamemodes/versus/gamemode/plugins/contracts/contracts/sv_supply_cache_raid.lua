local PLUGIN = PLUGIN

local function combineLootTable(npc, attacker, position, angles)
  local loot = {
    ["health_vial"] = 0.25,
  }

  hook.Run("ModifyContractLootTable", npc, loot, attacker, position, angles)

  return loot
end

-- Supply Cache Raid contract
-- A high-value Combine supply cache has been located. Multiple parties want it.
-- First one there gets to loot it — but the Combine aren't going to let that happen quietly.

-- This contract:
-- - Breach a Combine supply depot and fight through the defenders
-- - Loot the supply cache (interact) to retrieve a supply manifest
-- - Escape with escalating Combine pressure as the alarm has been raised
-- - Extract with the manifest item

-- DESIGN NOTES:
-- - This is the most combat-heavy of the three contracts, with the highest reward to match.
-- - PvP interference: A subsequent player can race to the cache and plant a disruptor device on it
--   before the first player loots it. If they succeed, the first player's loot is "compromised"
--   (supply manifest is degraded — they still extract but for reduced reward).
--   This creates a genuine race and decision point for both sides.
-- - The extraction phase has the heaviest enemy presence of any contract — carrying the manifest
--   paints a target on the player's back.

PLUGIN.register("supply_cache_raid", {
  name = {
    "Scavenger's Run",
    "Supply Cache Raid",
    "The Haul",
    "First Come, First Served",
    "Cache Rush",
    "Manifest Mayhem",
    "The Big Score",
    "High-Value Target",
    "Jackpot",
    "The Motherlode",
    "The Big Haul",
  },

  -- One-line description shown in contract listings
  description = {
    "A nearby Combine supply cache has been located. Punch through the defenders, grab the manifest, and get out before the grid locks down.",
    "We've got word of a high-value Combine supply cache in your area. Breach the depot, loot the cache, and extract with the manifest before the Combine lock it down.",
    "A Combine supply cache has been located nearby. Fight through the defenders, loot the cache to get the manifest, and extract before the grid locks down.",
    "There's a Combine supply cache in your sector that's ripe for the taking. Breach the depot, grab the manifest from the cache, and get out before the alarm triggers.",
    "A high-value Combine supply cache has been located in your vicinity. Punch through the defenders, loot the cache to retrieve the manifest, and extract before the grid locks down.",
    "We've got intel on a nearby Combine supply cache. Your mission: breach the depot, grab the manifest from the cache, and get out before the alarm triggers.",
    "A Combine supply cache has been located in your area. Breach the depot, loot the cache to retrieve the manifest, and extract before the grid locks down.",
    "There's a high-value Combine supply cache in your sector. Punch through the defenders, grab the manifest from the cache, and get out before the alarm triggers.",
    "A nearby Combine supply cache has been located. Breach the depot, loot the cache to retrieve the manifest, and extract before the grid locks down.",
    "A Combine supply cache has been located in your sector. Breach the depot, loot the cache to retrieve the manifest, and extract before the grid locks down.",
    "A Combine supply cache has been located nearby. Punch through the defenders, grab the manifest from the cache, and get out before the grid locks down.",
  },

  -- Image to show behind the contract name and description. Should be 512x512 for best results.
  image = "versus/contracts/supply_cache_raid.png",

  tags = {
    { label = "heist", color = Color(255, 200, 50) },
    { label = "race",  color = Color(220, 120, 50) },
  },

  locations = {
    -- The supply cache itself
    supplyCache = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "combine_supply_cache",
      false,
      "Supply Cache"
    ),

    -- Spawn point far from the cache
    spawnPoint = PLUGIN.defineRelativeLocation(
      "versus_spawn_point",
      "supplyCache",
      PLUGIN.FAR_FROM_LOCATION,
      false,
      "Deployment Zone",
      false
    ),

    -- Extraction point (hidden until manifest is secured)
    extractionPoint = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "extraction_point",
      true,
      "Extraction Point",
      false
    ),
  },

  phases = {
    -- Phase 1: Spawn and briefing from Decker
    {
      spawn = {
        location = PLUGIN.referToContractLocation("spawnPoint"),
      },

      lore = {
        type = "radio",
        author = "Decker",
        portrait = "versus/npc/decker.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "You're on the clock, %PLAYER_NAME%. Others know about this cache too.",
              "%PLAYER_NAME%. Don't hang around — word travels fast in this city.",
            },
          },
          {
            delayInSeconds = 1,
            content = {
              "Combine supply depot, unmarked on civilian maps. Weapons, med supplies, and — more importantly — a full shipping manifest. Names, routes, transfer schedules. That paper alone is worth more than everything else in that building combined.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "Cache is marked. Punch through whatever's guarding it, grab the manifest, and get out. Combine will lock that grid down fast once the alarm triggers. Move.",
            },
          },
        }
      },

      completeCallback = { "wait", 4 },
    },

    -- Phase 2: Fight to the cache — heavy defending patrol
    {
      objective = {
        title = "Breach the Depot",
        description = "Fight through the Combine defenders and reach the supply cache.",
      },

      indicators = {
        {
          name = "Supply Cache",
          location = PLUGIN.referToContractLocation("supplyCache"),
        },
      },

      -- Heavy depot guards
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("supplyCache"),
          behavior = "defending",
          health = 80,
          count = 2,
          weapons = { "weapon_ar2" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("supplyCache"),
          behavior = "defending",
          health = 100,
          count = 2,
          weapons = { "weapon_shotgun" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractLocation("supplyCache"),
          behavior = "defending",
          count = 2,
        },
      },

      completeCallback = {
        "checkInRange",
        PLUGIN.referToContractLocation("supplyCache"),
        512,
      }
    },

    -- Phase 3: Loot the cache — interferable by a subsequent player
    {
      maxSubsequent = 1, -- One rival can race to disrupt the loot

      first = {
        objective = {
          title = "Loot the Cache",
          description = "Access the supply cache and retrieve the manifest before the Combine lock it down.",
        },

        lore = {
          type = "radio",
          author = "Decker",
          portrait = "versus/npc/decker.png",
          texts = {
            {
              delayInSeconds = 0.5,
              content = {
                "You're in. Hit that cache fast — I'm seeing chatter on the Combine freq. They'll be rolling a response.",
                "Nice work punching through. Get that manifest — you don't have long.",
              },
            },
          }
        },

        indicators = {
          {
            name = "Supply Cache",
            location = PLUGIN.referToContractLocation("supplyCache"),
          },
        },

        entities = {
          {
            entity = PLUGIN.referToContractLocation("supplyCache"),
            accessors = {
              InteractionCallback = { "setContractValue", "manifest_secured", true },
              InteractionTime = 6,
              InteractionName = "Loot Cache",
            }
          }
        },

        -- Remaining depot guards respond to the breach
        enemies = {
          {
            class = "npc_combine_s",
            location = PLUGIN.referToContractLocation("supplyCache"),
            behavior = "attacking",
            health = 90,
            count = 2,
            weapons = { "weapon_ar2" },
            lootTable = combineLootTable,
          },
        },

        completeCallback = { "checkContractValueEquals", "manifest_secured", true },
      },

      subsequent = {
        objective = {
          title = "Disrupt the Loot",
          description =
          "Plant a disruptor on the supply cache before they make off with the manifest. That data cannot leave this city.",
        },

        lore = {
          type = "radio",
          author = "Decker",
          portrait = "versus/npc/decker.png",
          texts = {
            {
              delayInSeconds = 0.5,
              content = {
                "Someone else is already at that cache, %PLAYER_NAME%. You know what to do — plant the disruptor and corrupt their haul. Nothing leaves clean.",
                "They beat you to the depot. Doesn't matter. Get in there, plant the disruptor on the cache — they take garbage home tonight.",
              },
            },
            {
              delayInSeconds = 2,
              content = {
                "Quick hands, %PLAYER_NAME%. They're already looting.",
              },
            },
          }
        },

        indicators = {
          {
            name = "Supply Cache [DISRUPT]",
            location = PLUGIN.referToContractLocation("supplyCache"),
          },
        },

        entities = {
          {
            entity = PLUGIN.referToContractLocation("supplyCache"),
            accessors = {
              InteractionCallback = { "setContractValue", "cache_disrupted", true },
              InteractionTime = 8,
              InteractionName = "Plant Disruptor",
            }
          }
        },

        completeCallback = { "checkContractValueEquals", "cache_disrupted", true },
      },
    },

    -- Phase 4: Alarm is triggered — escape with the manifest under heavy pressure
    {
      objective = {
        title = "Extract the Manifest",
        description = "The alarm is triggered. Fight your way to extraction before the grid locks down.",
      },

      clearProximityRequirement = true,

      lore = {
        type = "radio",
        author = "Decker",
        portrait = "versus/npc/decker.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "You've got it! Now get out — every Combine unit in the sector just got pinged your location.",
              "Manifest secured. Now run. Combine response incoming, and it's not going to be polite.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "I'm marking extraction. Move fast — they'll be all over that route in minutes.",
            },
          },
        }
      },

      giveItems = {
        {
          itemID = "supply_manifest",
          quantity = 1,
        },
      },

      indicators = {
        {
          name = "Extraction Point",
          location = PLUGIN.referToContractLocation("extractionPoint"),
        },
      },

      entities = {
        {
          entity = PLUGIN.referToContractLocation("extractionPoint"),
          accessors = {
            InteractionCallback = { "completeContract" },
            InteractionTime = 5,
            InteractionName = "Extract",
          },
        }
      },

      -- Heaviest enemy presence of any phase — Combine response to the breach
      spawnWaves = {
        {
          delayInSeconds = 0,
          enemies = {
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("extractionPoint"),
              behavior = "attacking",
              health = 90,
              count = 2,
              weapons = { "weapon_ar2" },
              lootTable = combineLootTable,
            },
            {
              class = "npc_manhack",
              location = PLUGIN.referToContractLocation("extractionPoint"),
              behavior = "attacking",
              count = 2,
            },
          },
        },
        {
          delayInSeconds = 20,
          enemies = {
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("extractionPoint"),
              behavior = "attacking",
              health = 100,
              count = 3,
              weapons = { "weapon_ar2", "weapon_smg1" },
              lootTable = combineLootTable,
            },
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("extractionPoint"),
              behavior = "attacking",
              health = 120,
              count = 1,
              weapons = { "weapon_shotgun" },
              lootTable = combineLootTable,
            },
          },
        },
      },

      completeCallback = { "wait", 10 },
    },

    -- Phase 5: Final extraction window
    {
      objective = {
        title = "Get Out Now",
        description = "Reach the extraction point and deliver the manifest to the resistance.",
      },

      indicators = {
        {
          name = "Extraction Point",
          location = PLUGIN.referToContractLocation("extractionPoint"),
        },
      },

      entities = {
        {
          entity = PLUGIN.referToContractLocation("extractionPoint"),
          accessors = {
            InteractionCallback = { "completeContract" },
            InteractionTime = 5,
            InteractionName = "Extract",
          },
        }
      },

      completeCallback = nil,
    },
  }, -- end phases
})
