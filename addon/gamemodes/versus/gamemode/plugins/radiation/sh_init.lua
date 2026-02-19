local PLUGIN = PLUGIN

PLUGIN.name = "Radiation System"
PLUGIN.libraryKey = "radiation"
PLUGIN.description =
"Radiation system for irradiated maps. Players accumulate radiation and cannot take contracts once they exceed a threshold."

-- Seconds between each +1 radiation unit on a radiated map
PLUGIN.accumulationRate = 30

-- Seconds between each -1 radiation unit on a non-radiated map server
PLUGIN.decontaminationRate = 60

-- Radiation level at which contracts are locked
PLUGIN.contractThreshold = 80

-- Maximum radiation level
PLUGIN.maxLevel = 100

--- Returns whether the current map is irradiated.
--- The radiation info entity sets the VersusRadiationMap global when it initialises.
--- @return boolean
function PLUGIN.mapIsRadiated()
  return GetGlobalBool("VersusRadiationMap", false)
end
