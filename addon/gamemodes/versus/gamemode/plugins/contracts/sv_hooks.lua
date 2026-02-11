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

    if not currentPhase.completeCallback then
      -- Some handler will probably force with the 'completePhase' function
      continue
    end

    local isComplete = PLUGIN.callContractFunction(
      player,
      player._VersusCurrentContract.bag,
      currentPhase.completeCallback,
      "Contract phase has 'completeCallback' key but completion function is not registered"
    )

    if not isComplete then
      continue
    end

    PLUGIN.handleContractPhaseCompletion(player)
  end
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

  -- Assign the contract to the player
  PLUGIN.assignContractToPlayer(player, preparedContract)

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
