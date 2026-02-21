local PLUGIN = PLUGIN

util.AddNetworkString("versus.lootcrate.beginUnlock")
util.AddNetworkString("versus.lootcrate.unlockComplete")

--- Spawns a loot crate entity at the specified position.
--- @param itemPool VersusItemInstance[]
--- @param position Vector
--- @param angle? Angle
--- @return Entity
function PLUGIN.makeLootCrate(itemPool, position, angle)
  local entity = ents.Create("versus_lootcrate_random")

  entity:SetItemPool(itemPool)
  entity:SetPos(position)
  entity:SetAngles(angle or Angle(0, 0, 0))
  entity:Spawn()

  return entity
end

function PLUGIN.spawnLootCrate(player, itemPool, position)
  if (not position) then
    position = player:GetEyeTraceNoCursor().HitPos

    position.z = position.z + 16
  end

  local toPlayer = (player:GetPos() - position):Angle()
  local rotatedToPlayer = Angle(0, toPlayer.y, 0)
  local entity = PLUGIN.makeLootCrate(itemPool, position, rotatedToPlayer)

  return entity
end

--[[
  Net Messages
--]]

-- Receive the "animation done" confirmation from a client and open their inventory.
-- Pending state (activator, fallback timer name) is stored on the crate entity itself
-- because ENT methods run outside the plugin loader and cannot access PLUGIN.
net.Receive("versus.lootcrate.unlockComplete", function(len, ply)
  local crate = net.ReadEntity()

  if (not IsValid(crate) or not IsValid(ply)) then
    return
  end

  -- Only honour the response from the player who opened this crate.
  if (crate._pendingActivator ~= ply) then
    return
  end

  timer.Remove(crate._unlockTimerName)
  crate._pendingActivator = nil
  crate._unlockTimerName  = nil
  crate._IsOpening        = false

  versus.inventory.openOrCreateNamedInventory(ply, crate:GetChestName(), crate, nil)
end)
