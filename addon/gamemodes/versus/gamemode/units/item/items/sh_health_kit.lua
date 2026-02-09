local UNIT = UNIT
local ITEM = ITEM

ITEM.base = "base_heal"
ITEM.name = "Health Kit"
ITEM.size = 1
ITEM.cost = 300
ITEM.seller = { "medic" }
ITEM.model = "models/items/healthkit.mdl"
ITEM.healAmount = 50
ITEM.description = "A health kit which restores " .. ITEM.healAmount .. " health."
