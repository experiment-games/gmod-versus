local PLUGIN = PLUGIN

PLUGIN.localConditionsCompleted = PLUGIN.localConditionsCompleted or {}
PLUGIN.localExtractions = PLUGIN.localExtractions or {}
PLUGIN.conditionIndicators = PLUGIN.conditionIndicators or {}

PLUGIN.lockedColor = Color(255, 100, 100, 255)
PLUGIN.completedColor = Color(100, 255, 100, 255)
PLUGIN.unlockedColor = Color(255, 200, 80, 255)

function PLUGIN.hasCompletedCondition(player, condition)
  return PLUGIN.localConditionsCompleted[condition:EntIndex()] == true
end

function PLUGIN.createHUDContainer()
  if IsValid(PLUGIN.hudContainer) then
    PLUGIN.hudContainer:Remove()
  end

  PLUGIN.hudContainer = vgui.Create("versus_ExtractionHUDContainer")
end

function PLUGIN.updateHUDContainer()
  if not IsValid(PLUGIN.hudContainer) then
    PLUGIN.createHUDContainer()
  end

  if IsValid(PLUGIN.assignedExtractionPoint) then
    PLUGIN.hudContainer:SetExtractionPoint(PLUGIN.assignedExtractionPoint)
  else
    PLUGIN.hudContainer:Clear()
  end
end

function PLUGIN.clearHUDContainer()
  if IsValid(PLUGIN.hudContainer) then
    PLUGIN.hudContainer:Clear()
  end
end

function PLUGIN.showExtractionProgress(extractionPoint, extractionTime)
  if IsValid(PLUGIN.extractionProgressPanel) then
    PLUGIN.extractionProgressPanel:Remove()
  end

  PLUGIN.extractionProgressPanel = vgui.Create("versus_Timer")
  PLUGIN.extractionProgressPanel:SetTimer(extractionTime, true, "EXTRACTING")
  PLUGIN.extractionProgressPanel:SizeToContents(250)
  PLUGIN.extractionProgressPanel:MoveToDefaultPosition()
end

function PLUGIN.hideExtractionProgress()
  if IsValid(PLUGIN.extractionProgressPanel) then
    PLUGIN.extractionProgressPanel:Remove()
    PLUGIN.extractionProgressPanel = nil
  end
end

-- Assign an extraction point and create indicators
function PLUGIN.assignExtractionPoint(extractionPoint)
  PLUGIN.clearExtractionPoint()

  PLUGIN.assignedExtractionPoint = extractionPoint

  -- Create indicator for extraction point
  PLUGIN.extractionIndicatorID = versus.indicator.create({
    pos = function()
      return extractionPoint:GetPos()
    end,
    text = function()
      return extractionPoint:GetExtractionName()
    end,
    color = function()
      local locked = not IsValid(extractionPoint) and true or extractionPoint:GetLocked()
      local color = locked and PLUGIN.lockedColor or PLUGIN.unlockedColor

      return color
    end,
    scale = 1.2,
    removeOnReach = false
  })

  -- Find and create indicators for required conditions
  PLUGIN.updateConditionIndicators()
  PLUGIN.updateHUDContainer()
end

-- Clear extraction point and all indicators
function PLUGIN.clearExtractionPoint()
  if PLUGIN.extractionIndicatorID then
    versus.indicator.remove(PLUGIN.extractionIndicatorID)
    PLUGIN.extractionIndicatorID = nil
  end

  for conditionIndex, indicatorID in pairs(PLUGIN.conditionIndicators) do
    versus.indicator.remove(indicatorID)
  end

  PLUGIN.conditionIndicators = {}
  PLUGIN.assignedExtractionPoint = nil

  PLUGIN.updateHUDContainer()
end
