local PLUGIN = PLUGIN

util.AddNetworkString("versus.contracts.receiveContracts")
util.AddNetworkString("versus.combat.showServerSelectionScreen")

function PLUGIN.forceReselectContract(player)
  -- Lose the contract
  player._VersusContract = nil

  PLUGIN.generateContractsForPlayer(player)
  versus.extraction.clearAssignedExtractionPoint(player)

  -- TODO: Show death screen before showing contract selection again.
  net.Start("versus.contracts.forceReselectContract")
  net.Send(player)
end

--- Returns versus_extraction_point entities that are currently valid extraction points
--- @return table # Table of valid extraction point entities
function PLUGIN.getValidExtractionPoints()
  -- TODO: Later we'll filter which ones are already being used by other players, but for now we'll just return all of them
  return ents.FindByClass("versus_extraction_point")
end

--- Finds the spawn point (versus_spawn_point) furthest from the given position
--- Used to assign spawn points far away from the extraction point.
--- @param position Vector # The position to find spawn points far away from
--- @return Entity? # The spawn point entity, or nil if none found
function PLUGIN.findFurthestSpawnPoint(position)
  local spawnPoints = ents.FindByClass("versus_spawn_point")
  local furthestSpawn = nil
  local maxDistance = -1

  for _, spawn in ipairs(spawnPoints) do
    if IsValid(spawn) then
      local distance = position:Distance(spawn:GetPos())
      if distance > maxDistance then
        maxDistance = distance
        furthestSpawn = spawn
      end
    end
  end

  return furthestSpawn
end

--- Generates contracts for the given player, based on the current map and available extraction points.
--- The player will select one of the generated contracts to complete for rewards.
--- @param player Player # The player to generate contracts for
function PLUGIN.generateContractsForPlayer(player)
  local extractionPoints = PLUGIN.getValidExtractionPoints()

  if #extractionPoints == 0 then
    ErrorNoHalt(
      "TODO: Implement fallback if no extraction points are found on the map. Currently contracts will not be generated.\n")
    return
  end

  -- For now we'll generate a single type of contract "extract" which just requires the player to go to an extraction point and extract.
  -- Later we can add more complex contract types with different objectives, like:
  -- - Kill a certain number of enemies
  -- - Collect certain items
  -- - Survive for a certain amount of time
  -- - Extract a hostage from point A to point B
  local contracts = {}

  PLUGIN.clearContracts(player)

  -- For now we create a contract for each extraction point
  for _, extractionPoint in ipairs(extractionPoints) do
    if IsValid(extractionPoint) then
      table.insert(contracts, PLUGIN.registerContract(player, {
        -- When not enabled, the contract cannot be selected and the reason is shown in the UI.
        enabled = true,
        name = "Extract from " .. extractionPoint:GetExtractionName(),
        type = "extract",
        extractionPoint = extractionPoint,
        spawnPoint = PLUGIN.findFurthestSpawnPoint(extractionPoint:GetPos()),
        difficulty = "MEDIUM",
        pvpMode = "BOTH",
        reward = "LOW",
        rewards = {
          -- TODO: Implement experience.
          -- Only reward experience for now. Other items are those that they find in the world, so we won't include them as contract rewards.
          experience = 100,
        },
        enemies = {
          {
            class = "npc_combine_s",
            location = PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR,
            health = 50,
            count = 5,
            weapons = { "weapon_ar2", "weapon_smg1" },
            lootTable = function(attacker, position, angles)
              -- Let's spawn a health vial, or ammo for the player's current weapon
              local loot = {
                ["health_vial"] = 0.2,
              }

              if (IsValid(attacker) and attacker:IsPlayer()) then
                local activeWeapon = attacker:GetActiveWeapon()

                if (IsValid(activeWeapon)) then
                  local ammoType = activeWeapon:GetPrimaryAmmoType()

                  if (ammoType and ammoType ~= -1) then
                    local ammoItemID = versus.weapon.getItemIDFromAmmoType(ammoType)

                    if (ammoItemID) then
                      loot[ammoItemID] = 0.3
                    end
                  end
                end
              end

              return loot
            end
          },
          {
            class = "npc_combine_s",
            location = PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE,
            health = 100,
            count = 10,
            weapons = { "weapon_ar2", "weapon_smg1", "weapon_shotgun" },
            lootTable = {
              ["ammo_762x51"] = 0.2,
              ["health_kit"] = 0.2,
            }
          },
          {
            class = "npc_combine_s",
            model = "models/combine_super_soldier.mdl",
            health = { 100, 120 },
            location = PLUGIN.ENEMY_NEAR_EXTRACTION,
            count = 10,
            weapons = { "weapon_ar2", "weapon_smg1", "weapon_shotgun" },
            lootTable = {
              ["ammo_12gauge"] = 0.2,
              ["health_kit"] = 0.3,
            }
          },
          {
            class = "npc_manhack",
            location = PLUGIN.ENEMY_NEAR_EXTRACTION,
            count = 10,
          }
        }
      }))
    end
  end

  -- Disable the first contract for testing
  contracts[1].enabled = false
  contracts[1].unavailableReason = "This contract is currently unavailable."

  -- Send the generated contracts to the player
  net.Start("versus.contracts.receiveContracts")
  net.WriteUInt(#contracts, PLUGIN.bitCountContractAmount)

  for _, contract in ipairs(contracts) do
    net.WriteUInt(contract.id, PLUGIN.bitCountContractID)
    net.WriteBool(contract.enabled)

    if (not contract.enabled) then
      net.WriteString(contract.unavailableReason or "This contract is currently unavailable.")
    end

    net.WriteString(contract.name)
    net.WriteString(contract.type)
    net.WriteEntity(contract.extractionPoint)
    net.WriteEntity(contract.spawnPoint)
    net.WriteString(contract.difficulty)
    net.WriteString(contract.reward)
    net.WriteString(contract.pvpMode)
  end

  net.Send(player)
end

--- Clears any contracts and starts with new ones, forcing the player to reselect a contract.
--- This is used when the player dies, to force them to select a new contract each time they play.
--- @param player Player # The player to register the contract for
function PLUGIN.clearContracts(player)
  player._VersusContracts = {}
end

--- Registers a contract for a player, setting an ID and returns the contract data.
--- @param player Player # The player to register the contract for
--- @param contractData table # The data for the contract to register
--- @return table # The registered contract data, including the generated ID
function PLUGIN.registerContract(player, contractData)
  contractData.id = table.insert(player._VersusContracts, contractData)

  return contractData
end

--local contract = PLUGIN.getContractByID(player, contractID)
--- Retrieves a contract by ID for a given player.
--- @param player Player # The player to get the contract for
--- @param contractID number # The ID of the contract to retrieve
--- @return table? # The contract data if found, or nil if not found
function PLUGIN.getContractByID(player, contractID)
  if (not player._VersusContracts) then
    return nil
  end

  return player._VersusContracts[contractID]
end

--- Get all NPC spawn points
function PLUGIN.getSpawnNPCPoints()
  return ents.FindByClass("versus_npc_spawn_point")
end

--- Gets all NPC spawn points that are in between the two positions. This is used to
--- determine spawn points between the player's spawn and the extraction point, so we can spawn enemies there.
--- @param startPos Vector # The first position to compare
--- @param endPos Vector # The second position to compare
--- @param maxWidth? number # Maximum perpendicular distance from the direct line (optional, defaults to infinite)
--- @return table # Table of spawn point entities that are in between the two positions
function PLUGIN.getSpawnNPCPointsBetween(startPos, endPos, maxWidth)
  local spawnPoints = PLUGIN.getSpawnNPCPoints()
  local pointsBetween = {}

  maxWidth = maxWidth or 1024

  for _, spawn in ipairs(spawnPoints) do
    if IsValid(spawn) then
      local spawnPos = spawn:GetPos()

      local lineVec = endPos - startPos
      local pointVec = spawnPos - startPos

      -- Project pointVec onto lineVec to find how far along the line the spawn is
      local t = pointVec:Dot(lineVec) / lineVec:LengthSqr()

      -- If t is between 0 and 1, the spawn point is "between" the two positions
      if t > 0 and t < 1 then
        -- Find the closest point on the line to the spawn point
        local closestPointOnLine = startPos + lineVec * t
        -- Calculate perpendicular distance
        local perpDistance = spawnPos:Distance(closestPointOnLine)

        if perpDistance <= maxWidth then
          table.insert(pointsBetween, spawn)
        end
      end
    end
  end

  return pointsBetween
end

--- Sorts spawn points by distance from extraction and groups them into location categories
--- @param spawnPoints table # Table of spawn point entities
--- @param startPos Vector # Player spawn position
--- @param endPos Vector # Extraction point position
--- @return table # Table with keys ENEMY_NEAR_SPAWN, ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR, ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE, ENEMY_NEAR_EXTRACTION
function PLUGIN.categorizeSpawnPoints(spawnPoints, startPos, endPos)
  -- Sort spawn points by distance to extraction (furthest first)
  table.sort(spawnPoints, function(a, b)
    return a:GetPos():DistToSqr(endPos) > b:GetPos():DistToSqr(endPos)
  end)

  local totalDistance = startPos:Distance(endPos)
  local categorized = {
    [PLUGIN.ENEMY_NEAR_SPAWN] = {},
    [PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR] = {},
    [PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE] = {},
    [PLUGIN.ENEMY_NEAR_EXTRACTION] = {}
  }

  for _, spawn in ipairs(spawnPoints) do
    local spawnPos = spawn:GetPos()
    local distanceFromStart = spawnPos:Distance(startPos)

    -- Calculate what percentage along the path this spawn is
    local percentageAlongPath = distanceFromStart / totalDistance

    if percentageAlongPath < 0.25 then
      -- First quarter - near spawn
      table.insert(categorized[PLUGIN.ENEMY_NEAR_SPAWN], spawn)
    elseif percentageAlongPath < 0.50 then
      -- Second quarter - between spawn and extraction, far from extraction
      table.insert(categorized[PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR], spawn)
    elseif percentageAlongPath < 0.75 then
      -- Third quarter - between spawn and extraction, close to extraction
      table.insert(categorized[PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE], spawn)
    else
      -- Last quarter - near extraction
      table.insert(categorized[PLUGIN.ENEMY_NEAR_EXTRACTION], spawn)
    end
  end

  return categorized
end

function PLUGIN.setupEnemiesForPlayerContract(player, contract, contractID)
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

function PLUGIN.produceLootAtPosition(attacker, lootTable, position, angles)
  if (isfunction(lootTable)) then
    lootTable = lootTable(attacker, position, angles)
  end

  -- Roll for each item independently based on its percentage chance
  for itemID, chance in pairs(lootTable) do
    local roll = math.random()

    if (roll <= chance) then
      local item = versus.item.createInstance(itemID)

      if (not item) then
        ErrorNoHalt("[NPC Spawner] Invalid item ID in loot table: " .. tostring(itemID) .. "\n")
        continue
      end

      local itemEntity = versus.item.make(item, position + Vector(0, 0, 30), angles or AngleRand(-180, 180))
      itemEntity:DropToFloor()

      if (IsValid(attacker) and attacker:IsPlayer()) then
        attacker._VersusLootItems = attacker._VersusLootItems or {}
        table.insert(attacker._VersusLootItems, itemEntity)
      end

      hook.Run("VersusNPCLootProduced", item, itemEntity)
    end
  end
end
