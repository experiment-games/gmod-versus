local PLUGIN = PLUGIN

util.AddNetworkString("versus.contracts.receiveContracts")

--- Returns versus_extraction_point entities that are currently valid extraction points
--- @return table # Table of valid extraction point entities
function PLUGIN:getValidExtractionPoints()
  -- TODO: Later we'll filter which ones are already being used by other players, but for now we'll just return all of them
  return ents.FindByClass("versus_extraction_point")
end

--- Finds the spawn point (versus_spawn_point) furthest from the given position
--- Used to assign spawn points far away from the extraction point.
--- @param position Vector # The position to find spawn points far away from
--- @return Entity? # The spawn point entity, or nil if none found
function PLUGIN:findFurthestSpawnPoint(position)
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
function PLUGIN:generateContractsForPlayer(player)
  local extractionPoints = self:getValidExtractionPoints()

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

  for _, extractionPoint in ipairs(extractionPoints) do
    if IsValid(extractionPoint) then
      table.insert(contracts, self:registerContract(player, {
        enabled = true,
        name = "Extract from " .. extractionPoint:GetExtractionName(),
        type = "extract",
        extractionPoint = extractionPoint,
        spawnPoint = self:findFurthestSpawnPoint(extractionPoint:GetPos()),
        difficulty = "EASY",
        pvpMode = "BOTH",
        reward = "LOW",
        rewards = {
          -- TODO: Implement experience.
          -- Only reward experience for now. Other items are those that they find in the world, so we won't include them as contract rewards.
          experience = 100,
        }
      }))
    end
  end

  -- Send the generated contracts to the player
  net.Start("versus.contracts.receiveContracts")
  net.WriteUInt(#contracts, self.bitCountContractAmount)

  for _, contract in ipairs(contracts) do
    net.WriteUInt(contract.id, self.bitCountContractID)
    net.WriteBool(contract.enabled)
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

--- Registers a contract for a player, setting an ID and returns the contract data.
--- @param player Player # The player to register the contract for
--- @param contractData table # The data for the contract to register
--- @return table # The registered contract data, including the generated ID
function PLUGIN:registerContract(player, contractData)
  player._VersusContracts = player._VersusContracts or {}
  contractData.id = table.insert(player._VersusContracts, contractData)

  return contractData
end

--local contract = PLUGIN:getContractByID(player, contractID)
--- Retrieves a contract by ID for a given player.
--- @param player Player # The player to get the contract for
--- @param contractID number # The ID of the contract to retrieve
--- @return table? # The contract data if found, or nil if not found
function PLUGIN:getContractByID(player, contractID)
  if (not player._VersusContracts) then
    return nil
  end

  return player._VersusContracts[contractID]
end
