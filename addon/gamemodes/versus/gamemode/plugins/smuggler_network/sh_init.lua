local PLUGIN = PLUGIN

PLUGIN.libraryKey = "smuggler"

-- Heat thresholds
PLUGIN.HEAT_COOL = 0
PLUGIN.HEAT_WARM = 26
PLUGIN.HEAT_HOT = 51
PLUGIN.HEAT_BURNED = 76
PLUGIN.HEAT_MAX = 100

-- Heat decays from full (100) to zero in 30 minutes of real time
PLUGIN.HEAT_DECAY_PER_SECOND = 100 / (30 * 60)

-- Default bribe cost parameters (can be overridden per node via bribeBaseCost / bribeCostMultiplier)
PLUGIN.BRIBE_BASE_COST = 100
PLUGIN.BRIBE_HEAT_COST_MULTIPLIER = 3

-- Seconds between periodic server-side run-completion checks
PLUGIN.RUN_CHECK_INTERVAL = 60

-- Fraction of risk that heat can add at maximum (40% at full heat)
PLUGIN.HEAT_RISK_CONTRIBUTION = 0.4

-- Rolls below effectiveRisk but above this fraction of it give a partial result
PLUGIN.PARTIAL_SUCCESS_THRESHOLD = 0.5

-- Partial successes pay out this fraction of the normal reward range
PLUGIN.PARTIAL_REWARD_FRACTION = 0.3

--[[
  Map and route registration system
--]]

-- Reset on each load since this is definition data, not runtime state.
PLUGIN.maps = {}

--- Registers a map with node positions for the smuggler network.
--- mapData fields: name (string), width (number), height (number), nodes (table[])
--- Each node: id (string), x (number), y (number), color (Color),
---            displayName (string, optional), canBribe (bool, optional)
--- @param mapID string
--- @param mapData table
function PLUGIN.registerMap(mapID, mapData)
  mapData.id = mapID
  mapData.routes = {}
  PLUGIN.maps[mapID] = mapData
end

--- Registers a route on the given map, connecting a sequence of nodes with lines.
--- routeData fields: name, description, duration, cost, baseRisk, reward{min,max},
---                   heatGainOnRun, nodes (ordered list of nodeIDs)
--- @param mapID string
--- @param routeID string
--- @param routeData table
function PLUGIN.registerRoute(mapID, routeID, routeData)
  local map = PLUGIN.maps[mapID]

  if (not map) then
    ErrorNoHaltWithStack("smuggler: registerRoute called for unknown map '" .. mapID .. "'\n")
    return
  end

  routeData.id = routeID
  routeData.mapID = mapID
  table.insert(map.routes, routeData)
end

--- Returns the map with the given ID, or nil.
--- @param mapID string
--- @return table?
function PLUGIN.getMap(mapID)
  return PLUGIN.maps[mapID]
end

--- Returns the node with the given ID from the given map, or nil.
--- @param mapID string
--- @param nodeID string
--- @return table?
function PLUGIN.getMapNode(mapID, nodeID)
  local map = PLUGIN.getMap(mapID)
  if (not map) then return nil end

  for _, node in ipairs(map.nodes or {}) do
    if (node.id == nodeID) then return node end
  end
end

--- Returns a flat list of all registered routes across all maps.
--- @return table[]
function PLUGIN.getAllRoutes()
  local routes = {}

  for _, map in pairs(PLUGIN.maps) do
    for _, route in ipairs(map.routes) do
      table.insert(routes, route)
    end
  end

  return routes
end

PLUGIN.runners = {
  {
    id = "rookie",
    name = "Rookie",
    description = "Cheap and willing, but shaky under pressure.",
    fee = 50,
    successModifier = 0.10,
    heatGainModifier = 1.0,
  },
  {
    id = "veteran",
    name = "Veteran",
    description = "Reliable and experienced. A solid choice for most runs.",
    fee = 200,
    successModifier = -0.10,
    heatGainModifier = 1.0,
  },
  {
    id = "fixer",
    name = "Fixer",
    description = "Expensive, but keeps things clean. Leaves less heat behind.",
    fee = 500,
    successModifier = -0.05,
    heatGainModifier = 0.5,
  },
}

--- Returns route data for the given ID by searching all maps, or nil if not found.
--- @param routeID string
--- @return table?
function PLUGIN.getRoute(routeID)
  for _, map in pairs(PLUGIN.maps) do
    for _, route in ipairs(map.routes) do
      if (route.id == routeID) then return route end
    end
  end
end

--- Returns runner data for the given ID, or nil if not found.
--- @param runnerID string
--- @return table?
function PLUGIN.getRunner(runnerID)
  for _, runner in ipairs(PLUGIN.runners) do
    if (runner.id == runnerID) then
      return runner
    end
  end
end

--- Returns a human-readable heat label for the given heat value.
--- @param heat number
--- @return string
function PLUGIN.getHeatLabel(heat)
  if (heat >= PLUGIN.HEAT_BURNED) then
    return "Burned"
  elseif (heat >= PLUGIN.HEAT_HOT) then
    return "Hot"
  elseif (heat >= PLUGIN.HEAT_WARM) then
    return "Warm"
  else
    return "Cool"
  end
end

--- Returns the heat colour for the given heat value.
--- @param heat number
--- @return Color
function PLUGIN.getHeatColor(heat)
  if (heat >= PLUGIN.HEAT_BURNED) then
    return Color(220, 50, 50)
  elseif (heat >= PLUGIN.HEAT_HOT) then
    return Color(220, 130, 40)
  elseif (heat >= PLUGIN.HEAT_WARM) then
    return Color(210, 200, 40)
  else
    return Color(70, 190, 90)
  end
end

--- Calculates the cost to bribe a node at the current heat level.
--- Uses node.bribeBaseCost and node.bribeCostMultiplier when set, falling back to the plugin defaults.
--- @param node table The bribeable node definition
--- @param heat number The current heat value for the route
--- @return number
function PLUGIN.calculateBribeCost(node, heat)
  local base = node.bribeBaseCost or PLUGIN.BRIBE_BASE_COST
  local multiplier = node.bribeCostMultiplier or PLUGIN.BRIBE_HEAT_COST_MULTIPLIER
  return math.floor(base + heat * multiplier)
end

--- Formats a duration in seconds as a human-readable string (e.g. "2h 30m").
--- @param seconds number
--- @return string
function PLUGIN.formatDuration(seconds)
  seconds = math.max(0, math.floor(seconds))

  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local remainingSeconds = seconds % 60

  if (hours > 0) then
    return hours .. "h " .. minutes .. "m"
  elseif (minutes > 0) then
    return minutes .. "m " .. remainingSeconds .. "s"
  else
    return remainingSeconds .. "s"
  end
end

versus.includePrefixed("sv_hooks.lua")

--[[
  Data definitions
--]]

PLUGIN.registerMap("city_network", {
  name = "City Network",
  width = 460,
  height = 320,
  nodes = {
    { id = "safe_house", x = 55, y = 270, color = Color(70, 190, 90), displayName = "Safe House" },
    { id = "backstreet", x = 130, y = 200, color = Color(80, 140, 220), displayName = "Backstreet" },
    { id = "checkpoint_alpha", x = 240, y = 140, color = Color(220, 80, 80), displayName = "Checkpoint α", canBribe = true, bribeActionLabel = "Bribe", bribeHeatReduction = 20, bribeBaseCost = 100, bribeCostMultiplier = 3 },
    { id = "dockside_gate", x = 375, y = 205, color = Color(220, 130, 40), displayName = "Dockside Gate", canBribe = true, bribeActionLabel = "Pay Hush Money to", bribeHeatReduction = 15, bribeBaseCost = 150, bribeCostMultiplier = 5 },
    { id = "city_center", x = 245, y = 265, color = Color(80, 140, 220), displayName = "City Center" },
    { id = "industrial_zone", x = 395, y = 295, color = Color(80, 140, 220), displayName = "Industrial" },
    { id = "northern_drop", x = 145, y = 65, color = Color(80, 140, 220), displayName = "Northern Drop" },
  },
})

PLUGIN.registerRoute("city_network", "ghost_run", {
  name = "Ghost Run",
  description = "A quiet hop through familiar backstreets. Low exposure, low reward.",
  duration = 2 * 3600,
  cost = 100,
  baseRisk = 0.15,
  reward = { min = 250, max = 400 },
  heatGainOnRun = 10,
  nodes = { "safe_house", "backstreet", "city_center" },
})

PLUGIN.registerRoute("city_network", "dock_shuffle", {
  name = "Dock Shuffle",
  description = "Moving goods through the busy docks. Someone always has their eye on you.",
  duration = 4 * 3600,
  cost = 200,
  baseRisk = 0.25,
  reward = { min = 500, max = 750 },
  heatGainOnRun = 15,
  nodes = { "safe_house", "city_center", "dockside_gate", "industrial_zone" },
})

PLUGIN.registerRoute("city_network", "midnight_express", {
  name = "Midnight Express",
  description = "A long haul across the city under the cover of darkness.",
  duration = 8 * 3600,
  cost = 350,
  baseRisk = 0.30,
  reward = { min = 900, max = 1300 },
  heatGainOnRun = 20,
  nodes = { "safe_house", "backstreet", "checkpoint_alpha", "northern_drop" },
})

PLUGIN.registerRoute("city_network", "contraband_convoy", {
  name = "Contraband Convoy",
  description = "High-value cargo moving under constant scrutiny. Handle with care.",
  duration = 12 * 3600,
  cost = 600,
  baseRisk = 0.35,
  reward = { min = 1500, max = 2200 },
  heatGainOnRun = 25,
  nodes = { "safe_house", "city_center", "checkpoint_alpha", "dockside_gate" },
})

PLUGIN.registerRoute("city_network", "the_long_game", {
  name = "The Long Game",
  description = "A complex city-wide operation. Maximum exposure, maximum payout.",
  duration = 24 * 3600,
  cost = 1000,
  baseRisk = 0.40,
  reward = { min = 3000, max = 5000 },
  heatGainOnRun = 30,
  nodes = { "safe_house", "backstreet", "checkpoint_alpha", "northern_drop", "dockside_gate", "industrial_zone" },
})
