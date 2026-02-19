local UNIT = UNIT

util.AddNetworkString("versus.weapon.switch")
util.AddNetworkString("versus.weapon.cancelSwitch")

-- For weapon items that have rarity, we scale the damage of the weapon based on the rarity modifier.
function UNIT.hook:ScaleNPCDamage(npc, hitGroup, damageInfo)
  local weapon = damageInfo:GetWeapon()

  if (IsValid(weapon) and weapon:IsPlayer()) then
    weapon = weapon:GetActiveWeapon()
  end

  if (not IsValid(weapon) or not weapon._VersusItem) then
    return
  end

  local item = weapon._VersusItem

  if (item.rarity) then
    local rarity = versus.item.getRarity(item.rarity)

    if (rarity and rarity.modifier) then
      damageInfo:ScaleDamage(rarity.modifier)
    end
  end
end

-- Called when a players inventory is loaded and each item is checked for validity
function UNIT.hook:AdjustInventoryItemLoadData(inventory, item, itemData)
  if (item and item.isWeapon) then
    itemData.isEquipped = nil
  end
end

function UNIT.hook:PlayerHolsteredAll(player)
end

-- Called when a player attempts to drop a weapon.
function UNIT.hook:PlayerCanDrop(player, weaponItem, silent, attacker)
  -- Only if they own the item. So we prevent dropping items they are given at spawn/temporarily
  if (not versus.inventory.hasItem(player, weaponItem)) then
    if (not silent) then
      versus.message.notify(player, "You do not own this weapon!", NOTIFY_ERROR)
    end

    return false
  end
end

-- Called as a player dies (not called for KillSilent).
function UNIT.hook:DoPlayerDeath(player, attacker, damageInfo)
  for _, weapon in pairs(player:GetWeapons()) do
    local weaponItem = weapon._VersusItem

    if (weaponItem and hook.Run("PlayerCanDrop", player, weaponItem, true, attacker) ~= false) then
      versus.inventory.takeItem(player, weaponItem)

      weaponItem.isEquipped = false

      versus.item.make(
        weaponItem,
        player:GetPos() + Vector(math.random(-32, 32), math.random(-32, 32), 0),
        Angle(0, math.random(0, 360), 0)
      )
    end
  end
end

--- When the player no longer has any grenade ammo, we want to switch away from their grenade.
function UNIT.hook:PlayerThink(player)
  local activeWeapon = player:GetActiveWeapon()

  if (not IsValid(activeWeapon)) then
    return
  end

  if (activeWeapon._VersusItem) then
    local ammoType = activeWeapon:GetPrimaryAmmoType()
    local ammoCount = player:GetAmmoCount(ammoType)

    -- Also add the clip ammo to the total count
    ammoCount = ammoCount + activeWeapon:Clip1()

    if (ammoCount <= 0) then
      if (activeWeapon._VersusItem.isGrenadeWeapon) then
        -- Switch to the first non-grenade weapon
        for _, weapon in pairs(player:GetWeapons()) do
          if (weapon ~= activeWeapon and not (weapon._VersusItem and weapon._VersusItem.isGrenadeWeapon)) then
            UNIT.forceSelect(player, weapon:GetClass())
            break
          end
        end
      end
    end
  end
end

-- Do not have NPC's drop their weapons on death, as they are not versus items.
function UNIT.hook:PlayerDroppedWeapon(playerOrNPC, weapon)
  if (playerOrNPC:IsNPC()) then
    weapon:Remove()
  end
end
