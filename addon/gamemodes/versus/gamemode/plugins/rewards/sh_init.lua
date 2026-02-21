local PLUGIN = PLUGIN

PLUGIN.libraryKey = "rewards"

-- XP awarded per point of damage dealt to NPCs
PLUGIN.XP_PER_DAMAGE = 0.5

-- Base XP awarded for killing an NPC
PLUGIN.XP_PER_KILL = 100

-- XP awarded for completing a contract, multiplied by the amount of contract items collected.
PLUGIN.XP_PER_CONTRACT = 1000

-- Level formula constant (Level N requires BASE * (N ^ EXPONENT) total XP)
PLUGIN.LEVEL_XP_BASE = 1000
PLUGIN.LEVEL_XP_EXPONENT = 1.5

-- How much enemy count grows per level above 1.
-- e.g. 0.05 = +5% per level, so at level 10 a group of 6 becomes 9.
PLUGIN.DIFFICULTY_COUNT_SCALE_PER_LEVEL = 0.05

-- How much enemy health grows per level above 1.
-- e.g. 0.08 = +8% per level, so at level 10 a 40hp enemy becomes ~69hp.
PLUGIN.DIFFICULTY_HEALTH_SCALE_PER_LEVEL = 0.08

-- Level at which new-player damage protection is fully removed.
PLUGIN.PROTECTION_MAX_LEVEL = 10

-- Fraction of damage a level-1 player receives (0.5 = takes 50% of incoming damage).
PLUGIN.PROTECTION_MIN_DAMAGE_FACTOR = 0.5

--- Calculate the total XP required to reach a specific level
--- @param level number The level to calculate XP for
--- @return number The total XP needed to reach that level
function PLUGIN.getXPForLevel(level)
  if level <= 1 then
    return 0
  end

  return math.floor(PLUGIN.LEVEL_XP_BASE * math.pow(level - 1, PLUGIN.LEVEL_XP_EXPONENT))
end

--- Calculate what level a player should be based on their total XP
--- @param xp number The player's total XP
--- @return number The level the player should be at
function PLUGIN.getLevelFromXP(xp)
  local level = 1

  while PLUGIN.getXPForLevel(level + 1) <= xp do
    level = level + 1
  end

  return level
end

--- Returns a difficulty multiplier >= 1.0 for a given level.
--- Level 1 = 1.0 (authored difficulty, no change). Each level above 1 adds scalingPerLevel.
--- @param level number The player's current level
--- @param scalingPerLevel number How much to add per level (e.g. 0.05 for +5%/level)
--- @return number A multiplier >= 1.0
function PLUGIN.getDifficultyMultiplier(level, scalingPerLevel)
  return 1.0 + (math.max(1, level) - 1) * scalingPerLevel
end

--- Scales an enemy count up for the player's level. Returns at least 1.
--- Contract values are authored as the level-1 baseline.
--- @param count number Base enemy count
--- @param level number The player's current level
--- @return number Scaled count
function PLUGIN.scaledEnemyCount(count, level)
  return math.max(1, math.Round(count * PLUGIN.getDifficultyMultiplier(level, PLUGIN.DIFFICULTY_COUNT_SCALE_PER_LEVEL)))
end

--- Scales enemy health up for the player's level. Returns at least 1.
--- Contract values are authored as the level-1 baseline.
--- @param health number Base enemy health
--- @param level number The player's current level
--- @return number Scaled health
function PLUGIN.scaledEnemyHealth(health, level)
  return math.max(1, math.Round(health * PLUGIN.getDifficultyMultiplier(level, PLUGIN.DIFFICULTY_HEALTH_SCALE_PER_LEVEL)))
end

--- Returns the fraction of incoming damage a player should receive based on their level.
--- Level 1 = PROTECTION_MIN_DAMAGE_FACTOR (heavy reduction).
--- Level PROTECTION_MAX_LEVEL+ = 1.0 (no protection).
--- Scales linearly between the two.
--- @param level number The player's current level
--- @return number A multiplier between PROTECTION_MIN_DAMAGE_FACTOR and 1.0
function PLUGIN.getPlayerDamageFactor(level)
  if level >= PLUGIN.PROTECTION_MAX_LEVEL then
    return 1.0
  end

  local t = (level - 1) / (PLUGIN.PROTECTION_MAX_LEVEL - 1)
  return PLUGIN.PROTECTION_MIN_DAMAGE_FACTOR + (1.0 - PLUGIN.PROTECTION_MIN_DAMAGE_FACTOR) * t
end
