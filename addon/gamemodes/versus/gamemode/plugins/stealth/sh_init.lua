local PLUGIN = PLUGIN

PLUGIN.name = "Stealth"
PLUGIN.libraryKey = "stealth"
PLUGIN.description =
"Stealth camouflage and thermal vision equipment."

-- Distance (units) at which a stealthed player is detected by nearby NPCs simply by being close
PLUGIN.detectionRadius = 32

-- Distance (units) around a footstep within which a nearby NPC will hear it and break stealth.
PLUGIN.noiseDetectionRadius = 128

-- NW variable keys used to broadcast stealth / thermal states to all clients
PLUGIN.nwKeyStealthActive = "VersusStealthActive"
PLUGIN.nwKeyThermalActive = "VersusThermalActive"

-- Resource key for the battery that powers stealth camo and thermal vision
PLUGIN.batteryKey = "battery"

-- Battery drained per second while stealth camouflage is active
PLUGIN.batteryDrainRateStealth = 8

-- Battery drained per second while thermal vision is active
PLUGIN.batteryDrainRateThermal = 5

-- Define the battery resource (units are fully loaded before plugins run).
versus.resource.define(PLUGIN.batteryKey, {
  max = 100,
  rechargeRate = 6,
  rechargeDelay = 4,
})
