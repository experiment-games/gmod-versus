local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.name = "Supply Manifest"
ITEM.category = "Contract"
ITEM.size = 0
ITEM.model = "models/computergibs.mdl"
ITEM.description =
"A data drive containing the supply manifest for a shipment. It has details on the contents of the shipment and where it needs to go."

-- Never save this to the database as its a mission item only
ITEM.dontSave = true
