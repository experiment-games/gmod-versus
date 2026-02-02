local PLUGIN = PLUGIN

-- Called when a player starts extracting at an extraction point
-- Return false to prevent extraction
function PLUGIN.hook:PlayerStartExtraction(player, extractionPoint)
end

-- Called when a player successfully completes extraction
function PLUGIN.hook:PlayerExtracted(player, extractionPoint)
end

-- Called when a player completes an extraction condition
-- Return false to prevent completion
function PLUGIN.hook:PlayerCompleteExtractionCondition(player, condition)
end

-- Called when an extraction point unlocks (all conditions met)
function PLUGIN.hook:ExtractionPointUnlocked(extractionPoint)
end
