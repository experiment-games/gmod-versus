local NPC = {}

NPC.name = "Decontaminator"
NPC.description = "Removes radiation for a fee."
NPC.model = "models/Humans/Group03m/male_09.mdl"
NPC.bodygroups = {}
NPC.health = versus.npc.NO_HEALTH
NPC.voiceSet = {
  "vo/npc/male01/hi01.wav",
  "vo/npc/male01/hi02.wav",
  "vo/npc/male01/doingsomething.wav",
  "vo/npc/male01/excuseme01.wav",
}

function NPC:onInteract(player, npcEntity)
  versus.npc.openNPCMenu(player, "versus_Decontaminator")
end

versus.npc.registerNPC("decontaminator", NPC)
