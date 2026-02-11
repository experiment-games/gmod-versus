local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("spawnWaves", function(player, bag, data)
  if not data or not istable(data) then
    ErrorNoHalt("[Contract] spawnWaves: Invalid data provided\n")
    return
  end

  -- Process each wave in the data
  for waveIndex, waveData in ipairs(data) do
    local delayInSeconds = waveData.delayInSeconds or 0

    -- Schedule wave spawn after delay
    timer.Simple(delayInSeconds, function()
      if not IsValid(player) then
        ErrorNoHalt("[Contract] spawnWaves: Player invalid when spawning wave " .. waveIndex .. "\n")
        return
      end

      print("[Contract] Spawning wave " .. waveIndex .. " for " .. player:Nick())

      -- Spawn each enemy group in the wave
      for _, enemyData in ipairs(waveData.enemies or {}) do
        local npcClass = enemyData.class
        local count = enemyData.count or 1
        local weapons = enemyData.weapons or {}
        local health = enemyData.health
        local behavior = enemyData.behavior or "idle"
        local location = enemyData.location
        local lootTable = enemyData.lootTable

        if not npcClass then
          ErrorNoHalt("[Contract] spawnWaves: No class specified for enemy\n")
          continue
        end

        if not location then
          ErrorNoHalt("[Contract] spawnWaves: No location specified for enemy class " .. npcClass .. "\n")
          continue
        end

        local entity = PLUGIN.getEntityFromReference(player, location)

        if not IsValid(entity) then
          ErrorNoHalt("[Contract] spawnWaves: Failed to find entity for enemy spawn location: " ..
            util.TableToJSON(location) .. "\n")
          continue
        end

        -- Spawn NPCs around the location point
        local spawnedNPCs = versus.npc.spawnNPCsAroundPoint(
          npcClass,
          entity:GetPos(),
          count,
          weapons,
          player -- Set player as primary enemy
        )

        -- Configure each spawned NPC
        for _, npc in ipairs(spawnedNPCs) do
          if IsValid(npc) then
            -- Set custom health if specified
            if health and health > 0 then
              npc:SetHealth(health)
              npc:SetMaxHealth(health)
            end

            -- Attach loot spawner if provided
            if lootTable then
              versus.npc.attachLootSpawner(npc, function(npcEntity, attacker, inflictor)
                -- Spawn loot from the loot table
                for _, loot in ipairs(lootTable) do
                  local itemID = loot.itemID
                  local chance = loot.chance or 1.0
                  local amount = loot.amount or 1

                  if math.random() <= chance then
                    for i = 1, amount do
                      versus.inventory.spawnItem(itemID, npcEntity:GetPos() + Vector(0, 0, 32))
                    end
                  end
                end
              end)
            end

            -- Set behavior based on the specified type
            if behavior == "attacking" or behavior == "chase" then
              versus.npc.setChase(npc, player)
            elseif behavior == "assault" then
              -- For assault, we need an assault point - use player's position
              local rallyPoint = location
              local assaultPoint = player:GetPos()
              versus.npc.setAssault({ npc }, assaultPoint, rallyPoint, { urgent = true })
            elseif behavior == "defending" then
              -- Defend the spawn location
              versus.npc.setDefendPoint(npc, location, 2048)
            elseif behavior == "patrol" then
              -- Find nearby patrol points and set patrol
              local patrolPoints = versus.npc.director.getNearbyPatrolPoints(location, 2000)
              if #patrolPoints > 0 then
                versus.npc.setPatrol(npc, patrolPoints)
              else
                -- Fallback to chase if no patrol points
                versus.npc.setChase(npc, player)
              end
            elseif behavior == "follow" then
              versus.npc.setFollow(npc, player, { formation = true })
            end
            -- If behavior is "idle" or unrecognized, NPC will just stand there
          end
        end
      end
    end)
  end
end)
