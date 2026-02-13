local PLUGIN = PLUGIN

-- Spawns the player at a location defined in the contract's locations table.
PLUGIN.registerContractPhaseKeyHandler("spawn", function(player, bag, data)
  local locationReference = data.location
  local entity = PLUGIN.getEntityFromReference(player, locationReference)

  if (IsValid(entity)) then
    player._VersusPreferedSpawnPoint = entity -- PlayerSelectSpawn will check for this and use it if available
    player:Spawn()
  else
    error(
      "Failed to find entity for contract phase spawn key with location reference: "
      .. util.TableToJSON(locationReference)
    )
  end
end)
