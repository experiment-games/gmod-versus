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
