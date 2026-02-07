local PLUGIN = PLUGIN

PLUGIN.libraryKey = "extraction"

PLUGIN.name = "Extraction System"
PLUGIN.description = "Extraction shooter mechanics with extraction points, conditions to extract, and spawn points"

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("sv_hooks.lua")
