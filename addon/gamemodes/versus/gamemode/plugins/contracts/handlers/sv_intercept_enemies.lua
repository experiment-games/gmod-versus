local PLUGIN = PLUGIN

--- Handler: interceptEnemies
---
--- Spawns enemies at a calculated point on the straight line between the player's current
--- position and a destination location, creating a force that cuts off their route.
--- All spawned NPCs immediately chase the player — use `spawnWaves` for stationary defenders.
---
--- Schema:
--- {
---   destination       = PLUGIN.referToContractLocation("someKey"),
---                       -- the location the player is heading toward
---   interceptFraction = number?,
---                       -- 0.0 (near player) to 1.0 (at destination), default 0.5
---   enemies = {         -- one or more enemy groups
---     {
---       class         = string,           -- NPC class (e.g. "npc_combine_s")
---       count         = number?,          -- default 1
---       weapons       = string[]?,        -- weapon class names to give
---       health        = number|{min,max}?, -- fixed or random range
---       lootTable     = table|function?,  -- drops on death
---       model         = string?,          -- custom model path
---       skin          = number?,          -- skin index
---       bodygroups    = table?,           -- { [group] = value }
---       relationships = string[]?,        -- e.g. "npc_citizen D_NU 99"
---     },
---   },
--- }
PLUGIN.registerContractPhaseKeyHandler("interceptEnemies", function(player, bag, data)
  if not istable(data) then
    error("Data for contract phase interceptEnemies key is not a table: " .. tostring(data))
    return
  end

  if not data.destination then
    ErrorNoHalt("[Contract] interceptEnemies: No destination specified\n")
    return
  end

  if not istable(data.enemies) then
    ErrorNoHalt("[Contract] interceptEnemies: No enemies table specified\n")
    return
  end

  local destinationEntity = PLUGIN.getEntityFromReference(player, data.destination)

  if not IsValid(destinationEntity) then
    ErrorNoHalt("[Contract] interceptEnemies: Failed to find entity for destination: " ..
      util.TableToJSON(data.destination) .. "\n")
    return
  end

  local fraction     = math.Clamp(data.interceptFraction or 0.5, 0, 1)
  local playerPos    = player:GetPos()
  local destPos      = destinationEntity:GetPos()
  local interceptPos = playerPos + (destPos - playerPos) * fraction

  for _, enemyGroup in ipairs(data.enemies) do
    local npcClass = enemyGroup.class

    if not npcClass then
      ErrorNoHalt("[Contract] interceptEnemies: Enemy group is missing 'class'\n")
      continue
    end

    local count = enemyGroup.count or 1

    local npcs = versus.npc.spawnNPCsAroundPoint(
      npcClass,
      interceptPos,
      count,
      enemyGroup.weapons,
      player
    )

    for _, npc in ipairs(npcs) do
      PLUGIN.registerContractNPC(player, bag, npc)

      -- Intercept enemies always actively chase the player
      versus.npc.setChase(npc, player)

      if enemyGroup.relationships then
        for _, relationship in ipairs(enemyGroup.relationships) do
          npc:AddRelationship(relationship)
        end
      end

      if enemyGroup.lootTable then
        versus.npc.attachLootSpawner(npc, function(npcEntity, attacker, inflictor)
          PLUGIN.produceLootAtPosition(npc, attacker, enemyGroup.lootTable, npcEntity:GetPos())
        end)
      end

      if enemyGroup.model then
        npc:SetModel(enemyGroup.model)
      end

      if enemyGroup.skin then
        npc:SetSkin(enemyGroup.skin)
      end

      if enemyGroup.bodygroups then
        for group, value in pairs(enemyGroup.bodygroups) do
          npc:SetBodygroup(group, value)
        end
      end

      if enemyGroup.health then
        local health = enemyGroup.health
        if istable(health) then
          health = math.random(health[1], health[2])
        end
        npc:SetHealth(health)
        npc:SetMaxHealth(health)
      end
    end
  end
end)
