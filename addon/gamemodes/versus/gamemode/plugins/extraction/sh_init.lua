local PLUGIN = PLUGIN

PLUGIN.libraryKey = "extraction"

PLUGIN.name = "Extraction System"
PLUGIN.description = "Extraction shooter mechanics with extraction points, conditions to extract, and spawn points"

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

-- Check if a player has extracted
function PLUGIN.hasPlayerExtracted(player)
  return player:GetNWBool("versus_Extracted", false)
end
