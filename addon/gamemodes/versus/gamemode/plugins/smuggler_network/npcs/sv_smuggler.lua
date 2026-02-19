local PLUGIN = PLUGIN

local NPC = versus.npc.get("smuggler") or {}

NPC.name = "Smuggler"
NPC.description = "Runs a clandestine network of couriers. Ask about available routes."
NPC.model = "models/Humans/Group03/male_07.mdl"
NPC.bodygroups = {}
NPC.health = versus.npc.NO_HEALTH

function NPC:onInteract(player, npcEntity)
  PLUGIN.openMapUI(player)
end

versus.npc.registerNPC("smuggler", NPC)
