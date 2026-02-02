local PLUGIN = PLUGIN

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

net.Receive("versus.extraction.conditionCompleted", function(len, player)
  local conditionIndex = net.ReadUInt(MAX_EDICT_BITS)

  PLUGIN.localConditionsCompleted[conditionIndex] = true

  hook.Run("PlayerCompleteExtractionCondition", player, Entity(conditionIndex))
end)
