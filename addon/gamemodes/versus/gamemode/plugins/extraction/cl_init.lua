local PLUGIN = PLUGIN

PLUGIN.localConditionsCompleted = PLUGIN.localConditionsCompleted or {}
PLUGIN.localExtractions = PLUGIN.localExtractions or {}

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
