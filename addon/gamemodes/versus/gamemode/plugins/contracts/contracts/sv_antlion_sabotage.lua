local PLUGIN = PLUGIN

local function combineLootTable(attacker, position, angles)
  -- Let's spawn a health vial, or ammo for the player's current weapon
  local loot = {
    ["health_vial"] = 0.2,
  }

  if (IsValid(attacker) and attacker:IsPlayer()) then
    local activeWeapon = attacker:GetActiveWeapon()

    if (IsValid(activeWeapon)) then
      local ammoType = activeWeapon:GetPrimaryAmmoType()

      if (ammoType and ammoType ~= -1) then
        local ammoItemID = versus.weapon.getItemIDFromAmmoType(ammoType)

        if (ammoItemID) then
          loot[ammoItemID] = 0.3
        end
      end
    end
  end

  return loot
end

-- Antlion Nest Sabotage contract
-- The resistance needs to clear out an antlion nest that's threatening a key supply route.

-- IMPORTANT: Before assigning this contract to a player, you must prepare it using:
--   PLUGIN.prepareContractForPlayer(player, "antlion_sabotage")
-- This will:
--   1. Randomly select an antlion nest from the map
--   2. Find the furthest spawn point from that nest
--   3. Randomly select an extraction point
--   4. Store all resolved locations in player._VersusAvailableContracts["antlion_sabotage"]
-- Each player can get different nest/spawn/extraction combinations, making the contract feel unique.

-- This contract:
-- - Plant demolition charges on an antlion nest's egg chamber
-- - Player must hold position near the nest while charges arm (90 seconds)
-- - Antlion swarms come in escalating waves during the countdown
-- - Other players might interfere or compete for resources in the area
-- - Extraction becomes urgent as the nest prepares to explode

-- DESIGN NOTES:
-- - Failure handling: If player dies during contract, they should restart at the current phase checkpoint
--   (e.g., if they die during defense, restart at defense beginning). Consider adding a "retries" limit.
-- - PvP interference: Future implementation could allow other players to:
--   * Accept a counter-contract to defuse the charges before detonation
--   * Kill the player and steal the demolition detonator for their own use
--   * Compete for antlion resources (extract pheromones, carapaces, etc.)

-- This is purposefully a simple table, such that we can generate this more easily in the future (e.g: dynamically
-- and custom-fit for the player with an LLM)
PLUGIN.register("antlion_sabotage", {
  name = {
    "Antlion Nest Sabotage",
    "Nest Demolition",
    "Antlion Extermination",
    "Egg Chamber Destruction",
  },

  difficulty = PLUGIN.DIFFICULTY_MEDIUM,
  reward = PLUGIN.REWARD_LOW,
  combatStyle = PLUGIN.COMBAT_STYLE_MIXED,

  -- Locations are registered upfront for easy querying
  locations = {
    -- Random antlion nest
    antlionNest = PLUGIN.defineLocation("versus_objective_interaction", "antlion_nest", false, "Antlion Nest"),

    -- Spawn point far from the randomly selected antlion nest
    spawnPoint = PLUGIN.defineRelativeLocation("versus_spawn_point", "antlionNest", PLUGIN.FAR_FROM_LOCATION, false,
      "Deployment Zone"),

    -- Extraction point (hidden until player reaches extraction phase)
    extractionPoint = PLUGIN.defineLocation("versus_objective_interaction", "extraction_point", true, "Extraction Point"),
  },

  phases = {
    -- The player first spawns far away from their first interaction point. They are given some lore.
    {
      -- Should always be first in the contract, spawns the player at a location near or far from somewhere else.
      spawn = {
        -- Where to spawn. The spawn point is now a registered location in the contract.
        -- The spawnPoint is defined as FAR_FROM_LOCATION relative to the antlionNest, so the player
        -- will spawn at the furthest versus_spawn_point from the randomly selected antlion nest.
        location = PLUGIN.referToContractLocation("spawnPoint", PLUGIN.EXACT),
      },

      -- Lore to communicate to player
      lore = {
        -- Types for lore can be given through:
        -- - radio: Chat Radio Messages from NPC
        -- - (future implementation, not now) audio: Voice Lines through earpiece (select mp3 files)
        -- - (future implementation, not now) panel: Mission Brief tablet/piece of paper (just a popup panel with a background image
        --   that can be swapped depending on preferred style)
        type = "radio",

        -- Author, in case of chat radio messages this is put in front of the messages (e.g: "Maria Chen: We've got a...")
        author = "Maria Chen",

        -- Optional portrait to display with the radio message
        portrait = "versus/npc/chen_maria.png",

        -- Texts to trickle to the player
        texts = {
          {
            -- Relative to previous text (or phase start in this case, since its first)
            delayInSeconds = 1,

            -- A random one from this table is selected (to have variation when working the same contract later)
            content = {
              "Thanks for taking this contract %PLAYER_NAME%, we really need your help with this one.",
              "Good to see you %PLAYER_NAME%, we've got a dangerous situation here.",
            },
          },
          {
            delayInSeconds = 1,
            content = {
              "We've located a large antlion nest that's blocking one of our main supply routes. Convoys can't get through safely with all those bugs swarming the area.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "I'm marking the nest location for you now. Plant these demolition charges on their egg chamber - that should collapse the whole nest. Watch out, they'll defend their eggs fiercely.",
            },
          }
        }
      },

      -- Its a table with function name and parameters it is called with those parameters in a Think hook to
      -- see if the phase should end and move on to the next phase.
      completeCallback = {
        "wait",
        4, -- Wait 4 seconds before moving to the next phase, to give time for the lore to be read and absorbed by the player.
      }
    },

    -- The player then gets the objective and should go to that to interact with it.
    {
      -- The objective key puts an objective that can be completed on the players HUD during this phase.
      objective = {
        -- Title of the objective to show
        title = "Plant Charges",

        -- Description to elaborate
        description = "Reach the antlion nest and plant demolition charges on the egg chamber.",
      },

      -- The indicators key is used to setup indicators on the player's HUD that point towards something.
      -- It can be used to point towards an entity, a location, or just generally mark a location on the map.
      indicators = {
        {
          -- Name to show above the indicator
          name = "Antlion Nest",

          -- Where to mark the indicator
          location = PLUGIN.referToContractLocation("antlionNest"), -- Defaults to PLUGIN.EXACT, points to the randomly selected antlion nest.
        },
      },

      -- entities is a key is used to setup/modify entities for the player to interact with.
      entities = {
        {
          -- Find the entity related to the antlion nest (e.g: a versus_objective_interaction with the tag antlion_nest) and set it up for interaction.
          -- This is the entity the player needs to interact with to plant the charges and start the countdown.
          entity = PLUGIN.referToContractLocation("antlionNest"),

          accessors = {
            -- This is a special case that will also have the player injected as the first parameter to SetInteractionCallback,
            -- since interaction callbacks need to be player-specific (e.g: if multiple players have the same contract, they
            -- should not override each other's interaction callbacks).
            InteractionCallback = {
              -- Function name and parameters called when player interacts with the entity
              "setContractValue",
              "charges_planted",
              true
            },

            -- How long it takes to interact with the entity, used in the progress bar during the planting phase
            InteractionTime = 5,

            -- Text to show on the entity to interact with it.
            InteractionName = "Plant Charges",
          }
        }
      },

      -- enemies is a key used to setup enemies and place them somewhere.
      enemies = {
        {
          class = "npc_antlion",
          location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),

          -- The behavior can be:
          -- - defending: they stay around the location, waiting for a player to defend against.
          -- - attacking: they actively chase down the player (current NPC behavior in this plugin)
          behavior = "defending",
          health = 40,
          count = 6,
          lootTable = combineLootTable,
        },
        {
          class = "npc_antlion_worker",
          location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          health = 25,
          count = 4,
        },
      },

      -- Completion condition: wait for player to interact with the nest and plant the charges
      completeCallback = {
        "checkContractValueEquals",
        "charges_planted",
        true,
      }
    },

    -- Player has planted the charges, now must defend while they arm (countdown phase)
    {
      objective = {
        title = "Defend the Charges",
        description = "Hold your position while the demolition charges arm. Don't let the antlions destroy them!",
      },

      lore = {
        type = "radio",
        author = "Maria Chen",
        portrait = "versus/npc/chen_maria.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "Charges planted! The timer is set for 90 seconds. Stay close and defend them - if the antlions damage the charges, the mission fails.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "They know you're there now. Expect heavy resistance!",
            },
          }
        }
      },

      indicators = {
        {
          name = "Demolition Charges",
          location = PLUGIN.referToContractLocation("antlionNest"),
        },
      },

      -- Progress bar showing the countdown until charges are armed
      progressBar = {
        duration = 90,
        type = "decrement",
        label = "Arming Charges",

        -- This checks a condition every frame, if it returns false the progress bar pauses
        shouldProgressCallback = {
          "checkContractValueNotEquals",
          "countdown_paused",
          true
        },

        -- Callback when the progress bar completes
        completeCallback = {
          "completePhase",
        }
      },

      -- Player must stay near the charges or the countdown pauses
      proximityRequirement = {
        location = PLUGIN.referToContractLocation("antlionNest"),
        maxDistance = 512,
        warningMessage = "Stay near the charges or they'll stop arming!",
        returnInRangeMessage = "Back in range - timer resumed.",
        outOfRangeCallback = {
          "setContractValue",
          "countdown_paused",
          true
        },
        returnInRangeCallback = {
          "setContractValue",
          "countdown_paused",
          false
        }
      },

      -- Enemies spawn in waves throughout the phase duration
      -- The spawnWaves key allows enemies to spawn at intervals rather than all at once
      spawnWaves = {
        {
          -- Spawn timing relative to phase start
          delayInSeconds = 0,

          enemies = {
            {
              class = "npc_antlion",
              location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 50,
              count = 5,
              lootTable = combineLootTable,
            },
            {
              class = "npc_antlion_worker",
              location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 30,
              count = 4,
            }
          }
        },
        {
          delayInSeconds = 30,

          enemies = {
            {
              class = "npc_antlion",
              location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 60,
              count = 7,
              lootTable = combineLootTable,
            },
            {
              class = "npc_antlion_worker",
              location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 35,
              count = 5,
            }
          }
        },
        {
          delayInSeconds = 60,

          enemies = {
            {
              class = "npc_antlion",
              location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 70,
              count = 8,
              lootTable = combineLootTable,
            },
            {
              class = "npc_antlion_worker",
              location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 40,
              count = 6,
            },
            {
              class = "npc_antlionguard",
              location = PLUGIN.referToContractLocation("antlionNest", PLUGIN.NEAR_TO_LOCATION),
              behavior = "attacking",
              health = 500,
              count = 1,
              lootTable = combineLootTable,
            }
          }
        },
      },
    },

    -- The player has defended against all the waves and the charges are armed, they receive the detonator.
    {
      objective = {
        title = "Charges Armed",
        description =
        "The demolition charges are armed and ready! Get to the extraction point before the nest collapses.",
      },

      clearProximityRequirement = true, -- Clear the previous phase's proximity requirement since its no longer needed

      lore = {
        type = "radio",
        author = "Maria Chen",
        portrait = "versus/npc/chen_maria.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "Excellent work %PLAYER_NAME%! The charges are armed and those bugs won't be bothering our convoys anymore.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "Here's the detonator - get to the extraction point and we'll blow that nest sky high once you're clear!",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "Move fast, the antlions are regrouping and they're NOT happy about those charges!",
            },
          }
        }
      },

      -- The giveItem key is used to give the player an item, in this case a demolition detonator.
      -- This item grants bonus XP when extracted with, to reward the player for successfully completing the waves and holding their position.
      giveItems = {
        {
          itemID = "demolition_detonator",
          quantity = 1,
        },
      },

      indicators = {
        {
          name = "Extraction Point",

          -- This points to the randomly selected extraction point defined in the locations table
          location = PLUGIN.referToContractLocation("extractionPoint"),
        },
      },

      entities = {
        {
          -- Setup the randomly selected versus_objective_interaction entity for interaction.
          -- The player needs to interact with this to extract and complete the contract.
          entity = PLUGIN.referToContractLocation("extractionPoint"),

          accessors = {
            InteractionCallback = {
              "completeContract",
            },

            InteractionTime = 5,

            InteractionName = "Extract",
          },
        }
      },

      -- We spawn enemies between the player and the extraction point to increase the risk of extraction and make it more
      -- engaging, since the player now needs to escape before the nest explodes.
      enemies = {
        {
          class = "npc_antlion",
          location = PLUGIN.referToContractLocation("extractionPoint", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          health = 60,
          count = 5,
          lootTable = combineLootTable,
        },
        {
          class = "npc_antlion_worker",
          location = PLUGIN.referToContractLocation("extractionPoint", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          health = 35,
          count = 4,
        },
        {
          class = "npc_antlionguard",
          location = PLUGIN.referToContractLocation("extractionPoint", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          health = 500,
          count = 1,
          lootTable = combineLootTable,
        },
      },

      completeCallback = {
        "wait",
        10, -- Give player time to read the lore before showing where the extraction point is
      },
    },

    -- Final phase: extraction point is ready
    {
      objective = {
        title = "Extract Now!",
        description =
        "Reach the extraction point immediately. The nest is about to explode!",
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
            InteractionCallback = {
              "completeContract",
            },

            InteractionTime = 5,

            InteractionName = "Extract",
          },
        }
      },

      -- Take the detonator when they extract
      takeItems = {
        {
          itemID = "demolition_detonator",
          quantity = 1,
        },
      },

      -- No need for completes, we manually call completeContract in the interaction callback when the player interacts
      -- with the extraction point after arming the charges, to complete the contract.
      completeCallback = nil,
    }
  }, -- end phases
})
