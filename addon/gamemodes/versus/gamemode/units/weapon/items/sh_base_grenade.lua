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
  local ammoAmount = self.amount

  -- Based on rarity, increase ammo amount
  local rarity = versus.item.getRarity(self.rarity)

  if (rarity) then
    ammoAmount = math.floor(ammoAmount * (rarity.modifier or 1))
  end

  player:GiveAmmo(ammoAmount, self.ammoType, true)
  player:EmitSound("items/ammo_pickup.wav", 75, 100, 1, CHAN_ITEM)
end
