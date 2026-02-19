local PLUGIN = PLUGIN

util.AddNetworkString("versus.smuggler.openMapUI")
util.AddNetworkString("versus.smuggler.syncData")
util.AddNetworkString("versus.smuggler.launchRun")
util.AddNetworkString("versus.smuggler.claimResult")
util.AddNetworkString("versus.smuggler.showResult")
util.AddNetworkString("versus.smuggler.bribeNode")

versus.includeDirectory(PLUGIN.fullPath .. "/npcs")

--- Returns (and lazily initialises) the player's persisted smuggler data table.
--- @param player Player
--- @return table
function PLUGIN.getPlayerData(player)
  local characterData = player:getCharacter("data")

  if (not characterData.smuggler) then
    characterData.smuggler = {
      routeHeat = {},
      heatTimestamps = {},
      activeRuns = {},
      completedRuns = {},
    }
  end

  return characterData.smuggler
end

--- Returns the current heat for a route after applying real-time decay.
--- @param player Player
--- @param routeID string
--- @return number
function PLUGIN.getRouteHeat(player, routeID)
  local smugglerData = PLUGIN.getPlayerData(player)
  local heat = smugglerData.routeHeat[routeID] or 0
  local lastUpdate = smugglerData.heatTimestamps[routeID] or os.time()
  local elapsed = os.time() - lastUpdate
  local decayAmount = elapsed * PLUGIN.HEAT_DECAY_PER_SECOND

  return math.max(0, heat - decayAmount)
end

--- Persists the heat value for a route, recording the current timestamp.
--- @param player Player
--- @param routeID string
--- @param heat number
function PLUGIN.setRouteHeat(player, routeID, heat)
  local smugglerData = PLUGIN.getPlayerData(player)
  smugglerData.routeHeat[routeID] = math.Clamp(heat, 0, PLUGIN.HEAT_MAX)
  smugglerData.heatTimestamps[routeID] = os.time()
end

--- Rolls the given loot table and returns a list of item IDs that were awarded.
--- Each entry is an independent roll: item is awarded when math.random() <= chance.
--- @param lootTable table A map of itemID → chance (0–1)
--- @return string[]
function PLUGIN.rollLootTable(lootTable)
  local awarded = {}

  for itemID, chance in pairs(lootTable) do
    if (math.random() <= chance) then
      table.insert(awarded, itemID)
    end
  end

  return awarded
end

--- Calculates the outcome of a completed run.
--- Returns outcome string ("success", "partial", or "burned") and the cash reward.
--- @param route table
--- @param runner table
--- @param heatAtLaunch number
--- @return string, number
function PLUGIN.calculateRunOutcome(route, runner, heatAtLaunch)
  -- Heat contributes up to HEAT_RISK_CONTRIBUTION additional risk at full heat (100).
  -- Risk is clamped to 5–95% so success is always at least possible.
  local effectiveRisk = route.baseRisk
      + (heatAtLaunch / PLUGIN.HEAT_MAX) * PLUGIN.HEAT_RISK_CONTRIBUTION
      + runner.successModifier

  effectiveRisk = math.Clamp(effectiveRisk, 0.05, 0.95)

  local roll = math.random()

  if (roll > effectiveRisk) then
    -- Full success: roll beat the risk entirely
    local cashReward = math.random(route.reward.min, route.reward.max)
    return "success", cashReward
  elseif (roll > effectiveRisk * PLUGIN.PARTIAL_SUCCESS_THRESHOLD) then
    -- Partial success: roll fell between 50% and 100% of effectiveRisk
    local cashReward = math.random(
      math.floor(route.reward.min * PLUGIN.PARTIAL_REWARD_FRACTION),
      math.floor(route.reward.max * PLUGIN.PARTIAL_REWARD_FRACTION)
    )
    return "partial", cashReward
  else
    -- Burned: roll fell below 50% of effectiveRisk, nothing recovered
    return "burned", 0
  end
end

--- Attempts to launch a smuggling run for the player.
--- Returns true on success, or false and an error message on failure.
--- @param player Player
--- @param routeID string
--- @param runnerID string
--- @return boolean, string?
function PLUGIN.launchRun(player, routeID, runnerID)
  local route = PLUGIN.getRoute(routeID)
  local runner = PLUGIN.getRunner(runnerID)

  if (not route or not runner) then
    return false, "Invalid route or runner."
  end

  local smugglerData = PLUGIN.getPlayerData(player)

  if (smugglerData.activeRuns[routeID]) then
    return false, "A run is already in progress on this route."
  end

  local heat = PLUGIN.getRouteHeat(player, routeID)

  if (heat >= PLUGIN.HEAT_BURNED) then
    return false, "This route is burned. Wait for it to cool down."
  end

  local totalCost = route.cost + runner.fee
  local canAfford, deficit = versus.finance.canAfford(player, totalCost)

  if (not canAfford) then
    return false, "You need another " .. versus.util.formatMoney(deficit) .. " to launch this run."
  end

  versus.finance.takeMoney(player, totalCost, "Smuggler run: " .. route.name)

  local startTime = os.time()
  local endTime = startTime + route.duration

  smugglerData.activeRuns[routeID] = {
    runnerID = runnerID,
    startTime = startTime,
    endTime = endTime,
    heatAtLaunch = heat,
  }

  local heatGain = route.heatGainOnRun * runner.heatGainModifier
  PLUGIN.setRouteHeat(player, routeID, heat + heatGain)

  return true
end

--- Checks all active runs for a player and queues results for completed ones.
--- @param player Player
function PLUGIN.checkRunCompletions(player)
  local smugglerData = PLUGIN.getPlayerData(player)
  local now = os.time()

  for routeID, runData in pairs(smugglerData.activeRuns) do
    if (now >= runData.endTime) then
      local route = PLUGIN.getRoute(routeID)
      local runner = PLUGIN.getRunner(runData.runnerID)

      if (route and runner) then
        local outcome, cashReward = PLUGIN.calculateRunOutcome(route, runner, runData.heatAtLaunch)

        local awardedItems = {}

        if (outcome == "success" and route.lootTable) then
          awardedItems = PLUGIN.rollLootTable(route.lootTable)
        end

        table.insert(smugglerData.completedRuns, {
          routeID = routeID,
          routeName = route.name,
          runnerID = runData.runnerID,
          runnerName = runner.name,
          outcome = outcome,
          cashReward = cashReward,
          awardedItems = awardedItems,
        })
      end

      smugglerData.activeRuns[routeID] = nil
    end
  end
end

--- Sends the current smuggler state to the player.
--- @param player Player
function PLUGIN.syncDataToPlayer(player)
  local smugglerData = PLUGIN.getPlayerData(player)
  local now = os.time()
  local routeHeats = {}

  for _, route in ipairs(PLUGIN.getAllRoutes()) do
    routeHeats[route.id] = PLUGIN.getRouteHeat(player, route.id)
  end

  local activeRunsList = {}

  for routeID, runData in pairs(smugglerData.activeRuns) do
    table.insert(activeRunsList, {
      routeID = routeID,
      runnerID = runData.runnerID,
      endTime = runData.endTime,
    })
  end

  net.Start("versus.smuggler.syncData")
  net.WriteTable({
    routeHeats = routeHeats,
    activeRuns = activeRunsList,
    pendingResults = #smugglerData.completedRuns,
    now = now,
  })
  net.Send(player)
end

--- Opens the smuggler map UI for the player.
--- @param player Player
function PLUGIN.openMapUI(player)
  PLUGIN.checkRunCompletions(player)
  PLUGIN.syncDataToPlayer(player)

  net.Start("versus.smuggler.openMapUI")
  net.Send(player)
end

--[[
  Net Messages
--]]

net.Receive("versus.smuggler.launchRun", function(len, player)
  local routeID = net.ReadString()
  local runnerID = net.ReadString()
  local success, errorMessage = PLUGIN.launchRun(player, routeID, runnerID)

  if (not success) then
    versus.message.notify(player, errorMessage, NOTIFY_ERROR)
    return
  end

  PLUGIN.syncDataToPlayer(player)
end)

net.Receive("versus.smuggler.claimResult", function(len, player)
  local smugglerData = PLUGIN.getPlayerData(player)

  if (#smugglerData.completedRuns == 0) then
    return
  end

  local result = table.remove(smugglerData.completedRuns, 1)

  if (result.cashReward > 0) then
    versus.finance.giveMoney(player, result.cashReward, "Smuggler run reward: " .. result.routeName)
  end

  local awardedItemKeys = {}

  for _, itemID in ipairs(result.awardedItems or {}) do
    local item = versus.item.createInstance(itemID)

    if (item) then
      local key = versus.inventory.giveItem(player, item)
      table.insert(awardedItemKeys, key)
    end
  end

  net.Start("versus.smuggler.showResult")
  net.WriteString(result.outcome)
  net.WriteString(result.routeName)
  net.WriteString(result.runnerName)
  net.WriteUInt(result.cashReward, 32)
  net.WriteUInt(#awardedItemKeys, 8)

  for _, key in ipairs(awardedItemKeys) do
    net.WriteUInt(key, versus.inventory.bitSizeItemKeys)
  end

  net.Send(player)

  PLUGIN.syncDataToPlayer(player)
end)

net.Receive("versus.smuggler.bribeNode", function(len, player)
  local routeID = net.ReadString()
  local nodeID = net.ReadString()
  local route = PLUGIN.getRoute(routeID)

  if (not route) then return end

  local node = PLUGIN.getMapNode(route.mapID, nodeID)

  if (not node or not node.canBribe) then return end

  -- Verify the node is part of this route
  local nodeOnRoute = false

  for _, nid in ipairs(route.nodes or {}) do
    if (nid == nodeID) then
      nodeOnRoute = true
      break
    end
  end

  if (not nodeOnRoute) then return end

  local currentHeat = PLUGIN.getRouteHeat(player, routeID)
  local bribeCost = PLUGIN.calculateBribeCost(node, currentHeat)
  local canAfford, deficit = versus.finance.canAfford(player, bribeCost)

  if (not canAfford) then
    versus.message.notify(
      player,
      "You need another " .. versus.util.formatMoney(deficit) .. " to bribe this checkpoint.",
      NOTIFY_ERROR
    )
    return
  end

  versus.finance.takeMoney(player, bribeCost, "Bribed " .. (node.displayName or nodeID) .. " on route: " .. route.name)
  PLUGIN.setRouteHeat(player, routeID, math.max(0, currentHeat - node.bribeHeatReduction))

  PLUGIN.syncDataToPlayer(player)
end)
