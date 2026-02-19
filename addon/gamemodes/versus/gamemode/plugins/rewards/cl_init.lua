local PLUGIN = PLUGIN

--[[
  Character Panel Integration
--]]

function PLUGIN.hook:VersusCharacterBuildLeftPanel(leftPanel, characterPanel)
  local levelDisplay = vgui.Create("versus_LevelDisplay", leftPanel)
  levelDisplay:Dock(TOP)
  levelDisplay:DockMargin(0, 0, 0, 8)
end

function PLUGIN.showRewardScreen(
    title,
    subtitle,
    items,
    xpGained,
    currentLevel,
    xpToNextLevel,
    currentXP,
    startLevel,
    startXP
)
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
    rewardScreen:SetExperience(
      xpGained,
      currentLevel,
      xpToNextLevel,
      currentXP,
      startLevel,
      startXP
    )
  end

  return rewardScreen
end

--[[
  Net Messages
--]]

net.Receive("versus.rewards.showScreen", function()
  local itemKeys = {}
  local title = net.ReadString()
  local subtitle = net.ReadString()
  local itemCount = net.ReadUInt(16)
  for i = 1, itemCount do
    local itemKey = net.ReadUInt(versus.inventory.bitSizeItemKeys)
    table.insert(itemKeys, itemKey)
  end
  local xpGained = net.ReadUInt(32)
  local currentLevel = net.ReadUInt(32)
  local xpToNextLevel = net.ReadUInt(32)
  local currentXP = net.ReadUInt(32)
  local startLevel = net.ReadUInt(16)
  local startXP = net.ReadUInt(32)

  local items = {}

  for _, itemKey in ipairs(itemKeys) do
    local item = versus.inventory.getItem(LocalPlayer(), itemKey)

    if item then
      table.insert(items, item)
    else
      print("Warning: Could not find item with key ", itemKey, " for reward screen")
    end
  end

  PLUGIN.showRewardScreen(
    title,
    subtitle,
    items,
    xpGained,
    currentLevel,
    xpToNextLevel,
    currentXP,
    startLevel,
    startXP
  )
end)
