local UNIT = UNIT

function UNIT.hook:HUDShouldDraw(name)
  if (name == "CHudWeaponSelection") then
    return false
  end
end

-- Hook into weapon slot selection
function UNIT.hook:PlayerBindPress(ply, bind, pressed, code)
  if not pressed then return end

  -- Slot selection (1-6) - show menu at current weapon
  local slot = string.match(bind, "slot(%d)")
  if slot then
    UNIT:showWeaponSelection()
    return
  end

  -- Weapon cycling
  if bind == "invnext" then
    if not IsValid(UNIT.weaponSelection) then
      UNIT:createWeaponSelection()
    end

    if UNIT.weaponSelection.targetAlpha == 0 then
      UNIT:showWeaponSelection()
    end

    UNIT.weaponSelection:NextWeapon()
    return true
  elseif bind == "invprev" then
    if not IsValid(UNIT.weaponSelection) then
      UNIT:createWeaponSelection()
    end

    if UNIT.weaponSelection.targetAlpha == 0 then
      UNIT:showWeaponSelection()
    end

    UNIT.weaponSelection:PreviousWeapon()
    return true
  end

  -- Confirm selection with attack
  if IsValid(UNIT.weaponSelection) and UNIT.weaponSelection.targetAlpha > 0 then
    if bind == "+attack" then
      UNIT.weaponSelection:ConfirmSelection()
      return true
    end
  end
end

-- Initialize on client spawn
function UNIT.hook:InitPostEntity()
  UNIT:createWeaponSelection()
end
