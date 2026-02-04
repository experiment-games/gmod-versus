local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Ammo Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_ammo"
ITEM.isAmmunition = true
ITEM.category = "Ammunition"
ITEM.size = 1

ITEM.model = "models/items/boxsrounds.mdl"

ITEM.description = "Used to fill up your weapons."
ITEM.actionTexts = {
  ["Use"] = "Load",
}

function ITEM:onUse(player)
  player:GiveAmmo(self.amount, self.ammoType, true)
end

function ITEM:onDrop(player, position) end
