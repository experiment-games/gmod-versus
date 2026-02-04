local UNIT = UNIT

util.AddNetworkString("versus.weapon.forceSelect")

function UNIT.forceSelect(player, weaponOrClass)
  local weaponClass = weaponOrClass

  if (not isstring(weaponOrClass)) then
    weaponClass = weaponOrClass:GetClass()
  end

  player:SelectWeapon(weaponClass)
end

function UNIT.equipWeaponItem(player, item)
  local weapon = player:Give(item.weaponClass)

  weapon._VersusItem = item
  weapon:SetNWString("versus_ItemID", item.itemID)
  UNIT.forceSelect(player, item.weaponClass)

  player:EmitSound("physics/metal/weapon_footstep1.wav", 75, 70, .8)

  return true
end

function UNIT.holsterWeaponItem(player, weapon)
  if (not IsValid(weapon)) then
    weapon = player:GetActiveWeapon()
  end

  local item = weapon._VersusItem

  if (not IsValid(weapon) or not item) then
    versus.message.notify(player, "This is not a valid weapon!", NOTIFY_ERROR)
    return
  end

  local class = weapon:GetClass()

  if (hook.Run("PlayerCanHolster", player, class, false) == false) then
    return
  end

  player:EmitSound("physics/metal/weapon_footstep2.wav", 75, 70, .8)

  player:StripWeapon(weapon:GetClass())
end

-- Holsters all of a player's weapons.
function UNIT.holsterAllWeaponItems(player)
  for _, weapon in pairs(player:GetWeapons()) do
    local class = weapon:GetClass()

    if (weapon._VersusItem and hook.Run("PlayerCanHolster", player, class, true) ~= false) then
      UNIT.holsterWeaponItem(player, weapon)
    end
  end

  hook.Run("PlayerHolsteredAll", player)
end
