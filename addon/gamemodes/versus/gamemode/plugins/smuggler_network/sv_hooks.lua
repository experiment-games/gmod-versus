local PLUGIN = PLUGIN

-- Periodically check for completed runs and notify players.
function PLUGIN.hook:Think()
  if((PLUGIN._nextRunCheckTime or 0) > CurTime())then return end

  PLUGIN._nextRunCheckTime = CurTime() + PLUGIN.RUN_CHECK_INTERVAL

  for _, player in ipairs(player.GetAll()) do
    if(IsValid(player) and player:IsConnected())then
      local smugglerData = PLUGIN.getPlayerData(player)
      local previousCount = #smugglerData.completedRuns

      PLUGIN.checkRunCompletions(player)

      if(#smugglerData.completedRuns > previousCount)then
        versus.message.notify(
          player,
          "A smuggling run has returned. Talk to the smuggler to collect your results.",
          NOTIFY_GENERIC
        )
      end
    end
  end
end

function PLUGIN.hook:PlayerInitialized(player)
  PLUGIN.checkRunCompletions(player)
end
