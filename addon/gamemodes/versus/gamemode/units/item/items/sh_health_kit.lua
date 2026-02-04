local UNIT = UNIT
local ITEM = ITEM

ITEM.base = "base_heal"
ITEM.name = "Health Kit"
ITEM.size = 1
ITEM.batch = 10
ITEM.cost = 300
ITEM.model = "models/items/healthkit.mdl"
ITEM.healAmount = 50
ITEM.description = "A health kit which restores " .. ITEM.healAmount .. " health."
