local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Hazmat Suit (Armored)"
ITEM.base = "base_armor"
ITEM.size = 2.5
ITEM.cost = 30000

ITEM.skin = 0
ITEM.model = "models/stalker/outfit/lone_seva.mdl"
ITEM.equipModel = "models/stalkertnb/seva_monolith_heavy.mdl"

ITEM.description =
"Armored hazmat suit providing excellent protection against various threats, including gas-based attacks."

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
ITEM.damageScale = 0.7

-- How much damage the item can take before it breaks.
ITEM.maxHealth = 2500
ITEM.health = ITEM.maxHealth
