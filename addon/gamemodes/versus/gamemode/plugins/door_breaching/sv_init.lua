local PLUGIN = PLUGIN

function PLUGIN:openDoor(entity, client, noSound)
  if (not entity:IsDoor()) then
    return
  end

  local origin = client:GetShootPos() - (client:GetAimVector() * 5)
  entity:Fire("Unlock")

  if (origin and string.lower(entity:GetClass()) == "prop_door_rotating") then
    entity:OpenDoorAwayFrom(origin, nil, true)
  else
    entity:Fire("Open")
  end

  if (not noSound) then
    sound.Play("physics/wood/wood_plank_break3.wav", entity:GetPos())
  end
end

function PLUGIN:isDoorHitPointVulnerable(entity, damagePosition)
  return entity:WorldToLocal(damagePosition):DistToSqr(Vector(-1.0313, 41.8047, -8.1611)) <= 64
end

function PLUGIN:entityBreached(entity, client, breach, noSound)
  self:openDoor(entity, client, noSound)
end

function PLUGIN.hook:EntityTakeDamage(entity, damageInfo)
  if (not damageInfo:IsBulletDamage()) then
    return
  end

  local attacker = damageInfo:GetAttacker()

  if (not IsValid(attacker) or not attacker:IsPlayer()) then
    return
  end

  local weapon = attacker:GetActiveWeapon()

  if (not IsValid(weapon) or not weapon:IsWeapon()) then
    return
  end

  if (weapon._VersusItem and weapon._VersusItem.isMeleeWeapon) then
    return
  end

  if (string.lower(entity:GetClass()) ~= "prop_door_rotating") then
    return
  end

  local damagePosition = damageInfo:GetDamagePosition()

  if (not self:isDoorHitPointVulnerable(entity, damagePosition)) then
    return
  end

  -- If the door isn't locked, it'll always be vulnerable.
  if (not entity:IsLocked()) then
    versus.util.impactEffect(damagePosition, 8, false)
    self:entityBreached(entity, damageInfo:GetAttacker())

    return
  end

  if (not IsValid(attacker) or not attacker:IsPlayer()) then
    return
  end

  local canBreach = hook.Run("CanPlayerShootOpen", attacker, entity)

  if (canBreach == false) then
    return
  end

  versus.util.impactEffect(damagePosition, 8, false)
  self:entityBreached(entity, attacker)
end
