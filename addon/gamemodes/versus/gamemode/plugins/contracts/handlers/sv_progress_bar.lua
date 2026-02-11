local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("progressBar", function(player, bag, data)
  local time = data.duration
  local countDown = data.type == "decrement"
  local text = data.label
  local timerName = "versus.contractProgressBarThink_" .. player:SteamID()

  -- We need to keep polling the shouldProgressCallback since the progress bar may need to pause and resume based on changing conditions
  local pollingInterval = 0.1
  timer.Create(timerName, pollingInterval, 0, function()
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
    local shouldProgress = callbackFunc(player, bag, unpack(args))

    if (not shouldProgress) then
      versus.objectives.setObjectiveTimerPaused(player, true)
      bag.phase.progressBarPaused = true
      return
    elseif (bag.phase.progressBarPaused) then
      bag.phase.progressBarPaused = nil
      versus.objectives.setObjectiveTimerPaused(player, false)
    end

    time = time - pollingInterval

    if (time <= 0) then
      timer.Remove(timerName)
      bag.phase.progressBarPaused = nil

      if (not data.completeCallback) then
        return
      end

      local completeCallbackFunc = PLUGIN.getContractFunction(data.completeCallback[1])

      if not completeCallbackFunc then
        error("Contract phase progressBar key has completeCallback but function is not registered: " ..
          tostring(data.completeCallback[1]))
        return
      end

      local completeCallbackArgs = { unpack(data.completeCallback, 2) }
      completeCallbackFunc(player, bag, unpack(completeCallbackArgs))
    end
  end)

  versus.objectives.setObjectiveTimer(player, time, countDown, text)
end)
