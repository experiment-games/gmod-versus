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

    local shouldProgress = PLUGIN.callContractFunction(
      player,
      bag,
      data.shouldProgressCallback,
      "Contract phase progressBar key has shouldProgressCallback but function is not registered"
    )

    if shouldProgress == nil then
      return
    end

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

      PLUGIN.callContractFunction(
        player,
        bag,
        data.completeCallback,
        "Contract phase progressBar key has completeCallback but function is not registered"
      )
    end
  end)

  versus.objectives.setObjectiveTimer(player, time, countDown, text)
end)
