local PLUGIN = PLUGIN

PLUGIN.libraryKey = "rewards"

-- XP awarded per point of damage dealt to NPCs
PLUGIN.XP_PER_DAMAGE = 0.5

-- Base XP awarded for killing an NPC
PLUGIN.XP_PER_KILL = 100

-- Level formula constant (Level N requires BASE * (N ^ EXPONENT) total XP)
PLUGIN.LEVEL_XP_BASE = 1000
PLUGIN.LEVEL_XP_EXPONENT = 1.5

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
