local PLUGIN = PLUGIN

PLUGIN.assignedExtractionPoint = nil
PLUGIN.extractionIndicatorID = nil
PLUGIN.conditionIndicators = {}

-- Assign an extraction point and create indicators
function PLUGIN:assignExtractionPoint(extractionPoint)
  self:clearExtractionPoint()

  self.assignedExtractionPoint = extractionPoint

  -- Create indicator for extraction point
  self.extractionIndicatorID = versus.indicator.create({
    pos = function()
      return extractionPoint:GetPos()
    end,
    text = function()
      return extractionPoint:GetExtractionName()
    end,
    color = function()
      local locked = not IsValid(extractionPoint) and true or extractionPoint:GetLocked()
      local color = locked and self.lockedColor or self.unlockedColor

      return color
    end,
    scale = 1.2,
    removeOnReach = false
  })

  -- Find and create indicators for required conditions
  self:updateConditionIndicators()
  self:updateHUDContainer()
end

-- Clear extraction point and all indicators
function PLUGIN:clearExtractionPoint()
  if self.extractionIndicatorID then
    versus.indicator.remove(self.extractionIndicatorID)
    self.extractionIndicatorID = nil
  end

  for conditionIndex, indicatorID in pairs(self.conditionIndicators) do
    versus.indicator.remove(indicatorID)
  end

  self.conditionIndicators = {}
  self.assignedExtractionPoint = nil

  self:updateHUDContainer()
end

-- Update condition indicators based on completion status
function PLUGIN:updateConditionIndicators()
  if not IsValid(self.assignedExtractionPoint) then return end

  -- Clear existing condition indicators
  for conditionIndex, indicatorID in pairs(self.conditionIndicators) do
    versus.indicator.remove(indicatorID)
  end
  self.conditionIndicators = {}

  -- Find all conditions linked to this extraction point
  local extractionPointName = self.assignedExtractionPoint:GetExtractionName()

  for _, condition in ipairs(ents.FindByClass("versus_extraction_condition")) do
    if IsValid(condition) and condition:GetExtractionPointName() == extractionPointName then
      local completed = self:hasCompletedCondition(LocalPlayer(), condition)

      if not completed then
        local indicatorID = versus.indicator.create({
          pos = function()
            return condition:GetPos()
          end,
          text = function()
            return condition:GetConditionName()
          end,
          color = function()
            local completed = self:hasCompletedCondition(LocalPlayer(), condition)
            return completed and PLUGIN.completedColor or PLUGIN.unlockedColor
          end,
          scale = 1.0,
          removeOnReach = false
        })

        self.conditionIndicators[condition:EntIndex()] = indicatorID
      end
    end
  end
end

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
