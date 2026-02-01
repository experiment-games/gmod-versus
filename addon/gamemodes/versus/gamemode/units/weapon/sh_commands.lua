local UNIT = UNIT

do
  local COMMAND = versus.command.define("holster")
  COMMAND.description = "Holster your current weapon."

  function COMMAND:onRun(player)
    local weapon = player:GetActiveWeapon()

    -- Check if they can holster another weapon yet.
    if (not player:IsAdmin() and player._NextHolsterWeapon and player._NextHolsterWeapon > CurTime()) then
      versus.message.notify(player,
        "You cannot holster this weapon for " .. math.ceil(player._NextHolsterWeapon - CurTime()) .. " second(s)!",
        NOTIFY_ERROR)

      return false
    end

    player._NextHolsterWeapon = CurTime() + 2

    if (hook.Run("PlayerCanHolster", player, class) == false) then
      return
    end

    versus.weapon.holsterWeaponItem(player, weapon)
    versus.weapon.forceSelectHands(player)
  end
end

do
  local COMMAND = versus.command.define("drop")
  COMMAND.description = "Drop your current weapon where you are looking."
  COMMAND.requiredFlags = "b"

  -- TODO: This duplicates logic from DoPlayerDeath logic for dropping weapons. Refactor.
  function COMMAND:onRun(player)
    local weapon = player:GetActiveWeapon()

    if (not IsValid(weapon)) then
      versus.message.notify(player, "This is not a valid weapon!", NOTIFY_ERROR)
      return
    end

    local class = weapon:GetClass()
    local weaponItem = weapon._VersusItem

    if (not weaponItem) then
      versus.message.notify(player, "This is not a valid weapon!", NOTIFY_ERROR)
      return
    end

    if (hook.Run("PlayerCanDrop", player, weaponItem) == false) then
      return
    end

    local position = player:GetEyeTrace().HitPos

    -- Check to see if this position is too far away.
    if (not versus.entity.isNearPosition(player, position, 256)) then
      versus.message.notify(player, "You cannot drop your weapon that far away!", NOTIFY_ERROR)
      return
    end

    versus.inventory.takeItem(player, weaponItem)

    weaponItem.isEquipped = false

    versus.item.make(weaponItem, position + Vector(0, 0, 32))

    player:StripWeapon(class)
    versus.weapon.forceSelectHands(player)
  end
end
