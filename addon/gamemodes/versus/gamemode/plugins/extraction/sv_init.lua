local PLUGIN = PLUGIN

util.AddNetworkString("versus.extraction.startExtraction")
util.AddNetworkString("versus.extraction.completeExtraction")
util.AddNetworkString("versus.extraction.completeCondition")
util.AddNetworkString("versus.extraction.assignExtractionPoint")
util.AddNetworkString("versus.extraction.failedExtraction")

-- Get all extraction points in the map
function PLUGIN.getExtractionPoints()
  return ents.FindByClass("versus_extraction_point")
end

-- Get all extraction conditions in the map
function PLUGIN.getExtractionConditions()
  return ents.FindByClass("versus_extraction_condition")
end

-- Check if a player has extracted
function PLUGIN.hasPlayerExtracted(player)
  return player:GetNWBool("versus_Extracted", false)
end

-- Mark a player as extracted
function PLUGIN.setPlayerExtracted(player, extracted)
  player:SetNWBool("versus_Extracted", extracted or false)
end

-- Get all completed conditions for a player
function PLUGIN.getCompletedConditions(player)
  return player._extractionConditionsCompleted or {}
end

-- Check if player has completed a condition
function PLUGIN.hasCompletedCondition(player, condition)
  local completed = PLUGIN.getCompletedConditions(player)
  return completed[condition:EntIndex()] == true
end

-- Mark a condition as completed for a player
function PLUGIN.setConditionCompleted(player, condition, completed)
  player._extractionConditionsCompleted = player._extractionConditionsCompleted or {}
  player._extractionConditionsCompleted[condition:EntIndex()] = completed or false
end

-- Check if all conditions are met for extraction point
function PLUGIN.areConditionsMet(player, extractionPoint)
  local requiredConditions = extractionPoint:GetRequiredConditions()

  -- If no conditions required, always met
  if (#requiredConditions == 0) then
    return true
  end

  for _, condition in ipairs(requiredConditions) do
    if (IsValid(condition) and not PLUGIN.hasCompletedCondition(player, condition)) then
      return false
    end
  end

  return true
end

-- Assign an extraction point to a player
function PLUGIN.assignExtractionPointToPlayer(player, extractionPoint)
  if not IsValid(player) or not IsValid(extractionPoint) then
    return false
  end

  player._assignedExtractionPoint = extractionPoint

  -- Network to client
  net.Start("versus.extraction.assignExtractionPoint")
  net.WriteUInt(extractionPoint:EntIndex(), MAX_EDICT_BITS)
  net.Send(player)

  versus.message.notify(player,
    "Extraction objective assigned: " .. extractionPoint:GetExtractionName(),
    NOTIFY_GENERIC)

  return true
end

-- Clear assigned extraction point for a player
function PLUGIN.clearAssignedExtractionPoint(player)
  if not IsValid(player) then return end

  player._assignedExtractionPoint = nil

  -- Network to client (send invalid index)
  net.Start("versus.extraction.assignExtractionPoint")
  net.WriteUInt(0, MAX_EDICT_BITS)
  net.Send(player)
end

-- Get assigned extraction point for a player
function PLUGIN.getAssignedExtractionPoint(player)
  if not IsValid(player) then return nil end
  return player._assignedExtractionPoint
end

-- Check if player has an assigned extraction point
function PLUGIN.hasAssignedExtractionPoint(player)
  return IsValid(PLUGIN.getAssignedExtractionPoint(player))
end

-- Assign random extraction point to player
function PLUGIN.assignRandomExtractionPoint(player)
  local extractionPoints = PLUGIN.getExtractionPoints()

  if #extractionPoints == 0 then
    versus.message.notify(player, "No extraction points available on this map!", NOTIFY_ERROR)
    return false
  end

  local randomPoint = extractionPoints[math.random(1, #extractionPoints)]
  return PLUGIN.assignExtractionPointToPlayer(player, randomPoint)
end

-- Assign nearest extraction point to player
function PLUGIN.assignNearestExtractionPoint(player)
  local extractionPoints = PLUGIN.getExtractionPoints()

  if #extractionPoints == 0 then
    versus.message.notify(player, "No extraction points available on this map!", NOTIFY_ERROR)
    return false
  end

  local playerPos = player:GetPos()
  local nearestPoint = nil
  local nearestDistance = math.huge

  for _, point in ipairs(extractionPoints) do
    if IsValid(point) then
      local distance = playerPos:Distance(point:GetPos())
      if distance < nearestDistance then
        nearestDistance = distance
        nearestPoint = point
      end
    end
  end

  if nearestPoint then
    return PLUGIN.assignExtractionPointToPlayer(player, nearestPoint)
  end

  return false
end

-- Find all conditions required for a specific extraction point
function PLUGIN.getConditionsForExtractionPoint(extractionPoint)
  if not IsValid(extractionPoint) then return {} end

  local conditions = {}
  local extractionPointName = extractionPoint:GetExtractionName()

  for _, condition in ipairs(PLUGIN.getExtractionConditions()) do
    if IsValid(condition) and condition:GetExtractionPointName() == extractionPointName then
      table.insert(conditions, condition)
    end
  end

  return conditions
end

-- Start extraction for a player
function PLUGIN.startExtraction(player, extractionPoint)
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

  local timerName = "versus_extraction_" .. player:SteamID64()
  player._extractionTimer = timerName
  player._extractionPoint = extractionPoint
  player._extractionStartPos = player:GetPos()

  -- Call hook for increasing difficulty
  hook.Run("PlayerStartExtraction", player, extractionPoint)

  net.Start("versus.extraction.startExtraction")
  net.WriteEntity(extractionPoint)
  net.WriteUInt(extractionTime, 16)
  net.WriteUInt(extractionPoint:GetMaxDistance(), 16)
  net.Send(player)

  local checks = math.ceil(extractionTime) * 2 -- check every 0.5 seconds
  local checkInterval = extractionTime / checks
  local checkCount = 0

  timer.Create(timerName, checkInterval, checks, function()
    if (not IsValid(player)) then
      return
    end

    -- Check if player is still near extraction point
    local maxDistance = extractionPoint:GetMaxDistance()
    local distance = player:GetPos():Distance(extractionPoint:GetPos())

    if (distance > maxDistance) then
      versus.message.notify(player, "Extraction failed! You moved too far from the extraction point.", NOTIFY_ERROR)
      player._extractionPoint = nil
      player._extractionTimer = nil

      net.Start("versus.extraction.failedExtraction")
      net.WriteEntity(extractionPoint)
      net.Send(player)

      hook.Run("PlayerFailedExtraction", player, extractionPoint)

      timer.Remove(timerName)

      return
    end

    if (checkCount == checks - 1) then
      player._extractionTimer = nil

      -- Successfully extracted
      PLUGIN.completeExtraction(player, extractionPoint)
    end

    checkCount = checkCount + 1
  end)

  return true
end

-- Complete extraction for a player
function PLUGIN.completeExtraction(player, extractionPoint)
  if (not IsValid(player) or not IsValid(extractionPoint)) then
    return
  end

  -- Call hook
  hook.Run("PlayerExtracted", player, extractionPoint)

  net.Start("versus.extraction.completeExtraction")
  net.WriteEntity(extractionPoint)
  net.Send(player)

  -- Mark as extracted
  PLUGIN.setPlayerExtracted(player, true)

  versus.message.notify(player, "Extraction complete! You have successfully extracted.", NOTIFY_GENERIC)

  -- Kill player silently (they shouldn't respawn)
  player:KillSilent()

  player._extractionPoint = nil
end

-- Complete an extraction condition
function PLUGIN.completeCondition(player, condition)
  if (not IsValid(player) or not IsValid(condition)) then
    return false
  end

  -- Check if already completed
  if (PLUGIN.hasCompletedCondition(player, condition)) then
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

    PLUGIN.setConditionCompleted(player, condition, true)
    versus.message.notify(player, "Objective completed: " .. conditionName, NOTIFY_GENERIC)

    net.Start("versus.extraction.completeCondition")
    net.WriteEntity(condition)
    net.Send(player)

    -- Check if this unlocks any extraction points
    PLUGIN.checkExtractionPointsUnlock(player, condition)

    -- Call the condition's OnComplete
    if (condition.OnComplete) then
      condition:OnComplete(player)
    end
  end)

  return true
end

-- Check if any extraction points should unlock
function PLUGIN.checkExtractionPointsUnlock(player, condition)
  for _, extractionPoint in ipairs(ents.FindByClass("versus_extraction_point")) do
    if (IsValid(extractionPoint)) then
      local requiredConditions = extractionPoint:GetRequiredConditions()
      local allCompleted = true

      for _, reqCondition in ipairs(requiredConditions) do
        if (IsValid(reqCondition) and not PLUGIN.hasCompletedCondition(player, reqCondition)) then
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

--[[
  Console Commands
--]]

-- Console command to manually assign extraction point
concommand.Add("versus_assign_extraction", function(ply, cmd, args)
  if not IsValid(ply) or not ply:IsAdmin() then return end

  if #args < 1 then
    ply:ChatPrint("Usage: versus_assign_extraction <player_name> [extraction_point_name]")
    return
  end

  local targetName = args[1]
  local target = nil

  -- Find target player
  for _, player in ipairs(player.GetAll()) do
    if string.find(string.lower(player:Name()), string.lower(targetName)) then
      target = player
      break
    end
  end

  if not IsValid(target) then
    ply:ChatPrint("Player not found: " .. targetName)
    return
  end

  if #args >= 2 then
    -- Assign specific extraction point by name
    local pointName = table.concat(args, " ", 2)
    local found = false

    for _, point in ipairs(PLUGIN.getExtractionPoints()) do
      if IsValid(point) and string.find(string.lower(point:GetExtractionName()), string.lower(pointName)) then
        PLUGIN.assignExtractionPointToPlayer(target, point)
        ply:ChatPrint("Assigned " .. point:GetExtractionName() .. " to " .. target:Name())
        found = true
        break
      end
    end

    if not found then
      ply:ChatPrint("Extraction point not found: " .. pointName)
    end
  else
    -- Assign random extraction point
    if PLUGIN.assignRandomExtractionPoint(target) then
      ply:ChatPrint("Assigned random extraction point to " .. target:Name())
    end
  end
end)

-- Console command to clear extraction assignment
concommand.Add("versus_clear_extraction", function(ply, cmd, args)
  if not IsValid(ply) or not ply:IsAdmin() then return end

  if #args < 1 then
    ply:ChatPrint("Usage: versus_clear_extraction <player_name>")
    return
  end

  local targetName = args[1]
  local target = nil

  for _, player in ipairs(player.GetAll()) do
    if string.find(string.lower(player:Name()), string.lower(targetName)) then
      target = player
      break
    end
  end

  if not IsValid(target) then
    ply:ChatPrint("Player not found: " .. targetName)
    return
  end

  PLUGIN.clearAssignedExtractionPoint(target)
  ply:ChatPrint("Cleared extraction assignment for " .. target:Name())
end)
