local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Grenade Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_grenade"
ITEM.isGrenadeWeapon = true
ITEM.category = "Grenades"
ITEM.size = 1

ITEM.model = "models/weapons/w_grenade.mdl"
ITEM.description = "Grenades are explosive devices that can be thrown to deal area damage."

function ITEM:onUse(player)
  player:GiveAmmo(self.amount, self.ammoType, true)
  player:EmitSound("items/ammo_pickup.wav", 75, 100, 1, CHAN_ITEM)
end
