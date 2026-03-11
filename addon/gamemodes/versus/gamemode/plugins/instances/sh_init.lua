--[[
	An instancing system that allows entities to be visible only to specific players.
	By default, all players are in the global instance (nil).
	When a player is moved to a specific instance, they can only see entities that belong to that instance.

	Instances are identified by unique strings (typically SteamID64).
	Entities can belong to one instance at a time.
	Players can be in one instance at a time.

	Each instance can have an owner. When the owner disconnects, the instance is automatically destroyed.

	TODO: Prevent in-character chat
	TODO: Prevent server-side only EmitSounds from playing (only shared calls to EmitSound can be stopped by EntityEmitSound)
]]

local PLUGIN = PLUGIN

--- @class InstanceData
--- @field entities table<Entity, boolean> Entities belonging to this instance
--- @field players table<Player, boolean> Players in this instance
--- @field owner Player|nil The client that owns this instance

PLUGIN.libraryKey = "instance"

PLUGIN.instances = PLUGIN.instances or {}             -- instanceID -> InstanceData
PLUGIN.playerInstances = PLUGIN.playerInstances or {} -- Player -> instanceID
PLUGIN.entityInstances = PLUGIN.entityInstances or {} -- Entity -> instanceID
PLUGIN.instanceOwners = PLUGIN.instanceOwners or {}   -- instanceID -> Player (for quick lookup)

local function errorWithPrefix(msg)
  ErrorNoHalt("[Versus Instance Plugin] " .. msg .. "\n")
end

if (SERVER) then
  --- Gets all children of an entity recursively
  --- @param entity Entity
  --- @return table<Entity>
  local function getEntityChildren(entity)
    local children = {}

    if (not IsValid(entity)) then
      return children
    end

    -- Get direct children
    local directChildren = entity:GetChildren()

    for _, child in ipairs(directChildren) do
      if (IsValid(child)) then
        table.insert(children, child)
        -- Recursively get children of children
        local grandchildren = getEntityChildren(child)
        for _, grandchild in ipairs(grandchildren) do
          table.insert(children, grandchild)
        end
      end
    end

    return children
  end

  --- Common logic for adding entities to instances with networking
  --- @param entity Entity
  --- @param instanceID string
  --- @param isPlayer boolean
  local function addEntityToInstance(entity, instanceID, isPlayer)
    if (not IsValid(entity)) then
      errorWithPrefix("Attempted to add invalid entity to instance '" .. tostring(instanceID) .. "'\n")
      return false
    end

    -- Remove from previous instance if it exists
    local oldInstanceID = PLUGIN.entityInstances[entity] or PLUGIN.playerInstances[entity]
    if (oldInstanceID) then
      if (isPlayer) then
        PLUGIN.removePlayer(entity)
      else
        PLUGIN.removeEntity(entity)
      end
    end

    -- Create instance if it doesn't exist
    local instance = PLUGIN.createInstance(instanceID)

    -- Add entity to appropriate collection
    if (isPlayer) then
      instance.players[entity] = true
      PLUGIN.playerInstances[entity] = instanceID
    else
      instance.entities[entity] = true
      PLUGIN.entityInstances[entity] = instanceID
    end

    -- Network the entity's instance ID
    entity:SetNWString("InstanceID", instanceID)

    -- Needed for ShouldCollide to work
    entity._VersusInstanceOldCustomCollisionCheck = entity:GetCustomCollisionCheck()
    entity:SetCustomCollisionCheck(true)

    return true
  end

  --- Common logic for removing entities from instances
  --- @param entity Entity
  --- @param isPlayer boolean
  local function removeEntityFromInstance(entity, isPlayer)
    if (not IsValid(entity)) then
      return false
    end

    local instanceID
    if (isPlayer) then
      instanceID = PLUGIN.playerInstances[entity]
    else
      instanceID = PLUGIN.entityInstances[entity]
    end

    if (not instanceID) then
      return false
    end

    local instance = PLUGIN.instances[instanceID]
    if (instance) then
      if (isPlayer) then
        instance.players[entity] = nil
        PLUGIN.playerInstances[entity] = nil
      else
        instance.entities[entity] = nil
        PLUGIN.entityInstances[entity] = nil
      end
    end

    -- Clear networked instance ID
    entity:SetNWString("InstanceID", "")

    -- Restore collision check
    entity:SetCustomCollisionCheck(entity._VersusInstanceOldCustomCollisionCheck or false)

    return instanceID
  end

  --- Creates a new instance or returns existing one
  --- @param instanceID string
  --- @param owner Player|nil Optional owner of the instance
  --- @return InstanceData
  function PLUGIN.createInstance(instanceID, owner)
    if (not PLUGIN.instances[instanceID]) then
      PLUGIN.instances[instanceID] = {
        entities = {},
        players = {},
        owner = owner
      }

      -- Track ownership for quick lookup
      if (IsValid(owner)) then
        PLUGIN.instanceOwners[instanceID] = owner
      end
    end

    return PLUGIN.instances[instanceID]
  end

  --- Sets the owner of an instance
  --- @param instanceID string
  --- @param owner Player The new owner
  function PLUGIN.setInstanceOwner(instanceID, owner)
    if (not IsValid(owner)) then
      errorWithPrefix("Attempted to set invalid owner for instance '" .. tostring(instanceID) .. "'\n")
      return
    end

    local instance = PLUGIN.instances[instanceID]
    if (not instance) then
      errorWithPrefix("Attempted to set owner for non-existent instance '" ..
        tostring(instanceID) .. "'\n")
      return
    end

    local oldOwner = instance.owner
    instance.owner = owner
    PLUGIN.instanceOwners[instanceID] = owner

    hook.Run("InstanceOwnerChanged", instanceID, owner, oldOwner)
  end

  --- Gets the owner of an instance
  --- @param instanceID string
  --- @return Player|nil
  function PLUGIN.getInstanceOwner(instanceID)
    local instance = PLUGIN.instances[instanceID]
    return instance and instance.owner or nil
  end

  --- Checks if a player owns an instance
  --- @param client Player
  --- @param instanceID string
  --- @return boolean
  function PLUGIN.isInstanceOwner(client, instanceID)
    local instance = PLUGIN.instances[instanceID]
    return instance and instance.owner == client or false
  end

  --- Gets all instances owned by a player
  --- @param client Player
  --- @return table<string, InstanceData>
  function PLUGIN.getPlayerOwnedInstances(client)
    local ownedInstances = {}

    for instanceID, owner in pairs(PLUGIN.instanceOwners) do
      if (owner == client) then
        ownedInstances[instanceID] = PLUGIN.instances[instanceID]
      end
    end

    return ownedInstances
  end

  --- Adds an entity and its children to an instance
  --- @param entity Entity
  --- @param instanceID string
  --- @param includeChildren? boolean Optional, defaults to true
  function PLUGIN.addEntity(entity, instanceID, includeChildren)
    if (includeChildren == nil) then includeChildren = true end

    if (not addEntityToInstance(entity, instanceID, false)) then
      return
    end

    -- Add children to the same instance
    if (includeChildren) then
      local children = getEntityChildren(entity)
      for _, child in ipairs(children) do
        if (IsValid(child)) then
          addEntityToInstance(child, instanceID, false)
          hook.Run("EntityAddedToInstance", child, instanceID)
        end
      end
    end

    hook.Run("EntityAddedToInstance", entity, instanceID)
  end

  --- Removes an entity and its children from its instance
  --- @param entity Entity
  --- @param includeChildren? boolean Optional, defaults to true
  function PLUGIN.removeEntity(entity, includeChildren)
    if (includeChildren == nil) then includeChildren = true end

    -- Remove children first
    if (includeChildren) then
      local children = getEntityChildren(entity)
      for _, child in ipairs(children) do
        if (IsValid(child)) then
          local childInstanceID = removeEntityFromInstance(child, false)
          if (childInstanceID) then
            hook.Run("EntityRemovedFromInstance", child, childInstanceID)
          end
        end
      end
    end

    -- Remove the main entity
    local instanceID = removeEntityFromInstance(entity, false)
    if (instanceID) then
      hook.Run("EntityRemovedFromInstance", entity, instanceID)
    end
  end

  --- Adds a player to an instance
  --- ! Do not call this function in PlayerSpawn, Loadout or anything similar. Use timer.Simple(0, ...) to
  --- ! delay the call a frame. Otherwise the player's hands will not have been parented to the predicted
  --- ! viewmodel yet, causing the hands to be invisible.
  --- @param client Player
  --- @param instanceID? string Optional ID to identify the instance by, defaults to SteamID64
  function PLUGIN.addPlayer(client, instanceID)
    instanceID = instanceID or client:SteamID64()

    if (not addEntityToInstance(client, instanceID, true)) then
      return
    end

    hook.Run("PlayerAddedToInstance", client, instanceID)
  end

  --- Removes a player from their instance (returns them to global)
  --- @param client Player
  function PLUGIN.removePlayer(client)
    local instanceID = removeEntityFromInstance(client, true)
    if (instanceID) then
      hook.Run("PlayerRemovedFromInstance", client, instanceID)
    end
  end

  --- Gets the instance ID a player is in
  --- @param client Player
  --- @return string|nil
  function PLUGIN.getPlayerInstance(client)
    return PLUGIN.playerInstances[client]
  end

  --- Gets the instance ID an entity belongs to
  --- @param entity Entity
  --- @return string|nil
  function PLUGIN.getEntityInstance(entity)
    return PLUGIN.entityInstances[entity]
  end

  --- Checks if a player can see an entity based on instancing
  --- @param client Player
  --- @param entity Entity
  --- @return boolean
  function PLUGIN.canPlayerSeeEntity(client, entity)
    local playerInstance = PLUGIN.playerInstances[client]
    local entityInstance = PLUGIN.entityInstances[entity]

    -- If entity has no instance, it's visible to everyone (shared map entities)
    if (not entityInstance) then
      return true
    end

    -- If player has no instance but entity does, they can't see it
    if (not playerInstance and entityInstance) then
      return false
    end

    -- If they're in the same instance, they can see each other
    return playerInstance == entityInstance
  end

  --- Checks if a player can see another player based on instancing
  --- @param viewer Player
  --- @param target Player
  --- @return boolean
  function PLUGIN.canPlayerSeePlayer(viewer, target)
    local viewerInstance = PLUGIN.playerInstances[viewer]
    local targetInstance = PLUGIN.playerInstances[target]

    -- If neither are in an instance, they can see each other
    if (not viewerInstance and not targetInstance) then
      return true
    end

    -- If they're in the same instance, they can see each other
    return viewerInstance == targetInstance
  end

  --- Destroys an instance and removes all its entities and players
  --- @param instanceID string
  --- @param reason string|nil Optional reason for destruction
  function PLUGIN.destroyInstance(instanceID, reason)
    local instance = PLUGIN.instances[instanceID]
    if (not instance) then
      return
    end

    hook.Run("InstancePreDestroy", instanceID, reason or "manual")

    -- Remove all players from instance
    for client, _ in pairs(instance.players) do
      if (IsValid(client)) then
        PLUGIN.removePlayer(client)
      end
    end

    -- Remove all entities (this will also remove them from the world)
    for entity, _ in pairs(instance.entities) do
      if (IsValid(entity)) then
        PLUGIN.removeEntity(entity)
        entity:Remove()
      end
    end

    -- Clear ownership tracking
    PLUGIN.instanceOwners[instanceID] = nil

    -- Clear the instance
    PLUGIN.instances[instanceID] = nil

    hook.Run("InstanceDestroyed", instanceID, reason or "manual")
  end

  --- Gets all players in an instance
  --- @param instanceID string
  --- @return Player[]
  function PLUGIN.getPlayersInInstance(instanceID)
    local instance = PLUGIN.instances[instanceID]
    local players = {}

    for player, _ in pairs(instance and instance.players or {}) do
      table.insert(players, player)
    end

    return players
  end

  --- Gets all entities in the given instance
  --- @param instanceID string
  --- @return Entity[]
  function PLUGIN.getEntitiesInInstance(instanceID)
    local instance = PLUGIN.instances[instanceID]
    local entities = {}

    for entity, _ in pairs(instance and instance.entities or {}) do
      table.insert(entities, entity)
    end

    return entities
  end

  --- Gets all active instances
  --- @return table<string, InstanceData>
  function PLUGIN.getAllInstances()
    return PLUGIN.instances
  end

  --- Transfers ownership of an instance to another player
  --- @param instanceID string
  --- @param newOwner Player
  --- @param oldOwner Player|nil Optional verification of current owner
  function PLUGIN.transferInstanceOwnership(instanceID, newOwner, oldOwner)
    if (not IsValid(newOwner)) then
      errorWithPrefix("Attempted to transfer instance ownership to invalid player\n")
      return false
    end

    local instance = PLUGIN.instances[instanceID]
    if (not instance) then
      errorWithPrefix("Attempted to transfer ownership of non-existent instance '" ..
        tostring(instanceID) .. "'\n")
      return false
    end

    -- Verify current ownership if specified
    if (oldOwner and instance.owner ~= oldOwner) then
      errorWithPrefix("Instance ownership verification failed for '" .. tostring(instanceID) .. "'\n")
      return false
    end

    local previousOwner = instance.owner
    instance.owner = newOwner
    PLUGIN.instanceOwners[instanceID] = newOwner

    hook.Run("InstanceOwnershipTransferred", instanceID, newOwner, previousOwner)
    return true
  end

  -- Hook to handle when entities get parented
  hook.Add("EntitySetParent", "versusInstanceParentChild", function(child, parent)
    -- Validate entities
    if (not IsValid(child) or not IsValid(parent)) then
      return
    end

    -- Get the parent's instance
    local parentInstance = PLUGIN.getEntityInstance(parent)

    -- If parent is a player, check their instance instead
    if (parent:IsPlayer()) then
      parentInstance = PLUGIN.getPlayerInstance(parent)
    end

    -- Get the child's current instance
    local childInstance = PLUGIN.getEntityInstance(child)

    -- If parent has an instance and child doesn't match, move child to parent's instance
    if (parentInstance and parentInstance ~= childInstance) then
      -- Remove child from current instance first (if any)
      if (childInstance) then
        PLUGIN.removeEntity(child, false) -- Don't include children to avoid recursion
      end

      -- Add child to parent's instance (don't include children to avoid double-processing)
      PLUGIN.addEntity(child, parentInstance, false)

      -- Call hook for external systems
      hook.Run("EntityMovedToParentInstance", child, parent, parentInstance, childInstance)
    elseif (not parentInstance and childInstance) then
      -- If parent is not instanced but child is, remove child from instance
      PLUGIN.removeEntity(child, false)

      hook.Run("EntityRemovedFromParentInstance", child, parent, childInstance)
    end
  end)

  -- Hook to handle when entities lose their parent (via SetParent(nil) or parent removal)
  local function HandleOrphanedEntity(entity)
    if (not IsValid(entity)) then
      return
    end

    -- Check if this entity was in an instance and now has no parent
    local entityInstance = PLUGIN.getEntityInstance(entity)
    if (entityInstance and not IsValid(entity:GetParent())) then
      -- Entity is orphaned and in an instance - keep it in the instance
      -- This maintains consistency unless explicitly moved by other code
      return
    end
  end

  --[[
		Server hooks
	--]]

  -- Clean up when entities are removed
  hook.Add("EntityRemoved", "versusInstanceCleanup", function(entity)
    if (not IsValid(entity)) then
      return
    end

    -- Get all children of the removed entity
    local children = entity:GetChildren()
    for _, child in ipairs(children) do
      if (IsValid(child)) then
        -- Child will be automatically orphaned, but keep it in the same instance
        -- The existing EntityRemoved hook in your system will clean up if needed
        HandleOrphanedEntity(child)
      end
    end

    PLUGIN.removeEntity(entity)
  end)

  -- Clean up when players disconnect - destroy owned instances
  hook.Add("PlayerSaveDisconnect", "versusInstanceCleanup", function(client)
    -- Remove player from their current instance
    PLUGIN.removePlayer(client)

    -- Destroy all instances owned by this player
    local ownedInstances = PLUGIN.getPlayerOwnedInstances(client)

    for instanceID, _ in pairs(ownedInstances) do
      PLUGIN.destroyInstance(instanceID, "owner_disconnect")
    end
  end)


  -- Prevent players from hearing voice chat across instances
  hook.Add("PlayerCanHearPlayersVoice", "versusPreventHearingOtherInstancePlayers", function(listener, speaker)
    return PLUGIN.canPlayerSeePlayer(listener, speaker)
  end)

  -- Prevent physgun interactions across instances
  hook.Add("PhysgunPickup", "versusInstancePhysgunPickup", function(client, entity)
    if (not PLUGIN.canPlayerSeeEntity(client, entity)) then
      return false
    end
  end)

  -- Prevent gravgun interactions across instances
  hook.Add("GravGunOnPickedUp", "versusInstanceGravgunPickup", function(client, entity)
    if (not PLUGIN.canPlayerSeeEntity(client, entity)) then
      return false
    end
  end)

  hook.Add("GravGunPunt", "versusInstanceGravgunPunt", function(client, entity)
    if (not PLUGIN.canPlayerSeeEntity(client, entity)) then
      return false
    end
  end)

  -- Prevent damage across instances
  hook.Add("EntityTakeDamage", "versusInstanceDamage", function(target, dmgInfo)
    local attacker = dmgInfo:GetAttacker()

    if (IsValid(attacker) and attacker:IsPlayer()) then
      -- Get instances
      local attackerInstance = PLUGIN.getPlayerInstance(attacker)
      local targetInstance

      if (target:IsPlayer()) then
        targetInstance = PLUGIN.getPlayerInstance(target)
      else
        targetInstance = PLUGIN.getEntityInstance(target)
      end

      -- Allow damage if in same instance or no instances
      if (attackerInstance == targetInstance) then
        return
      end

      -- Allow damage between neighboring chunks
      if (hook.Run("ShouldInstanceBlockEntityDamage", attacker, target, attackerInstance, targetInstance) == false) then
        return
      end

      -- Block damage for all other cases
      return true
    end
  end)

  -- Prevent use interactions across instances
  hook.Add("PlayerUse", "versusInstancePlayerUse", function(client, entity)
    if (not PLUGIN.canPlayerSeeEntity(client, entity)) then
      return false
    end
  end)

  -- Prevent tool gun usage across instances
  hook.Add("CanTool", "versusInstanceCanTool", function(client, trace, tool)
    local entity = trace.Entity
    if (IsValid(entity) and not PLUGIN.canPlayerSeeEntity(client, entity)) then
      return false
    end
  end)

  -- Prevent duplicator interactions across instances
  hook.Add("CanDrive", "versusInstanceCanDrive", function(client, entity)
    if (not PLUGIN.canPlayerSeeEntity(client, entity)) then
      return false
    end
  end)

  -- Prevent property interactions across instances
  hook.Add("CanProperty", "versusInstanceCanProperty", function(client, property, entity)
    if (not PLUGIN.canPlayerSeeEntity(client, entity)) then
      return false
    end
  end)

  -- Commented, otherwise player:Give wont work
  -- -- Prevent right-click context menu interactions across instances
  -- hook.Add("PlayerCanPickupWeapon", "versusInstancePickupWeapon", function(client, weapon)
  -- 	if (not PLUGIN.canPlayerSeeEntity(client, weapon)) then
  -- 		return false
  -- 	end
  -- end)

  -- Prevent item pickup across instances (for dropped items)
  hook.Add("PlayerCanPickupItem", "versusInstancePickupItem", function(client, item)
    if (not PLUGIN.canPlayerSeeEntity(client, item)) then
      return false
    end
  end)

  -- Prevent vehicles from being entered across instances
  hook.Add("CanPlayerEnterVehicle", "versusInstanceEnterVehicle", function(client, vehicle, role)
    if (not PLUGIN.canPlayerSeeEntity(client, vehicle)) then
      return false
    end
  end)

  -- Prevent spawning entities in other instances
  hook.Add("PlayerSpawnedSENT", "versusInstanceSpawnedSENT", function(client, entity)
    -- Automatically add spawned entities to the player's instance
    local playerInstance = PLUGIN.getPlayerInstance(client)
    if (playerInstance) then
      PLUGIN.addEntity(entity, playerInstance)
    end
  end)

  hook.Add("PlayerSpawnedProp", "versusInstanceSpawnedProp", function(client, model, entity)
    -- Automatically add spawned props to the player's instance
    local playerInstance = PLUGIN.getPlayerInstance(client)
    if (playerInstance) then
      PLUGIN.addEntity(entity, playerInstance)
    end
  end)

  hook.Add("PlayerSpawnedNPC", "versusInstanceSpawnedNPC", function(client, entity)
    -- Automatically add spawned NPCs to the player's instance
    local playerInstance = PLUGIN.getPlayerInstance(client)
    if (playerInstance) then
      PLUGIN.addEntity(entity, playerInstance)
    end
  end)

  hook.Add("PlayerSpawnedVehicle", "versusInstanceSpawnedVehicle", function(client, entity)
    -- Automatically add spawned vehicles to the player's instance
    local playerInstance = PLUGIN.getPlayerInstance(client)
    if (playerInstance) then
      PLUGIN.addEntity(entity, playerInstance)
    end
  end)

  -- Prevent picking up objects with hands across instances.
  hook.Add("CanPlayerHoldObject", "versusInstanceHoldObject", function(client, object)
    if (not PLUGIN.canPlayerSeeEntity(client, object)) then
      return false
    end
  end)

  -- Ensure player/entity ragdolls are in the same instance as the player/entity that spawned them
  hook.Add("EntityRagdollCreated", "versusInstanceEntityRagdoll", function(entity, ragdoll)
    local ownerInstance = entity:IsPlayer()
        and PLUGIN.getPlayerInstance(entity)
        or PLUGIN.getEntityInstance(entity)

    if (ownerInstance) then
      PLUGIN.addEntity(ragdoll, ownerInstance)
    end
  end)
else
  --- Client-side function to get a player's instance using networked data
  --- @param client Player
  --- @return string|nil
  function PLUGIN.getPlayerInstance(client)
    if (not IsValid(client)) then
      return nil
    end

    local instanceID = client:GetNWString("InstanceID", "")
    return instanceID ~= "" and instanceID or nil
  end

  --- Client-side function to get an entity's instance using networked data
  --- @param entity Entity
  --- @return string|nil
  function PLUGIN.getEntityInstance(entity)
    if (not IsValid(entity)) then
      return nil
    end

    local instanceID = entity:GetNWString("InstanceID", "")
    return instanceID ~= "" and instanceID or nil
  end

  --- Shared function to check if a player can see an entity based on instancing
  --- @param client Player
  --- @param entity Entity
  --- @return boolean
  function PLUGIN.canPlayerSeeEntity(client, entity)
    local playerInstance = PLUGIN.getPlayerInstance(client)
    local entityInstance = PLUGIN.getEntityInstance(entity)

    -- If entity has no instance, it's visible to everyone (shared map entities)
    if (not entityInstance) then
      return true
    end

    -- If player has no instance but entity does, they can't see it
    if (not playerInstance and entityInstance) then
      return false
    end

    -- If they're in the same instance, they can see each other
    return playerInstance == entityInstance
  end

  --- Shared function to check if a player can see another player based on instancing
  --- @param viewer Player
  --- @param target Player
  --- @return boolean
  function PLUGIN.canPlayerSeePlayer(viewer, target)
    local viewerInstance = PLUGIN.getPlayerInstance(viewer)
    local targetInstance = PLUGIN.getPlayerInstance(target)

    -- If neither are in an instance, they can see each other
    if (not viewerInstance and not targetInstance) then
      return true
    end

    -- If they're in the same instance, they can see each other
    return viewerInstance == targetInstance
  end

  --- Client-side function to check if the local player can see another player
  --- @param target Player
  --- @return boolean
  function PLUGIN.canSeePlayer(target)
    local localPlayer = LocalPlayer()
    if (not IsValid(localPlayer) or not IsValid(target)) then
      return true
    end

    return PLUGIN.canPlayerSeePlayer(localPlayer, target)
  end

  --- Client-side function to check if the local player can see an entity
  --- @param entity Entity
  --- @return boolean
  function PLUGIN.canSeeEntity(entity)
    local localPlayer = LocalPlayer()
    if (not IsValid(localPlayer) or not IsValid(entity)) then
      return true
    end

    return PLUGIN.canPlayerSeeEntity(localPlayer, entity)
  end

  --[[
		Client hooks
	--]]

  -- Store entities that should be hidden due to instance mismatch
  PLUGIN.hiddenEntities = PLUGIN.hiddenEntities or {}
  local hiddenEntities = PLUGIN.hiddenEntities

  -- Store entities in PVS so not all entities have to be looped in PreRender
  PLUGIN.entitiesInPVS = PLUGIN.entitiesInPVS or {}
  local entitiesInPVS = PLUGIN.entitiesInPVS

  -- Track entities entering PVS
  hook.Add("NotifyShouldTransmit", "versusInstancePVSTracking", function(entity, shouldTransmit)
    if (shouldTransmit) then
      entitiesInPVS[entity] = true
    else
      entitiesInPVS[entity] = nil
      -- Clean up hidden entities when they leave PVS
      if (hiddenEntities[entity]) then
        hiddenEntities[entity] = nil
      end
    end
  end)

  -- Lookups since thse are used in hooks that are called often and this micro optimization helps
  local isValid = IsValid
  local localPlayerFunction = LocalPlayer
  local canSeeEntity = PLUGIN.canSeeEntity
  local canSeePlayer = PLUGIN.canSeePlayer

  -- Pre-render hook to hide entities from other instances
  hook.Add("PreRender", "versusInstanceVisibilityControl", function()
    local localPlayer = localPlayerFunction()

    if (not isValid(localPlayer)) then
      return
    end

    -- Process only entities in PVS
    for entity, _ in pairs(entitiesInPVS) do
      if (isValid(entity) and entity ~= localPlayer) then
        local shouldHide = false

        -- Check if entity should be visible to local player
        if (entity:IsPlayer()) then
          shouldHide = not canSeePlayer(entity)
        else
          shouldHide = not canSeeEntity(entity)
        end

        -- Allow overriding if the player can be seen. This could for example be used when using instances
        -- for chunks and you want to draw players in the bordering chunk with SetRenderOrigin.
        local shouldHideOverride = hook.Run("ShouldInstanceHideEntity", localPlayer, entity, shouldHide)

        if (shouldHideOverride ~= nil) then
          shouldHide = shouldHideOverride
        end

        local isCurrentlyHidden = hiddenEntities[entity]

        if (shouldHide and not isCurrentlyHidden) then
          -- Need to hide this entity
          entity._VersusOldNoDraw = entity:GetNoDraw()
          entity:SetNoDraw(true)
          hiddenEntities[entity] = true
        elseif (not shouldHide and isCurrentlyHidden) then
          -- Need to show this entity
          entity:SetNoDraw(entity._VersusOldNoDraw or false)
          entity._VersusOldNoDraw = nil
          hiddenEntities[entity] = nil
        end
      end
    end
  end)

  -- Clean up when entities are removed
  hook.Add("EntityRemoved", "versusInstanceVisibilityCleanup", function(entity)
    entitiesInPVS[entity] = nil

    if (hiddenEntities[entity]) then
      hiddenEntities[entity] = nil
    end
  end)

  -- Hide player names/overlays for players in different instances
  hook.Add("HUDDrawTargetID", "versusInstanceTargetID", function()
    local trace = localPlayerFunction():GetEyeTrace()
    local target = trace.Entity

    if (isValid(target) and target:IsPlayer()) then
      if (not canSeePlayer(target)) then
        return true -- Prevent drawing target ID
      end
    end
  end)

  -- Prevent sound from playing across instances
  hook.Add("EntityEmitSound", "versusInstanceEntitySound", function(data)
    local entity = data.Entity

    if (isValid(entity)) then
      local localPlayer = localPlayerFunction()

      if (isValid(localPlayer)) then
        -- If it's a player sound
        if (entity:IsPlayer()) then
          if (not canSeePlayer(entity)) then
            return false
          end
        else
          -- For entity sounds, check if we can see the entity
          if (not canSeeEntity(entity)) then
            return false
          end
        end
      end
    end
  end)

  -- Prevent client-side prediction errors for interactions
  hook.Add("CreateMove", "versusInstanceCreateMove", function(cmd)
    local localPlayer = localPlayerFunction()
    if (cmd:KeyDown(IN_USE)) then
      local trace = localPlayer:GetEyeTrace()
      local entity = trace.Entity

      if (isValid(entity) and not canSeeEntity(entity)) then
        cmd:RemoveKey(IN_USE)
      end
    end
  end)
end

--[[
	Shared hooks
--]]

-- Micro-optimize lookup (ShouldCollide hook is called very often)
local getEntityInstance = PLUGIN.getEntityInstance
local getPlayerInstance = PLUGIN.getPlayerInstance

-- Collision prevention across instances
hook.Add("ShouldCollide", "versusInstanceShouldCollide", function(ent1, ent2)
  -- If one is the world, return to have default behaviour
  if (not IsValid(ent1) or not IsValid(ent2)) then
    return
  end

  local inst1 = ent1:IsPlayer() and getPlayerInstance(ent1) or getEntityInstance(ent1)
  local inst2 = ent2:IsPlayer() and getPlayerInstance(ent2) or getEntityInstance(ent2)

  -- If neither is in an instance
  if (not inst1 and not inst2) then
    return
  end

  -- If the entity is not a player and it doesn't have an instance, it's in the global instance and should collide with everything
  -- Otherwise instanced player traces wouldn't hit the instance switcher for example (which is in the shared world)
  if (not ent1:IsPlayer() and not inst1) then
    return
  end

  if (not ent2:IsPlayer() and not inst2) then
    return
  end

  -- If they're in the same instance, allow collision
  if (inst1 and inst1 == inst2) then
    return
  end

  return false
end)

-- Shared trace filtering
hook.Add("PlayerTraceAttack", "versusInstanceTraceAttack", function(client, damageinfo, dir, trace)
  local attacker = damageinfo:GetAttacker()

  if (IsValid(attacker) and attacker:IsPlayer()) then
    if (attacker:IsPlayer()) then
      if (not PLUGIN.canPlayerSeePlayer(client, attacker)) then
        return true -- Block trace
      end
    else
      if (not PLUGIN.canPlayerSeeEntity(client, attacker)) then
        return true -- Block trace
      end
    end
  end
end)

--[[
	Commands
--]]

do
  local COMMAND = versus.command.define("instancegetid")
  COMMAND.description = "Get the instance ID of a player."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Player", "The player to get the instance ID of.")

  function COMMAND:onRun(player, target)
    local instanceID = PLUGIN.getPlayerInstance(target)

    if (not instanceID) then
      versus.message.notify(player, "Player is not in an instance.", NOTIFY_GENERIC)
      return
    end

    versus.message.notify(player, "Player's instance ID: " .. instanceID, NOTIFY_GENERIC)
  end
end
