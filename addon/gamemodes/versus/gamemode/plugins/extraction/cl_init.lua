local PLUGIN = PLUGIN

PLUGIN.localConditionsCompleted = PLUGIN.localConditionsCompleted or {}
PLUGIN.localExtractions = PLUGIN.localExtractions or {}

function PLUGIN:hasCompletedCondition(player, condition)
  return self.localConditionsCompleted[condition:EntIndex()] == true
end
