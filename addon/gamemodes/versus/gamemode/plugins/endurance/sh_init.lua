local PLUGIN = PLUGIN

PLUGIN.name = "Endurance"
PLUGIN.libraryKey = "endurance"
PLUGIN.description = "Endurance mode: players hold out against waves of enemies for as long as they can."

-- Squad size constraints.
PLUGIN.SQUAD_MIN_SIZE = 2
PLUGIN.SQUAD_MAX_SIZE = 4

-- Convar holding the address of the endurance server (shown in the hideout for matchmaking).
PLUGIN.convarEnduranceServer = CreateConVar(
  "versus_endurance_server",
  "",
  { FCVAR_REPLICATED, FCVAR_ARCHIVE },
  "Address of the endurance server players are sent to after matchmaking (ip:port)"
)

-- Seconds between waves.
PLUGIN.WAVE_INTERVAL = 15

-- Base XP rewarded to each surviving member when a wave is cleared.
-- Scales linearly with wave number (XP_PER_WAVE * waveNumber).
PLUGIN.XP_PER_WAVE = 250

-- Seconds after the last squad member dies before all members are redirected to the hideout.
PLUGIN.SQUAD_WIPE_REDIRECT_DELAY = 30

-- Seconds players have to connect to the hideout server after being sent the redirect before
-- they are kicked from the endurance server.
PLUGIN.SQUAD_WIPE_KICK_DELAY = 60

--[[
  Wave config registry.

  Each endurance map registers its own tier list via PLUGIN.registerWaveConfig().
  Config files live in plugins/endurance/wavecfg/ and are named
  sh_wavecfg_<mapname>.lua so they are loaded on both client and server.

  PLUGIN.registerWaveConfig(mapName, tiers)
    mapName  (string)  Exact value returned by game.GetMap() for this map.
    tiers    (table)   Ordered array of tier tables (see format below).

  PLUGIN.getWaveConfig(mapName) -> tiers | nil

  Per-tier format — each tier becomes active starting from `fromWave` and stays
  active until a later tier takes over.  The tier with the highest `fromWave`
  that is still <= the current wave number is used.

  Per-tier `npcs` array — each NPC entry supports:
    class                 (string)    NPC class to spawn, e.g. "npc_zombie"
    count                 (number)    Base number of enemies to spawn each wave
    countIncreasePerWave  (number?)   Additional enemies added per wave above fromWave (default 0)
    baseHealth            (number)    Starting health at the beginning of this tier
    healthIncreasePerWave (number)    Health multiplier applied per wave above fromWave
                                      e.g. 1.1 → health × 1.1 each wave; 1.0 → fixed health
    model                 (string?)   Optional custom model path (set before Spawn — visual override)
    modelScale            (number?)   Optional model scale (default 1.0)
    weapons               (table?)    Optional list of weapon classes to give the NPC
    loot                  (fun?)      Optional loot spawner:
                                      function(npc, attacker, inflictor) end

  Per-tier optional `lootCrate` table — when present, a loot crate is dropped
  near the squad spawn every `everyXWaves` waves.  Each successive crate
  multiplies all item chances by the number of crates spawned so far, capped at
  4×, increasing the likelihood of rare items by the fourth crate but still
  leaving drops subject to RNG on each crate.
    everyXWaves           (number)    Spawn a crate once every this many waves
                                      (checked against the absolute wave number)
    items                 (table)     Chance table: { [itemID] = baseChance, ... }
                                      baseChance is in [0, 1]; after n crates the
                                      effective chance is min(baseChance × n, 1)
--]]

PLUGIN.waveConfigs = PLUGIN.waveConfigs or {}

--- Registers a wave config for an endurance map.
--- Call this from a wavecfg/ file, not from sh_init.lua directly.
--- @param mapName string  Exact map name as returned by game.GetMap()
--- @param tiers table     Ordered array of tier tables
function PLUGIN.registerWaveConfig(mapName, tiers)
  PLUGIN.waveConfigs[mapName] = tiers
end

--- Returns the registered tier array for `mapName`, or nil if none was registered.
--- @param mapName string
--- @return table?
function PLUGIN.getWaveConfig(mapName)
  return PLUGIN.waveConfigs[mapName]
end

-- Shared loot table for all endurance monsters.
-- Config files can reference PLUGIN.ENDURANCE_LOOT and PLUGIN.defaultLootSpawner.
PLUGIN.ENDURANCE_LOOT = {
  ["health_vial"]            = 0.05,
  ["health_kit"]             = 0.03,
  ["raw_furniture_material"] = 0.05,
}

function PLUGIN.defaultLootSpawner(npc, attacker, inflictor)
  versus.contracts.produceLootAtPosition(npc, attacker, PLUGIN.ENDURANCE_LOOT, npc:GetPos())
end

versus.includeDirectory(PLUGIN.fullPath .. "/wavecfg")

--[[
  Hooks
--]]

function PLUGIN.hook:PlayerShouldSelectContract(player)
  -- Don't have contract selection if we're in an endurance map
  if (GetGlobalBool("VersusEnduranceMap", false)) then
    return false
  end
end
