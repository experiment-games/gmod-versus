local PLUGN = PLUGN
local ITEM = ITEM

ITEM.name = "Equipment Base"
ITEM.category = "Clothing"
ITEM.size = 0
ITEM.isBaseItem = true
ITEM.isEquipment = true
ITEM.model = "models/props/de_tides/vending_hat.mdl"
ITEM.description =
"Base item for equipment. This item doesn't do anything on its own and is not meant to be used directly. It is meant to be inherited by other items that provide actual functionality."
ITEM.actionTexts = {
  ["Use"] = "Equip",
}

function ITEM:onUse(player)
  versus.equipment.equipItem(player, self)
end
