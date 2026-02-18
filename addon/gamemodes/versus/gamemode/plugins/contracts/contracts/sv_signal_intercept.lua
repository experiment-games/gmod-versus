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

-- Mockup of the signal intercept contract for brainstorming purposes.
-- The extraction plugin we currently have will need to be refactored to suit this new setup.

-- IMPORTANT: Before assigning this contract to a player, you must prepare it using:
--   PLUGIN.prepareContractForPlayer(player, "signal_intercept")
-- This will:
--   1. Randomly select a combine relay from the map
--   2. Find the furthest spawn point from that relay
--   3. Randomly select an extraction point
--   4. Store all resolved locations in player._VersusAvailableContracts["signal_intercept"]
-- Each player can get different relay/spawn/extraction combinations, making the contract feel unique.

-- This contract:
-- - Tap into a Combine relay to download encrypted traffic.
-- - Player must hold position near the relay while data downloads (90 seconds)
-- - Combine reinforcements come in escalating waves during the download
-- - Other players might be sent to destroy the same relay or steal the data
-- - Extraction becomes riskier the longer you stay

-- DESIGN NOTES:
-- - Failure handling: If player dies during contract, they should restart at the current phase checkpoint
--   (e.g., if they die during download, restart at download beginning). Consider adding a "retries" limit.
-- - PvP interference: Future implementation could allow other players to:
--   * Accept a counter-contract to destroy the relay before download completes
--   * Kill the player and steal the data_drive item for bonus XP
--   * Compete for the same relay (first to complete gets the data)

-- This is purposefully a simple table, such that we can generate this more easily in the future (e.g: dynamically
-- and custom-fit for the player with an LLM)
PLUGIN.register("signal_intercept", {
  name = {
    "Signal Intercept",
    "Combine Signal Intercept",
    "Relay Tap",
    "Encrypted Data Heist",
  },

  -- One-line description shown in contract listings
  description = {
    "Tap into a Combine relay to download encrypted traffic. Hold position while data downloads — Combine reinforcements come in escalating waves.",
    "We've intercepted chatter about a Combine relay in your area. Hack into it, download their encrypted traffic, and hold position against incoming reinforcements.",
    "A Combine relay is transmitting valuable encrypted data. Hack into it, download the traffic, and hold your position while the data transfers.",
    "There's a Combine relay in your sector that's transmitting encrypted data. Tap into it, download the traffic, and defend against incoming reinforcements.",
  },

  -- Image to show behind the contract name and description. Should be 512x512 for best results.
  image = "versus/contracts/signal_intercept.png",

  tags = {
    { label = "defend", color = Color(100, 160, 220) },
  },

  -- Locations are registered upfront for easy querying
  locations = {
    -- Random combine relay
    combineRelay = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "combine_relay",
      false,
      "Combine Relay"
    ),

    -- Spawn point far from the randomly selected combine relay
    spawnPoint = PLUGIN.defineRelativeLocation(
      "versus_spawn_point",
      "combineRelay",
      PLUGIN.FAR_FROM_LOCATION,
      false,
      "Deployment Zone",
      false
    ),

    -- Extraction point (hidden until player reaches extraction phase)
    extractionPoint = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "extraction_point",
      true,
      "Extraction Point",
      false
    ),
  },

  phases = {
    -- The player first spawns far away from their first interaction point. They are given some lore.
    {
      -- Should always be first in the contract, spawns the player at a location near or far from somewhere else.
      spawn = {
        -- Where to spawn. The spawn point is now a registered location in the contract.
        -- The spawnPoint is defined as FAR_FROM_LOCATION relative to the combineRelay, so the player
        -- will spawn at the furthest versus_spawn_point from the randomly selected combine relay.
        location = PLUGIN.referToContractLocation("spawnPoint"),
      },

      -- Lore to communicate to player
      lore = {
        -- Types for lore can be given through:
        -- - radio: Chat Radio Messages from NPC
        -- - (future implementation, not now) audio: Voice Lines through earpiece (select mp3 files)
        -- - (future implementation, not now) panel: Mission Brief tablet/piece of paper (just a popup panel with a background image
        --   that can be swapped depending on preferred style)
        type = "radio",

        -- Author, in case of chat radio messages this is put in front of the messages (e.g: "Jeffrey Song: Thanks for...")
        author = "Jeffrey Song",
        portrait = "versus/npc/song_jeffrey.png",

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
              "We've recently intercepted chatter about a Combine relay in your area. We need you to hack into it and download their encrypted traffic. Intel suggests it contains shipping manifests between Nova Prospekt and other facilities. This data will help us greatly.",
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
      completeCallback = {
        "wait",
        4, -- Wait 4 seconds before moving to the next phase, to give time for the lore to be read and absorbed by the player.
      }
    },

    -- The player then gets the objective and should go to that to interact with it.
    -- This phase supports interference: subsequent players can accept a contract to sabotage the relay
    {
      maxSubsequent = 2, -- Allow up to 2 subsequent players to interfere

      first = {
        -- The objective key puts an objective that can be completed on the players HUD during this phase.
        -- TODO: Refactor the extraction plugin's objectives into its own plugin, so we can easily set/manage objectives seperate from versus_objective_interaction entities/extraction.
        objective = {
          -- Title of the objective to show
          title = "Initiate Download",

          -- Description to elaborate
          description = "Interact with the relay to begin downloading encrypted traffic for the resistance.",
        },

        -- The indicators key is used to setup indicators on the player's HUD that point towards something.
        -- It can be used to point towards an entity, a location, or just generally mark a location on the map.
        indicators = {
          {
            -- Name to show above the indicator
            name = "Combine Relay",

            -- Where to mark the indicator
            location = PLUGIN.referToContractLocation("combineRelay"),
          },
        },

        -- entities is a key is used to setup/modify entities for the player to interact with.
        entities = {
          {
            -- Find the entity related to the combine relay (e.g: a versus_objective_interaction with the tag combine_relay) and set it up for interaction.
            -- This is the entity the player needs to interact with to start the download process.
            entity = PLUGIN.referToContractLocation("combineRelay"),

            accessors = {
              -- This is a special case that will also have the player injected as the first parameter to SetInteractionCallback,
              -- since interaction callbacks need to be player-specific (e.g: if multiple players have the same contract, they
              -- should not override each other's interaction callbacks).
              InteractionCallback = {
                -- Function name and parameters called when player interacts with the entity
                "setContractValue",
                "download_started",
                true
              },

              -- How long it takes to interact with the entity, used in the progress bar during the download phase
              InteractionTime = 5,

              -- Text to show on the entity to interact with it.
              InteractionName = "Initiate Download",
            }
          }
        },

        -- enemies is a key used to setup enemies and place them somewhere.
        enemies = {
          {
            class = "npc_combine_s",
            location = PLUGIN.referToContractLocation("combineRelay"),

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
            location = PLUGIN.referToContractLocation("combineRelay"),
            behavior = "defending",
            count = 2,
          },
        },

        -- Since it's a table checkContractValueEquals is called in Think with "download_started" and true as parameters
        completeCallback = {
          "checkContractValueEquals",
          "download_started",
          true
        },
      },

      subsequent = {
        objective = {
          title = "Sabotage Relay",
          description =
          "Stop the reckless data download that will bring Combine wrath down on the entire resistance. Sabotage the relay before the download begins.",
        },

        indicators = {
          {
            name = "Combine Relay [TARGET]",
            location = PLUGIN.referToContractLocation("combineRelay"),
          },
        },

        lore = {
          type = "radio",
          author = "Marcus Jones",
          portrait = "versus/npc/jones_marcus.png",
          texts = {
            {
              delayInSeconds = 0.5,
              content = {
                "%PLAYER_NAME%, we just got word someone's hacking a Combine relay in your sector. This is suicide - they'll bring an entire battalion down on us!",
                "Listen %PLAYER_NAME%, I know you mean well, but hacking that relay will get everyone in this area killed. The Combine will retaliate hard.",
              },
            },
            {
              delayInSeconds = 2,
              content = {
                "You need to stop them before they complete that download. We can't afford the heat this will bring. I'm sorry, but our people's safety comes first.",
                "I'm marking the relay location. Stop that download before the Combine trace it back to our safehouses. Neutralize the threat if you have to.",
              },
            },
          }
        },

        -- Subsequent players spawn closer to the relay for PvP encounter
        spawn = {
          location = PLUGIN.referToContractLocation("combineRelay"),
        },

        -- Subsequent players still complete the same way - when first player starts download
        completeCallback = {
          "checkContractValueEquals",
          "download_started",
          true
        },
      },
    },

    -- Once the player initiates the download, they must hold position near the relay while data downloads.
    -- Enemies come in escalating waves until the download completes.
    -- Subsequent players try to destroy the relay to stop the download
    {
      maxSubsequent = 2, -- Allow up to 2 subsequent players to interfere during download

      first = {
        objective = {
          title = "Hold Position",
          description =
          "Hold your position near the relay and defend against incoming Combine reinforcements while the data downloads.",
        },

        -- The progressBar key displays a progress bar on the player's HUD with a label and time
        progressBar = {
          -- Other types can be "increment" to have the bar go upwards instead of downwards
          type = "decrement",

          -- Label to show above the progress bar
          label = "Downloading Signal Data",

          -- Duration in seconds for the progress bar to fill (should match completes wait time)
          duration = 30, -- TODO: 90, just lowered for testing purposes

          shouldProgressCallback = {
            -- Function name and parameters called in Think to determine if the progress bar should progress
            "checkContractValueNotEquals",
            "download_paused",
            true
          },

          completeCallback = {
            "completePhase"
          },
        },

        -- The proximityRequirement key enforces that the player stays near a location
        -- Can be used for any contract that requires holding ground, defending an area, etc.
        proximityRequirement = {
          -- Reference to the location the player must stay near
          location = PLUGIN.referToContractLocation("combineRelay"),

          -- Maximum distance player can be from location (in units)
          maxDistance = 512,

          -- warning message to show once when player goes out of range
          warningMessage = "The download has been interrupted! Stay near the relay to ensure it successfully completes.",

          outOfRangeCallback = {
            -- Function name and parameters called when player fails the proximity requirement
            "setContractValue",
            "download_paused",
            true
          },

          returnInRangeCallback = {
            -- Function name and parameters called when player returns in range after failing the proximity requirement
            "setContractValue",
            "download_paused",
            false
          },
        },

        -- Enemies spawn in waves throughout the phase duration
        -- The spawnWaves key allows enemies to spawn at intervals rather than all at once
        spawnWaves = {
          {
            -- Spawn timing relative to phase start
            delayInSeconds = 0,

            enemies = {
              {
                class = "npc_combine_s",
                location = PLUGIN.referToContractLocation("combineRelay"),
                behavior = "attacking",
                health = 50,
                count = 4,
                weapons = { "weapon_ar2", "weapon_smg1" },
                lootTable = combineLootTable,
              },
              {
                class = "npc_manhack",
                location = PLUGIN.referToContractLocation("combineRelay"),
                behavior = "attacking",
                count = 3,
              }
            }
          },
          {
            delayInSeconds = 30,

            enemies = {
              {
                class = "npc_combine_s",
                location = PLUGIN.referToContractLocation("combineRelay"),
                behavior = "attacking",
                health = 75,
                count = 6,
                weapons = { "weapon_ar2", "weapon_smg1" },
                lootTable = combineLootTable,
              },
              {
                class = "npc_manhack",
                location = PLUGIN.referToContractLocation("combineRelay"),
                behavior = "attacking",
                count = 4,
              }
            }
          },
          {
            delayInSeconds = 60,

            enemies = {
              {
                class = "npc_combine_s",
                location = PLUGIN.referToContractLocation("combineRelay"),
                behavior = "attacking",
                health = 100,
                count = 8,
                weapons = { "weapon_ar2", "weapon_smg1" },
                lootTable = combineLootTable,
              },
              {
                class = "npc_manhack",
                location = PLUGIN.referToContractLocation("combineRelay"),
                behavior = "attacking",
                count = 6,
              },
            }
          },
        },
      },

      subsequent = {
        objective = {
          title = "Destroy Relay",
          description =
          "The download has started! Destroy the relay before the data transfer completes and dooms the entire resistance cell!",
        },

        lore = {
          type = "radio",
          author = "Marcus Jones",
          portrait = "versus/npc/jones_marcus.png",
          texts = {
            {
              delayInSeconds = 0.5,
              content = {
                "Dammit %PLAYER_NAME%, the download's already started! Every second that relay is active increases the chance the Combine triangulate our position!",
                "They've started the download! %PLAYER_NAME%, you need to plant explosives on that relay NOW before we're all compromised!",
              },
            },
            {
              delayInSeconds = 2,
              content = {
                "I know you don't want to do this, but it's them or our entire cell. Destroy that relay before it's too late!",
              },
            },
          }
        },

        indicators = {
          {
            name = "Relay [DESTROY]",
            location = PLUGIN.referToContractLocation("combineRelay"),
          },
        },

        -- Give subsequent players an objective to destroy the relay
        entities = {
          {
            entity = PLUGIN.referToContractLocation("combineRelay"),
            accessors = {
              InteractionCallback = {
                "setContractValue",
                "relay_destroyed",
                true
              },
              InteractionTime = 10,
              InteractionName = "Plant Explosives",
            }
          }
        },

        -- Subsequent players win if they destroy the relay OR outlast the download timer
        -- They sync with first player's phase completion, so they auto-complete/fail when download finishes
        completeCallback = {
          "checkContractValueEquals",
          "relay_destroyed",
          true
        },
      },
    },

    -- The player has defended against all the waves and downloaded the data, they receive the data drive.
    {
      objective = {
        title = "Data Downloaded",
        description =
        "Download complete! The encrypted traffic has been written to a data drive. Wait for extraction instructions.",
      },

      clearProximityRequirement = true, -- Clear the previous phase's proximity requirement since its no longer needed

      lore = {
        type = "radio",
        author = "Jeffrey Song",
        portrait = "versus/npc/song_jeffrey.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "Excellent work %PLAYER_NAME%! The download is complete and you've secured the data.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "Take the data drive to an extraction point - the Combine will be sending reinforcements to recover that data, so move quickly!",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "I'm marking an extraction point for you now. Good luck!",
            },
          }
        }
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

      -- We spawn enemies in between the player and the extraction point to increase the risk of extraction and make it more
      -- engaging, since the player is now carrying valuable data that the combine want to get back.
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("extractionPoint"),
          behavior = "defending",
          health = 75,
          count = 6,
          weapons = { "weapon_ar2", "weapon_smg1" },
          lootTable = combineLootTable,
        },
        {
          class = "npc_manhack",
          location = PLUGIN.referToContractLocation("extractionPoint"),
          behavior = "defending",
          count = 6,
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
        title = "Extraction Unlocked",
        description =
        "Make your way to the extraction point to complete the contract and deliver the encrypted data to the resistance.",
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

      -- No need for completes, we manually call completeContract in the interaction callback when the player interacts
      -- with the extraction point after downloading the data, to complete the contract.
      completeCallback = nil,
    }
  }, -- end phases
})
