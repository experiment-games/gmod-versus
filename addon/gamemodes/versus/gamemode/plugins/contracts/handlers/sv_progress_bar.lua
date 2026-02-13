local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("progressBar", function(player, bag, data)
  local time = data.duration
  local countDown = data.type == "decrement"
  local text = data.label
  local pollingInterval = 0.1

  -- We need to keep polling the shouldProgressCallback since the progress bar may need to pause and resume based on changing conditions
  PLUGIN.createPhaseTimer(player, bag, "progressBarThink", pollingInterval, 0, function()
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
      -- Timer will be cleaned up automatically by cleanupPhase
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
