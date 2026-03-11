local PLUGIN = PLUGIN

local function combineLootTable(npc, attacker, position, angles)
  local loot = {
    ["health_vial"] = 0.2,
  }

  hook.Run("ModifyContractLootTable", npc, loot, attacker, position, angles)

  return loot
end

-- Propaganda Blackout contract
-- The Combine have deployed a mobile broadcast tower that's blanketing civilian comms with
-- propaganda and masking their own tactical frequencies. The resistance needs it gone.
-- But the tower draws power from three substations — cutting all three first will ensure
-- a clean destruction and prevent an emergency restart.

-- This contract:
-- - Disable three sequential power junctions scattered across the map
-- - Each junction is lightly-to-moderately guarded by Combine patrols
-- - Reach and destroy the now-unpowered broadcast tower (8s interact + defending wave)
-- - Extract

-- DESIGN NOTES:
-- - No hold/defend phases with countdown timers — the pacing comes from navigating
--   between three objectives, each with a small encounter. Rewards exploration over attrition.
-- - The patrol composition escalates with each junction: scouts → soldiers → soldiers + manhacks.
-- - The tower destruction phase is the only moment of real intensity, functioning as a
--   climactic fight after the slower build-up.
-- - No PvP interference hook — this contract is designed as a pure solo/co-op experience
--   with atmospheric tension rather than competitive pressure.

PLUGIN.register("propaganda_blackout", {
  name = {
    "Dead Air",
    "Propaganda Blackout",
    "Cut the Signal",
    "Lights Out",
    "Silent Broadcast",
    "Dark Frequencies",
    "Signal Jammed",
    "Blackout Protocol",
    "Silent Tower",
  },

  -- One-line description shown in contract listings
  description = {
    "The Combine have deployed a mobile broadcast tower that's blanketing civilian comms with propaganda and masking their own tactical frequencies. Disable the three power junctions feeding it, then take it out while it's dark.",
    "We've got a situation with a Combine broadcast tower drowning out civilian radios and masking their comms. We need you to disable the three power junctions feeding it, then take it out while it's dark.",
    "A Combine broadcast tower is jamming civilian frequencies and masking their own comms. Your mission: disable the three power junctions feeding it, then destroy it while it's dark.",
    "The Combine have set up a mobile broadcast tower that's interfering with civilian radios and masking their comms. We need you to disable the three power junctions feeding it, then take it out while it's dark.",
    "A Combine broadcast tower is causing chaos by jamming civilian frequencies and masking their comms. Your objective: disable the three power junctions feeding it, then destroy it while it's dark.",
    "The Combine have deployed a mobile broadcast tower that's disrupting civilian radios and masking their comms. We need you to disable the three power junctions feeding it, then take it out while it's dark.",
    "A Combine broadcast tower is wreaking havoc by jamming civilian frequencies and masking their comms. Your task: disable the three power junctions feeding it, then destroy it while it's dark.",
    "The Combine have set up a mobile broadcast tower that's interfering with civilian radios and masking their comms. We need you to disable the three power junctions feeding it, then take it out while it's dark.",
    "A Combine broadcast tower is causing chaos by jamming civilian frequencies and masking their comms. Your mission: disable the three power junctions feeding it, then destroy it while it's dark.",
    "The Combine have deployed a mobile broadcast tower that's disrupting civilian radios and masking their comms. We need you to disable the three power junctions feeding it, then take it out while it's dark.",
  },

  -- Image to show behind the contract name and description. Should be 512x512 for best results.
  image = "versus/contracts/propaganda_blackout.png",

  tags = {
    { label = "sabotage",    color = Color(180, 120, 220) },
    { label = "multi-stage", color = Color(255, 180, 50) },
    { label = "pve",         color = Color(100, 160, 220) },
  },

  locations = {
    -- Three power junctions feeding the broadcast tower
    junctionA = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "power_junction_a",
      false,
      "Power Junction A"
    ),

    junctionB = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "power_junction_b",
      false,
      "Power Junction B"
    ),

    junctionC = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "power_junction_c",
      false,
      "Power Junction C"
    ),

    -- The broadcast tower itself
    broadcastTower = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "broadcast_tower",
      false,
      "Broadcast Tower"
    ),

    -- Spawn point far from junction A (entry point)
    spawnPoint = PLUGIN.defineRelativeLocation(
      "versus_spawn_point",
      "junctionA",
      PLUGIN.FAR_FROM_LOCATION,
      false,
      "Deployment Zone",
      false
    ),

    -- Extraction point (hidden until tower is destroyed)
    extractionPoint = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "extraction_point",
      true,
      "Extraction Point",
      false
    ),
  },

  phases = {
    -- Phase 1: Spawn and briefing from Reyes
    {
      spawn = {
        location = PLUGIN.referToContractLocation("spawnPoint"),
      },

      lore = {
        type = "radio",
        author = "Reyes",
        portrait = "versus/npc/reyes.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "Good, you're in position. Listen carefully, %PLAYER_NAME% — this one needs to be done right.",
              "%PLAYER_NAME%, thanks for taking this. I'll be brief because the signal window won't last.",
            },
          },
          {
            delayInSeconds = 1,
            content = {
              "The Combine have a mobile broadcast tower running in your sector. It's been drowning out civilian emergency frequencies for three weeks and masking their own tactical comms. We need it destroyed.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "Here's the thing — if you just blow the tower, their systems will hot-restart it from a backup generator within the hour. You need to cut the power first. Three substations are feeding it. I'm marking all three.",
            },
          },
          {
            delayInSeconds = 3,
            content = {
              "Disable all three junctions, then hit the tower while it's dark. Once it's down, get to extraction. Simple in theory. Watch yourself out there.",
            },
          },
        }
      },

      completeCallback = { "wait", 6 },
    },

    -- Phase 2: Disable all three junctions — shown simultaneously, player chooses the order
    {
      objective = {
        title = "Disable the Power Junctions",
        description = "All three power junctions are marked. Disable them in any order before moving on the tower.",
      },

      subObjectives = {
        { id = "junction_a", text = "Disable Junction A" },
        { id = "junction_b", text = "Disable Junction B" },
        { id = "junction_c", text = "Disable Junction C" },
      },

      indicators = {
        {
          name = "Junction A",
          location = PLUGIN.referToContractLocation("junctionA"),
        },
        {
          name = "Junction B",
          location = PLUGIN.referToContractLocation("junctionB"),
        },
        {
          name = "Junction C",
          location = PLUGIN.referToContractLocation("junctionC"),
        },
      },

      entities = {
        {
          entity = PLUGIN.referToContractLocation("junctionA"),
          accessors = {
            InteractionCallback = { "chain",
              { "markSubObjectiveDone", "junction_a" },
              { "removeIndicator",      "Junction A" },
            },
            InteractionTime = 4,
            InteractionName = "Disable Junction",
          }
        },
        {
          entity = PLUGIN.referToContractLocation("junctionB"),
          accessors = {
            InteractionCallback = { "chain",
              { "markSubObjectiveDone", "junction_b" },
              { "removeIndicator",      "Junction B" },
            },
            InteractionTime = 4,
            InteractionName = "Disable Junction",
          }
        },
        {
          entity = PLUGIN.referToContractLocation("junctionC"),
          accessors = {
            InteractionCallback = { "chain",
              { "markSubObjectiveDone", "junction_c" },
              { "removeIndicator",      "Junction C" },
            },
            InteractionTime = 4,
            InteractionName = "Disable Junction",
          }
        },
      },

      enemies = {
        -- Junction A — light scout patrol
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("junctionA"),
          behavior = "defending",
          health = 60,
          count = 2,
          weapons = { "weapon_smg1" },
          lootTable = combineLootTable,
        },

        -- Junction B — standard patrol with manhack sweep
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("junctionB"),
          behavior = "defending",
          health = 70,
          count = 2,
          weapons = { "weapon_ar2", "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractLocation("junctionB"),
          behavior = "defending",
          count = 1,
        },

        -- Junction C — heaviest patrol: soldiers, a shotgunner, and two manhacks
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("junctionC"),
          behavior = "defending",
          health = 80,
          count = 2,
          weapons = { "weapon_ar2" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("junctionC"),
          behavior = "defending",
          health = 90,
          count = 1,
          weapons = { "weapon_shotgun" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractLocation("junctionC"),
          behavior = "defending",
          count = 2,
        },
      },

      completeCallback = { "allSubObjectivesComplete" },
    },

    -- Phase 3: All junctions disabled — destroy the broadcast tower
    {
      objective = {
        title = "Destroy the Broadcast Tower",
        description = "All power junctions are offline. Move to the tower and destroy it while it's dark.",
      },

      lore = {
        type = "radio",
        author = "Reyes",
        portrait = "versus/npc/reyes.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "All three junctions offline — the tower is running on nothing. This is your window, %PLAYER_NAME%. Get in there and bring it down.",
              "That's it. Tower is dark. Move on it now before they figure out what's happening.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "There'll still be a guard detail at the tower itself. They won't know why the power is out, but they'll know you shouldn't be there.",
            },
          },
        }
      },

      indicators = {
        {
          name = "Broadcast Tower",
          location = PLUGIN.referToContractLocation("broadcastTower"),
        },
      },

      entities = {
        {
          entity = PLUGIN.referToContractLocation("broadcastTower"),
          accessors = {
            InteractionCallback = { "setContractValue", "tower_destroyed", true },
            InteractionTime = 8,
            InteractionName = "Destroy Tower",
          }
        }
      },

      -- Tower guard detail — a concentrated defending force at the climax
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("broadcastTower"),
          behavior = "defending",
          health = 90,
          count = 2,
          weapons = { "weapon_ar2" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("broadcastTower"),
          behavior = "defending",
          health = 100,
          count = 1,
          weapons = { "weapon_shotgun" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractLocation("broadcastTower"),
          behavior = "defending",
          count = 2,
        },
      },

      completeCallback = { "checkContractValueEquals", "tower_destroyed", true },
    },

    -- Phase 4: Tower is down — extract
    {
      objective = {
        title = "Extract",
        description = "The tower is destroyed. Get to the extraction point.",
      },

      lore = {
        type = "radio",
        author = "Reyes",
        portrait = "versus/npc/reyes.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "It's done. That signal is gone. Every civilian radio in a five kilometre radius just came back to life, %PLAYER_NAME%.",
              "Tower is down. Clean work. The Combine just lost a big piece of their local comms network.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "Extraction point is marked. Get out of there — and thank you.",
            },
          },
        }
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
