local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("enemies", function(player, bag, data)
  -- data is an array of enemy groups to spawn
  -- Each enemy group has:
  -- - class: NPC class name
  -- - location: Location reference (from PLUGIN.referToContractLocation)
  -- - behavior: "defending" or "attacking"
  -- - health: Number or {min, max} table for random health
  -- - count: Number of NPCs to spawn
  -- - weapons: Optional array of weapon class names
  -- - lootTable: Optional table or function for loot drops
  -- - model: Optional custom model
  -- - skin: Optional skin index
  -- - bodygroups: Optional table of bodygroup indices

  if not istable(data) then
    error("Data for contract phase enemies key is not a table: " .. tostring(data))
    return
  end

  local level = versus.rewards.getPlayerLevel(player) or 1

  for _, enemyGroup in ipairs(data) do
    local npcClass = enemyGroup.class
    local locationReference = enemyGroup.location
    local count = enemyGroup.count or 1

    -- Scale count and health based on player level (bosses are exempt from count scaling
    -- so scripted moments always fire as authored)
    if not enemyGroup.isBoss then
      count = versus.rewards.scaledEnemyCount(count, level)
    end

    -- Get the entity from the location reference
    local targetEntity = PLUGIN.getEntityFromReference(player, locationReference)

    if not IsValid(targetEntity) then
      ErrorNoHalt("Failed to find entity for enemy spawn location: " .. util.TableToJSON(locationReference) .. "\n")
      continue
    end

    local targetPos = targetEntity:GetPos()

    -- Spawn NPCs around the target position
    local npcs = versus.npc.spawnNPCsAroundPoint(
      npcClass,
      targetPos,
      count,
      enemyGroup.weapons,
      player
    )

    -- Configure each spawned NPC
    for _, npc in ipairs(npcs) do
      -- Register NPC for cleanup
      PLUGIN.registerContractNPC(player, bag, npc)

      -- Set enemy behavior
      if enemyGroup.behavior == "attacking" then
        npc:SetEnemy(player)
        npc:UpdateEnemyMemory(player, player:GetPos())
      elseif enemyGroup.behavior == "defending" then
        -- TODO: For defending behavior, set them to stay around the location
        -- TODO: add additional AI behavior here to make them patrol or hold position
      end

      -- Apply custom entity relationships
      -- Each entry is a string in the format "<classname|entity_name> <disposition> <priority>"
      -- e.g. "npc_citizen D_NU 99" to make this NPC neutral toward citizens
      -- Valid dispositions: D_HT (hate), D_FR (fear), D_LI (like), D_NU (neutral)
      if enemyGroup.relationships then
        for _, relationship in ipairs(enemyGroup.relationships) do
          npc:AddRelationship(relationship)
        end
      end

      -- Attach loot spawner if loot table is provided
      if enemyGroup.lootTable then
        versus.npc.attachLootSpawner(npc, function(npc, attacker, inflictor)
          PLUGIN.produceLootAtPosition(npc, attacker, enemyGroup.lootTable, npc:GetPos())
        end)
      end

      -- Apply custom model if specified
      if enemyGroup.model then
        npc:SetModel(enemyGroup.model)
      end

      -- Apply custom skin if specified
      if enemyGroup.skin then
        npc:SetSkin(enemyGroup.skin)
      end

      -- Apply bodygroups if specified
      if enemyGroup.bodygroups then
        for group, value in pairs(enemyGroup.bodygroups) do
          npc:SetBodygroup(group, value)
        end
      end

      -- Apply health if specified, scaled by player level
      if enemyGroup.health then
        if istable(enemyGroup.health) then
          local health = math.random(enemyGroup.health[1], enemyGroup.health[2])
          health = versus.rewards.scaledEnemyHealth(health, level)
          npc:SetHealth(health)
        else
          local health = enemyGroup.health
          health = versus.rewards.scaledEnemyHealth(health, level)
          npc:SetHealth(health)
        end
      end
    end
  end
end)
