local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Cammo Suit (Pro)"
ITEM.base = "base_armor"
ITEM.size = 3
ITEM.cost = 30000
ITEM.lootWeight = 0.005 / 100

ITEM.skin = 0
ITEM.model = "models/stalker/outfit/military.mdl"
ITEM.equipModel = "models/stalkertnb/rad_monoboss.mdl"

ITEM.description =
"Cammo suit providing excellent protection against various threats, including gas-based attacks."

-- Protects against gas-based attacks, such as tear gas.
ITEM.resistanceAgainstGas = 0.98

-- Which hitgroups this item provides protection for.
ITEM.hitGroups = {
  [HITGROUP_CHEST] = true,
  [HITGROUP_STOMACH] = true,
  [HITGROUP_LEFTARM] = true,
  [HITGROUP_RIGHTARM] = true,
  [HITGROUP_LEFTLEG] = true,
  [HITGROUP_RIGHTLEG] = true,
}

-- How much the item reduces incoming damage by (0.90 means 10% damage reduction).
ITEM.damageScale = 0.65

-- How much damage the item can take before it breaks.
ITEM.maxHealth = 6000
ITEM.health = ITEM.maxHealth
