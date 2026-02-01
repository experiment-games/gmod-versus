local UNIT = UNIT

-- How many seconds the weapon switch ui stays on screen for
UNIT.weaponSwitchTimeSpan = 3

-- How many seconds interval must be before the next weapon is selected on the UI
UNIT.minimumScrollInterval = 0.04

UNIT.switchingWeapon = nil
UNIT.switchingWeaponTo = nil
UNIT.switchingWeaponNow = nil
UNIT.lastTryWeaponSwitch = 0
UNIT.lastTryWeaponSwitchIndex = nil

function UNIT.cancelSwitchToWeapon()
  UNIT.switchingWeapon = nil
  net.Start("versus.weapon.cancelSwitch")
  net.SendToServer()
end

function UNIT.switchToWeapon(weapon, immediate, noSound)
  if (weapon == nil) then
    return
  end

  local player = LocalPlayer()

  if (immediate) then
    UNIT.switchingWeapon = nil
    UNIT.lastTryWeaponSwitch = -UNIT.weaponSwitchTimeSpan

    if (not IsValid(weapon)
          or not IsValid(player)
          or not player:HasWeapon(weapon:GetClass())) then
      ErrorNoHalt("Tried to equip invalid weapon!")
      print(weapon)
      return
    end

    if (not noSound) then
      surface.PlaySound("common/wpn_moveselect.wav")
    end

    UNIT.switchingWeaponNow = true -- used for prediction
    input.SelectWeapon(weapon)
    return
  end

  if (weapon == player:GetActiveWeapon()) then
    UNIT.switchingWeapon = nil
    UNIT.lastTryWeaponSwitch = -UNIT.weaponSwitchTimeSpan
    return
  end

  if (UNIT.switchingWeapon ~= nil
        and UNIT.switchingWeapon.weapon == weapon) then
    return
  end

  net.Start("versus.weapon.switch")
  net.WriteEntity(weapon)
  net.SendToServer()

  local data = {
    weapon = weapon,
    delay = UNIT.weaponSwitchDelay
  }

  hook.Run("AdjustPlayerWeaponSwitchData", player, weapon, data)

  data.equipAt = CurTime() + data.delay

  UNIT.switchingWeapon = data
end
