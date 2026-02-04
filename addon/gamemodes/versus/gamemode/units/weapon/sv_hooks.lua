local UNIT = UNIT

util.AddNetworkString("versus.weapon.switch")
util.AddNetworkString("versus.weapon.cancelSwitch")

-- Called when a players inventory is loaded and each item is checked for validity
function UNIT.hook:AdjustInventoryItemLoadData(inventory, item, itemData)
  if (item and item.isWeapon) then
    itemData.isEquipped = nil
  end
end

function UNIT.hook:PlayerHolsteredAll(player)
end

-- Called when a player's weapons should be given.
function UNIT.hook:PostPlayerLoadout(player)
  -- Select the first weapon after loadout
  local weapons = player:GetWeapons()

  if (#weapons > 0) then
    UNIT.forceSelect(player, weapons[1]:GetClass())
  end
end

-- Called as a player dies (not called for KillSilent).
function UNIT.hook:DoPlayerDeath(player, attacker, damageInfo)
  for _, weapon in pairs(player:GetWeapons()) do
    local weaponItem = weapon._VersusItem

    if (weaponItem and hook.Run("PlayerCanDrop", player, weaponItem, true, attacker) ~= false) then
      versus.inventory.takeItem(player, weaponItem)

      weaponItem.isEquipped = false

      versus.item.make(weaponItem, player:GetPos())
    end
  end
end
