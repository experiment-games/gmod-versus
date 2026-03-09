local PLUGIN = PLUGIN

PLUGIN.currentManifest = nil
PLUGIN.spawnedEntities = {}

-- Load the manifest from disk (contains only map name)
function PLUGIN.loadManifest()
  local manifestPath = PLUGIN.manifestPath
  local manifestData = file.Read(manifestPath, "GAME")

  if (not manifestData) then
    return nil
  end

  local success, manifest = pcall(util.JSONToTable, manifestData)

  if (not success or not manifest) then
    ErrorNoHalt("[Server Manifest] Failed to parse manifest JSON: " .. tostring(manifest) .. "\n")
    return nil
  end

  print("[Server Manifest] Loaded manifest successfully")
  return manifest
end

-- Calculate match score between map name and file name based on common segments
function PLUGIN.calculateMapMatchScore(mapName, fileName)
  local score = 0

  -- Partial match based on common segments
  local mapSegments = string.Split(mapName, "_")
  local fileSegments = string.Split(fileName, "_")

  for _, mapSeg in ipairs(mapSegments) do
    for _, fileSeg in ipairs(fileSegments) do
      if mapSeg == fileSeg then
        score = score + 10
      end
    end
  end

  return score
end

-- Load map-specific data, trying exact match first, then best partial match
-- Returns the parsed map table, or nil if not found
function PLUGIN.loadMapData(mapName)
  if (not mapName) then
    ErrorNoHalt("[Server Manifest] Cannot load data for nil map name\n")
    return nil
  end

  -- Try exact map name first
  local exactPath = "data/versus/maps/" .. mapName .. ".json"
  local mapData = file.Read(exactPath, "GAME")

  if (mapData) then
    local success, mapTable = pcall(util.JSONToTable, mapData)

    if (not success or not mapTable) then
      ErrorNoHalt("[Server Manifest] Failed to parse map entity JSON: " .. tostring(mapTable) .. "\n")
      return nil
    end

    print("[Server Manifest] Loaded data for map: " .. mapName)
    return mapTable
  end

  -- Copy it from data_static/versus/maps_backups if it exists exactly, so we can restore
  -- from backup on production.
  local backupPath = "data_static/versus/maps_backups/" .. mapName .. ".json"

  if (file.Exists(backupPath, "GAME")) then
    local backupData = file.Read(backupPath, "GAME")

    if (backupData) then
      file.CreateDir("versus/maps")
      file.Write("versus/maps/" .. mapName .. ".json", backupData)
      print("[Server Manifest] Copied backup map data for " .. mapName .. " to data folder")
      return PLUGIN.loadMapData(mapName) -- Try loading again after copying
    end
  end

  -- Loop all files in the maps folder to find partial matches
  local files = file.Find("data/versus/maps/*.json", "GAME")
  local bestMatch = nil
  local bestScore = 0

  for _, fileName in ipairs(files) do
    local baseName = string.StripExtension(fileName)
    local score = PLUGIN.calculateMapMatchScore(mapName, baseName)

    if score > bestScore then
      bestScore = score
      bestMatch = fileName
    end
  end

  if bestMatch then
    mapData = file.Read("data/versus/maps/" .. bestMatch, "GAME")

    if (mapData) then
      local success, mapTable = pcall(util.JSONToTable, mapData)

      if (not success or not mapTable) then
        ErrorNoHalt("[Server Manifest] Failed to parse map entity JSON: " .. tostring(mapTable) .. "\n")
        return nil
      end

      print("[Server Manifest] Using best match for map data: " ..
        string.StripExtension(bestMatch) .. " (score: " .. bestScore .. ")")
      return mapTable
    end
  end

  print("[Server Manifest] No data found for map: " .. mapName)
  return nil
end

-- Load map-specific entity data, trying exact match first, then best partial match
-- Returns entities, convars (both may be nil)
function PLUGIN.loadMapEntities(mapName)
  local mapTable = PLUGIN.loadMapData(mapName)

  if (not mapTable) then
    return nil, nil
  end

  return mapTable.entities, mapTable.convars
end

-- Check if we're on the correct map
function PLUGIN.isCorrectMap(manifest)
  if (not manifest or not manifest.map) then
    return false
  end

  return string.lower(game.GetMap()) == string.lower(manifest.map)
end

-- Apply metadata to an entity
function PLUGIN.applyMetadata(entity, metadata)
  if (not metadata or not IsValid(entity)) then
    return
  end

  for key, value in pairs(metadata) do
    local setterName = "Set" .. key

    if (entity[setterName]) then
      entity[setterName](entity, value)
    else
      ErrorNoHalt("[Server Manifest] Entity of class " .. entity:GetClass() ..
        " does not have setter for metadata key '" .. key .. "'\n")
    end
  end
end

-- Spawn a single entity from manifest data
function PLUGIN.spawnEntity(entityData)
  if (not entityData.class) then
    ErrorNoHalt("[Server Manifest] Entity data missing 'class' field\n")
    return nil
  end

  local entity = ents.Create(entityData.class)

  if (not IsValid(entity)) then
    ErrorNoHalt("[Server Manifest] Failed to create entity: " .. entityData.class .. "\n")
    return nil
  end

  if (entityData.pos) then
    entity:SetPos(entityData.pos)
  end

  if (entityData.angle) then
    entity:SetAngles(entityData.angle)
  end

  if (entityData.model) then
    entity:SetModel(entityData.model)
  end

  if (entityData.skin) then
    entity:SetSkin(entityData.skin)
  end

  if (entityData.modelScale) then
    entity:SetModelScale(entityData.modelScale, 0)
  end

  if (entityData.metadata) then
    PLUGIN.applyMetadata(entity, entityData.metadata)
  end

  -- Spawn the entity
  entity:Spawn()
  entity:Activate()

  return entity
end

-- Clear all spawned entities
function PLUGIN.clearSpawnedEntities()
  for _, entity in pairs(PLUGIN.spawnedEntities) do
    if (IsValid(entity)) then
      entity:Remove()
    end
  end

  PLUGIN.spawnedEntities = {}
  print("[Server Manifest] Cleared all spawned entities")
end

-- Spawn all entities from entity data
function PLUGIN.spawnManifestEntities(entities)
  if (not entities or #entities == 0) then
    print("[Server Manifest] No entities to spawn")
    return
  end

  PLUGIN.clearSpawnedEntities()

  local spawnCount = 0

  for i, entityData in ipairs(entities) do
    local entity = PLUGIN.spawnEntity(entityData)

    if (IsValid(entity)) then
      table.insert(PLUGIN.spawnedEntities, entity)
      spawnCount = spawnCount + 1
    end
  end

  print("[Server Manifest] Spawned " .. spawnCount .. " entities")
end

-- Apply convars from the map manifest
function PLUGIN.applyMapConvars(convars)
  if (not convars or not istable(convars)) then
    return
  end

  for name, value in pairs(convars) do
    -- Only allow convar names that are safe identifiers (letters, numbers, underscores)
    if (not string.match(name, "^[%w_]+$")) then
      ErrorNoHalt("[Server Manifest] Skipping unsafe convar name: " .. tostring(name) .. "\n")
      continue
    end

    RunConsoleCommand(name, tostring(value))
    print("[Server Manifest] Set convar: " .. name .. " = " .. tostring(value))
  end
end

-- Apply the manifest to the server
function PLUGIN.applyManifest(manifest)
  if (not manifest) then
    ErrorNoHalt("[Server Manifest] Cannot apply nil manifest\n")
    return false
  end

  PLUGIN.currentManifest = manifest

  -- Check if we need to change maps
  if (not PLUGIN.isCorrectMap(manifest)) then
    print("[Server Manifest] Current map: " .. game.GetMap() .. ", required map: " .. manifest.map)
    print("[Server Manifest] Changing to map: " .. manifest.map)
    RunConsoleCommand("changelevel", manifest.map)
    return true
  end

  -- We're on the correct map, load and spawn entities
  print("[Server Manifest] On correct map, loading entities...")
  local entities, convars = PLUGIN.loadMapEntities(manifest.map)

  if (entities) then
    PLUGIN.spawnManifestEntities(entities)
  else
    print("[Server Manifest] No entities to spawn for this map")
  end

  PLUGIN.applyMapConvars(convars)

  hook.Run("ServerManifestApplied", manifest)

  return true
end

-- Write a manifest (map name only) to disk, scheduling a map change on next reboot.
function PLUGIN.writeManifest(map)
  if (not map or map == "") then
    ErrorNoHalt("[Server Manifest] Cannot write manifest with empty map name\n")
    return false
  end

  local manifest = { map = map }
  local manifestJSON = util.TableToJSON(manifest, true)

  file.CreateDir("versus")
  file.Write("versus/server_manifest.json", manifestJSON)

  print("[Server Manifest] Wrote next map to manifest: " .. map)
  return true
end

-- Reload the manifest and reapply it
function PLUGIN.reload()
  print("[Server Manifest] Reloading manifest...")
  local manifest = PLUGIN.loadManifest()

  if (manifest) then
    return PLUGIN.applyManifest(manifest)
  end

  return false
end

-- Initialize the manifest system
function PLUGIN.initialize()
  print("[Server Manifest] Initializing...")

  local manifest = PLUGIN.loadManifest()

  if (manifest) then
    -- If the manifest points to a different map, let applyManifest handle the changelevel.
    -- Entity loading will happen naturally on the next InitPostEntity after the level change.
    if (not PLUGIN.isCorrectMap(manifest)) then
      PLUGIN.applyManifest(manifest)
      return
    end

    PLUGIN.applyManifest(manifest)
  else
    -- No manifest, just load entities for the current map
    print("[Server Manifest] No manifest found, loading entities for current map...")
    local entities, convars = PLUGIN.loadMapEntities(game.GetMap())

    if (entities) then
      PLUGIN.spawnManifestEntities(entities)
    else
      print("[Server Manifest] No entity data found for current map")
    end

    PLUGIN.applyMapConvars(convars)
  end
end

-- Command goes past all entities and if they have VersusWritesToManifest, writes them to the manifest.
-- If VersusWritesToManifest is a table, the fields in the table are written to metadata (with Get[fieldkey])
-- convars is an optional table of { [convarName] = value } to include in the manifest.
function PLUGIN.generateManifestFromEntities(convars)
  local manifest = {}
  manifest.map = game.GetMap()
  manifest.entities = {}

  if (convars and istable(convars)) then
    manifest.convars = convars
  end

  for _, entity in ents.Iterator() do
    if (not IsValid(entity) or entity.VersusWritesToManifest == nil or entity:CreatedByMap()) then
      continue
    end

    local entityData = {}
    entityData.class = entity:GetClass()
    entityData.pos = entity:GetPos()
    entityData.angle = entity:GetAngles()
    entityData.model = entity:GetModel()
    entityData.skin = entity:GetSkin()
    entityData.modelScale = entity:GetModelScale()
    entityData.metadata = {}

    if (istable(entity.VersusWritesToManifest)) then
      for _, key in ipairs(entity.VersusWritesToManifest) do
        local getterName = "Get" .. key
        local getter = entity[getterName]

        if (getter) then
          entityData.metadata[key] = getter(entity)
        else
          ErrorNoHalt("[Server Manifest] Entity of class " .. entity:GetClass() ..
            " does not have getter for metadata key '" .. key .. "'\n")
        end
      end
    end

    table.insert(manifest.entities, entityData)
  end

  return manifest
end
