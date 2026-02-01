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
  UNIT.forceSelectHands(player)
end

-- Called when a player's weapons should be given.
function UNIT.hook:PlayerLoadout(player)
  player:Give("versus_hands")

  UNIT.forceSelectHands(player)
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

net.Receive("versus.weapon.switch", function(len, player)
  local weapon = net.ReadEntity()

  if (not IsValid(weapon)) then
    ErrorNoHalt("versus.weapon.switch: Invalid weapon entity given.\n")
    print(player, weapon)
    return
  end

  --player:chatMe("starts rummaging through their pockets.")
  player:EmitSound("physics/metal/weapon_footstep2.wav", 75, 100, .4)

  local data = {
    weapon = weapon,
    delay = UNIT.weaponSwitchDelay,
  }

  hook.Run("AdjustPlayerWeaponSwitchData", player, weapon, data)

  -- Allow a small margin earlier equipping from the client to account for
  -- lag/desync with client timing. Otherwise the server might reject the switch
  -- because the client thinks more time has passed than the server.
  data.equipAt = CurTime() + (data.delay * 0.9)

  player.switchingWeapon = data
end)

net.Receive("versus.weapon.cancelSwitch", function(len, player)
  player.switchingWeapon = nil
end)
