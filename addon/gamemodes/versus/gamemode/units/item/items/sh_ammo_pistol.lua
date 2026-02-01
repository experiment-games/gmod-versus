local ITEM = ITEM

ITEM.name = "Pistol Ammo"
ITEM.category = "Ammunition"
ITEM.batch = 10
ITEM.size = 1
ITEM.cost = 800
ITEM.model = "models/items/boxsrounds.mdl"
ITEM.plural = "Pistol Ammo"
ITEM.description = "Used to fill up pistols."

function ITEM:onUse(player)
  player:GiveAmmo(60, "pistol")
end

function ITEM:onDrop(player, position) end

function ITEM:onDestroy(player) end
