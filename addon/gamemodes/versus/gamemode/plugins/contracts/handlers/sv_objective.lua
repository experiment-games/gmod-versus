local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("objective", function(player, bag, data)
  versus.objectives.setObjective(player, data.title, data.description)
end)
