local UNIT = UNIT

UNIT.currentManifest = nil
UNIT.spawnedEntities = {}

UNIT.isManifestLoadingServerConVar = CreateConVar(
  "versus_manifest_loading_server",
  "0",
  FCVAR_ARCHIVE,
  "Whether the server manifest should be loaded on server start"
)

-- Load the manifest from disk
function UNIT.loadManifest()
  local manifestPath = UNIT.manifestPath
  local manifestData = file.Read(manifestPath, "GAME")

  if (not manifestData) then
    ErrorNoHalt("[Server Manifest] Could not find manifest at: " .. manifestPath .. "\n")
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

-- Check if we're on the correct map
function UNIT.isCorrectMap(manifest)
  if (not manifest or not manifest.map) then
    return false
  end

  return string.lower(game.GetMap()) == string.lower(manifest.map)
end

-- Apply metadata to an entity
function UNIT.applyMetadata(entity, metadata)
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
function UNIT.spawnEntity(entityData)
  if (not entityData.class) then
    ErrorNoHalt("[Server Manifest] Entity data missing 'class' field\n")
    return nil
  end

  local entity = ents.Create(entityData.class)

  if (not IsValid(entity)) then
    ErrorNoHalt("[Server Manifest] Failed to create entity: " .. entityData.class .. "\n")
    return nil
  end

  -- Set position
  if (entityData.pos) then
    entity:SetPos(entityData.pos)
  end

  -- Set angles
  if (entityData.angle) then
    entity:SetAngles(entityData.angle)
  end

  -- Apply metadata before spawn
  if (entityData.metadata) then
    UNIT.applyMetadata(entity, entityData.metadata)
  end

  -- Spawn the entity
  entity:Spawn()
  entity:Activate()

  print("[Server Manifest] Spawned entity: " .. entityData.class .. " at " .. tostring(entity:GetPos()))

  return entity
end

-- Clear all spawned entities
function UNIT.clearSpawnedEntities()
  for _, entity in pairs(UNIT.spawnedEntities) do
    if (IsValid(entity)) then
      entity:Remove()
    end
  end

  UNIT.spawnedEntities = {}
  print("[Server Manifest] Cleared all spawned entities")
end

-- Spawn all entities from the manifest
function UNIT.spawnManifestEntities(manifest)
  if (not manifest or not manifest.entities) then
    print("[Server Manifest] No entities to spawn in manifest")
    return
  end

  UNIT.clearSpawnedEntities()

  local spawnCount = 0

  for i, entityData in ipairs(manifest.entities) do
    local entity = UNIT.spawnEntity(entityData)

    if (IsValid(entity)) then
      table.insert(UNIT.spawnedEntities, entity)
      spawnCount = spawnCount + 1
    end
  end

  print("[Server Manifest] Spawned " .. spawnCount .. " entities from manifest")
end

-- Apply the manifest to the server
function UNIT.applyManifest(manifest)
  if (not manifest) then
    ErrorNoHalt("[Server Manifest] Cannot apply nil manifest\n")
    return false
  end

  UNIT.currentManifest = manifest

  -- Check if we need to change maps
  if (not UNIT.isCorrectMap(manifest)) then
    print("[Server Manifest] Current map: " .. game.GetMap() .. ", required map: " .. manifest.map)
    print("[Server Manifest] Changing to map: " .. manifest.map)
    RunConsoleCommand("changelevel", manifest.map)
    return true
  end

  -- We're on the correct map, spawn entities
  print("[Server Manifest] On correct map, spawning entities...")
  UNIT.spawnManifestEntities(manifest)

  hook.Run("ServerManifestApplied", manifest)

  return true
end

-- Reload the manifest and reapply it
function UNIT.reload()
  print("[Server Manifest] Reloading manifest...")
  local manifest = UNIT.loadManifest()

  if (manifest) then
    return UNIT.applyManifest(manifest)
  end

  return false
end

-- Initialize the manifest system
function UNIT.initialize()
  print("[Server Manifest] Initializing...")

  local manifest = UNIT.loadManifest()

  if (manifest) then
    UNIT.applyManifest(manifest)
  else
    print("[Server Manifest] No manifest loaded, skipping initialization")
  end
end
