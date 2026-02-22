local PLUGIN = PLUGIN

util.AddNetworkString("versus.killicons.notice")

function PLUGIN.hook:PlayerDeath(player, inflictor, attacker, ragdoll)
  if not IsValid(attacker) then
    return
  end

  -- NPC deaths don't matter; only show notices where a player is the victim.
  -- Only broadcast for player-vs-player or NPC-kills-player; skip world/environment deaths.
  if not attacker:IsPlayer() and not attacker:IsNPC() then
    return
  end

  -- Don't broadcast self-kills
  if attacker == player then
    return
  end

  local isAttackerPlayer = attacker:IsPlayer()
  local attackerName

  if isAttackerPlayer then
    attackerName = attacker:Nick()
  else
    attackerName = attacker:GetClass()
  end

  -- Prefer the explicit inflictor (e.g. a projectile) when it differs from the attacker.
  -- Fall back to the attacker's active weapon so the kill icon is always useful.
  local inflictorClass = ""

  if IsValid(inflictor) and inflictor ~= attacker and inflictor ~= player then
    inflictorClass = inflictor:GetClass()
  elseif isAttackerPlayer and IsValid(attacker:GetActiveWeapon()) then
    inflictorClass = attacker:GetActiveWeapon():GetClass()
  end

  net.Start("versus.killicons.notice")
  net.WriteString(attackerName)
  net.WriteBool(isAttackerPlayer)
  net.WriteString(player:Nick())
  net.WriteString(inflictorClass)
  net.Broadcast()
end
