local PLUGIN = PLUGIN

-- Duration must match ENT.UnlockDuration in sh_versus_lootcrate_random.lua.
-- The 3D2D animation is rendered entirely by the entity's Draw method (driven by
-- the versus_UnlockStartTime NW var), so only the timing needs to be kept in sync.
local UNLOCK_DURATION = 1.5

--[[
  Net Messages
--]]

-- Server told us (the activating client) to start the animation for a specific crate.
-- We no longer show a full-screen panel; the 3D2D billboard on the crate is visible to
-- all nearby players via the entity's Draw method.  We just wait for the animation to
-- finish and then confirm to the server so it can open our inventory.
net.Receive("versus.lootcrate.beginUnlock", function()
  local crate = net.ReadEntity()

  -- Wait for the animation plus a brief hold, then notify the server.
  timer.Simple(UNLOCK_DURATION + 0.35, function()
    if (not IsValid(crate)) then
      return
    end

    net.Start("versus.lootcrate.unlockComplete")
    net.WriteEntity(crate)
    net.SendToServer()
  end)
end)
