local PLUGIN = PLUGIN

PLUGIN.localContracts = PLUGIN.localContracts or {}

--- Stores the contracts received from the server for the local player.
--- @param contracts table # The list of contracts received from the server
function PLUGIN:receiveContracts(contracts)
  self.localContracts = contracts
  hook.Run("PlayerReceivedContracts", contracts)
end

--- Gets the current contracts for the local player.
--- @return table? # The list of current contracts for the local player
function PLUGIN:getLocalContracts()
  return self.localContracts
end

--- Gets a specific contract by ID for the local player.
--- @param contractID number # The ID of the contract to retrieve
--- @return table? # The contract data if found, or nil if not found
function PLUGIN:getLocalContract(contractID)
  return self.localContracts and self.localContracts[contractID] or nil
end
