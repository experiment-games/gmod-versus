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
  local noAmmo = true
  local weapon = player:Give(item.weaponClass, noAmmo)

  -- If the item has a stored clip, set it
  if (item.clip and item.clip > 0) then
    weapon:SetClip1(item.clip)
    item.clip = nil
  end

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

  local clip = weapon:Clip1()

  player:StripWeapon(weapon:GetClass())

  -- Store the ammo back to the item
  item.clip = clip
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

--- Returns a player's reserve ammo as items in their inventory.
--- Should only be called when the player is alive, not when they have already died
--- (dying drops all carried items, so no ammo needs to be returned in that case).
--- @param player Player The player whose ammo should be returned as items
function UNIT.returnEquippedAmmo(player)
  local ammo = player:GetAmmo()

  for ammoTypeID, amount in pairs(ammo) do
    if amount <= 0 then continue end

    if (hook.Run("PlayerShouldReturnAmmo", player, ammoTypeID, amount) == false) then
      return
    end

    local itemID = UNIT.getItemIDFromAmmoType(ammoTypeID)
    if not itemID then continue end

    local itemTable = versus.item.get(itemID)
    if not itemTable then continue end

    local stackSize = itemTable.amount or 1
    local fullStacks = math.floor(amount / stackSize)

    for i = 1, fullStacks do
      versus.inventory.giveItem(player, itemID)
    end

    local remainder = amount % stackSize
    if remainder > 0 then
      local instance = versus.item.createInstance(itemID)
      instance.amount = remainder
      versus.inventory.giveItem(player, instance)
    end
  end
end
