local PLUGIN = PLUGIN

util.AddNetworkString("versus.extraction.startExtraction")
util.AddNetworkString("versus.extraction.completeExtraction")
util.AddNetworkString("versus.extraction.completeCondition")

-- Start extraction for a player
function PLUGIN:startExtraction(player, extractionPoint)
  if (not IsValid(player) or not IsValid(extractionPoint)) then
    return false
  end

  -- Check if already extracting
  if (player._extractionTimer) then
    versus.message.notify(player, "You are already extracting!", NOTIFY_ERROR)
    return false
  end

  -- Check if extraction point is locked
  if (extractionPoint:GetLocked()) then
    versus.message.notify(player, "This extraction point is locked!", NOTIFY_ERROR)
    return false
  end

  -- Check hook
  if (hook.Run("PlayerStartExtraction", player, extractionPoint) == false) then
    return false
  end

  local extractionTime = extractionPoint:GetExtractionTime()

  versus.message.notify(player,
    "Extraction started! Stay near the extraction point for " .. extractionTime .. " seconds.", NOTIFY_GENERIC)

  local timerName = "versus_extraction_" .. player:SteamID64()
  player._extractionTimer = timerName
  player._extractionPoint = extractionPoint
  player._extractionStartPos = player:GetPos()

  -- Call hook for increasing difficulty
  hook.Run("PlayerStartExtraction", player, extractionPoint)

  net.Start("versus.extraction.startExtraction")
  net.WriteEntity(extractionPoint)
  net.WriteUInt(extractionTime, 16)
  net.Send(player)

  timer.Create(timerName, extractionTime, 1, function()
    if (not IsValid(player)) then
      return
    end

    player._extractionTimer = nil

    -- Check if player is still near extraction point
    local maxDistance = extractionPoint:GetMaxDistance()
    local distance = player:GetPos():Distance(extractionPoint:GetPos())

    if (distance > maxDistance) then
      versus.message.notify(player, "Extraction failed! You moved too far from the extraction point.", NOTIFY_ERROR)
      player._extractionPoint = nil
      return
    end

    -- Successfully extracted
    PLUGIN:completeExtraction(player, extractionPoint)
  end)

  return true
end

-- Complete extraction for a player
function PLUGIN:completeExtraction(player, extractionPoint)
  if (not IsValid(player) or not IsValid(extractionPoint)) then
    return
  end

  -- Call hook
  hook.Run("PlayerExtracted", player, extractionPoint)

  net.Start("versus.extraction.completeExtraction")
  net.WriteEntity(extractionPoint)
  net.Send(player)

  -- Mark as extracted
  self:setPlayerExtracted(player, true)

  versus.message.notify(player, "Extraction complete! You have successfully extracted.", NOTIFY_GENERIC)

  -- Kill player silently (they shouldn't respawn)
  player:KillSilent()

  player._extractionPoint = nil
end

-- Complete an extraction condition
function PLUGIN:completeCondition(player, condition)
  if (not IsValid(player) or not IsValid(condition)) then
    return false
  end

  -- Check if already completed
  if (self:hasCompletedCondition(player, condition)) then
    versus.message.notify(player, "You have already completed this objective!", NOTIFY_ERROR)
    return false
  end

  -- Check hook
  if (hook.Run("PlayerCompleteExtractionCondition", player, condition) == false) then
    return false
  end

  local conditionTime = condition:GetConditionTime() or 0
  local conditionName = condition:GetConditionName()

  versus.message.notify(player, "Completing objective: " .. conditionName .. "... (" .. conditionTime .. "s)",
    NOTIFY_GENERIC)

  local timerName = "versus_condition_" .. player:SteamID64() .. "_" .. condition:EntIndex()

  timer.Create(timerName, conditionTime, 1, function()
    if (not IsValid(player) or not IsValid(condition)) then
      return
    end

    self:setConditionCompleted(player, condition, true)
    versus.message.notify(player, "Objective completed: " .. conditionName, NOTIFY_GENERIC)

    net.Start("versus.extraction.completeCondition")
    net.WriteEntity(condition)
    net.Send(player)

    -- Check if this unlocks any extraction points
    self:checkExtractionPointsUnlock(player, condition)

    -- Call the condition's OnComplete
    if (condition.OnComplete) then
      condition:OnComplete(player)
    end
  end)

  return true
end

-- Check if any extraction points should unlock
function PLUGIN:checkExtractionPointsUnlock(player, condition)
  for _, extractionPoint in ipairs(ents.FindByClass("versus_extraction_point")) do
    if (IsValid(extractionPoint)) then
      local requiredConditions = extractionPoint:GetRequiredConditions()
      local allCompleted = true

      for _, reqCondition in ipairs(requiredConditions) do
        if (IsValid(reqCondition) and not self:hasCompletedCondition(player, reqCondition)) then
          allCompleted = false
          break
        end
      end

      if (allCompleted and extractionPoint:GetLocked()) then
        extractionPoint:SetLocked(false)
        versus.message.notify(player,
          "Extraction point '" .. extractionPoint:GetExtractionName() .. "' is now unlocked!", NOTIFY_GENERIC)

        hook.Run("ExtractionPointUnlocked", extractionPoint)
      end
    end
  end
end
