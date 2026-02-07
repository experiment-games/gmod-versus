local PLUGIN = PLUGIN

util.AddNetworkString("versus.contracts.selectContract")
util.AddNetworkString("versus.contracts.selectedContract")
util.AddNetworkString("versus.contracts.forceReselectContract")

-- We stop the player from spawning, up until they select a contract and are ready to play.
-- We must still call :Spawn() on the player to spawn them after setting _VersusContract.
function PLUGIN.hook:PlayerDeathThink(player)
  if (not player._VersusContract) then
    return true
  end
end

-- On initialization we generate contracts for the player to select from, and show the contract selection UI.
function PLUGIN.hook:PlayerInitialized(player)
  self.generateContractsForPlayer(player)
end

-- Spawn where the contract specifies
function PLUGIN.hook:PlayerSelectSpawn(player)
  if (player._VersusContract and player._VersusContract.spawnPoint and IsValid(player._VersusContract.spawnPoint)) then
    return player._VersusContract.spawnPoint
  end
end

-- For now players cannot try again after death, but will have to take up a new contract.
function PLUGIN.hook:CanPlayerRespawnInTime(player, attacker)
  -- Lose the contract
  player._VersusContract = nil

  PLUGIN.generateContractsForPlayer(player)
  versus.extraction.clearAssignedExtractionPoint(player)

  -- TODO: Show death screen before showing contract selection again.
  net.Start("versus.contracts.forceReselectContract")
  net.Send(player)

  return false
end

-- When the contract is selected, we setup the enemies in between based on the contract.
function PLUGIN.hook:PlayerSelectedContract(player, contract, contractID)
  local start = contract.spawnPoint:GetPos()
  local extraction = contract.extractionPoint:GetPos()
  local points = PLUGIN.getSpawnNPCPointsBetween(start, extraction)
  local sortedPoints = PLUGIN.categorizeSpawnPoints(points, start, extraction)

  local contractEnemies = contract.enemies

  if not contractEnemies then
    ErrorNoHalt("Contract " .. contractID .. " has no enemy data defined\n")
    return
  end

  -- Iterate through each enemy group defined in the contract
  for _, enemyGroup in ipairs(contractEnemies) do
    local npcClass = enemyGroup.class
    local location = enemyGroup.location
    local count = enemyGroup.count

    -- Get the spawn points for this location category
    local availableSpawns = sortedPoints[location]

    -- If no spawns in this category, find nearest available spawns from other categories
    if not availableSpawns or #availableSpawns == 0 then
      print("[Contract] Warning: No spawn points available for location category " ..
        location .. ", using nearest available")

      -- Collect all spawn points from all categories
      local allSpawns = {}
      for _, categorySpawns in pairs(sortedPoints) do
        for _, spawn in ipairs(categorySpawns) do
          table.insert(allSpawns, spawn)
        end
      end

      -- Determine the target position for this category
      local targetPos
      if location == PLUGIN.ENEMY_NEAR_SPAWN then
        targetPos = start
      elseif location == PLUGIN.ENEMY_NEAR_EXTRACTION then
        targetPos = extraction
      else
        -- For middle categories, use midpoint
        targetPos = (start + extraction) / 2
      end

      -- Sort all spawns by distance to target position
      table.sort(allSpawns, function(a, b)
        return a:GetPos():DistToSqr(targetPos) < b:GetPos():DistToSqr(targetPos)
      end)

      availableSpawns = allSpawns
    end

    if availableSpawns and #availableSpawns > 0 then
      -- Distribute enemies across available spawn points
      local spawnsPerPoint = math.ceil(count / #availableSpawns)
      local remaining = count

      for _, spawnPoint in ipairs(availableSpawns) do
        if remaining <= 0 then break end

        local spawnCount = math.min(spawnsPerPoint, remaining)
        local npcs = versus.npc.spawnNPCsAroundPoint(
          npcClass,
          spawnPoint:GetPos(),
          spawnCount,
          enemyGroup.weapons,
          player
        )

        -- Will have them go towards the player's spawn (but might run past them if the player detours)
        for _, npc in ipairs(npcs) do
          npc:SetEnemy(player)
          npc:UpdateEnemyMemory(player, player:GetPos())

          if (enemyGroup.lootTable) then
            versus.npc.attachLootSpawner(npc, function(npc, attacker, inflictor)
              PLUGIN.produceLootAtPosition(attacker, enemyGroup.lootTable, npc:GetPos())
            end)
          end

          if (enemyGroup.model) then
            npc:SetModel(enemyGroup.model)
          end

          if (enemyGroup.skin) then
            npc:SetSkin(enemyGroup.skin)
          end

          if (enemyGroup.bodygroups) then
            for group, value in pairs(enemyGroup.bodygroups) do
              npc:SetBodygroup(group, value)
            end
          end

          if (enemyGroup.health) then
            if (istable(enemyGroup.health)) then
              local health = math.random(enemyGroup.health[1], enemyGroup.health[2])
              npc:SetHealth(health)
            else
              npc:SetHealth(enemyGroup.health)
            end
          end
        end

        remaining = remaining - spawnCount
      end
    end
  end
end

--[[
  Console Commands
--]]

concommand.Add("versus_debug_points_between", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  if (not player._VersusContract) then
    versus.message.notify(player, "You must select a contract first to use this command.", NOTIFY_ERROR)
    return
  end

  local start = player._VersusContract.spawnPoint:GetPos()
  local extraction = player._VersusContract.extractionPoint:GetPos()
  local points = PLUGIN.getSpawnNPCPointsBetween(start, extraction)

  -- Draw debug lines to the points for 10 seconds
  for _, npcSpawn in ipairs(points) do
    local pos = npcSpawn:GetPos()
    debugoverlay.Cross(pos, 16, 10, Color(255, 0, 0), true)
  end

  local sortedPoints = PLUGIN.categorizeSpawnPoints(points, start, extraction)
  PrintTable(sortedPoints)
end)

concommand.Add("versus_skip_selection", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  player._VersusContract = {
    extractionPoint = nil,
  }
  player:Spawn()
end)

--[[
  Net Messages
--]]

net.Receive("versus.contracts.selectContract", function(len, player)
  local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
  local contract = PLUGIN.getContractByID(player, contractID)

  if (not contract) then
    ErrorNoHalt("Player selected invalid contract ID: " .. contractID .. "\n")
    return
  end

  player._VersusContract = contract
  player:Spawn()

  versus.extraction.assignExtractionPointToPlayer(player, contract.extractionPoint)

  net.Start("versus.contracts.selectedContract")
  net.WriteUInt(contractID, PLUGIN.bitCountContractID)
  net.Send(player)

  hook.Run("PlayerSelectedContract", player, contract, contractID)
end)
