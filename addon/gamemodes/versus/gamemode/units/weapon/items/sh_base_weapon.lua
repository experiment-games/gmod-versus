local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Weapon Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_weapon"
ITEM.isWeapon = true
ITEM.category = "Weapons"
ITEM.size = 1

-- Default slot. Individual weapon items should override this (e.g. "melee", "secondary", etc.)
ITEM.equipSlot = "primary"

ITEM.model = "models/weapons/w_rif_ak47.mdl"
ITEM.skin = 0

ITEM.description = "A reliable weapon for combat situations."

function ITEM:onEquip(player)
  versus.weapon.equipWeaponItem(player, self)
end

function ITEM:onUnequip(player)
  local weapon = player:GetWeapon(self.weaponClass)

  if (IsValid(weapon)) then
    versus.weapon.holsterWeaponItem(player, weapon)
  end
end

function ITEM:onUse(player)
  if (player:HasWeapon(self.weaponClass)) then
    versus.message.notify(player, "You already have a weapon like this equipped!", NOTIFY_ERROR)
    return false
  end

  versus.equipment.equipItem(player, self)
end

function ITEM:onDrop(player, position)
  if (versus.equipment.getEquippedItem(player, self.equipSlot) == self) then
    versus.equipment.unequipItem(player, self.equipSlot, false)
  end
end
