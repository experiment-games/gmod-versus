local PLUGIN = PLUGIN

util.AddNetworkString("versus.rewards.showScreen")
util.AddNetworkString("versus.rewards.screenContinue")

--- Sync the player's XP and level to their client via networked variables
--- @param player Player to sync
function PLUGIN.syncProgressionToClient(player)
  player:SetNWInt("versus_XP", player:getCharacter("xp", 0))
  player:SetNWInt("versus_Level", player:getCharacter("level", 1))
end

--- Initialize player XP and level data if not already set
--- @param player Player to initialize
function PLUGIN.initializePlayerProgression(player)
  if not player:getCharacter("xp") then
    player:setCharacter("xp", 0, true)
  end

  if not player:getCharacter("level") then
    player:setCharacter("level", 1, true)
  end
end

--- Get the player's current XP
--- @param player Player to check
--- @return number Current XP
function PLUGIN.getPlayerXP(player)
  return player:getCharacter("xp", 0)
end

--- Get the player's current level
--- @param player Player to check
--- @return number Current level
function PLUGIN.getPlayerLevel(player)
  return player:getCharacter("level", 1)
end

--- Get the XP needed to reach the player's next level
--- @param player Player to check
--- @return number XP needed for next level
function PLUGIN.getXPToNextLevel(player)
  local currentLevel = PLUGIN.getPlayerLevel(player)
  local currentXP = PLUGIN.getPlayerXP(player)
  local xpForNextLevel = PLUGIN.getXPForLevel(currentLevel + 1)

  return xpForNextLevel - currentXP
end

--- Add XP to a player and handle level ups
--- @param player Player to give XP to
--- @param amount number Amount of XP to add
--- @return boolean Whether the player leveled up
function PLUGIN.addXP(player, amount)
  if amount <= 0 then return false end

  local oldLevel = player:getCharacter("level", 1)
  local newXP = player:getCharacter("xp", 0) + amount
  local newLevel = PLUGIN.getLevelFromXP(newXP)
  local leveledUp = newLevel > oldLevel

  player:setCharacter("xp", newXP)

  if leveledUp then
    player:setCharacter("level", newLevel)

    -- Call hook for other systems to respond
    hook.Run("PlayerLevelUp", player, oldLevel, newLevel)
  end

  PLUGIN.syncProgressionToClient(player)

  return leveledUp
end

--- Grant XP based on damage dealt to an NPC
--- @param player Player who dealt damage
--- @param damage number Amount of damage dealt
function PLUGIN.grantDamageXP(player, damage)
  -- Only grant XP if player has an active contract
  if not player._VersusCurrentContract then
    return
  end

  local xpAmount = math.floor(damage * PLUGIN.XP_PER_DAMAGE)

  if xpAmount > 0 then
    PLUGIN.addXP(player, xpAmount)
  end
end

--- Grant XP for killing an NPC
--- @param player Player who got the kill
--- @param npc NPC that was killed
function PLUGIN.grantKillXP(player, npc)
  -- Only grant XP if player has an active contract
  if not player._VersusCurrentContract then
    return
  end

  local xpAmount = PLUGIN.XP_PER_KILL

  PLUGIN.addXP(player, xpAmount)
end

--- Shows the reward screen to the player with the given data
--- @param player Player to show the reward screen to
--- @param title string Title to display on the reward screen
--- @param subtitle string Subtitle to display on the reward screen
--- @param itemKeys table Table of item keys to display as rewards
--- @param xpGained number Amount of XP gained to display
--- @param currentLevel number Current player level to display
--- @param xpToNextLevel number XP needed for next level to display
--- @param currentXP number Current XP to display
--- @param startLevel number Starting level before XP was gained
--- @param startXP number Starting XP before XP was gained
function PLUGIN.showRewardScreen(
    player,
    title,
    subtitle,
    itemKeys,
    xpGained,
    currentLevel,
    xpToNextLevel,
    currentXP,
    startLevel,
    startXP
)
  net.Start("versus.rewards.showScreen")
  net.WriteString(title)
  net.WriteString(subtitle)
  net.WriteUInt(#itemKeys, 16)
  for _, itemKey in ipairs(itemKeys) do
    net.WriteUInt(itemKey, versus.inventory.bitSizeItemKeys)
  end
  net.WriteUInt(xpGained, 32)
  net.WriteUInt(currentLevel, 32)
  net.WriteUInt(xpToNextLevel, 32)
  net.WriteUInt(currentXP, 32)
  net.WriteUInt(startLevel or currentLevel, 16)
  net.WriteUInt(startXP or (currentXP - xpGained), 32)
  net.Send(player)
end

--- Shows the reward screen for a contract completion, using the items given during the contract
--- Gets XP and level data automatically from the player's character data
--- @param player Player to show the reward screen to
--- @param title string Title to display on the reward screen
--- @param subtitle string Subtitle to display on the reward screen
function PLUGIN.showContractRewardScreen(player, title, subtitle)
  local items = player._VersusContractItemsGiven or {}
  local itemKeys = {}

  -- Find the item keys for the given items
  for _, item in ipairs(items) do
    local itemKey = versus.inventory.getItemKey(player, item)

    -- The item may already be used (e.g: ammo/health)
    if itemKey then
      table.insert(itemKeys, itemKey)
    end
  end

  -- Get current progression data from player
  local currentXP = PLUGIN.getPlayerXP(player)
  local currentLevel = PLUGIN.getPlayerLevel(player)
  local xpToNextLevel = PLUGIN.getXPToNextLevel(player)

  -- Calculate XP gained during this contract and starting values
  local startXP = player._VersusContractStartXP or currentXP
  local xpGained = currentXP - startXP
  local startLevel = PLUGIN.getLevelFromXP(startXP)

  PLUGIN.showRewardScreen(
    player,
    title,
    subtitle,
    itemKeys,
    xpGained,
    currentLevel,
    xpToNextLevel,
    currentXP,
    startLevel,
    startXP
  )
end

--[[
  Hooks
--]]

function PLUGIN.hook:VersusPlayerBuildExtraColumns(columnDefinitions)
  table.insert(columnDefinitions, "`xp` bigint(20) UNSIGNED NOT NULL DEFAULT 0")
  table.insert(columnDefinitions, "`level` int(11) UNSIGNED NOT NULL DEFAULT 1")
end

function PLUGIN.hook:VersusPlayerBuildSelectColumns(columns)
  table.insert(columns, "`xp`")
  table.insert(columns, "`level`")
end

function PLUGIN.hook:PlayerPreDataLoad(player)
  player:setCharacter("xp", 0)
  player:setCharacter("level", 1)
end

function PLUGIN.hook:PlayerDataLoading(player, result)
  if not result then return end

  player:setCharacter("xp", tonumber(result.xp) or 0, true)
  player:setCharacter("level", tonumber(result.level) or 1, true)

  PLUGIN.syncProgressionToClient(player)
end

function PLUGIN.hook:PlayerSelectedContract(player, preparedContract, contractID)
  player._VersusContractItemsGiven = {}

  -- Store the player's XP at the start of the contract for reward screen
  player._VersusContractStartXP = PLUGIN.getPlayerXP(player)
end

function PLUGIN.hook:PostEntityTakeDamage(entity, damageInfo, wasTaken)
  if not wasTaken then return end

  -- Only track damage to NPCs
  if not entity:IsNPC() then return end

  local attacker = damageInfo:GetAttacker()

  -- Only track damage from players
  if not IsValid(attacker) or not attacker:IsPlayer() then return end

  -- Grant XP for the damage (function checks for active contract)
  PLUGIN.grantDamageXP(attacker, damageInfo:GetDamage())
end

function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  -- Only track kills by players
  if not IsValid(attacker) or not attacker:IsPlayer() then return end

  -- Grant kill XP (function checks for active contract)
  PLUGIN.grantKillXP(attacker, npc)
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

function PLUGIN.hook:PlayerContractCompleted(player, contract)
  -- When a contract completes, grant a base amount of XP for completion. Then also multiply by the amount of contract
  -- items the player had at the end. They will be removed shortly after this.
  local baseXP = PLUGIN.XP_PER_CONTRACT
  local contractItemMultiplier = 1 -- Mutiply by 1 by default.

  local inventory = player:getCharacter("inventory")

  -- Each contract item doubles the XP reward, so 1 item = 2x XP, 2 items = 3x XP, etc.
  -- This encourages players to keep contract items until the end, not losing it to an interfering player.
  for key, item in pairs(inventory) do
    if item.category == "Contract" then
      contractItemMultiplier = contractItemMultiplier + 1
    end
  end

  local totalXP = baseXP * contractItemMultiplier

  PLUGIN.addXP(player, totalXP)
end

concommand.Add("versus_test_extraction_reward", function(player, cmd, args)
  if (not player:IsSuperAdmin()) then
    return
  end

  -- Add some test items to the player's inventory to show on the reward screen
  local testItems = {
    { class = "health_vial",                    quantity = 2 },
    { class = "#rare_barnacle_adhesive_sample", quantity = 1 },
  }

  player._VersusContractItemsGiven = {}

  for _, itemData in ipairs(testItems) do
    local itemKeys = versus.inventory.giveItem(player, itemData.class, itemData.quantity)

    for _, itemKey in ipairs(itemKeys) do
      local item = versus.inventory.getItem(player, itemKey)

      table.insert(player._VersusContractItemsGiven, item)
    end
  end

  -- Delay so items given are already available on client
  timer.Simple(1, function()
    PLUGIN.showContractRewardScreen(
      player,
      ("Extraction Successful"):upper(), -- Title
      "High Value Target Eliminated"     -- Subtitle
    )
  end)
end)

concommand.Add("versus_add_xp", function(player, cmd, args)
  if (not player:IsSuperAdmin()) then
    return
  end

  local amount = tonumber(args[1]) or 100

  -- Store state before adding XP
  local oldLevel = PLUGIN.getPlayerLevel(player)
  local oldXP = PLUGIN.getPlayerXP(player)

  -- Add the XP
  PLUGIN.addXP(player, amount)

  -- Get state after adding XP
  local newLevel = PLUGIN.getPlayerLevel(player)
  local currentXP = PLUGIN.getPlayerXP(player)
  local xpToNextLevel = PLUGIN.getXPToNextLevel(player)

  -- Show reward screen to visualize the XP gain and any level ups
  PLUGIN.showRewardScreen(
    player,
    "XP AWARDED",
    "Testing XP System",
    {}, -- No items
    amount,
    newLevel,
    xpToNextLevel,
    currentXP,
    oldLevel,
    oldXP
  )
end)

concommand.Add("versus_set_level", function(player, cmd, args)
  if (not player:IsSuperAdmin()) then
    return
  end

  local targetLevel = tonumber(args[1])

  if not targetLevel or targetLevel < 1 then
    versus.message.notify(player, "Usage: versus_set_level <level>", NOTIFY_GENERIC)
    return
  end

  local xpNeeded = PLUGIN.getXPForLevel(targetLevel)

  player:setCharacter("xp", xpNeeded)
  player:setCharacter("level", targetLevel)

  versus.message.notify(
    player,
    string.format("Set your level to %d (XP: %d)", targetLevel, xpNeeded),
    NOTIFY_GENERIC
  )
end)

--[[
  Net Messages
--]]

net.Receive("versus.rewards.screenContinue", function(len, player)
  versus.contracts.forceReselectContract(player)
end)
