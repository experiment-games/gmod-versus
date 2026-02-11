local PLUGIN = PLUGIN

PLUGIN.EXACT = 0
PLUGIN.NEAR_TO_LOCATION = 1
PLUGIN.FAR_FROM_LOCATION = 2

function PLUGIN.referToContractEntity(locationID, distance)
  distance = distance or PLUGIN.EXACT

  return {
    id = locationID,
    distance = distance,
  }
end

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

-- Mockup of the signal intercept contract for brainstorming purposes.
-- The extraction plugin we currently have will need to be refactored to suit this new setup.

-- This contract:
-- - Tap into a Combine relay to download encrypted traffic.
-- - Player must hold position while data downloads in bursts
-- - Combine reinforcements escalate in waves
-- - Other players might be sent to destroy the same relay or steal the data
-- - Extraction becomes riskier the longer you stay

-- This is purposefully a simple table, such that we can generate this more easily in the future (e.g: dynamically
-- and custom-fit for the player with an LLM)
PLUGIN.register("signal_intercept", {
  phases = {
    -- The player first spawns far away from their first interaction point. They are given some lore.
    {
      -- Should always be first in the contract, spawns the player at a location near or far from somewhere else.
      spawn = {
        -- Where to spawn. If in this contract, we haven't looked for combine_relay yet, it is picked and stored in a contract bag for
        -- later reference. If there are multiple combine_relays, one is picked at random.
        -- The FAR_FROM_LOCATION option makes sure to spawn the player at a far distance from the combine_relay.
        location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.FAR_FROM_LOCATION), -- or PLUGIN.NEAR_TO_LOCATION or PLUGIN.EXACT
      },

      -- Lore to communicate to player
      lore = {
        -- Types for lore can be given through:
        -- - chat_radio: Chat Radio Messages from NPC
        -- - (future implementation, not now) audio: Voice Lines through earpiece (select mp3 files)
        -- - (future implementation, not now) panel: Mission Brief tablet/piece of paper (just a popup panel with a background image
        --   that can be swapped depending on preferred style)
        type = "chat_radio",

        -- Author, in case of chat radio messages this is put in front of the messages (e.g: "Jeffrey Song: Thanks for...")
        author = "Jeffrey Song",

        -- Texts to trickle to the player
        texts = {
          {
            -- Relative to previous text (or phase start in this case, since its first)
            delayInSeconds = 1,

            -- A random one from this table is selected (to have variation when working the same contract later)
            content = {
              "Thanks for helping the resistance out with this contract %PLAYER_NAME%, your help is appreciated!",
              "You're a true ally to the resistance, %PLAYER_NAME%!",
            },
          },
          {
            delayInSeconds = 1,
            content = {
              -- TODO: finish text
              "We've recently heard ... combine relay ... can you intercept and download their encrypted traffic ... Nova Prospekt and other locations ... will help us greatly.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "I'm marking the Combine Relay location for you now. You can expect some defensive combine forces at that location.",
            },
          }
        }
      },

      -- Its a table with function name and parameters it is called with those parameters in a Think hook to
      -- see if the phase should end and move on to the next phase.
      completes = {
        "wait",
        4, -- Wait 4 seconds before moving to the next phase, to give time for the lore to be read and absorbed by the player.
      }
    },

    -- The player then gets the objective and should go to that to interact with it.
    {
      -- The objective key puts an objective that can be completed on the players HUD during this phase.
      -- TODO: Refactor the extraction plugin's objectives into its own plugin, so we can easily set/manage objectives seperate from versus_extraction_condition entities/extraction.
      objective = {
        -- Title of the objective to show
        title = "Intercept Combine Relay",

        -- Description to elaborate
        description = "Interact with the relay to download encrypted traffic for the resistance.",
      },

      -- The indicators key is used to setup indicators on the player's HUD that point towards something.
      -- It can be used to point towards an entity, a location, or just generally mark a location on the map.
      indicators = {
        {
          -- Name to show above the indicator
          name = "Combine Relay",

          -- Where to mark the indicator
          location = PLUGIN.referToContractEntity("combine_relay"), -- Defaults to PLUGIN.EXACT, the exact location of the versus_extraction_condition tagged as combine_relay.
        },
      },

      -- entities is a key is used to setup/modify entities for the player to interact with.
      entities = {
        {
          -- Find the entity related to the combine relay (e.g: a versus_extraction_condition with the tag combine_relay) and set it up for interaction.
          -- This is the entity the player needs to interact with to complete the first objective and move on to the waves.
          entity = PLUGIN.referToContractEntity("combine_relay"),

          -- The player(s) this contract is for will automatically be AddPlayer'd on the entity, such that they can interact
          -- with it. The interaction they can have with it is:
          interaction = {
            -- Text to show on the entity to interact with it.
            text = "Intercept",

            -- How long it takes to interact
            duration = 5,

            -- Called after the interaction completes (setContractValue("intercepted", true))
            callback = {
              "setContractValue",
              "intercepted",
              true
            }
          }
        }
      },

      -- enemies is a key used to setup enemies and place them somewhere.
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),

          -- The behavior can be:
          -- - defending: they stay around the location, waiting for a player to defend against.
          -- - attacking: they actively chase down the player (current NPC behavior in this plugin)
          behavior = "defending",
          health = 50,
          count = 8,
          weapons = { "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          count = 2,
        },
      },

      -- Since it's a table checkContractValueEquals is called in Think with "intercepted" and true as parameters
      completes = {
        "checkContractValueEquals",
        "intercepted",
        true
      },
    },

    -- Once the player interacts with the combine relay, waves of combine start coming. Each wave is a phase.
    {
      objective = {
        title = "Hold Position (Wave 1/3)",
        description = "Hold your position and defend against incoming Combine reinforcements while the data downloads.",
      },

      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "attacking",
          health = 50,
          count = 4,
          weapons = { "weapon_ar2", "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "attacking",
          count = 4,
        }
      },

      completes = {
        "phaseEnemyCountEquals",
        0, -- When there are no enemies left from this phase, move on to the next phase.
      }
    },

    -- Phase 2 of the waves, slightly stronger enemies.
    {
      objective = {
        title = "Hold Position (Wave 2/3)",
        description = "Hold your position and defend against incoming Combine reinforcements while the data downloads.",
      },

      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "attacking",
          health = 75,
          count = 6,
          weapons = { "weapon_ar2", "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "attacking",
          count = 6,
        }
      },

      completes = {
        "phaseEnemyCountEquals",
        0,
      }
    },

    -- Phase 3 of the waves, even stronger enemies.
    {
      objective = {
        title = "Hold Position (Wave 3/3)",
        description = "Hold your position and defend against incoming Combine reinforcements while the data downloads.",
      },

      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "attacking",
          health = 100,
          count = 8,
          weapons = { "weapon_ar2", "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.NEAR_TO_LOCATION),
          behavior = "attacking",
          count = 8,
        },
      },

      completes = {
        "phaseEnemyCountEquals",
        0,
      },
    },

    -- The player has defended against all the waves and downloaded the data, they can now extract.
    {
      objective = {
        title = "Extraction Unlocked",
        description =
        "You've successfully intercepted the Combine relay and downloaded the encrypted traffic onto a data drive. Extraction is now unlocked, make your way to an extraction point to complete the contract.",
      },

      -- The giveItem key is used to give the player an item, in this case a data drive that represents the downloaded encrypted traffic.
      -- This item grants bonus XP when extracted with, to reward the player for successfully completing the waves and holding their position.
      -- We can later add another contract for other players to steal this data drive from the player and extract it themselves for bonus XP,
      -- to add more interaction between players.
      giveItems = {
        {
          itemID = "data_drive",
          quantity = 1,
        },
      },

      -- The locations key can be used to setup a location for the contract explicitly. Where referToContractEntity just picks one at
      -- random from the map with that tag, this is used when you want to explicitly set a location based on some other factor (e.g: the player's current location, or a location relative to another location).
      location = {
        -- We pick an extraction point far from the combine relay, to have the player move across the map and give us the chance to
        -- spawn more enemies on the way if we want to increase the difficulty/risk of extraction.
        {
          tag = "extraction_point",
          location = PLUGIN.referToContractEntity("combine_relay", PLUGIN.FAR_FROM_LOCATION),
        },
      },

      indicators = {
        {
          name = "Extraction Point",

          -- This would point towards the location we set up in the location key with the tag "extraction_point".
          location = PLUGIN.referToContractEntity("extraction_point"),
        },
      },


      entities = {
        {
          -- Setup the versus_extraction_point entity for interaction, similar to how we set up the combine relay for interaction in the previous phase.
          -- The player needs to interact with this to extract and complete the contract.
          entity = PLUGIN.referToContractEntity("extraction_point"),

          interaction = {
            text = "Extract",
            duration = 5,
            callback = {
              "completeContract",
            }
          }
        }
      },

      -- We spawn enemies in between the player and the extraction point to increase the risk of extraction and make it more
      -- engaging, since the player is now carrying valuable data that the combine want to get back.
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractEntity("extraction_point", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          health = 75,
          count = 6,
          weapons = { "weapon_ar2", "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractEntity("extraction_point", PLUGIN.NEAR_TO_LOCATION),
          behavior = "defending",
          count = 6,
        },
      },

      -- No need, we manually call completeContract in the interaction callback when the player interacts
      -- with the extraction point after downloading the data, to complete the contract.
      completes = nil,
    }
  }, -- end phases
})
