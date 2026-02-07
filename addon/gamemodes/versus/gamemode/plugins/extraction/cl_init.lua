local PLUGIN = PLUGIN

PLUGIN.localConditionsCompleted = PLUGIN.localConditionsCompleted or {}
PLUGIN.localExtractions = PLUGIN.localExtractions or {}
PLUGIN.conditionIndicators = PLUGIN.conditionIndicators or {}

PLUGIN.lockedColor = Color(255, 100, 100, 255)
PLUGIN.completedColor = Color(100, 255, 100, 255)
PLUGIN.unlockedColor = Color(255, 200, 80, 255)

function PLUGIN:hasCompletedCondition(player, condition)
  return self.localConditionsCompleted[condition:EntIndex()] == true
end

function PLUGIN:createHUDContainer()
  if IsValid(self.hudContainer) then
    self.hudContainer:Remove()
  end

  self.hudContainer = vgui.Create("versus_ExtractionHUDContainer")
end

function PLUGIN:updateHUDContainer()
  if not IsValid(self.hudContainer) then
    self:createHUDContainer()
  end

  if IsValid(self.assignedExtractionPoint) then
    self.hudContainer:SetExtractionPoint(self.assignedExtractionPoint)
  else
    self.hudContainer:Clear()
  end
end

function PLUGIN:clearHUDContainer()
  if IsValid(self.hudContainer) then
    self.hudContainer:Clear()
  end
end

function PLUGIN:showExtractionProgress(extractionPoint, extractionTime)
  if IsValid(self.extractionProgressPanel) then
    self.extractionProgressPanel:Remove()
  end

  self.extractionProgressPanel = vgui.Create("versus_ExtractionProgressPanel")
  self.extractionProgressPanel:SetExtractionData(extractionPoint, extractionTime)
end

function PLUGIN:hideExtractionProgress()
  if IsValid(self.extractionProgressPanel) then
    self.extractionProgressPanel.targetAlpha = 0
  end
end

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
