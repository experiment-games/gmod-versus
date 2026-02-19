local PLUGIN = PLUGIN

local function combineLootTable(npc, attacker, position, angles)
  local loot = {
    ["health_vial"] = 0.2,
  }

  hook.Run("ModifyContractLootTable", npc, loot, attacker, position, angles)

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

  -- One-line description shown in contract listings
  description = {
    "A resistance scout has been captured by the Combine and is being held at a local detention outpost. Fight through the facility, and get them to an extraction point.",
    "One of our scouts was grabbed by a Combine patrol and is being held at a nearby detention outpost. Get them out, and lead them to extraction.",
    "A resistance scout has been captured and is being held at a Combine detention outpost. Break them out, and escort them to an extraction point.",
    "We've got a situation with a captured scout being held at a Combine detention outpost. Get them out, and lead them to extraction.",
  },

  -- Image to show behind the contract name and description. Should be 512x512 for best results.
  image = "versus/contracts/prisoner_extraction.png",

  tags = {
    { label = "escort", color = Color(100, 200, 140) },
    { label = "pve",    color = Color(100, 160, 220) },
  },

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

      completeCallback = { "wait", 4 },
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

      -- The prisoner NPC — idle until the player interacts, then follows them
      escortNPCs = {
        {
          npcClass        = "npc_citizen",
          location        = PLUGIN.referToContractLocation("detentionCell"),
          health          = 100,
          interactionName = "Escort Prisoner",
          followCallback  = { "setContractValue", "prisoner_freed", true },
          deathCallback   = { "failContract", "The prisoner was killed before they could be extracted." },
        },
      },

      -- Combine guards defending the outpost
      enemies = {
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("detentionCell"),
          behavior = "defending",
          health = 60,
          count = 4,
          weapons = { "weapon_smg1" },
          lootTable = combineLootTable,
          -- Guards are keeping the prisoner in custody — they should not attack them
          relationships = { "npc_citizen D_NU 99" },
        },
        {
          class = "npc_combine_s",
          location = PLUGIN.referToContractLocation("detentionCell"),
          behavior = "defending",
          health = 80,
          count = 2,
          weapons = { "weapon_shotgun" },
          lootTable = combineLootTable,
          -- Guards are keeping the prisoner in custody — they should not attack them
          relationships = { "npc_citizen D_NU 99" },
        },
      },

      completeCallback = { "checkContractValueEquals", "prisoner_freed", true },
    },

    -- Phase 3: Escort the prisoner to the extraction point
    {
      objective = {
        title = "Escort to Extraction",
        description = "Lead the prisoner to the extraction point. Keep them alive.",
      },

      lore = {
        type = "radio",
        author = "Yeva Volkov",
        portrait = "versus/npc/volkov_yeva.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "They're with you — now move! Get them to the extraction point!",
              "Good work getting them out. Don't stop — get to extraction now!",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "The Combine will have heard that. Expect a response team. Keep the prisoner alive and get to extraction.",
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

      -- A Combine intercept team cuts across the route to extraction as soon as the
      -- prison break is detected — spawned ahead of the player on the path so they
      -- feel the route is being closed off rather than enemies merely catching up.
      interceptEnemies = {
        destination = PLUGIN.referToContractLocation("extractionPoint"),
        interceptFraction = 0.4, -- spawn closer to the player to create immediate pressure
        enemies = {
          {
            class         = "npc_combine_s",
            count         = 3,
            health        = 75,
            weapons       = { "weapon_smg1" },
            lootTable     = combineLootTable,
            -- Intercept team should not attack the prisoner they're chasing the player
            relationships = { "npc_citizen D_NU 99" },
          },
        },
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
              weapons = { "weapon_smg1" },
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
              weapons = { "weapon_ar2", "weapon_smg1" },
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

      completeCallback = nil,
    },
  }, -- end phases
})
