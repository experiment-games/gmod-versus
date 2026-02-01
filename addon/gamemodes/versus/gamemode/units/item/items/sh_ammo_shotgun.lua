local ITEM = ITEM

ITEM.name = "Shotgun Ammo"
ITEM.category = "Ammunition"
ITEM.batch = 10
ITEM.size = 1
ITEM.cost = 1000
ITEM.model = "models/items/boxbuckshot.mdl"
ITEM.plural = "Shotgun Ammo"
ITEM.description = "Used to fill up shotguns."

function ITEM:onUse(player)
  player:GiveAmmo(30, "buckshot")
end

function ITEM:onDrop(player, position) end

function ITEM:onDestroy(player) end
