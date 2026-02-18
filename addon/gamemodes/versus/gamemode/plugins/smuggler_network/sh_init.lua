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

-- Heat removed per successful bribe on a node
PLUGIN.BRIBE_HEAT_REDUCTION = 20

-- Bribe cost = BRIBE_BASE_COST + currentHeat * BRIBE_HEAT_COST_MULTIPLIER
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

PLUGIN.routes = {
  {
    id = "ghost_run",
    name = "Ghost Run",
    description = "A quiet hop through familiar backstreets. Low exposure, low reward.",
    duration = 2 * 3600,
    cost = 100,
    baseRisk = 0.15,
    reward = { min = 250, max = 400 },
    heatGainOnRun = 10,
  },
  {
    id = "dock_shuffle",
    name = "Dock Shuffle",
    description = "Moving goods through the busy docks. Someone always has their eye on you.",
    duration = 4 * 3600,
    cost = 200,
    baseRisk = 0.25,
    reward = { min = 500, max = 750 },
    heatGainOnRun = 15,
  },
  {
    id = "midnight_express",
    name = "Midnight Express",
    description = "A long haul across the city under the cover of darkness.",
    duration = 8 * 3600,
    cost = 350,
    baseRisk = 0.30,
    reward = { min = 900, max = 1300 },
    heatGainOnRun = 20,
  },
  {
    id = "contraband_convoy",
    name = "Contraband Convoy",
    description = "High-value cargo moving under constant scrutiny. Handle with care.",
    duration = 12 * 3600,
    cost = 600,
    baseRisk = 0.35,
    reward = { min = 1500, max = 2200 },
    heatGainOnRun = 25,
  },
  {
    id = "the_long_game",
    name = "The Long Game",
    description = "A complex city-wide operation. Maximum exposure, maximum payout.",
    duration = 24 * 3600,
    cost = 1000,
    baseRisk = 0.40,
    reward = { min = 3000, max = 5000 },
    heatGainOnRun = 30,
  },
}

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

--- Returns route data for the given ID, or nil if not found.
--- @param routeID string
--- @return table?
function PLUGIN.getRoute(routeID)
  for _, route in ipairs(PLUGIN.routes) do
    if(route.id == routeID)then
      return route
    end
  end
end

--- Returns runner data for the given ID, or nil if not found.
--- @param runnerID string
--- @return table?
function PLUGIN.getRunner(runnerID)
  for _, runner in ipairs(PLUGIN.runners) do
    if(runner.id == runnerID)then
      return runner
    end
  end
end

--- Returns a human-readable heat label for the given heat value.
--- @param heat number
--- @return string
function PLUGIN.getHeatLabel(heat)
  if(heat >= PLUGIN.HEAT_BURNED)then
    return "Burned"
  elseif(heat >= PLUGIN.HEAT_HOT)then
    return "Hot"
  elseif(heat >= PLUGIN.HEAT_WARM)then
    return "Warm"
  else
    return "Cool"
  end
end

--- Returns the heat colour for the given heat value.
--- @param heat number
--- @return Color
function PLUGIN.getHeatColor(heat)
  if(heat >= PLUGIN.HEAT_BURNED)then
    return Color(220, 50, 50)
  elseif(heat >= PLUGIN.HEAT_HOT)then
    return Color(220, 130, 40)
  elseif(heat >= PLUGIN.HEAT_WARM)then
    return Color(210, 200, 40)
  else
    return Color(70, 190, 90)
  end
end

--- Calculates the cost to bribe a contact on the given route at the current heat level.
--- @param heat number The current heat value for the route
--- @return number
function PLUGIN.calculateBribeCost(heat)
  return math.floor(PLUGIN.BRIBE_BASE_COST + heat * PLUGIN.BRIBE_HEAT_COST_MULTIPLIER)
end

--- Formats a duration in seconds as a human-readable string (e.g. "2h 30m").
--- @param seconds number
--- @return string
function PLUGIN.formatDuration(seconds)
  seconds = math.max(0, math.floor(seconds))

  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local remainingSeconds = seconds % 60

  if(hours > 0)then
    return hours .. "h " .. minutes .. "m"
  elseif(minutes > 0)then
    return minutes .. "m " .. remainingSeconds .. "s"
  else
    return remainingSeconds .. "s"
  end
end

versus.includePrefixed("sv_hooks.lua")
