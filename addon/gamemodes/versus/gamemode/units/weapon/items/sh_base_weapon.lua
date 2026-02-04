local UNIT = UNIT
local ITEM = ITEM

ITEM.name = "Weapon Base"
ITEM.isBaseItem = true
ITEM.itemID = "base_weapon"
ITEM.isWeapon = true
ITEM.category = "Weapons"
ITEM.size = 1

ITEM.model = "models/weapons/w_rif_ak47.mdl"
ITEM.skin = 0

ITEM.description = "A reliable weapon for combat situations."
ITEM.actionTexts = {
  ["Use"] = function(item)
    if (item.isEquipped) then
      return "Holster"
    else
      return "Equip"
    end
  end,
}

function ITEM:onEquip(player)
end

function ITEM:onUnequip(player)
end

function ITEM:onUse(player)
  if (self.isEquipped and player:HasWeapon(self.weaponClass)) then
    UNIT.holsterWeaponItem(player, player:GetWeapon(self.weaponClass))

    self.isEquipped = false

    versus.inventory.networkItemOverrides(player, self, "isEquipped")

    self:onUnequip(player)

    return false
  end

  if (player:HasWeapon(self.weaponClass)) then
    versus.message.notify(player, "You already have a weapon like this equipped!", NOTIFY_ERROR)
    return false
  end

  self.isEquipped = true

  versus.weapon.equipWeaponItem(player, self)

  versus.inventory.networkItemOverrides(player, self, "isEquipped")

  self:onEquip(player)

  -- Never remove weapon items on use, just equip them
  return false
end

function ITEM:onDrop(player, position)
  if (player:HasWeapon(self.weaponClass)) then
    UNIT.holsterWeaponItem(player, player:GetWeapon(self.weaponClass))
  end
end

function ITEM:onDestroy(player) end
