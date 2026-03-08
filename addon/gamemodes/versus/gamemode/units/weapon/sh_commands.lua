local UNIT = UNIT

do
  local COMMAND = versus.command.define("holster")
  COMMAND.description = "Holster your current weapon."

  function COMMAND:onRun(player)
    local weapon = player:GetActiveWeapon()

    if (not IsValid(weapon)) then
      return
    end

    local weaponItem = weapon._VersusItem

    if (not weaponItem) then
      return
    end

    -- Check if they can holster another weapon yet.
    if (not player:IsAdmin() and player._NextHolsterWeapon and player._NextHolsterWeapon > CurTime()) then
      versus.message.notify(player,
        "You cannot holster this weapon for " .. math.ceil(player._NextHolsterWeapon - CurTime()) .. " second(s)!",
        NOTIFY_ERROR)

      return false
    end

    player._NextHolsterWeapon = CurTime() + 2

    if (hook.Run("PlayerCanHolster", player, weapon:GetClass()) == false) then
      return
    end

    versus.equipment.unequipItem(player, weaponItem.equipSlot)
  end
end

do
  local COMMAND = versus.command.define("drop")
  COMMAND.description = "Drop your current weapon where you are looking."
  COMMAND.requiredFlags = "b"

  function COMMAND:onRun(player)
    local weapon = player:GetActiveWeapon()

    if (not IsValid(weapon)) then
      versus.message.notify(player, "This is not a valid weapon!", NOTIFY_ERROR)
      return
    end

    local weaponItem = weapon._VersusItem

    if (not weaponItem) then
      versus.message.notify(player, "This is not a valid weapon!", NOTIFY_ERROR)
      return
    end

    if (hook.Run("PlayerCanDropItem", player, weaponItem) == false) then
      return
    end

    local position = player:GetEyeTrace().HitPos

    -- Check to see if this position is too far away.
    if (not versus.entity.isNearPosition(player, position, 256)) then
      versus.message.notify(player, "You cannot drop your weapon that far away!", NOTIFY_ERROR)
      return
    end

    -- unequipItem with returnToInventory=false strips the weapon entity (via onUnequip)
    -- and removes from the slot, without giving the item back to inventory.
    versus.equipment.unequipItem(player, weaponItem.equipSlot, false)
    versus.item.make(weaponItem, position + Vector(0, 0, 32))
  end
end

do
  local COMMAND = versus.command.define("rollrarity")
  COMMAND.description = "Reroll the rarity of your current weapon."
  COMMAND.requiredFlags = "s"

  function COMMAND:onRun(player)
    local weapon = player:GetActiveWeapon()

    if (not IsValid(weapon)) then
      versus.message.notify(player, "This is not a valid weapon!", NOTIFY_ERROR)
      return
    end

    local weaponItem = weapon._VersusItem

    if (not weaponItem) then
      versus.message.notify(player, "This is not a valid weapon!", NOTIFY_ERROR)
      return
    end

    local rarity = versus.item.rollRarity()

    weaponItem.rarity = rarity and rarity.id or nil
    versus.inventory.networkItemOverrides(player, weaponItem, "rarity")

    if (not rarity) then
      versus.message.notify(player, "Rolled no rarity.", NOTIFY_GENERIC)
      return
    end

    versus.message.notify(player, "Rerolled weapon rarity to " .. rarity.id .. "!", NOTIFY_GENERIC)
  end
end
