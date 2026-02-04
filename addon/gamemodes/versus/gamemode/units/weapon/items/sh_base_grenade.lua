local UNIT = UNIT
local ITEM = ITEM

ITEM.base = "base_weapon"
ITEM.name = "Grenade Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_grenade"
ITEM.isGrenadeWeapon = true
ITEM.category = "Grenades"
ITEM.size = 1

ITEM.model = "models/weapons/w_grenade.mdl"

ITEM.description = "Grenades are explosive devices that can be thrown to deal area damage."

-- Commented as SWEP.Primary.DefaultClip gives ammo
function ITEM:onEquip(player)
  -- player:GiveAmmo(self.amount, self.ammoType, true)
end

function ITEM:onUnequip(player)
  -- Strip the grenade ammo (it will be re-added on next equip)
  -- local currentAmmo = player:GetAmmoCount(self.ammoType)
  -- local ammoToRemove = math.min(currentAmmo, self.amount)
  -- player:RemoveAmmo(ammoToRemove, self.ammoType)
end
