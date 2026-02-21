local PLUGIN = PLUGIN

local function zombieLootTable(npc, attacker, position, angles)
  -- Zombies drop health more reliably since they carry no weapons
  local loot = {
    ["health_vial"] = 0.35,
  }

  hook.Run("ModifyContractLootTable", npc, loot, attacker, position, angles)

  if (IsValid(attacker) and attacker:IsPlayer()) then
    local activeWeapon = attacker:GetActiveWeapon()

    if (IsValid(activeWeapon)) then
      local ammoType = activeWeapon:GetPrimaryAmmoType()

      if (ammoType and ammoType ~= -1) then
        local ammoItemID = versus.weapon.getItemIDFromAmmoType(ammoType)

        if (ammoItemID) then
          loot[ammoItemID] = 0.2
        end
      end
    end
  end

  return loot
end

-- Dead Reckoning contract
-- A resistance science outpost in an irradiated zone was overrun by a headcrab outbreak weeks ago.
-- Dr. Lazlo barely escaped with his life — but his inhibitor samples stayed behind.
-- Those samples could help the resistance develop a viable headcrab toxin dispersal system.
-- Someone has to go back in.

-- IMPORTANT: Before assigning this contract to a player, you must prepare it using:
--   PLUGIN.prepareContractForPlayer(player, "dead_reckoning")
-- This will:
--   1. Randomly select a contaminated research outpost from the map
--   2. Find the furthest spawn point from that outpost
--   3. Randomly select an extraction point
--   4. Store all resolved locations in player._VersusAvailableContracts["dead_reckoning"]

-- This contract:
-- - Navigate a radiation-contaminated wasteland to a zombie-overrun research outpost
-- - Retrieve inhibitor sample canisters from the research control panel (disturbs the nest)
-- - Upload the research data remotely while holding position as the zombies swarm (75 seconds)
-- - Fight out through the overrun facility with escalating zombie pressure
-- - Extract at the resistance decontamination point

-- DESIGN NOTES:
-- - The hold phase is the emotional core: the player is trapped in a zombie nest, radiation
--   ticking away, waiting for a progress bar to fill. The escalation from slow zombies to
--   fast zombies to poison zombies should feel like the outpost actively waking up.
-- - The sample canisters as a carried item create extraction tension — dying with them means
--   losing the mission payoff.
-- - PvP interference: Future implementation could allow another player to accept a counter-contract
--   to intercept and steal the samples during the escape phase, forcing a direct confrontation
--   between the player and a rival who's been lurking in the irradiated zone.

PLUGIN.register("dead_reckoning", {
  name = {
    "Dead Reckoning",
    "Into the Dead Zone",
    "No Sample Left Behind",
    "Nest Dive",
  },

  -- One-line description shown in contract listings
  description = {
    "A resistance outpost in an irradiated zone was overrun weeks ago. Get in, retrieve the inhibitor samples, upload the research data and get out.",
    "Dr. Lazlo's inhibitor research is locked inside a zombie-infested outpost deep in a contaminated area. Recover the samples and upload the data.",
    "A zombie outbreak consumed a resistance research outpost in an irradiated zone. The inhibitor samples inside could change the war...",
    "The contaminated outpost holds the only remaining copies of Lazlo's headcrab inhibitor research. Break in, grab the samples, survive, and extract.",
  },

  -- Image to show behind the contract name and description. Should be 512x512 for best results.
  image = "versus/contracts/zombies.png",

  tags = {
    { label = "horde",     color = Color(180, 50, 50) },
    { label = "defend",    color = Color(100, 160, 220) },
    { label = "radiation", color = Color(120, 200, 80) },
  },

  locations = {
    -- The contaminated research outpost
    researchOutpost = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "research_outpost",
      false,
      "Research Outpost"
    ),

    -- Spawn point far from the contaminated outpost
    spawnPoint = PLUGIN.defineRelativeLocation(
      "versus_spawn_point",
      "researchOutpost",
      PLUGIN.FAR_FROM_LOCATION,
      false,
      "Deployment Zone",
      false
    ),

    -- Extraction point (hidden until samples are secured)
    extractionPoint = PLUGIN.defineLocation(
      "versus_objective_interaction",
      "extraction_point",
      true,
      "Extraction Point",
      false
    ),
  },

  phases = {
    -- Phase 1: Spawn and briefing from Dr. Lazlo
    {
      spawn = {
        location = PLUGIN.referToContractLocation("spawnPoint"),
      },

      lore = {
        type = "radio",
        author = "Dr. Lazlo",
        portrait = "versus/npc/lazlo.png",
        texts = {
          {
            delayInSeconds = 1,
            content = {
              "This is Dr. Aleksei Lazlo. I owe you an apology before we even start — I'm the one who left those samples behind.",
              "This is Lazlo. Before you go any further, you should know what happened at that outpost. I left the samples. That's on me.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "The outbreak happened overnight. Headcrabs in the ventilation. By the time the alarm sounded we'd already lost four people. I ran. The inhibitor canisters stayed.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "I'm marking the control panel for you. Retrieve the canisters and plug in the uplink — I need the full dataset uploaded remotely before the samples are any use to us. That takes about seventy-five seconds, and the noise will draw every infected in that building.",
            },
          },
          {
            delayInSeconds = 2,
            content = {
              "I won't pretend it's safe. The zone is still hot — your suit will hold for the duration if you don't dawdle. The zombies are a bigger problem than the radiation. Good luck.",
            },
          },
        }
      },

      completeCallback = { "wait", 6 },
    },

    -- Phase 2: Cross the irradiated wasteland to the overrun outpost
    {
      objective = {
        title = "Reach the Outpost",
        description = "Cross the irradiated zone and reach the contaminated research outpost.",
      },

      indicators = {
        {
          name = "Research Outpost",
          location = PLUGIN.referToContractLocation("researchOutpost"),
        },
      },

      -- Wandering zombies patrolling the irradiated wasteland around the outpost
      enemies = {
        {
          class = "npc_zombie",
          location = PLUGIN.referToContractLocation("researchOutpost"),
          behavior = "attacking",
          health = 60,
          count = 3,
          lootTable = zombieLootTable,
        },
        {
          class = "npc_headcrab",
          location = PLUGIN.referToContractLocation("researchOutpost"),
          behavior = "attacking",
          health = 20,
          count = 2,
          lootTable = zombieLootTable,
        },
        {
          class = "npc_fastzombie",
          location = PLUGIN.referToContractLocation("researchOutpost"),
          behavior = "attacking",
          health = 50,
          count = 1,
          lootTable = zombieLootTable,
        },
      },

      completeCallback = {
        "checkInRange",
        PLUGIN.referToContractLocation("researchOutpost"),
        512,
      },
    },

    -- Phase 3: Retrieve the inhibitor samples — disturbs the nest inside the outpost
    {
      objective = {
        title = "Retrieve the Inhibitor Samples",
        description = "Locate the marked control panel and retrieve the inhibitor sample canisters. Expect resistance.",
      },

      lore = {
        type = "radio",
        author = "Dr. Lazlo",
        portrait = "versus/npc/lazlo.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "You're close. The canisters are secured at the main control panel — look for the marked console. Grab them first, then plug in the uplink. Do it fast.",
            },
          },
        }
      },

      indicators = {
        {
          name = "Control Panel",
          location = PLUGIN.referToContractLocation("researchOutpost"),
        },
      },

      entities = {
        {
          entity = PLUGIN.referToContractLocation("researchOutpost"),
          accessors = {
            InteractionCallback = { "setContractValue", "samples_retrieved", true },
            InteractionTime = 4,
            InteractionName = "Retrieve Samples",
          },
        },
      },

      -- Dormant infected inside the outpost — awakened when the player enters and disturbs the locker
      enemies = {
        {
          class = "npc_zombie",
          location = PLUGIN.referToContractLocation("researchOutpost"),
          behavior = "defending",
          health = 60,
          count = 3,
          lootTable = zombieLootTable,
        },
        {
          class = "npc_zombie_torso",
          location = PLUGIN.referToContractLocation("researchOutpost"),
          behavior = "attacking",
          health = 30,
          count = 2,
          lootTable = zombieLootTable,
        },
        {
          class = "npc_fastzombie",
          location = PLUGIN.referToContractLocation("researchOutpost"),
          behavior = "attacking",
          health = 50,
          count = 1,
          lootTable = zombieLootTable,
        },
        {
          class = "npc_headcrab_fast",
          location = PLUGIN.referToContractLocation("researchOutpost"),
          behavior = "attacking",
          health = 15,
          count = 2,
        },
      },

      completeCallback = { "checkContractValueEquals", "samples_retrieved", true },
    },

    -- Phase 4: Hold position while research data uploads — zombie horde awakens fully
    {
      objective = {
        title = "Upload Research Data",
        description =
        "Hold your position at the control panel while the research data uploads. Don't let the infected stop the upload!",
      },

      lore = {
        type = "radio",
        author = "Dr. Lazlo",
        portrait = "versus/npc/lazlo.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "Upload started. Seventy-five seconds. I know that sounds like a long time right now.",
              "Upload's running. Seventy-five seconds. Stay close to the panel — if you stray too far your suit's uplink loses the signal.",
            },
          },
          {
            delayInSeconds = 3,
            content = {
              "The outbreak spread through the ventilation and into the lower levels. Whatever is still alive down there, you've just told it exactly where you are.",
            },
          },
        }
      },

      indicators = {
        {
          name = "Control Panel",
          location = PLUGIN.referToContractLocation("researchOutpost"),
        },
      },

      -- Progress bar showing the data upload countdown
      progressBar = {
        duration = 75,
        type = "increment",
        label = "Uploading Research Data",

        -- If the player leaves proximity, the upload signal drops and pauses
        shouldProgressCallback = {
          "checkContractValueNotEquals",
          "upload_paused",
          true
        },

        completeCallback = {
          "completePhase",
        }
      },

      -- Player must stay near the terminal to maintain upload signal
      proximityRequirement = {
        location = PLUGIN.referToContractLocation("researchOutpost"),
        maxDistance = 384,
        warningMessage = "Too far from the panel — upload signal lost!",
        returnInRangeMessage = "Signal restored — upload resuming.",
        outOfRangeCallback = {
          "setContractValue",
          "upload_paused",
          true
        },
        returnInRangeCallback = {
          "setContractValue",
          "upload_paused",
          false
        }
      },

      -- Escalating zombie waves as the nest fully wakes up
      spawnWaves = {
        {
          -- Initial surge: the outpost's lower levels spill out
          delayInSeconds = 0,

          enemies = {
            {
              class = "npc_zombie",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 60,
              count = 3,
              lootTable = zombieLootTable,
            },
            {
              class = "npc_headcrab",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 20,
              count = 2,
            },
          },
        },
        {
          -- Second wave: fast infected converge from the upper floors
          delayInSeconds = 25,

          enemies = {
            {
              class = "npc_fastzombie",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 55,
              count = 3,
              lootTable = zombieLootTable,
            },
            {
              class = "npc_headcrab_fast",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 15,
              count = 3,
            },
            {
              class = "npc_zombie",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 70,
              count = 2,
              lootTable = zombieLootTable,
            },
          },
        },
        {
          -- Final wave: the deep infection stirs — poison zombies emerge
          delayInSeconds = 50,

          enemies = {
            {
              class = "npc_poisonzombie",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 250,
              count = 1,
              isBoss = true,
              bossName = "Bloated Infected",
              lootTable = zombieLootTable,
            },
            {
              class = "npc_fastzombie",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 60,
              count = 3,
              lootTable = zombieLootTable,
            },
            {
              class = "npc_headcrab_black",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 30,
              count = 2,
            },
          },
        },
      },
    },

    -- Phase 5: Upload complete — escape the outpost with the samples
    {
      objective = {
        title = "Get to Extraction",
        description = "Upload complete. Get to the extraction point — the infected are still swarming.",
      },

      clearProximityRequirement = true,

      lore = {
        type = "radio",
        author = "Dr. Lazlo",
        portrait = "versus/npc/lazlo.png",
        texts = {
          {
            delayInSeconds = 0.5,
            content = {
              "Upload complete. Everything transferred. Now get out of there — I'm marking an extraction point. Resistance team is standing by.",
              "Got it, full dataset received. Get to extraction. Move now.",
            },
          },
          {
            delayInSeconds = 3,
            content = {
              "And... thank you. Seriously. Don't die with those samples in your hands.",
            },
          },
        }
      },

      -- Give the player the physical inhibitor sample canisters to carry to extraction
      -- These grant bonus XP when extracted with, rewarding the player for surviving the hold phase
      giveItems = {
        {
          itemID = "inhibitor_samples",
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

      -- Fast infected and stragglers cut across the escape route
      -- Spawned between the outpost and extraction to pressure the escape
      interceptEnemies = {
        destination = PLUGIN.referToContractLocation("extractionPoint"),
        interceptFraction = 0.5,
        enemies = {
          {
            class = "npc_fastzombie",
            behavior = "attacking",
            health = 55,
            count = 2,
            lootTable = zombieLootTable,
          },
          {
            class = "npc_zombie",
            behavior = "attacking",
            health = 70,
            count = 2,
            lootTable = zombieLootTable,
          },
        },
      },

      -- Stragglers spill out of the outpost in pursuit
      spawnWaves = {
        {
          delayInSeconds = 5,
          enemies = {
            {
              class = "npc_zombie",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 65,
              count = 2,
              lootTable = zombieLootTable,
            },
            {
              class = "npc_fastzombie",
              location = PLUGIN.referToContractLocation("researchOutpost"),
              behavior = "attacking",
              health = 55,
              count = 2,
              lootTable = zombieLootTable,
            },
          },
        },
      },

      -- No completeCallback needed — completeContract fires from the extraction interaction above
      completeCallback = nil,
    },
  }, -- end phases
})
