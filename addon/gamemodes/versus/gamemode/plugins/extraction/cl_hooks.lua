local PLUGIN = PLUGIN

-- Hook to update indicators when conditions are completed
function PLUGIN.hook:PlayerCompleteExtractionCondition(player, condition)
  if player == LocalPlayer() then
    PLUGIN:updateConditionIndicators()
  end
end

-- Clean up on extraction complete
function PLUGIN.hook:PlayerExtracted(player, extractionPoint)
  if player == LocalPlayer() then
    PLUGIN:clearExtractionPoint()
  end
end

-- Hook into extraction start to show progress
function PLUGIN.hook:PlayerStartExtraction(player, extractionPoint, extractionTime)
  if player == LocalPlayer() then
    local extraction = PLUGIN.localExtractions[extractionPoint:EntIndex()]
    if extraction then
      PLUGIN:showExtractionProgress(extractionPoint, extraction.extractionTime)
    end
  end
end

-- Hook into extraction complete to hide progress
function PLUGIN.hook:PlayerExtracted(player, extractionPoint)
  if player == LocalPlayer() then
    PLUGIN:hideExtractionProgress()
  end
end

--[[
  Net Messages
--]]

net.Receive("versus.extraction.assignExtractionPoint", function()
  local extractionPointIndex = net.ReadUInt(MAX_EDICT_BITS)
  local extractionPoint = Entity(extractionPointIndex)

  if IsValid(extractionPoint) then
    PLUGIN:assignExtractionPoint(extractionPoint)
  else
    PLUGIN:clearExtractionPoint()
  end
end)

net.Receive("versus.extraction.startExtraction", function(len, player)
  local extractionPointIndex = net.ReadUInt(MAX_EDICT_BITS)
  local extractionTime = net.ReadUInt(16)

  PLUGIN.localExtractions[extractionPointIndex] = {
    startTime = CurTime(),
    extractionTime = extractionTime,
    completed = false,
  }

  hook.Run("PlayerStartExtraction", player, Entity(extractionPointIndex), extractionTime)
end)

net.Receive("versus.extraction.completeExtraction", function(len, player)
  local extractionPointIndex = net.ReadUInt(MAX_EDICT_BITS)

  PLUGIN.localExtractions[extractionPointIndex] = PLUGIN.localExtractions[extractionPointIndex] or {}
  PLUGIN.localExtractions[extractionPointIndex].completed = true

  hook.Run("PlayerExtracted", player, Entity(extractionPointIndex))
end)

net.Receive("versus.extraction.completeCondition", function(len, player)
  local conditionIndex = net.ReadUInt(MAX_EDICT_BITS)

  PLUGIN.localConditionsCompleted[conditionIndex] = true

  hook.Run("PlayerCompleteExtractionCondition", player, Entity(conditionIndex))
end)
