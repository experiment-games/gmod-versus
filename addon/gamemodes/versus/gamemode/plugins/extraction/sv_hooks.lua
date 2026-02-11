local PLUGIN = PLUGIN

-- Prevent respawning after extraction
function PLUGIN.hook:PlayerDeathThink(player)
  if (self.hasPlayerExtracted(player)) then
    return false
  end
end

-- Clean up on death
function PLUGIN.hook:PlayerDeath(player)
  -- Cancel any ongoing extraction
  if (player._extractionTimer) then
    timer.Remove(player._extractionTimer)
    player._extractionTimer = nil
  end
end

-- Clean up on disconnect
function PLUGIN.hook:PlayerDisconnected(player)
  if (player._extractionTimer) then
    timer.Remove(player._extractionTimer)
  end
end
