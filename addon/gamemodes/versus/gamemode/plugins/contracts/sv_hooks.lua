local PLUGIN = PLUGIN

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
