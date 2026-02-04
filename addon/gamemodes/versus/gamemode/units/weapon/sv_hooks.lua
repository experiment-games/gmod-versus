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

--- When the player no longer has any grenade ammo, we want to switch away from their grenade.
function UNIT.hook:PlayerThink(player)
  local activeWeapon = player:GetActiveWeapon()

  if (not IsValid(activeWeapon)) then
    return
  end

  if ((activeWeapon._VersusItem and activeWeapon._VersusItem.isGrenadeWeapon) or activeWeapon._VersusIsPermanentGrenade) then
    local ammoType = activeWeapon:GetPrimaryAmmoType()
    local ammoCount = player:GetAmmoCount(ammoType)

    -- Also add the clip ammo to the total count
    ammoCount = ammoCount + activeWeapon:Clip1()

    if (ammoCount <= 0) then
      -- Switch to the first non-grenade weapon
      for _, weapon in pairs(player:GetWeapons()) do
        if (weapon ~= activeWeapon and not (weapon._VersusItem and weapon._VersusItem.isGrenadeWeapon) and not weapon._VersusIsPermanentGrenade) then
          UNIT.forceSelect(player, weapon:GetClass())
          break
        end
      end
    end
  end
end
