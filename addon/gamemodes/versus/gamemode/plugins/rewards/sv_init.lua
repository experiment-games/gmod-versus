local PLUGIN = PLUGIN

util.AddNetworkString("versus.rewards.showScreen")
util.AddNetworkString("versus.rewards.screenContinue")

--- Shows the reward screen to the player with the given data
--- @param player Player to show the reward screen to
--- @param title string Title to display on the reward screen
--- @param subtitle string Subtitle to display on the reward screen
--- @param itemKeys table Table of item keys to display as rewards
--- @param xpGained number Amount of XP gained to display
--- @param currentLevel number Current player level to display
--- @param xpToNextLevel number XP needed for next level to display
--- @param currentXP number Current XP to display
function PLUGIN.showRewardScreen(player, title, subtitle, itemKeys, xpGained, currentLevel, xpToNextLevel, currentXP)
  net.Start("versus.rewards.showScreen")
  net.WriteString(title)
  net.WriteString(subtitle)
  net.WriteTable(itemKeys)
  net.WriteUInt(xpGained, 32)
  net.WriteUInt(currentLevel, 16)
  net.WriteUInt(xpToNextLevel, 16)
  net.WriteUInt(currentXP, 16)
  net.Send(player)
end

--- Shows the reward screen for a contract completion, using the items given during the contract
--- @param player Player to show the reward screen to
--- @param title string Title to display on the reward screen
--- @param subtitle string Subtitle to display on the reward screen
--- @param xpGained number Amount of XP gained to display
--- @param currentLevel number Current player level to display
--- @param xpToNextLevel number XP needed for next level to display
--- @param currentXP number Current XP to display
function PLUGIN.showContractRewardScreen(player, title, subtitle, xpGained, currentLevel, xpToNextLevel, currentXP)
  local items = player._VersusContractItemsGiven or {}
  local itemKeys = {}

  -- Find the item keys for the given items
  for _, item in ipairs(items) do
    local itemKey = versus.inventory.getItemKey(player, item)

    if itemKey then
      table.insert(itemKeys, itemKey)
    end
  end

  PLUGIN.showRewardScreen(
    player,
    title,
    subtitle,
    itemKeys,
    xpGained,
    currentLevel,
    xpToNextLevel,
    currentXP
  )
end

--[[
  Hooks
--]]

function PLUGIN.hook:PlayerSelectedContract(player, preparedContract, contractID)
  player._VersusContractItemsGiven = {}
end

-- We track items given to the player during a contract so we can display them on the reward
-- screen if they successfully complete the contract.
function PLUGIN.hook:PlayerItemGiven(player, item)
  if (not player._VersusCurrentContract) then
    return
  end

  table.insert(player._VersusContractItemsGiven, item)
end

function PLUGIN.hook:PlayerItemTaken(player, item)
  if (not player._VersusCurrentContract) then
    return
  end

  for index, givenItem in ipairs(player._VersusContractItemsGiven) do
    if givenItem == item then
      table.remove(player._VersusContractItemsGiven, index)
      break
    end
  end
end

concommand.Add("versus_test_extraction_reward", function(player, cmd, args)
  if (not player:IsSuperAdmin()) then
    return
  end

  local items = player._VersusContractItemsGiven or {}
  local itemKeys = {}

  -- Find the item keys for the given items
  for _, item in ipairs(items) do
    local itemKey = versus.inventory.getItemKey(player, item)

    if itemKey then
      table.insert(itemKeys, itemKey)
    end
  end

  PLUGIN.showRewardScreen(
    player,
    ("Extraction Successful"):upper(), -- Title
    "High Value Target Eliminated",    -- Subtitle
    itemKeys,                          -- Items table
    10000,                             -- XP gained
    5,                                 -- Current level
    40000,                             -- XP needed for next level
    25000                              -- Current XP
  )
end)

--[[
  Net Messages
--]]

net.Receive("versus.rewards.screenContinue", function(len, player)
  versus.contracts.forceReselectContract(player)
end)
