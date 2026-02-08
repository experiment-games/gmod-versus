local UNIT = UNIT

util.AddNetworkString("versus.finance.initialize")
util.AddNetworkString("versus.finance.initialized")

net.Receive("versus.finance.initialized", function(len, player)
  player._FinanceInitialized = true
end)

-- Called to get a list of functions that should return true when this unit
-- is done doing it's loading for the player. The player won't spawn until
-- all blockingCallbacks return true
function UNIT.hook:PlayerInitializing(player, blockingCallbacks)
  if (player:IsBot()) then
    return
  end

  net.Start("versus.finance.initialize")
  net.WriteUInt(UNIT.getMoney(player), 32)
  net.Send(player)

  table.insert(blockingCallbacks, function(player)
    return player._FinanceInitialized == true
  end)
end
