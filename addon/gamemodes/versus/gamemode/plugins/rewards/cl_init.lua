local PLUGIN = PLUGIN

function PLUGIN.showRewardScreen(title, subtitle, items, xpGained, currentLevel, xpToNextLevel, currentXP)
  local rewardScreen = vgui.Create("versus_RewardScreen")

  -- TODO: We are coupling this plugin too tightly to the contract system, but its easier for now
  if (IsValid(versus.contracts.radioStack)) then
    versus.contracts.radioStack:Remove()
    versus.contracts.radioStack = nil
  end

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

--[[
  Net Messages
--]]

net.Receive("versus.rewards.showScreen", function()
  local title = net.ReadString()
  local subtitle = net.ReadString()
  local itemKeys = net.ReadTable()
  local xpGained = net.ReadUInt(32)
  local currentLevel = net.ReadUInt(16)
  local xpToNextLevel = net.ReadUInt(16)
  local currentXP = net.ReadUInt(16)

  local items = {}

  for _, itemKey in ipairs(itemKeys) do
    local item = versus.inventory.getItem(LocalPlayer(), itemKey)

    if item then
      table.insert(items, item)
    end
  end

  PLUGIN.showRewardScreen(title, subtitle, items, xpGained, currentLevel, xpToNextLevel, currentXP)
end)
