local PLUGIN = PLUGIN

-- Auto-assign extraction points when player loads character
function PLUGIN.hook:PlayerLoadedCharacter(player, character)
  -- Auto-assign random extraction point (optional, can be disabled)
  -- Comment out the line below if you want manual assignment
  timer.Simple(0.5, function()
    if IsValid(player) then
      PLUGIN:assignRandomExtractionPoint(player)
    end
  end)
end

-- Clear assignment on disconnect
function PLUGIN.hook:PlayerDisconnected(player)
  player._assignedExtractionPoint = nil
end

-- Prevent respawning after extraction
function PLUGIN.hook:PlayerDeathThink(player)
  if (self:hasPlayerExtracted(player)) then
    return true
  end
end

-- Clean up on death
function PLUGIN.hook:PlayerDeath(player)
  -- Cancel any ongoing extraction
  if (player._extractionTimer) then
    timer.Remove(player._extractionTimer)
    player._extractionTimer = nil
  end
end

-- Clean up on disconnect
function PLUGIN.hook:PlayerDisconnected(player)
  if (player._extractionTimer) then
    timer.Remove(player._extractionTimer)
  end
end

-- When the manifest is loaded, ensure all conditions register with extraction points
function PLUGIN.hook:ServerManifestApplied(manifest)
  for _, condition in ipairs(self:getExtractionConditions()) do
    condition:SetupConnectionToExtractionPoint()
  end
end
