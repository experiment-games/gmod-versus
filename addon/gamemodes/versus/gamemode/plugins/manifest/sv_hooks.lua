local PLUGIN = PLUGIN

-- Initialize when the map is ready
function PLUGIN.hook:InitPostEntity()
  self:initialize()
end

-- Clean up spawned entities when the map is cleaned up
function PLUGIN.hook:PreCleanupMap()
  self:clearSpawnedEntities()
end

-- Console command to reload the manifest
concommand.Add("versus_reload_manifest", function(ply, cmd, args)
  if (IsValid(ply) and not ply:IsSuperAdmin()) then
    print("[Server Manifest] Only super admins can reload the manifest")
    return
  end

  PLUGIN:reload()
end)

-- Console command to spawn entities without changing map
concommand.Add("versus_spawn_manifest_entities", function(ply, cmd, args)
  if (IsValid(ply) and not ply:IsSuperAdmin()) then
    print("[Server Manifest] Only super admins can spawn manifest entities")
    return
  end

  if (not PLUGIN.currentManifest) then
    print("[Server Manifest] No manifest loaded. Use versus_reload_manifest first.")
    return
  end

  PLUGIN:spawnManifestEntities(PLUGIN.currentManifest)
end)

-- Console command to clear spawned entities
concommand.Add("versus_clear_manifest_entities", function(ply, cmd, args)
  if (IsValid(ply) and not ply:IsSuperAdmin()) then
    print("[Server Manifest] Only super admins can clear manifest entities")
    return
  end

  PLUGIN:clearSpawnedEntities()
end)

-- Console command to show current manifest info
concommand.Add("versus_manifest_info", function(ply, cmd, args)
  if (not PLUGIN.currentManifest) then
    print("[Server Manifest] No manifest loaded")
    return
  end

  print("[Server Manifest] Current Manifest Info:")
  print("  Map: " .. (PLUGIN.currentManifest.map or "N/A"))
  print("  On Correct Map: " .. tostring(PLUGIN:isCorrectMap(PLUGIN.currentManifest)))
  print("  Entity Count: " .. (PLUGIN.currentManifest.entities and #PLUGIN.currentManifest.entities or 0))
  print("  Spawned Entities: " .. #PLUGIN.spawnedEntities)
end)
