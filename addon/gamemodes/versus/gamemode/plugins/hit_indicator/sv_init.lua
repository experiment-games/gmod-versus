local PLUGIN = PLUGIN

util.AddNetworkString("versus.hitindicator.showHit")

function PLUGIN.hook:ScaleNPCDamage(npc, hitGroup, damageInfo)
  -- Store the last hitgroup on the NPC for later retrieval
  npc._VersusLastHitGroup = hitGroup
end

function PLUGIN.hook:PostEntityTakeDamage(entity, damageInfo, wasDamageTaken)
  if not wasDamageTaken then
    return
  end

  local attacker = damageInfo:GetAttacker()

  -- Only show for player attackers hitting other entities
  if not IsValid(attacker) or not attacker:IsPlayer() then
    return
  end

  if not IsValid(entity) then
    return
  end

  -- Don't show for self-damage
  if attacker == entity then
    return
  end

  -- Only show for players or NPCs
  if not entity:IsPlayer() and not entity:IsNPC() then
    return
  end

  local damage = damageInfo:GetDamage()

  -- Don't show for zero damage
  if damage <= 0 then
    return
  end

  -- Determine if this was a headshot (if the entity has a hitgroup system)
  local isHeadshot = false
  local hitGroup = entity._VersusLastHitGroup

  if hitGroup == HITGROUP_HEAD then
    isHeadshot = true
  end

  -- Determine if this was a critical hit
  local isCritical = false -- TODO: Add critical hit system

  -- Determine if this killed the target
  local isKill = entity:Health() <= 0

  -- Network to the attacker
  net.Start("versus.hitindicator.showHit")
  net.WriteFloat(damage)
  net.WriteBool(isHeadshot)
  net.WriteBool(isCritical)
  net.WriteBool(isKill)
  net.WriteVector(entity:WorldSpaceCenter())
  net.Send(attacker)
end
