local UNIT = UNIT
local ITEM = ITEM

ITEM.base = "base_heal"
ITEM.name = "Health Vial"
ITEM.size = 1
ITEM.batch = 10
ITEM.cost = 100
ITEM.seller = { "medic" }
ITEM.model = "models/healthvial.mdl"
ITEM.healAmount = 25
ITEM.description = "A health vial which restores " .. ITEM.healAmount .. " health."
