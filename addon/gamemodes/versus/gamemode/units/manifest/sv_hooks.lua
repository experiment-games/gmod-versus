local UNIT = UNIT

-- Initialize when the map is ready
function UNIT.hook:InitPostEntity()
  if (UNIT.isManifestLoadingServerConVar:GetBool()) then
    UNIT.initialize()
  end
end

-- Clean up spawned entities when the map is cleaned up
function UNIT.hook:PreCleanupMap()
  UNIT.clearSpawnedEntities()
end

-- Console command to reload the manifest
concommand.Add("versus_reload_manifest", function(ply, cmd, args)
  if (IsValid(ply) and not ply:IsAdmin()) then
    print("[Server Manifest] Only admins can reload the manifest")
    return
  end

  UNIT.reload()
end)

-- Console command to spawn entities without changing map
concommand.Add("versus_spawn_manifest_entities", function(ply, cmd, args)
  if (IsValid(ply) and not ply:IsAdmin()) then
    print("[Server Manifest] Only admins can spawn manifest entities")
    return
  end

  if (not UNIT.currentManifest) then
    print("[Server Manifest] No manifest loaded. Use versus_reload_manifest first.")
    return
  end

  UNIT.spawnManifestEntities(UNIT.currentManifest)
end)

-- Console command to clear spawned entities
concommand.Add("versus_clear_manifest_entities", function(ply, cmd, args)
  if (IsValid(ply) and not ply:IsAdmin()) then
    print("[Server Manifest] Only admins can clear manifest entities")
    return
  end

  UNIT.clearSpawnedEntities()
end)

-- Console command to show current manifest info
concommand.Add("versus_manifest_info", function(ply, cmd, args)
  if (not UNIT.currentManifest) then
    print("[Server Manifest] No manifest loaded")
    return
  end

  print("[Server Manifest] Current Manifest Info:")
  print("  Map: " .. (UNIT.currentManifest.map or "N/A"))
  print("  On Correct Map: " .. tostring(UNIT.isCorrectMap(UNIT.currentManifest)))
  print("  Entity Count: " .. (UNIT.currentManifest.entities and #UNIT.currentManifest.entities or 0))
  print("  Spawned Entities: " .. #UNIT.spawnedEntities)
end)
