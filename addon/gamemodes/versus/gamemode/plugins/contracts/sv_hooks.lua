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

-- After successful extraction we show the reward screen to the player, after which they can select a new contract.
function PLUGIN.hook:PlayerExtracted(player, extractionPoint)
  PLUGIN.forceReselectContract(player)
end

-- For now players cannot try again after death, but will have to take up a new contract.
function PLUGIN.hook:CanPlayerRespawnInTime(player, attacker)
  PLUGIN.forceReselectContract(player)
  return false
end

-- When the player dies, we fade and remove any items we spawned specifically for them
function PLUGIN.hook:PostPlayerDeath(player)
  for _, item in ipairs(player._VersusLootItems or {}) do
    if (IsValid(item)) then
      versus.util.decayEntity(item, 5)
    end
  end

  player._VersusLootItems = nil
end

-- When the contract is selected, we setup the enemies in between based on the contract.
function PLUGIN.hook:PlayerSelectedContract(player, contract, contractID)
  PLUGIN.setupEnemiesForPlayerContract(player, contract, contractID)
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

  net.Start("versus.contracts.selectedContract")
  net.WriteUInt(contractID, PLUGIN.bitCountContractID)
  net.Send(player)

  -- Freeze the player during a setup phase so they can equip their weapons
  player:Freeze(true)

  timer.Simple(PLUGIN.setupTimeInSeconds, function()
    if (not IsValid(player)) then
      return
    end

    player:Freeze(false)

    versus.extraction.assignExtractionPointToPlayer(player, contract.extractionPoint)

    hook.Run("PlayerSelectedContract", player, contract, contractID)
  end)
end)
