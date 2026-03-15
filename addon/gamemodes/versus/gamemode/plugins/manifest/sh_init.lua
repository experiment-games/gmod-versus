local PLUGIN = PLUGIN

PLUGIN.libraryKey = "manifest"
PLUGIN.manifestPath = "data/versus/server_manifest.json"

versus.includePrefixed("sv_hooks.lua")
versus.includePrefixed("sh_commands.lua")
