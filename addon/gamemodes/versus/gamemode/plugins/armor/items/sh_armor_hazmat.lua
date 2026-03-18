local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Hazmat Suit"
ITEM.base = "base_armor"
ITEM.size = 2
ITEM.cost = 25000
ITEM.lootWeight = 0.0085 / 100

ITEM.skin = 0
ITEM.model = "models/stalker/outfit/dolg_seva.mdl"
ITEM.equipModel = "models/stalkertnb/beri_seva.mdl"

ITEM.description = "Hazmat suit providing protection against various threats, including gas-based attacks."

-- Protects against gas-based attacks, such as tear gas.
ITEM.resistanceAgainstGas = 0.95

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
ITEM.damageScale = 0.85

-- How much damage the item can take before it breaks.
ITEM.maxHealth = 2000
ITEM.health = ITEM.maxHealth
