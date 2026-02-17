local PLUGIN = PLUGIN

local function combineLootTable(attacker, position, angles)
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

-- Prisoner Extraction contract
-- A resistance scout has been captured and is being held at a Combine detention outpost.
-- The player must break them out before the Combine can interrogate them and compromise the cell.

-- This contract:
-- - Fight through a Combine detention outpost to reach the holding cell
-- - Release the prisoner (5s interact)
-- - Hold near the extraction zone while the prisoner makes their way out (45 seconds)
--   A second wave of Combine reinforcements arrives during this window
-- - Extract

-- DESIGN NOTES:
-- - The "escort window" progress bar is the emotional core of this contract — the player can't
--   leave without the prisoner, creating natural tension without a hard escort mechanic.
-- - PvP interference: Future implementation could allow a rival player to accept a
--   counter-contract to eliminate the prisoner before they can be extracted, preventing
--   the resistance cell's location from being kept secret.

PLUGIN.register("prisoner_extraction", {
  name = {
    "Loose Ends",
    "Prisoner Extraction",
    "Get Them Out",
    "No One Left Behind",
  },

  difficulty = PLUGIN.DIFFICULTY_EASY,
  reward = PLUGIN.REWARD_LOW,
  combatStyle = PLUGIN.COMBAT_STYLE_PVE,

  locations = {
    -- The detention cell where the prisoner is being held
    detentionCell = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "combine_detention_cell",
      false,
      "Detention Cell"
    ),

    -- Spawn point far from the detention cell
    spawnPoint = PLUGIN.defineRelativeLocation(
      "versus_spawn_point",
      "detentionCell",
      PLUGIN.FAR_FROM_LOCATION,
      false,
      "Deployment Zone",
      false
    ),

    -- Extraction point (hidden until the prisoner is freed)
    extractionPoint = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "extraction_point",
      true,
      "Extraction Point",
      false
    ),
  },

  phases = {
    -- Phase 1: Spawn and briefing
    {
      spawn = {
        location = PLUGIN.referToContractLocation("spawnPoint"),
      },

      lore = {
        type = "radio",
        author = "Yeva Volkov",
        portrait = "versus/npc/volkov_yeva.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "Glad you picked this up, %PLAYER_NAME%. We're running out of time.",
              "%PLAYER_NAME%, I won't sugarcoat this — we need you moving fast.",
            },
          },
          {
            delayInSeconds = 1,
            content = {
              "One of our scouts was grabbed by a Combine patrol two days ago. They're being held at a local detention outpost. If the Combine finish their interrogation, our entire cell is blown.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "I'm marking the outpost for you now. Fight through to the holding cell, get them out, and bring them to an extraction point. Don't let them die in there.",
            },
          },
        }
      },

      completeCallback = {"wait", 4},
    },

    -- Phase 2: Fight to the detention cell and release the prisoner
    {
      objective = {
        title = "Reach the Holding Cell",
        description = "Fight through the Combine outpost and release the captured resistance scout.",
      },

      indicators = {
        {
          name = "Detention Cell",
          location = PLUGIN.referToContractLocation("detentionCell"),
        },
      },

      entities = {
        {
          entity = PLUGIN.referToContractLocation("detentionCell"),
          accessors = {
            InteractionCallback = {"setContractValue", "prisoner_freed", true},
            InteractionTime = 5,
            InteractionName = "Release Prisoner",
          }
        }
      },

      -- Combine guards defending the outpost
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("detentionCell"),
          behavior = "defending",
          health = 60,
          count = 4,
          weapons = {"weapon_smg1"},
          lootTable = combineLootTable,
        },
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("detentionCell"),
          behavior = "defending",
          health = 80,
          count = 2,
          weapons = {"weapon_shotgun"},
          lootTable = combineLootTable,
        },
      },

      completeCallback = {"checkContractValueEquals", "prisoner_freed", true},
    },

    -- Phase 3: Prisoner is moving — hold near extraction while they make their way out
    {
      objective = {
        title = "Escort to Extraction",
        description = "Hold near the extraction point while the prisoner makes their way out. Don't let them get cut off.",
      },

      lore = {
        type = "radio",
        author = "Yeva Volkov",
        portrait = "versus/npc/volkov_yeva.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "They're free! But they're hurt, %PLAYER_NAME% — they need time to get to you.",
              "You did it! They're moving, but slowly. Cover that extraction point!",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "The Combine will have heard that. Expect a response team incoming. Hold that position — they need 45 seconds to reach you.",
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

      -- Progress bar representing the prisoner moving to the extraction point
      progressBar = {
        duration = 45,
        type = "decrement",
        label = "Prisoner en route...",
        shouldProgressCallback = {"checkContractValueNotEquals", "extraction_blocked", true},
        completeCallback = {"completePhase"},
      },

      -- Player must hold near the extraction point or the prisoner has no safe path
      proximityRequirement = {
        location = PLUGIN.referToContractLocation("extractionPoint"),
        maxDistance = 600,
        warningMessage = "Stay near the extraction point — the prisoner needs a clear path!",
        returnInRangeMessage = "Back in position. Prisoner moving again.",
        outOfRangeCallback = {"setContractValue", "extraction_blocked", true},
        returnInRangeCallback = {"setContractValue", "extraction_blocked", false},
      },

      -- Combine reinforcements arrive in response to the prison break
      spawnWaves = {
        {
          delayInSeconds = 5,
          enemies = {
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("extractionPoint"),
              behavior = "attacking",
              health = 70,
              count = 4,
              weapons = {"weapon_smg1"},
              lootTable = combineLootTable,
            },
          },
        },
        {
          delayInSeconds = 25,
          enemies = {
            {
              class = "npc_combine_s",
              location = PLUGIN.referToContractLocation("extractionPoint"),
              behavior = "attacking",
              health = 80,
              count = 5,
              weapons = {"weapon_ar2", "weapon_smg1"},
              lootTable = combineLootTable,
            },
            {
              class = "npc_manhack",
              location = PLUGIN.referToContractLocation("extractionPoint"),
              behavior = "attacking",
              count = 3,
            },
          },
        },
      },
    },

    -- Phase 4: Prisoner has arrived — extract
    {
      objective = {
        title = "Extract",
        description = "The prisoner is with you. Get out now.",
      },

      clearProximityRequirement = true,

      lore = {
        type = "radio",
        author = "Yeva Volkov",
        portrait = "versus/npc/volkov_yeva.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "They made it! %PLAYER_NAME%, get them out of there right now.",
              "The prisoner is with you. Extract immediately — you've done enough.",
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
            InteractionCallback = {"completeContract"},
            InteractionTime = 5,
            InteractionName = "Extract",
          },
        }
      },

      completeCallback = nil,
    },
  }, -- end phases
})
