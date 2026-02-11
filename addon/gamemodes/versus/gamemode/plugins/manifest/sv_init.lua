local PLUGIN = PLUGIN

PLUGIN.currentManifest = nil
PLUGIN.spawnedEntities = {}

-- Load the manifest from disk
function PLUGIN:loadManifest()
  local manifestPath = self.manifestPath
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
function PLUGIN:isCorrectMap(manifest)
  if (not manifest or not manifest.map) then
    return false
  end

  return string.lower(game.GetMap()) == string.lower(manifest.map)
end

-- Apply metadata to an entity
function PLUGIN:applyMetadata(entity, metadata)
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
function PLUGIN:spawnEntity(entityData)
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
    self:applyMetadata(entity, entityData.metadata)
  end

  -- Spawn the entity
  entity:Spawn()
  entity:Activate()

  print("[Server Manifest] Spawned entity: " .. entityData.class .. " at " .. tostring(entity:GetPos()))

  return entity
end

-- Clear all spawned entities
function PLUGIN:clearSpawnedEntities()
  for _, entity in pairs(self.spawnedEntities) do
    if (IsValid(entity)) then
      entity:Remove()
    end
  end

  self.spawnedEntities = {}
  print("[Server Manifest] Cleared all spawned entities")
end

-- Spawn all entities from the manifest
function PLUGIN:spawnManifestEntities(manifest)
  if (not manifest or not manifest.entities) then
    print("[Server Manifest] No entities to spawn in manifest")
    return
  end

  self:clearSpawnedEntities()

  local spawnCount = 0

  for i, entityData in ipairs(manifest.entities) do
    local entity = self:spawnEntity(entityData)

    if (IsValid(entity)) then
      table.insert(self.spawnedEntities, entity)
      spawnCount = spawnCount + 1
    end
  end

  print("[Server Manifest] Spawned " .. spawnCount .. " entities from manifest")
end

-- Apply the manifest to the server
function PLUGIN:applyManifest(manifest)
  if (not manifest) then
    ErrorNoHalt("[Server Manifest] Cannot apply nil manifest\n")
    return false
  end

  self.currentManifest = manifest

  -- Check if we need to change maps
  if (not self:isCorrectMap(manifest)) then
    print("[Server Manifest] Current map: " .. game.GetMap() .. ", required map: " .. manifest.map)
    print("[Server Manifest] Changing to map: " .. manifest.map)
    RunConsoleCommand("changelevel", manifest.map)
    return true
  end

  -- We're on the correct map, spawn entities
  print("[Server Manifest] On correct map, spawning entities...")
  self:spawnManifestEntities(manifest)

  hook.Run("ServerManifestApplied", manifest)

  return true
end

-- Reload the manifest and reapply it
function PLUGIN:reload()
  print("[Server Manifest] Reloading manifest...")
  local manifest = self:loadManifest()

  if (manifest) then
    return self:applyManifest(manifest)
  end

  return false
end

-- Initialize the manifest system
function PLUGIN:initialize()
  print("[Server Manifest] Initializing...")

  local manifest = self:loadManifest()

  if (manifest) then
    self:applyManifest(manifest)
  else
    print("[Server Manifest] No manifest loaded, skipping initialization")
  end
end

-- Command goes past all entities and if they have VersusWritesToManifest, writes them to the manifest.
-- If VersusWritesToManifest is a table, the fields in the table are written to metadata (with Get[fieldkey])
function PLUGIN:generateManifestFromEntities()
  local manifest = {}
  manifest.map = game.GetMap()
  manifest.entities = {}

  for _, entity in pairs(ents.GetAll()) do
    if (not IsValid(entity) or entity.VersusWritesToManifest == nil) then
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
