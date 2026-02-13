local PLUGIN = PLUGIN

util.AddNetworkString("versus.contracts.selectContract")
util.AddNetworkString("versus.contracts.selectedContract")
util.AddNetworkString("versus.contracts.forceReselectContract")

--[[
  Hooks
--]]

-- On think, we check if players in a certain contract phase should progress to the next phase based on the
-- contract's 'completeCallback' key. This key holds a table where the first value is the function that checks for
-- completion and the other values are arguments to pass to that function.
-- If the function returns true, the player progresses to the next phase.
function PLUGIN.hook:Think()
  for _, player in player.Iterator() do
    if not player._VersusCurrentContract then
      continue
    end

    local contract = player._VersusCurrentContract and PLUGIN.getContract(player._VersusCurrentContract.id)

    if not contract then
      continue
    end

    local currentPhase = contract.phases[player._VersusCurrentContract.phaseIndex]

    -- Get the role-appropriate phase
    local role = player._VersusContractRole or "first"
    local actualPhase = PLUGIN.getPhaseForRole(currentPhase, role)

    if not actualPhase.completeCallback then
      -- Some handler will probably force with the 'completePhase' function
      continue
    end

    local isComplete = PLUGIN.callContractFunction(
      player,
      player._VersusCurrentContract.bag,
      actualPhase.completeCallback,
      "Contract phase has 'completeCallback' key but completion function is not registered"
    )

    if not isComplete then
      continue
    end

    PLUGIN.handleContractPhaseCompletion(player)
  end
end

function PLUGIN.hook:PlayerSelectSpawn(player)
  if (not player._VersusPreferedSpawnPoint) then
    return
  end

  local spawnPoint = player._VersusPreferedSpawnPoint
  player._VersusPreferedSpawnPoint = nil -- Clear it so it doesn't interfere with future spawns

  print("Spawning player at preferred spawn point: " .. tostring(spawnPoint), spawnPoint:GetPos())
  return spawnPoint
end

-- We stop the player from spawning, up until they select a contract and are ready to play.
-- We must still call :Spawn() on the player to spawn them after setting _VersusCurrentContract.
function PLUGIN.hook:PlayerDeathThink(player)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  if (not player._VersusCurrentContract) then
    return false
  end
end

-- On initialization we generate contracts for the player to select from, and show the contract selection UI.
function PLUGIN.hook:PlayerInitialized(player)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  PLUGIN.generateContractsForPlayer(player)
end

-- For now players cannot try again after death, but will have to take up a new contract.
function PLUGIN.hook:CanPlayerRespawnInTime(player, attacker)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  PLUGIN.forceReselectContract(player)
  return false
end

-- When the player dies, we fade and remove any items we spawned specifically for them
function PLUGIN.hook:PostPlayerDeath(player)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  for _, item in ipairs(player._VersusLootItems or {}) do
    if (IsValid(item)) then
      versus.util.decayEntity(item, 5)
    end
  end

  player._VersusLootItems = nil

  -- Clean up entity reservations
  PLUGIN.cleanupContractReservations(player)

  -- Handle contract cleanup for linked players
  if player._VersusCurrentContract then
    if player._VersusContractRole == "first" then
      -- Fail all linked subsequent players
      if player._VersusContractSubsequents then
        for _, subsequentPlayer in ipairs(player._VersusContractSubsequents) do
          if IsValid(subsequentPlayer) then
            PLUGIN.failContract(subsequentPlayer, "The primary contractor has died.")
          end
        end
      end

      -- Remove from active instances
      if player._VersusContractInstanceID then
        local contractID = player._VersusCurrentContract.id
        if PLUGIN.activeContractInstances[contractID] then
          PLUGIN.activeContractInstances[contractID][player._VersusContractInstanceID] = nil
        end
      end
    elseif player._VersusContractRole == "subsequent" then
      -- Unlink from first player
      if player._VersusContractLinkedTo and IsValid(player._VersusContractLinkedTo) then
        PLUGIN.unlinkContractInstance(player._VersusContractLinkedTo, player)
      end
    end
  end
end

-- Clean up contract linkages on player disconnect
function PLUGIN.hook:PlayerDisconnected(player)
  -- Clean up entity reservations
  PLUGIN.cleanupContractReservations(player)

  if not player._VersusCurrentContract then
    return
  end

  if player._VersusContractRole == "first" then
    -- Fail all linked subsequent players
    if player._VersusContractSubsequents then
      for _, subsequentPlayer in ipairs(player._VersusContractSubsequents) do
        if IsValid(subsequentPlayer) then
          PLUGIN.failContract(subsequentPlayer, "The primary contractor has disconnected.")
        end
      end
    end

    -- Remove from active instances
    if player._VersusContractInstanceID then
      local contractID = player._VersusCurrentContract.id
      if PLUGIN.activeContractInstances[contractID] then
        PLUGIN.activeContractInstances[contractID][player._VersusContractInstanceID] = nil
      end
    end
  elseif player._VersusContractRole == "subsequent" then
    -- Unlink from first player
    if player._VersusContractLinkedTo and IsValid(player._VersusContractLinkedTo) then
      PLUGIN.unlinkContractInstance(player._VersusContractLinkedTo, player)
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
  local numericContractID = net.ReadUInt(PLUGIN.bitCountContractID)

  -- Convert numeric ID back to string ID
  local contractID = player._VersusContractIDMap and player._VersusContractIDMap[numericContractID]

  if not contractID then
    ErrorNoHalt("Player selected invalid contract ID: " .. tostring(numericContractID) .. "\n")
    return
  end

  -- Get the prepared contract for this player
  local preparedContract = player._VersusAvailableContracts and player._VersusAvailableContracts[contractID]

  if not preparedContract then
    ErrorNoHalt("Player does not have prepared contract: " .. contractID .. "\n")
    return
  end

  -- Check if this is a subsequent contract
  local subsequentData = player._VersusSubsequentContractData and player._VersusSubsequentContractData[contractID]
  local role = subsequentData and "subsequent" or "first"
  local linkedToPlayer = subsequentData and subsequentData.firstPlayer or nil

  -- Verify the first player is still valid for subsequent contracts
  if role == "subsequent" then
    if not IsValid(linkedToPlayer) or not linkedToPlayer._VersusCurrentContract then
      versus.message.notify(player, "This interference contract is no longer available.", NOTIFY_ERROR)
      PLUGIN.generateContractsForPlayer(player) -- Refresh contracts
      return
    end

    -- Subsequent contracts share the first player's entities, so we don't need to reserve
  elseif role == "first" then
    -- NOW we reserve the entities for this player
    local reserved = PLUGIN.reserveContractLocations(player, contractID, preparedContract.locations)

    if not reserved then
      -- Some entities are no longer available (another player took them)
      versus.message.notify(player, "This contract is no longer available. Entities are in use.", NOTIFY_ERROR)
      PLUGIN.generateContractsForPlayer(player) -- Refresh contracts with newly available options
      return
    end
  end

  -- Assign the contract to the player
  PLUGIN.assignContractToPlayer(player, preparedContract, role, linkedToPlayer)

  -- Network the selection back to client
  net.Start("versus.contracts.selectedContract")
  net.WriteUInt(numericContractID, PLUGIN.bitCountContractID)
  net.Send(player)

  -- Freeze the player during a setup phase so they can equip their weapons
  player:Freeze(true)

  timer.Simple(PLUGIN.setupTimeInSeconds, function()
    if not IsValid(player) then
      return
    end

    player:Freeze(false)

    hook.Run("PlayerSelectedContract", player, preparedContract, contractID)
  end)
end)
