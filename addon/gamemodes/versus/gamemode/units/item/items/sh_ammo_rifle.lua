local ITEM = ITEM

ITEM.name = "Rifle Ammo"
ITEM.category = "Ammunition"
ITEM.batch = 10
ITEM.size = 1
ITEM.cost = 1000
ITEM.model = "models/items/boxmrounds.mdl"
ITEM.plural = "Rifle Ammo"
ITEM.description = "Used to fill up rifles."

function ITEM:onUse(player)
  player:GiveAmmo(60, "smg1")
end

function ITEM:onDrop(player, position) end

function ITEM:onDestroy(player) end
