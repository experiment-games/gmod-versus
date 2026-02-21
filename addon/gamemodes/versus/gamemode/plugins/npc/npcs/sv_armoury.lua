local PLUGIN = PLUGIN
local NPC = PLUGIN.get("armoury") or {}

NPC.name = "Armoury"
NPC.description = "Sells weapons and ammo."
NPC.model = "models/Humans/Group03/female_06.mdl"
NPC.bodygroups = {}
NPC.health = PLUGIN.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  PLUGIN.openNPCMenu(player, "versus_Shop", "armoury")
end

PLUGIN.registerNPC("armoury", NPC)
