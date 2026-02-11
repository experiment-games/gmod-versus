local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("progressBar", function(player, bag, data)
  local time = data.duration
  local countDown = data.type == "decrement"
  local text = data.label

  local timerName = "versus.contractProgressBarThink_" .. player:SteamID()

  timer.Create(timerName, time, 1, function()
    if not IsValid(player) then
      timer.Remove(timerName)
      return
    end

    local callbackFunc = PLUGIN.getContractFunction(data.shouldProgressCallback[1])

    if not callbackFunc then
      error("Contract phase progressBar key has shouldProgressCallback but function is not registered: " ..
        tostring(data.shouldProgressCallback[1]))
      return
    end

    local args = { unpack(data.shouldProgressCallback, 2) }

    callbackFunc(player, bag, unpack(args))
  end)

  versus.objectives.setObjectiveTimer(player, time, countDown, text)
end)
