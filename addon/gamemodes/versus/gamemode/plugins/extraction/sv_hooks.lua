local PLUGIN = PLUGIN

-- Get all extraction points in the map
function PLUGIN:getExtractionPoints()
  return ents.FindByClass("versus_extraction_point")
end

-- Get all extraction conditions in the map
function PLUGIN:getExtractionConditions()
  return ents.FindByClass("versus_extraction_condition")
end

-- Get all spawn points in the map
function PLUGIN:getSpawnPoints()
  return ents.FindByClass("versus_spawn_point")
end

-- Get a random spawn point
function PLUGIN:getRandomSpawnPoint()
  local spawnPoints = self:getSpawnPoints()

  if (#spawnPoints == 0) then
    return nil
  end

  return spawnPoints[math.random(1, #spawnPoints)]
end

-- Check if a player has extracted
function PLUGIN:hasPlayerExtracted(player)
  return player:GetNWBool("versus_Extracted", false)
end

-- Mark a player as extracted
function PLUGIN:setPlayerExtracted(player, extracted)
  player:SetNWBool("versus_Extracted", extracted or false)
end

-- Get all completed conditions for a player
function PLUGIN:getCompletedConditions(player)
  return player._extractionConditionsCompleted or {}
end

-- Check if player has completed a condition
function PLUGIN:hasCompletedCondition(player, condition)
  local completed = self:getCompletedConditions(player)
  return completed[condition:EntIndex()] == true
end

-- Mark a condition as completed for a player
function PLUGIN:setConditionCompleted(player, condition, completed)
  player._extractionConditionsCompleted = player._extractionConditionsCompleted or {}
  player._extractionConditionsCompleted[condition:EntIndex()] = completed or false
end

-- Check if all conditions are met for extraction point
function PLUGIN:areConditionsMet(player, extractionPoint)
  local requiredConditions = extractionPoint:GetRequiredConditions()

  -- If no conditions required, always met
  if (#requiredConditions == 0) then
    return true
  end

  for _, condition in ipairs(requiredConditions) do
    if (IsValid(condition) and not self:hasCompletedCondition(player, condition)) then
      return false
    end
  end

  return true
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
