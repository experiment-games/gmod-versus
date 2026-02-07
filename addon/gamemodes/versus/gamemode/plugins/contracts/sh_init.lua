local PLUGIN = PLUGIN

PLUGIN.name = "Contracts System"
PLUGIN.description =
"Contracts for players to complete objectives for rewards. Interacts with the extraction plugin and rewards plugin."

PLUGIN.bitCountContractAmount = 5
PLUGIN.bitCountContractID = 32

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sv_hooks.lua")
