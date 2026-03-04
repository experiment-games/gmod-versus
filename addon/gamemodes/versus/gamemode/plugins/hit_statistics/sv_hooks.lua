local PLUGIN = PLUGIN

function PLUGIN.hook:VersusBuildCreateTablesQueriesCore(queries)
  table.insert(queries, [[
		CREATE TABLE IF NOT EXISTS `player_hit_stats` (
			`steam_id` varchar(255) NOT NULL PRIMARY KEY,
			`total_shots` int(11) UNSIGNED DEFAULT 0,
			`player_hits_generic` int(11) UNSIGNED DEFAULT 0,
			`player_hits_head` int(11) UNSIGNED DEFAULT 0,
			`player_hits_chest` int(11) UNSIGNED DEFAULT 0,
			`player_hits_stomach` int(11) UNSIGNED DEFAULT 0,
			`player_hits_leftarm` int(11) UNSIGNED DEFAULT 0,
			`player_hits_rightarm` int(11) UNSIGNED DEFAULT 0,
			`player_hits_leftleg` int(11) UNSIGNED DEFAULT 0,
			`player_hits_rightleg` int(11) UNSIGNED DEFAULT 0,
			`player_hits_gear` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_generic` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_head` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_chest` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_stomach` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_leftarm` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_rightarm` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_leftleg` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_rightleg` int(11) UNSIGNED DEFAULT 0,
			`npc_hits_gear` int(11) UNSIGNED DEFAULT 0,
			`kills` int(11) UNSIGNED DEFAULT 0,
			`deaths` int(11) UNSIGNED DEFAULT 0,
			`headshot_kills` int(11) UNSIGNED DEFAULT 0,
			`npc_kills` int(11) UNSIGNED DEFAULT 0,
			`last_updated` int(11) UNSIGNED NOT NULL DEFAULT 0
		);
	]])
end

function PLUGIN.hook:PostEntityFireBullets(entity, bulletInfo)
  if (not entity:IsPlayer()) then
    return
  end

  local weapon = entity:GetActiveWeapon()

  if (not IsValid(weapon)) then
    return
  end

  -- Commented since TacRP only fired multiple bullets with penetration, which we disabled.
  -- -- Some TacRP weapons fire multiple bullets over multiple frames. This delay
  -- -- will ensure we count only once for each bullet fired, hopefully not missing
  -- -- any when automatic firing.
  -- if (versus.util.throttled("shotFiredTracker", 0.001, entity)) then
  -- 	return
  -- end

  PLUGIN.incrementPendingStat(entity, "shots_fired", 1)
end

-- Track damage dealt to other players with body part information
function PLUGIN.hook:ScalePlayerDamage(target, hitgroup, damageInfo)
  local attacker = damageInfo:GetAttacker()

  if (not IsValid(attacker) or not attacker:IsPlayer()) then
    return
  end

  -- Don't track self-damage
  if (attacker == target) then
    return
  end

  PLUGIN.incrementPendingHit(attacker, hitgroup, "player")
end

-- Track damage dealt to NPC's with body part information
function PLUGIN.hook:ScaleNPCDamage(npc, hitgroup, damageInfo)
  local attacker = damageInfo:GetAttacker()

  if (not IsValid(attacker) or not attacker:IsPlayer()) then
    return
  end

  PLUGIN.incrementPendingHit(attacker, hitgroup, "npc")
end

-- Track when NPCs are killed
function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  if (not IsValid(attacker) or not attacker:IsPlayer()) then
    return
  end

  PLUGIN.incrementPendingStat(attacker, "npc_kills", 1)
end

-- Track when players are killed (for kill/death ratios)
function PLUGIN.hook:PlayerDeath(victim, inflictor, attacker)
  if (not IsValid(attacker) or not attacker:IsPlayer()) then
    return
  end

  if (not IsValid(victim) or not victim:IsPlayer()) then
    return
  end

  -- Don't track suicide
  if (attacker == victim) then
    return
  end

  PLUGIN.incrementPendingStat(attacker, "kills", 1)
  PLUGIN.incrementPendingStat(victim, "deaths", 1)

  -- Check if it was a headshot kill
  local hitgroup = victim:LastHitGroup() or HITGROUP_GENERIC

  if (hitgroup == HITGROUP_HEAD) then
    PLUGIN.incrementPendingStat(attacker, "headshot_kills", 1)
  end
end

-- Save all pending stats to database
function PLUGIN.saveData()
  if (table.IsEmpty(PLUGIN.pendingStats)) then
    return
  end

  for steamID, stats in pairs(PLUGIN.pendingStats) do
    -- Build the update expressions for ON DUPLICATE KEY UPDATE
    local updates = {}
    local insertColumns = { "steam_id" }
    local insertValues = { "'" .. steamID .. "'" }

    if (stats.shots_fired) then
      table.insert(updates, "total_shots = total_shots + " .. stats.shots_fired)
      table.insert(insertColumns, "total_shots")
      table.insert(insertValues, stats.shots_fired)
    end

    if (stats.kills) then
      table.insert(updates, "kills = kills + " .. stats.kills)
      table.insert(insertColumns, "kills")
      table.insert(insertValues, stats.kills)
    end

    if (stats.deaths) then
      table.insert(updates, "deaths = deaths + " .. stats.deaths)
      table.insert(insertColumns, "deaths")
      table.insert(insertValues, stats.deaths)
    end

    if (stats.headshot_kills) then
      table.insert(updates, "headshot_kills = headshot_kills + " .. stats.headshot_kills)
      table.insert(insertColumns, "headshot_kills")
      table.insert(insertValues, stats.headshot_kills)
    end

    if (stats.npc_kills) then
      table.insert(updates, "npc_kills = npc_kills + " .. stats.npc_kills)
      table.insert(insertColumns, "npc_kills")
      table.insert(insertValues, stats.npc_kills)
    end

    -- Add player hitgroup updates
    for hitgroupID, count in pairs(stats.player_hits or {}) do
      local hitgroupName = PLUGIN.hitgroupNames[hitgroupID]

      if (hitgroupName) then
        local columnName = "player_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
        table.insert(updates, columnName .. " = " .. columnName .. " + " .. count)
        table.insert(insertColumns, columnName)
        table.insert(insertValues, count)
      end
    end

    -- Add NPC hitgroup updates
    for hitgroupID, count in pairs(stats.npc_hits or {}) do
      local hitgroupName = PLUGIN.hitgroupNames[hitgroupID]

      if (hitgroupName) then
        local columnName = "npc_hits_" .. string.lower(string.gsub(hitgroupName, " ", ""))
        table.insert(updates, columnName .. " = " .. columnName .. " + " .. count)
        table.insert(insertColumns, columnName)
        table.insert(insertValues, count)
      end
    end

    if (#updates > 0) then
      -- Add last_updated to both insert and update
      table.insert(updates, "last_updated = " .. os.time())
      table.insert(insertColumns, "last_updated")
      table.insert(insertValues, os.time())

      local query = [[
				INSERT INTO player_hit_stats (]] .. table.concat(insertColumns, ", ") .. [[)
				VALUES (]] .. table.concat(insertValues, ", ") .. [[)
				ON DUPLICATE KEY UPDATE ]] .. table.concat(updates, ", ")

      versus.database.query(query)
    end
  end

  -- Clear pending stats after saving
  PLUGIN.pendingStats = {}
end
