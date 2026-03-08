local PLUGIN = PLUGIN

PLUGIN.name = "Stealth"
PLUGIN.libraryKey = "stealth"
PLUGIN.description =
"Stealth camouflage and thermal vision equipment. Players can activate stealth with the C key when they have the camo equipped. NPCs react to noise and proximity, breaking stealth when the player gets too close or their footsteps are heard by a nearby enemy."

-- Distance (units) at which a stealthed player is detected by nearby NPCs simply by being close
PLUGIN.detectionRadius = 200

-- Distance (units) around a footstep within which a nearby NPC will hear it and break stealth.
-- Crouching suppresses footstep sounds in the engine entirely, so crouched players stay hidden.
PLUGIN.noiseDetectionRadius = 400

-- NW variable keys used to broadcast stealth / thermal states to all clients
PLUGIN.nwKeyStealthActive = "VersusStealthActive"
PLUGIN.nwKeyThermalActive = "VersusThermalActive"
