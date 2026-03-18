local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Bandit Armor (Black)"
ITEM.base = "base_armor"
ITEM.size = 1.5
ITEM.cost = 15000
ITEM.lootWeight = 0.01 / 100

ITEM.skin = 0
ITEM.model = "models/stalker/outfit/bandit3a.mdl"
ITEM.equipModel = "models/player/bandit/banditboss1.mdl"

ITEM.description = "A cloak making light armor."

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
ITEM.damageScale = 0.90

-- How much damage the item can take before it breaks.
ITEM.maxHealth = 1000
ITEM.health = ITEM.maxHealth
