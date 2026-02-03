local PLUGIN = PLUGIN

PLUGIN.localConditionsCompleted = PLUGIN.localConditionsCompleted or {}
PLUGIN.localExtractions = PLUGIN.localExtractions or {}

PLUGIN.lockedColor = Color(255, 100, 100, 255)
PLUGIN.completedColor = Color(100, 255, 100, 255)
PLUGIN.unlockedColor = Color(255, 200, 80, 255)

function PLUGIN:showRewardScreen(title, subtitle, items, xpGained, currentLevel, xpToNextLevel, currentXP)
  local rewardScreen = vgui.Create("versus_RewardScreen")

  if title then
    rewardScreen:SetTitle(title)
  end

  if subtitle then
    rewardScreen:SetSubtitle(subtitle)
  end

  if items then
    rewardScreen:SetItems(items)
  end

  if xpGained then
    rewardScreen:SetExperience(xpGained, currentLevel, xpToNextLevel, currentXP)
  end

  return rewardScreen
end

concommand.Add("versus_test_extraction_reward", function()
  if (not LocalPlayer():IsSuperAdmin()) then
    return
  end

  local items = {
    versus.item.find("ammo_pistol"),
  }

  PLUGIN:showRewardScreen(
    ("Extraction Successful"):upper(), -- Title
    "High Value Target Eliminated",    -- Subtitle
    items,                             -- Items table
    10000,                             -- XP gained
    5,                                 -- Current level
    40000,                             -- XP needed for next level
    25000                              -- Current XP
  )
end)

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
