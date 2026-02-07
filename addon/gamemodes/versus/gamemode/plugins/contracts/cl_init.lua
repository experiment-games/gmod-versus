local PLUGIN = PLUGIN

PLUGIN.localContracts = PLUGIN.localContracts or {}

--- Stores the contracts received from the server for the local player.
--- @param contracts table # The list of contracts received from the server
function PLUGIN:receiveContracts(contracts)
  self.localContracts = contracts
  hook.Run("PlayerReceivedContracts", contracts)
end

--- Gets the current contracts for the local player.
--- @return table # The list of current contracts for the local player
function PLUGIN:getLocalContracts()
  return self.localContracts or {}
end
