local UNIT = UNIT

-- Called when a player presses F1.
function UNIT.hook:ShowHelp(player)
  net.Start("versus.showMenu")
  net.Send(player)
end
