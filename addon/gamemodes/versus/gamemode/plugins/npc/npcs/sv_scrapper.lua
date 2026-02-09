local PLUGIN = PLUGIN
local NPC = PLUGIN.get("scrapper") or {}

NPC.name = "Scrapper"
NPC.description = "Buys unwanted items for cash."
NPC.model = "models/Humans/Group03/male_07.mdl"
NPC.bodygroups = {}
NPC.health = PLUGIN.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  PLUGIN.openNPCMenu(player, "versus_Scrapper")
end

PLUGIN.registerNPC("scrapper", NPC)
