local PLUGIN = PLUGIN

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
