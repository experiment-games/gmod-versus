local UNIT = UNIT

-- Return true to prevent switching weapon
function UNIT.hook:PlayerSwitchWeapon(player, oldWeapon, newWeapon)
  -- Prediction:
  if (CLIENT) then
    if (not UNIT.switchingWeaponNow) then
      print "denying weapon switch"
      return true
    else
      UNIT.switchingWeaponNow = nil
    end
  end

  if (SERVER) then
    if (player.switchingWeapon == nil
          or not IsValid(player.switchingWeapon.weapon)
          or player.switchingWeapon.weapon ~= newWeapon
          or player.switchingWeapon.equipAt > CurTime()) then
      return true
    else
      --player:chatMe("takes out a %s.", newWeapon:GetPrintName())
      player:EmitSound("physics/metal/weapon_footstep1.wav", 75, 70, .8)
    end
  end
end

-- Switching between these weapons is near instant, to allow for easy building/camera use
local instantBetween = {
  ["gmod_tool"] = true,
  ["weapon_physgun"] = true,
  ["gmod_camera"] = true,
}

function UNIT.hook:AdjustPlayerWeaponSwitchData(player, weapon, data)
  if (not IsValid(weapon) or not IsValid(player:GetActiveWeapon())) then
    return
  end

  if (
        instantBetween[weapon:GetClass()]
        and instantBetween[player:GetActiveWeapon():GetClass()]
      ) then
    data.delay = 0.1
  end
end
