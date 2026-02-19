local UNIT = UNIT

util.AddNetworkString("versus.unit.command.execute")

function UNIT.runPlayerCommand(player, arguments)
  if (not player._VersusInitialized) then
    versus.message.notify(player, "You haven't initialized yet!", NOTIFY_ERROR)
    return
  end

  if (not arguments or not arguments[1]) then
    versus.message.notify(player, arguments[1] .. " is not a valid command!", NOTIFY_ERROR)
    return
  end

  local commandText = arguments[1]
  local command = UNIT.stored[commandText:lower()]

  if (not command) then
    versus.message.notify(player, commandText .. " is not a valid command!", NOTIFY_ERROR)
    return
  end

  local parameters = arguments
  table.remove(parameters, 1)

  for index, parameter in pairs(parameters) do
    parameters[index] = string.Replace(parameters[index], " ' ", "'")
    parameters[index] = string.Replace(parameters[index], " : ", ":")
  end

  if (hook.Run("PlayerCanUseCommand", player, command, parameters) == false) then
    return
  end

  local requiredFlags = command.requiredFlags

  if (requiredFlags and not versus.player.hasFlags(player, requiredFlags)) then
    versus.message.notify(player, "You do not have access to the " .. command .. " command, " .. player:Name() .. ".",
      NOTIFY_ERROR)
    return
  end

  local success, fault = command:run(player, parameters)

  if (success == false) then
    versus.message.notify(player, fault, NOTIFY_ERROR)
    print(player:getSteamID64(), player:getCombinedName(), fault .. "\n")
  end

  if (not GAMEMODE:IsListenServer()) then
    if (table.concat(parameters, " ") ~= "") then
      print(player:getCombinedName() .. " used 'versus " .. commandText .. " " .. table.concat(parameters, " ") .. "'.")
    else
      print(player:getCombinedName() .. " used 'versus " .. commandText .. "'.")
    end
  end

  if (table.concat(parameters, " ") ~= "") then
    versus.player.printConsoleAccess(
      player:getCombinedName() .. " used 'versus " .. commandText .. " " .. table.concat(parameters, " ") .. "'.", "a")
  else
    versus.player.printConsoleAccess(player:getCombinedName() .. " used 'versus " .. commandText .. "'.", "a")
  end
end

-- Legacy:
concommand.Add("versus", function(player, _, arguments)
  UNIT.runPlayerCommand(player, arguments)
end)

net.Receive("versus.unit.command.execute", function(len, player)
  local commandText = net.ReadString()
  local argumentsString = net.ReadString()

  -- TODO: We could do some throttling here, and at least let the player know if they are being throttled.

  local arguments = {}
  for argument in string.gmatch(argumentsString, "%$q(.-)%$q") do
    table.insert(arguments, argument)
  end

  UNIT.runPlayerCommand(player, { commandText, unpack(arguments) })
end)
