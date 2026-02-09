local PLUGIN = PLUGIN
local NPC = PLUGIN.get("armoury") or {}

NPC.name = "Armoury"
NPC.description = "Buys and sells weapons and ammo."
NPC.model = "models/Humans/Group03/male_08.mdl"
NPC.bodygroups = {}
NPC.health = PLUGIN.NO_HEALTH

function NPC:onInteract(client, npcEntity)
  print("Interacted with Armoury NPC")
end

PLUGIN.registerNPC("armoury", NPC)
