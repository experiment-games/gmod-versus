local PLUGIN = PLUGIN

util.AddNetworkString("versus.contracts.selectContract")
util.AddNetworkString("versus.contracts.selectedContract")

-- We stop the player from spawning, up until they select a contract and are ready to play.
-- We must still call :Spawn() on the player to spawn them after setting _VersusContract.
function PLUGIN.hook:PlayerDeathThink(player)
  if (not player._VersusContract) then
    return true
  end
end

-- On initialization we generate contracts for the player to select from, and show the contract selection UI.
function PLUGIN.hook:PlayerInitialized(player)
  self:generateContractsForPlayer(player)
end

-- Spawn where the contract specifies
function PLUGIN.hook:PlayerSelectSpawn(player)
  if (player._VersusContract and player._VersusContract.spawnPoint and IsValid(player._VersusContract.spawnPoint)) then
    return player._VersusContract.spawnPoint
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.contracts.selectContract", function(len, player)
  local contractID = net.ReadUInt(PLUGIN.bitCountContractID)
  local contract = PLUGIN:getContractByID(player, contractID)

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
end)
