local PLUGIN = PLUGIN

-- Fade out bodies after death and remove them after a certain time to prevent clutter and lag
function PLUGIN.hook:CreateClientsideRagdoll(entity, ragdoll)
  versus.util.decayEntity(ragdoll, 5)
end
