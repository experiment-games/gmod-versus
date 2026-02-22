local PLUGIN = PLUGIN

-- How long (in seconds) after the last monster dies before the camp's props
-- and loot crate are removed, giving players time to loot.
local CAMP_LINGER_DELAY = 5 * 60

function PLUGIN.hook:InitPostEntity()
  -- Give the map a moment to finish loading before reading spawn points.
  timer.Simple(3, function()
    PLUGIN.updateWorldCampSpawns()
  end)
end

function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  local instance = npc._VersusCampInstance

  if (not instance) then
    return
  end

  instance.killedNPCs = instance.killedNPCs + 1

  if (instance.killedNPCs < instance.totalNPCs) then
    return
  end

  -- All monsters cleared.  Remove the camp from the active list so the world
  -- spawner can replace it, but leave props and loot crate in place so players
  -- have time to loot before the area is cleaned up.
  for i, active in ipairs(PLUGIN.activeCamps) do
    if (active == instance) then
      table.remove(PLUGIN.activeCamps, i)
      break
    end
  end

  if (instance.isWorld) then
    timer.Simple(30, function()
      PLUGIN.updateWorldCampSpawns()
    end)
  end

  -- Linger delay: remove props and the loot crate after players have had
  -- time to collect rewards.
  timer.Simple(CAMP_LINGER_DELAY, function()
    for _, prop in ipairs(instance.spawnedProps) do
      if (IsValid(prop)) then
        prop:Remove()
      end
    end

    if (IsValid(instance.lootcrate)) then
      instance.lootcrate:Remove()
    end
  end)
end

--[[
  Console Commands
--]]

-- Admin command to draw where the camps are (debugoverlay) to find them easily
concommand.Add("versus_encounters_draw", function(ply, cmd, args)
  if (not IsValid(ply) or not ply:IsAdmin()) then
    return
  end

  for _, spawn in ipairs(PLUGIN.activeCamps) do
    debugoverlay.Box(spawn.position, Vector(-16, -16, 0), Vector(16, 16, 72), 30, Color(255, 0, 0))
  end
end)
