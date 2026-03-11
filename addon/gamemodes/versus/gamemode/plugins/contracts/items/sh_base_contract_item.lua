local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Base Contract Item"
ITEM.size = 0
ITEM.category = "Contract"
ITEM.description = "A base contract item"
ITEM.isBaseItem = true
ITEM.isContractItem = true

-- Never save this to the database as its a mission item only
ITEM.dontSave = true
