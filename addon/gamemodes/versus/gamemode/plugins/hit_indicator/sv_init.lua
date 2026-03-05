local PLUGIN = PLUGIN

util.AddNetworkString("versus.hitindicator.showHit")
util.AddNetworkString("versus.hitindicator.showDamageReceived")

function PLUGIN.hook:ScaleNPCDamage(npc, hitGroup, damageInfo)
  -- Store the last hitgroup on the NPC for later retrieval
  npc._VersusLastHitGroup = hitGroup
end

function PLUGIN.hook:PostEntityTakeDamage(entity, damageInfo, wasDamageTaken)
  if not wasDamageTaken then
    return
  end

  if not IsValid(entity) then
    return
  end

  local damage = damageInfo:GetDamage()

  -- Don't show for zero damage
  if damage <= 0 then
    return
  end

  local attacker = damageInfo:GetAttacker()

  -- Show hit indicator to the attacker (player hitting something)
  if IsValid(attacker) and attacker:IsPlayer() and attacker ~= entity then
    if entity:IsPlayer() or entity:IsNPC() then
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

      net.Start("versus.hitindicator.showHit")
      net.WriteFloat(damage)
      net.WriteBool(isHeadshot)
      net.WriteBool(isCritical)
      net.WriteBool(isKill)
      net.WriteVector(entity:WorldSpaceCenter())
      net.Send(attacker)
    end
  end

  -- Show damage direction indicator to the victim player
  if entity:IsPlayer() and IsValid(attacker) and attacker ~= entity then
    net.Start("versus.hitindicator.showDamageReceived")
    net.WriteVector(attacker:WorldSpaceCenter())
    net.Send(entity)
  end
end
