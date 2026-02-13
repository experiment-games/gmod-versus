local PLUGIN = PLUGIN

util.AddNetworkString("versus.contracts.receiveContracts")
util.AddNetworkString("versus.combat.showServerSelectionScreen")

PLUGIN.contracts = PLUGIN.contracts or {}
PLUGIN.contractFunctions = PLUGIN.contractFunctions or {}
PLUGIN.contractPhaseKeyHandlers = PLUGIN.contractPhaseKeyHandlers or {}
PLUGIN.activeContractInstances = PLUGIN.activeContractInstances or {}

PLUGIN.EXACT = 0
PLUGIN.NEAR_TO_LOCATION = 1
PLUGIN.FAR_FROM_LOCATION = 2

--- Creates a location definition for use in the contract's "locations" table.
--- @param class string The entity class to search for
--- @param tag any The tag of the specific entity to find (can be nil for random selection)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @param displayName? string Optional. The display name for this location in the UI. Defaults to "Objective".
--- @return table # A location definition table
function PLUGIN.defineLocation(class, tag, hidden, displayName)
  return {
    class = class,
    tag = tag,
    hidden = hidden or false,
    displayName = displayName or "Objective",
  }
end

--- Creates a relative location definition that will be resolved based on another location.
--- @param class string The entity class to search for
--- @param relativeToKey string The key of the location this should be relative to
--- @param distance number Distance modifier (NEAR_TO_LOCATION or FAR_FROM_LOCATION)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @param displayName? string Optional. The display name for this location in the UI. Defaults to "Objective".
--- @return table # A relative location definition table
function PLUGIN.defineRelativeLocation(class, relativeToKey, distance, hidden, displayName)
  return {
    class = class,
    relativeToKey = relativeToKey,
    distance = distance,
    hidden = hidden or false,
    displayName = displayName or "Objective",
  }
end

--- References a location from the contract's locations table.
--- @param locationKey string The key of the location in the contract's locations table
--- @param distance number Optional distance modifier (EXACT, NEAR_TO_LOCATION, or FAR_FROM_LOCATION). Defaults to EXACT.
--- @return table # A location reference table
function PLUGIN.referToContractLocation(locationKey, distance)
  distance = distance or PLUGIN.EXACT

  return {
    locationKey = locationKey,
    distance = distance,
  }
end

--- Gets the display name for a location from a player's prepared contract.
--- @param player Player The player whose contract to check
--- @param locationKey string The key of the location to get the display name for
--- @return string # The display name for the location, or "Objective" if not found
function PLUGIN.getLocationDisplayName(player, locationKey)
  if not player._VersusAvailableContracts then return "Objective" end

  local contractID = player._VersusCurrentContract and player._VersusCurrentContract.id
  if not contractID then return "Objective" end

  local preparedContract = player._VersusAvailableContracts[contractID]
  if not preparedContract or not preparedContract.locations then return "Objective" end

  local location = preparedContract.locations[locationKey]
  if not location then return "Objective" end

  return location.displayName or "Objective"
end

--- Registers a contract so it can be assigned to a player and they can move
--- through its phases.
--- @param contractID string Unique identifier for the contract. Used when assigning the contract to a player.
--- @param contractTable table The contract definition table. Should contain a "locations" key (a table of named location definitions) and a "phases" key (a list of phases that the player will progress through).
function PLUGIN.register(contractID, contractTable)
  contractTable.id = contractID
  PLUGIN.contracts[contractID] = contractTable
end

--- Gets a contract definition table by its ID.
--- @param contractID string Unique identifier for the contract.
--- @return table The contract definition table, or nil if no contract with the given ID exists.
function PLUGIN.getContract(contractID)
  return PLUGIN.contracts[contractID]
end

--- Registers a contract phase key handler. Contract phases have various keys with data. When a player progresses to a new phase, the contract system
--- goes through all these keys and handles them accordingly. For example, if a phase has assigned
--- a "spawnWaves" key, the contract system will spawn the defined enemy waves. This function allows you to define custom keys and how the contract system should handle them.
--- @param key string The name of the key to handle. For example, "spawnWaves".
--- @param handlerFunction fun(player: Player, bag: table, data: table) A function that takes in the player and the key's data, and handles it accordingly. This function will be called whenever a player progresses to a new contract phase that contains the specified key.
function PLUGIN.registerContractPhaseKeyHandler(key, handlerFunction)
  PLUGIN.contractPhaseKeyHandlers[key] = handlerFunction
end

--- Gets a contract phase key handler function by the key name.
--- @param key string The name of the key to handle. For example, "spawnWaves".
--- @return fun(player: Player, bag: table, data: table)? # The handler function for the specified key, or nil if no handler is registered for that key.
function PLUGIN.getContractPhaseKeyHandler(key)
  return PLUGIN.contractPhaseKeyHandlers[key]
end

--- Registers a contract function that can be used in contract phase definitions (e.g: in the "completeCallback" key to check for phase completion).
--- @param funcID string Unique identifier for the function. This is what you will reference in the contract phase definitions.
--- @param func fun(player: Player, bag: table, ...: any):(any?) The function that implements the desired behavior. This can take any arguments you want, but typically the first argument will be the player and the rest will be defined by the contract phase.
function PLUGIN.registerContractFunction(funcID, func)
  PLUGIN.contractFunctions[funcID] = func
end

--- Gets a registered contract function by its ID.
--- @param funcID string Unique identifier for the function.
--- @return fun(player: Player, bag: table, ...: any):(any?)? # The registered function, or nil if no function is registered with the given ID.
function PLUGIN.getContractFunction(funcID)
  return PLUGIN.contractFunctions[funcID]
end

--- Checks if a phase is interferable (has first/subsequent structure).
--- @param phase table The phase definition table
--- @return boolean # True if the phase has first/subsequent structure, false otherwise
function PLUGIN.isPhaseInterferable(phase)
  return phase.first ~= nil and phase.subsequent ~= nil
end

--- Gets the appropriate sub-phase based on the player's role.
--- @param phase table The phase definition table
--- @param role string The player's role ("first" or "subsequent")
--- @return table # The phase data for the given role, or the original phase if not interferable
function PLUGIN.getPhaseForRole(phase, role)
  if not PLUGIN.isPhaseInterferable(phase) then
    return phase
  end

  return phase[role] or phase
end

--- Creates a timer that will be automatically cleaned up when the phase ends or contract fails.
--- @param player Player The player whose contract this timer belongs to
--- @param bag table The contract instance bag
--- @param name string Unique name for this timer within the phase
--- @param delay number Delay between timer calls
--- @param repetitions number Number of repetitions (0 for infinite)
--- @param callback function Function to call on timer tick
--- @return string # The full timer name
function PLUGIN.createPhaseTimer(player, bag, name, delay, repetitions, callback)
  bag.phase.timers = bag.phase.timers or {}

  local fullTimerName = "versus.contract." .. player:SteamID() .. ".phase." .. name

  -- Store the timer name for cleanup
  table.insert(bag.phase.timers, fullTimerName)

  timer.Create(fullTimerName, delay, repetitions, function()
    if not IsValid(player) then
      timer.Remove(fullTimerName)
      return
    end

    callback()
  end)

  return fullTimerName
end

--- Creates a simple delayed timer that will be automatically cleaned up when the phase ends or contract fails.
--- @param player Player The player whose contract this timer belongs to
--- @param bag table The contract instance bag
--- @param name string Unique name for this timer within the phase
--- @param delay number Delay before calling the callback
--- @param callback function Function to call after delay
--- @return string # The full timer name
function PLUGIN.createPhaseTimerSimple(player, bag, name, delay, callback)
  bag.phase.timers = bag.phase.timers or {}

  local fullTimerName = "versus.contract." .. player:SteamID() .. ".phase." .. name

  -- Store the timer name for cleanup
  table.insert(bag.phase.timers, fullTimerName)

  timer.Create(fullTimerName, delay, 1, function()
    if not IsValid(player) then
      timer.Remove(fullTimerName)
      return
    end

    callback()
  end)

  return fullTimerName
end

--- Creates a timer that will be automatically cleaned up when the contract ends or fails.
--- @param player Player The player whose contract this timer belongs to
--- @param bag table The contract instance bag
--- @param name string Unique name for this timer within the contract
--- @param delay number Delay between timer calls
--- @param repetitions number Number of repetitions (0 for infinite)
--- @param callback function Function to call on timer tick
--- @return string # The full timer name
function PLUGIN.createContractTimer(player, bag, name, delay, repetitions, callback)
  bag.contract.timers = bag.contract.timers or {}

  local fullTimerName = "versus.contract." .. player:SteamID() .. ".contract." .. name

  -- Store the timer name for cleanup
  table.insert(bag.contract.timers, fullTimerName)

  timer.Create(fullTimerName, delay, repetitions, function()
    if not IsValid(player) then
      timer.Remove(fullTimerName)
      return
    end

    callback()
  end)

  return fullTimerName
end

--- Cleans up all phase-specific resources (timers, objectives, indicators, etc.)
--- @param player Player The player whose phase to clean up
--- @param bag table The contract instance bag
function PLUGIN.cleanupPhase(player, bag)
  if not bag or not bag.phase then return end

  -- Remove all phase timers
  if bag.phase.timers then
    for _, timerName in ipairs(bag.phase.timers) do
      timer.Remove(timerName)
    end
    bag.phase.timers = nil
  end

  -- Clear proximity requirement
  versus.objectives.removeObjectiveRadiusRender(player, "phaseProximity")

  -- Clear objective timer (progress bars)
  versus.objectives.clearObjectiveTimer(player)

  -- Clear indicators
  versus.indicator.removeAll(player)

  -- Clear any entity interactions set during this phase
  if bag.phase.entities then
    for _, entity in ipairs(bag.phase.entities) do
      if IsValid(entity) and entity.ClearInteractionCallback then
        entity:ClearInteractionCallback(player)
      end
    end
    bag.phase.entities = nil
  end
end

--- Cleans up all contract-specific resources
--- @param player Player The player whose contract to clean up
--- @param bag table The contract instance bag
function PLUGIN.cleanupContract(player, bag)
  if not bag or not bag.contract then return end

  -- Remove all contract timers
  if bag.contract.timers then
    for _, timerName in ipairs(bag.contract.timers) do
      timer.Remove(timerName)
    end
    bag.contract.timers = nil
  end

  -- Clear objectives
  versus.objectives.clearObjective(player)

  -- Clean up any spawned NPCs that are tracked
  if bag.contract.spawnedNPCs then
    for _, npc in ipairs(bag.contract.spawnedNPCs) do
      if IsValid(npc) then
        npc:Remove()
      end
    end
    bag.contract.spawnedNPCs = nil
  end

  -- Clear any contract-wide entity interactions
  if bag.contract.entities then
    for _, entity in ipairs(bag.contract.entities) do
      if IsValid(entity) and entity.ClearInteractionCallback then
        entity:ClearInteractionCallback(player)
      end
    end
    bag.contract.entities = nil
  end
end

--- Registers an entity as being used by the current phase
--- @param player Player The player whose contract this entity belongs to
--- @param bag table The contract instance bag
--- @param entity Entity The entity to register
function PLUGIN.registerPhaseEntity(player, bag, entity)
  bag.phase.entities = bag.phase.entities or {}
  table.insert(bag.phase.entities, entity)
end

--- Registers an entity as being used by the contract
--- @param player Player The player whose contract this entity belongs to
--- @param bag table The contract instance bag
--- @param entity Entity The entity to register
function PLUGIN.registerContractEntity(player, bag, entity)
  bag.contract.entities = bag.contract.entities or {}
  table.insert(bag.contract.entities, entity)
end

--- Registers an NPC as being spawned by the contract
--- @param player Player The player whose contract this NPC belongs to
--- @param bag table The contract instance bag
--- @param npc NPC The NPC to register
function PLUGIN.registerContractNPC(player, bag, npc)
  bag.contract.spawnedNPCs = bag.contract.spawnedNPCs or {}
  table.insert(bag.contract.spawnedNPCs, npc)
end

--- Links a subsequent player's contract to a first player's contract instance.
--- @param firstPlayer Player The player with the first role
--- @param subsequentPlayer Player The player with the subsequent role
function PLUGIN.linkContractInstances(firstPlayer, subsequentPlayer)
  if not firstPlayer._VersusCurrentContract or not subsequentPlayer._VersusCurrentContract then
    error("Cannot link contracts: one or both players do not have active contracts")
    return
  end

  -- Initialize subsequent players table if needed
  firstPlayer._VersusContractSubsequents = firstPlayer._VersusContractSubsequents or {}
  table.insert(firstPlayer._VersusContractSubsequents, subsequentPlayer)

  -- Link subsequent to first
  subsequentPlayer._VersusContractLinkedTo = firstPlayer
end

--- Unlinks a subsequent player from a first player's contract.
--- @param firstPlayer Player The player with the first role
--- @param subsequentPlayer Player The player with the subsequent role
function PLUGIN.unlinkContractInstance(firstPlayer, subsequentPlayer)
  if firstPlayer._VersusContractSubsequents then
    for i, linkedPlayer in ipairs(firstPlayer._VersusContractSubsequents) do
      if linkedPlayer == subsequentPlayer then
        table.remove(firstPlayer._VersusContractSubsequents, i)
        break
      end
    end
  end

  subsequentPlayer._VersusContractLinkedTo = nil
end

--- Synchronizes phase progression for all subsequent players linked to a first player.
--- Called when the first player completes a phase.
--- @param firstPlayer Player The player with the first role who just completed a phase
function PLUGIN.syncPhaseProgression(firstPlayer)
  if not firstPlayer._VersusContractSubsequents then
    return
  end

  local contract = PLUGIN.getContract(firstPlayer._VersusCurrentContract.id)
  if not contract then
    return
  end

  local newPhaseIndex = firstPlayer._VersusCurrentContract.phaseIndex

  for i = #firstPlayer._VersusContractSubsequents, 1, -1 do
    local subsequentPlayer = firstPlayer._VersusContractSubsequents[i]

    if not IsValid(subsequentPlayer) or not subsequentPlayer._VersusCurrentContract then
      table.remove(firstPlayer._VersusContractSubsequents, i)
      continue
    end

    -- Check if subsequent player has a phase at this index
    local subsequentPhase = contract.phases[newPhaseIndex]

    if not subsequentPhase then
      -- No more phases for subsequent, fail their contract
      PLUGIN.failContract(subsequentPlayer, "The primary contract objective has been completed.")
      table.remove(firstPlayer._VersusContractSubsequents, i)
      continue
    end

    -- Check if this phase has a subsequent variant
    local hasSubsequentVariant = PLUGIN.isPhaseInterferable(subsequentPhase) and subsequentPhase.subsequent ~= nil

    if not hasSubsequentVariant then
      -- Phase doesn't support subsequent players, fail their contract
      PLUGIN.failContract(subsequentPlayer, "The primary contract has progressed to a phase you cannot interfere with.")
      table.remove(firstPlayer._VersusContractSubsequents, i)
      continue
    end

    -- Sync the subsequent player to the new phase
    subsequentPlayer._VersusCurrentContract.phaseIndex = newPhaseIndex
    PLUGIN.handleContractPhase(subsequentPlayer, contract.phases[newPhaseIndex])
  end
end

--- Fails a player's contract with a reason.
--- @param player Player The player whose contract should fail
--- @param reason string The reason for the contract failure
function PLUGIN.failContract(player, reason)
  if not player._VersusCurrentContract then
    return
  end

  -- Clean up contract resources before notifying player
  local bag = player._VersusCurrentContract.bag
  if bag then
    PLUGIN.cleanupPhase(player, bag)
    PLUGIN.cleanupContract(player, bag)
  end

  -- Notify the player
  versus.message.notify(player, "Contract Failed: " .. reason, NOTIFY_ERROR)

  -- Clean up linkages if this is a subsequent player
  if player._VersusContractLinkedTo and IsValid(player._VersusContractLinkedTo) then
    PLUGIN.unlinkContractInstance(player._VersusContractLinkedTo, player)
  end

  -- Fail all linked subsequent players if this is a first player
  if player._VersusContractSubsequents then
    for _, subsequentPlayer in ipairs(player._VersusContractSubsequents) do
      if IsValid(subsequentPlayer) and subsequentPlayer._VersusCurrentContract then
        -- Recursively fail the subsequent player's contract
        PLUGIN.failContract(subsequentPlayer, "The primary contractor's mission has failed.")
      end
    end
    player._VersusContractSubsequents = nil
  end

  -- Remove from active instances if first player
  if player._VersusContractInstanceID and player._VersusContractRole == "first" then
    local contractID = player._VersusCurrentContract.id
    if PLUGIN.activeContractInstances[contractID] then
      PLUGIN.activeContractInstances[contractID][player._VersusContractInstanceID] = nil
    end
  end

  -- Clear the contract
  player._VersusCurrentContract = nil
  player._VersusContractRole = nil
  player._VersusContractInstanceID = nil

  -- TODO: Decide what happens after failure - force reselect or delay?
  hook.Run("PlayerContractFailed", player, reason)
end

--- Calls a contract function from callback data. Callback data should be a table where [1] is the function ID and [2+] are additional arguments.
--- @param player Player The player to pass to the function
--- @param bag table The contract bag to pass to the function
--- @param callbackData table The callback data table where [1] is the function ID and [2+] are arguments
--- @param errorOnMissing? boolean|string If true/string, errors when function is not found. If string, uses it as the error message prefix. Defaults to false.
--- @return any? # The result of the function call, or nil if the function doesn't exist
function PLUGIN.callContractFunction(player, bag, callbackData, errorOnMissing)
  if (not istable(callbackData) or #callbackData == 0) then
    if (errorOnMissing) then
      error("Invalid callback data: expected table with function ID at [1]")
    end

    return nil
  end

  local funcID = callbackData[1]
  local func = PLUGIN.getContractFunction(funcID)

  if (not func) then
    if (errorOnMissing) then
      local errorMsg = isstring(errorOnMissing) and errorOnMissing or "Contract function not registered"
      error(errorMsg .. ": " .. tostring(funcID))
    end

    return nil
  end

  local args = { unpack(callbackData, 2) }
  return func(player, bag, unpack(args))
end

--- Gets a location definition from a contract by its key.
--- @param contractID string The ID of the contract
--- @param locationKey string The key of the location in the contract's locations table
--- @return table? # The location definition table, or nil if the contract or location doesn't exist
function PLUGIN.getContractLocation(contractID, locationKey)
  local contract = PLUGIN.getContract(contractID)
  if not contract or not contract.locations then
    return nil
  end

  return contract.locations[locationKey]
end

--- Gets all visible locations from a contract for map preview.
--- Locations with hidden=true are excluded.
--- @param contractID string The ID of the contract
--- @return table # A table of location keys to location definitions that should be shown on the map preview
function PLUGIN.getVisibleContractLocations(contractID)
  local contract = PLUGIN.getContract(contractID)
  if not contract or not contract.locations then
    return {}
  end

  local visibleLocations = {}

  for locationKey, locationDef in pairs(contract.locations) do
    if not locationDef.hidden then
      visibleLocations[locationKey] = locationDef
    end
  end

  return visibleLocations
end

--- Checks if an entity is available for contract use (not already reserved by another player).
--- @param entity Entity The entity to check
--- @param forPlayer? Player Optional. The player who wants to use this entity (bypasses check if entity is reserved by this player)
--- @return boolean # True if entity is available, false otherwise
function PLUGIN.isEntityAvailable(entity, forPlayer)
  if not IsValid(entity) then return false end

  local reservedBy = entity._VersusReservedBy
  if not reservedBy then return true end

  if not IsValid(reservedBy) then
    -- Cleanup stale reservation
    entity._VersusReservedBy = nil
    entity._VersusReservedForContract = nil
    return true
  end

  return reservedBy == forPlayer
end

--- Reserves entities for a contract instance. Marks entities as being used by a specific player.
--- @param player Player The player who is reserving these entities
--- @param contractID string The contract ID
--- @param resolvedLocations table The resolved locations table containing entities to reserve
--- @return boolean # True if all entities were successfully reserved, false if any conflicts
function PLUGIN.reserveContractLocations(player, contractID, resolvedLocations)
  -- First pass: check if all entities are available
  for locationKey, locationData in pairs(resolvedLocations) do
    if IsValid(locationData.entity) then
      if not PLUGIN.isEntityAvailable(locationData.entity, player) then
        return false -- Entity already reserved by another player
      end
    end
  end

  -- Second pass: reserve all entities
  for locationKey, locationData in pairs(resolvedLocations) do
    if IsValid(locationData.entity) then
      locationData.entity._VersusReservedBy = player
      locationData.entity._VersusReservedForContract = contractID
    end
  end

  return true
end

--- Cleans up entity reservations for a player's contract.
--- @param player Player The player whose contract entities should be unreserved
function PLUGIN.cleanupContractReservations(player)
  if not player._VersusCurrentContract then return end

  local preparedContract = player._VersusAvailableContracts and player._VersusAvailableContracts[player._VersusCurrentContract.id]
  if preparedContract and preparedContract.locations then
    for _, locationData in pairs(preparedContract.locations) do
      if IsValid(locationData.entity) then
        locationData.entity._VersusReservedBy = nil
        locationData.entity._VersusReservedForContract = nil
      end
    end
  end
end

--- Prepares a contract instance for a specific player by resolving all location references.
--- This handles random entity selection and relative location positioning.
--- NOTE: This does NOT reserve entities - use reserveContractLocations() after player selects the contract.
--- @param player Player The player for whom to prepare the contract
--- @param contractID string The ID of the contract to prepare
--- @return table? # The prepared contract instance with resolved locations, or nil if locations couldn't be resolved
function PLUGIN.prepareContractForPlayer(player, contractID)
  local contract = PLUGIN.getContract(contractID)

  if (not contract) then
    error("Attempted to prepare invalid contract ID: " .. tostring(contractID))
  end

  -- Initialize the player's contract storage if needed
  player._VersusAvailableContracts = player._VersusAvailableContracts or {}

  -- Create a copy of the contract's locations to resolve
  local resolvedLocations = {}
  local pendingRelative = {}

  -- First pass: resolve non-relative locations
  for locationKey, locationDef in pairs(contract.locations) do
    if locationDef.relativeToKey then
      -- This is a relative location, handle it in the second pass
      table.insert(pendingRelative, { key = locationKey, def = locationDef })
    else
      -- This is a direct location
      local entity = nil

      if locationDef.tag == nil then
        -- Random selection: pick a random entity of this class
        local entities = ents.FindByClass(locationDef.class)
        if #entities > 0 then
          entity = entities[math.random(1, #entities)]
        end
      else
        -- Specific tag: find the exact entity
        local entities = ents.FindByClass(locationDef.class)
        for _, ent in ipairs(entities) do
          if not locationDef.tag or (ent.GetTag and ent:GetTag() == locationDef.tag) then
            entity = ent
            break
          end
        end
      end

      if IsValid(entity) then
        resolvedLocations[locationKey] = {
          class = locationDef.class,
          tag = entity.GetTag and entity:GetTag() or nil,
          entity = entity,
          position = entity:GetPos(),
          hidden = locationDef.hidden,
          displayName = locationDef.displayName or "Objective",
        }
      else
        ErrorNoHaltWithStack("Failed to resolve location '" .. locationKey .. "' for contract " .. contractID .. "\n")
        return nil -- Failed to resolve, contract not available
      end
    end
  end

  -- Second pass: resolve relative locations
  for _, relativeInfo in ipairs(pendingRelative) do
    local locationKey = relativeInfo.key
    local locationDef = relativeInfo.def

    local baseLocation = resolvedLocations[locationDef.relativeToKey]
    if not baseLocation then
      ErrorNoHaltWithStack("Cannot resolve relative location '" ..
        locationKey .. "': base location '" .. locationDef.relativeToKey .. "' not found\n")
      continue
    end

    local entities = ents.FindByClass(locationDef.class)
    local selectedEntity = nil

    if locationDef.distance == PLUGIN.NEAR_TO_LOCATION then
      -- Find closest entity
      local closestDistance = math.huge
      for _, entity in ipairs(entities) do
        local distance = baseLocation.position:Distance(entity:GetPos())
        if distance < closestDistance then
          closestDistance = distance
          selectedEntity = entity
        end
      end
    elseif locationDef.distance == PLUGIN.FAR_FROM_LOCATION then
      -- Find farthest entity
      local farthestDistance = -math.huge
      for _, entity in ipairs(entities) do
        local distance = baseLocation.position:Distance(entity:GetPos())
        if distance > farthestDistance then
          farthestDistance = distance
          selectedEntity = entity
        end
      end
    end

    if IsValid(selectedEntity) then
      resolvedLocations[locationKey] = {
        class = locationDef.class,
        tag = selectedEntity.GetTag and selectedEntity:GetTag() or nil,
        entity = selectedEntity,
        position = selectedEntity:GetPos(),
        hidden = locationDef.hidden,
        displayName = locationDef.displayName or "Objective",
      }
    else
      ErrorNoHaltWithStack("Failed to resolve relative location '" ..
        locationKey .. "' for contract " .. contractID .. "\n")
      return nil -- Failed to resolve, contract not available
    end
  end

  -- Store the prepared contract instance
  local preparedContract = {
    id = contractID,
    name = PLUGIN.resolveContractName(contract.name),
    locations = resolvedLocations,
    phases = contract.phases,
  }

  player._VersusAvailableContracts[contractID] = preparedContract

  return preparedContract
end

--- Resolves a contract name based on the options defined in the contract. If the name is a string, it is
--- returned directly. If it is a table, a random entry is selected and returned.
--- @param nameOption string|table The name option defined in the contract. Can be a string or a table of strings.
--- @return string # The resolved contract name.
function PLUGIN.resolveContractName(nameOption)
  if type(nameOption) == "string" then
    return nameOption
  elseif type(nameOption) == "table" and #nameOption > 0 then
    return nameOption[math.random(1, #nameOption)]
  else
    return "Unnamed Contract"
  end
end

--- Assigns a contract to a player. This will set the player's current contract to the specified contract and initialize their progress to the first phase.
--- @param player Player The player to assign the contract to.
--- @param preparedContract table The prepared contract instance to assign to the player. This should be the result of PLUGIN.prepareContractForPlayer.
--- @param role? string Optional. The role for this player ("first" or "subsequent"). Defaults to "first".
--- @param linkedToPlayer? Player Optional. If role is "subsequent", this is the first player to link to.
function PLUGIN.assignContractToPlayer(player, preparedContract, role, linkedToPlayer)
  if not preparedContract then
    error("Failed to assign contract to player: preparedContract is nil")
    return
  end

  role = role or "first"

  player._VersusCurrentContract = {
    id = preparedContract.id,
    phaseIndex = 1,
    bag = {
      -- This bag is cleared every time a new phase is assigned.
      phase = {},

      -- This bag persists across all phases of the same contract, and can be used to store any data you want related to the player's overall progress in the contract. For example, if the player needs to collect certain items across multiple phases, you could store that information here.
      contract = {},
    },
  }

  player._VersusContractRole = role

  -- Handle role-specific setup
  if role == "first" then
    -- Generate unique instance ID and register
    player._VersusContractInstanceID = tostring(player:SteamID64()) .. "_" .. tostring(CurTime())

    PLUGIN.activeContractInstances[preparedContract.id] = PLUGIN.activeContractInstances[preparedContract.id] or {}
    PLUGIN.activeContractInstances[preparedContract.id][player._VersusContractInstanceID] = {
      player = player,
      preparedContract = preparedContract,
      startTime = CurTime(),
    }
  elseif role == "subsequent" then
    -- Link to the first player if provided
    if linkedToPlayer and IsValid(linkedToPlayer) then
      PLUGIN.linkContractInstances(linkedToPlayer, player)

      -- Sync to the first player's current phase
      if linkedToPlayer._VersusCurrentContract then
        player._VersusCurrentContract.phaseIndex = linkedToPlayer._VersusCurrentContract.phaseIndex
      end
    end
  end

  PLUGIN.handleContractPhase(player, preparedContract.phases[player._VersusCurrentContract.phaseIndex])
end

--- Makes the given contracts available to the player. This should be called when the player first becomes
--- eligible for these contracts (e.g: upon joining the game or completing a previous contract).
--- @param player Player The player to make the contracts available for.
--- @param contractIDs table A list of contract IDs to make available to the player.
function PLUGIN.makeContractsAvailableToPlayer(player, contractIDs)
  player._VersusAvailableContracts = player._VersusAvailableContracts or {}

  for _, contractID in ipairs(contractIDs) do
    local preparedContract = PLUGIN.prepareContractForPlayer(player, contractID)
    player._VersusAvailableContracts[contractID] = preparedContract
  end
end

--- Handles a contract phase for a player. This function goes through all the keys in the phase and calls the corresponding handlers for each key.
--- @param player Player The player whose contract phase is being handled.
--- @param phase table The contract phase definition table. This should contain various keys that define what happens during this phase, such as "objective", "lore", "spawnWaves", etc.
function PLUGIN.handleContractPhase(player, phase)
  -- Get the appropriate sub-phase based on player's role
  local role = player._VersusContractRole or "first"
  local actualPhase = PLUGIN.getPhaseForRole(phase, role)

  -- Clean up the previous phase before starting a new one
  local bag = player._VersusCurrentContract.bag
  if bag then
    PLUGIN.cleanupPhase(player, bag)
  end

  -- Clear the phase bag for the new phase
  player._VersusCurrentContract.bag.phase = {}

  for key, data in pairs(actualPhase) do
    local handler = PLUGIN.getContractPhaseKeyHandler(key)

    if (handler) then
      handler(player, player._VersusCurrentContract.bag, data)
    else
      ErrorNoHaltWithStack("No handler registered for contract phase key: " .. tostring(key) .. "\n")
    end
  end
end

--- Progress the player to the next phase of their current contract, or handle contract completion if there are no more phases.
--- @param player Player The player to progress to the next phase.
function PLUGIN.handleContractPhaseCompletion(player)
  if not player._VersusCurrentContract then
    error("Attempted to progress contract phase for player who does not have an active contract")
    return
  end

  local contract = PLUGIN.getContract(player._VersusCurrentContract.id)

  if not contract then
    error(
      "Attempted to progress contract phase for player with invalid contract ID: " ..
      tostring(player._VersusCurrentContract.id)
    )
    return
  end

  -- Progress to next phase
  player._VersusCurrentContract.phaseIndex = player._VersusCurrentContract.phaseIndex + 1

  -- If this is a first player, sync subsequent players
  if player._VersusContractRole == "first" then
    PLUGIN.syncPhaseProgression(player)
  end

  -- Check if there is a next phase to progress to
  if contract.phases[player._VersusCurrentContract.phaseIndex] then
    local nextPhase = contract.phases[player._VersusCurrentContract.phaseIndex]
    local role = player._VersusContractRole or "first"

    -- Check if this phase supports the player's role
    if PLUGIN.isPhaseInterferable(nextPhase) and role == "subsequent" and not nextPhase.subsequent then
      -- Subsequent player reached a phase they can't interfere with
      PLUGIN.failContract(player, "The primary contract has progressed beyond your interference capability.")
      return
    end

    PLUGIN.handleContractPhase(player, nextPhase)
  else
    -- Contract completed, handle completion (e.g: give rewards, mark as completed, etc.)
    PLUGIN.handleContractCompletion(player, contract)

    -- Clean up contract instance
    if player._VersusContractRole == "first" then
      -- Fail all remaining subsequent players
      if player._VersusContractSubsequents then
        for _, subsequentPlayer in ipairs(player._VersusContractSubsequents) do
          if IsValid(subsequentPlayer) then
            PLUGIN.failContract(subsequentPlayer, "The primary contract has been completed.")
          end
        end
      end

      -- Remove from active instances
      if player._VersusContractInstanceID then
        local contractID = player._VersusCurrentContract.id
        if PLUGIN.activeContractInstances[contractID] then
          PLUGIN.activeContractInstances[contractID][player._VersusContractInstanceID] = nil
        end
      end
    elseif player._VersusContractRole == "subsequent" then
      -- Unlink from first player
      if player._VersusContractLinkedTo and IsValid(player._VersusContractLinkedTo) then
        PLUGIN.unlinkContractInstance(player._VersusContractLinkedTo, player)
      end
    end

    player._VersusCurrentContract = nil -- Clear current contract
    player._VersusContractRole = nil
    player._VersusContractInstanceID = nil
  end
end

--- Finishes a contract for a player. This should be called when a player completes the final phase of a contract. This function can handle giving rewards, marking the contract as completed, and any other cleanup or progression logic needed upon contract completion.
--- @param player Player The player who completed the contract.
--- @param contract table The contract definition table for the completed contract.
function PLUGIN.handleContractCompletion(player, contract)
  -- Clean up contract resources
  local bag = player._VersusCurrentContract and player._VersusCurrentContract.bag
  if bag then
    PLUGIN.cleanupPhase(player, bag)
    PLUGIN.cleanupContract(player, bag)
  end

  -- TODO: implementation for giving rewards, marking contract as completed, etc.`
  ErrorNoHaltWithStack("Not yet implemented! Player " .. player:Nick() .. " completed contract: " .. contract.id .. "\n")
end

--- Gets an entity based on a location reference. A location reference is a table that contains a locationKey
--- and a distance modifier (e.g: NEAR_TO_LOCATION, FAR_FROM_LOCATION, or EXACT). This function will resolve
--- the location from the player's prepared contract and return the entity.
--- @see PLUGIN.referToContractLocation for creating location references
--- @param player Player The player for whom we are trying to get the entity.
--- @param locationReference table The location reference table created with PLUGIN.referToContractLocation
--- @return Entity? # The entity that matches the location reference, or nil if no matching entity is found.
function PLUGIN.getEntityFromReference(player, locationReference)
  -- Get the prepared contract instance for this player
  local preparedContract = player._VersusAvailableContracts and
      player._VersusAvailableContracts[player._VersusCurrentContract.id]

  if not preparedContract or not preparedContract.locations then
    error("Player does not have a prepared contract or contract has no locations")
    return nil
  end

  local locationDef = preparedContract.locations[locationReference.locationKey]
  if not locationDef then
    error("Location key not found in prepared contract: " .. tostring(locationReference.locationKey))
    return nil
  end

  -- For prepared contracts, we can directly find the entity by its tag
  -- The distance modifier should be EXACT since locations are already resolved
  if locationReference.distance == PLUGIN.EXACT then
    for _, location in pairs(preparedContract.locations) do
      if location.class == locationDef.class and location.tag == locationDef.tag then
        return location.entity
      end
    end
  elseif locationReference.distance == PLUGIN.NEAR_TO_LOCATION then
    -- Find nearest entity of this class to the player
    local entities = ents.FindByClass(locationDef.class)
    local closestEntity = nil
    local closestDistance = math.huge

    for _, entity in ipairs(entities) do
      local distance = player:GetPos():Distance(entity:GetPos())
      if distance < closestDistance then
        closestDistance = distance
        closestEntity = entity
      end
    end

    return closestEntity
  elseif locationReference.distance == PLUGIN.FAR_FROM_LOCATION then
    -- Find farthest entity of this class from the player
    local entities = ents.FindByClass(locationDef.class)
    local farthestEntity = nil
    local farthestDistance = -math.huge

    for _, entity in ipairs(entities) do
      local distance = player:GetPos():Distance(entity:GetPos())
      if distance > farthestDistance then
        farthestDistance = distance
        farthestEntity = entity
      end
    end

    return farthestEntity
  end

  return nil
end

--[[
  Contract Functions
--]]

-- Waits for a certain amount of time (in seconds) before allowing the player to progress to the next phase.
PLUGIN.registerContractFunction("wait", function(player, bag, timeInSeconds)
  bag.phase.waitStartTime = bag.phase.waitStartTime or CurTime()

  if CurTime() - bag.phase.waitStartTime >= timeInSeconds then
    return true
  end

  return false
end)

-- Sets a value in the player's contract bag. This can be used to track progress or state across phases.
PLUGIN.registerContractFunction("setContractValue", function(player, bag, key, value)
  bag.contract[key] = value
end)

-- Checks if a value in the player's contract bag equals a specified value. This can be used in completeCallback to check for phase completion based on contract state.
PLUGIN.registerContractFunction("checkContractValueEquals", function(player, bag, key, expectedValue)
  return bag.contract[key] == expectedValue
end)

-- Checks if the value in the player's contract bag does not equal a specified value. This can be used in completeCallback to check for phase completion based on contract state.
PLUGIN.registerContractFunction("checkContractValueNotEquals", function(player, bag, key, unexpectedValue)
  return bag.contract[key] ~= unexpectedValue
end)

-- Sets a value in the player's current phase bag. This can be used to track progress or state within the current phase.
PLUGIN.registerContractFunction("setPhaseValue", function(player, bag, key, value)
  bag.phase[key] = value
end)

-- Checks if the value in the player's phase bag equals a specified value. This can be used in completeCallback to check for phase completion based on phase-specific state.
PLUGIN.registerContractFunction("checkPhaseValueEquals", function(player, bag, key, expectedValue)
  return bag.phase[key] == expectedValue
end)

-- Completes the current phase
PLUGIN.registerContractFunction("completePhase", function(player, bag)
  PLUGIN.handleContractPhaseCompletion(player)
end)

-- Completes the contract
PLUGIN.registerContractFunction("completeContract", function(player, bag)
  if not player._VersusCurrentContract then
    error("Attempted to complete contract for player who does not have an active contract")
  end

  PLUGIN.handleContractCompletion(player, PLUGIN.getContract(player._VersusCurrentContract.id))
end)

--[[
  Load Definitions
--]]

-- These must come after all of the above.
versus.includeDirectory(PLUGIN.fullPath .. "/contracts")
versus.includeDirectory(PLUGIN.fullPath .. "/handlers")

-- Handled in Think hook
PLUGIN.registerContractPhaseKeyHandler("completeCallback", function(player, bag, callbackData)
  -- This key is handled in the Think hook by calling the specified completion function with the provided arguments.
end)

--- Generates subsequent (interference) contract variants for active contracts
--- @param player Player The player to generate subsequent contracts for
--- @return table # A table of subsequent contract instances { contractID_instanceID = { preparedContract, firstPlayer, role = "subsequent" } }
function PLUGIN.generateSubsequentContracts(player)
  local subsequentContracts = {}

  -- Look through all active contract instances
  for contractID, instances in pairs(PLUGIN.activeContractInstances) do
    local contract = PLUGIN.getContract(contractID)

    if not contract then
      continue
    end

    -- Check each instance
    for instanceID, instanceData in pairs(instances) do
      local firstPlayer = instanceData.player
      local preparedContract = instanceData.preparedContract

      -- Skip if first player is not valid or is the same as requesting player
      if not IsValid(firstPlayer) or firstPlayer == player then
        continue
      end

      -- Skip if first player doesn't have an active contract
      if not firstPlayer._VersusCurrentContract then
        continue
      end

      -- Get the current phase of the first player
      local currentPhaseIndex = firstPlayer._VersusCurrentContract.phaseIndex
      local currentPhase = contract.phases[currentPhaseIndex]

      -- Check if this phase is interferable and has subsequent variant
      if not PLUGIN.isPhaseInterferable(currentPhase) or not currentPhase.subsequent then
        continue
      end

      -- Check maxSubsequent limit
      local maxSubsequent = currentPhase.maxSubsequent or 1
      local currentSubsequentCount = #(firstPlayer._VersusContractSubsequents or {})

      if currentSubsequentCount >= maxSubsequent then
        continue
      end

      -- Create a subsequent contract variant
      -- Use the same prepared contract but mark it as subsequent
      local subsequentID = contractID .. "_" .. instanceID
      subsequentContracts[subsequentID] = {
        preparedContract = preparedContract,
        firstPlayer = firstPlayer,
        role = "subsequent",
        originalContractID = contractID,
      }
    end
  end

  return subsequentContracts
end

--- Generates and networks available contracts to a player
--- @param player Player The player to generate contracts for
function PLUGIN.generateContractsForPlayer(player)
  -- Get all registered contracts
  local availableContractIDs = {}

  for contractID, _ in pairs(PLUGIN.contracts) do
    table.insert(availableContractIDs, contractID)
  end

  if #availableContractIDs == 0 then
    ErrorNoHalt("No contracts registered to generate for player\n")
    return
  end

  -- Prepare contracts for the player (resolves locations)
  PLUGIN.makeContractsAvailableToPlayer(player, availableContractIDs)

  -- Generate subsequent (interference) contracts
  local subsequentContracts = PLUGIN.generateSubsequentContracts(player)

  -- Add subsequent contracts to available contracts
  player._VersusAvailableContracts = player._VersusAvailableContracts or {}
  player._VersusSubsequentContractData = player._VersusSubsequentContractData or {}

  for subsequentID, data in pairs(subsequentContracts) do
    player._VersusAvailableContracts[subsequentID] = data.preparedContract
    player._VersusSubsequentContractData[subsequentID] = data
  end

  -- Network the contracts to the client
  PLUGIN.networkContractsToPlayer(player)
end

--- Networks the player's available contracts to the client
--- @param player Player The player to network contracts to
function PLUGIN.networkContractsToPlayer(player)
  local availableContracts = player._VersusAvailableContracts or {}
  local contractList = {}

  -- Convert to list for networking and assign numeric IDs
  local numericID = 1
  player._VersusContractIDMap = player._VersusContractIDMap or {}
  player._VersusContractIDMap = {} -- Reset the map

  for contractID, preparedContract in pairs(availableContracts) do
    -- Check if this is a subsequent contract
    local subsequentData = player._VersusSubsequentContractData and player._VersusSubsequentContractData[contractID]
    local originalContractID = subsequentData and subsequentData.originalContractID or contractID
    local contract = PLUGIN.getContract(originalContractID)

    if contract then
      -- Map numeric ID to string ID for this player
      player._VersusContractIDMap[numericID] = contractID

      table.insert(contractList, {
        numericID = numericID,
        id = contractID,
        name = preparedContract.name .. (subsequentData and " [INTERFERENCE]" or ""),
        enabled = true,
        difficulty = contract.difficulty or PLUGIN.DIFFICULTY_MEDIUM,
        reward = contract.reward or PLUGIN.REWARD_LOW,
        combatStyle = subsequentData and PLUGIN.COMBAT_STYLE_MIXED or (contract.combatStyle or PLUGIN.COMBAT_STYLE_PVE),
        locations = preparedContract.locations,
        isSubsequent = subsequentData ~= nil,
      })

      numericID = numericID + 1
    end
  end

  net.Start("versus.contracts.receiveContracts")
  net.WriteUInt(#contractList, PLUGIN.bitCountContractAmount)

  for _, contractData in ipairs(contractList) do
    net.WriteUInt(contractData.numericID, PLUGIN.bitCountContractID)
    net.WriteBool(contractData.enabled)

    if not contractData.enabled then
      net.WriteString(contractData.unavailableReason or "Unavailable")
    end

    net.WriteString(contractData.name)
    net.WriteUInt(contractData.difficulty, 3)
    net.WriteUInt(contractData.reward, 3)
    net.WriteUInt(contractData.combatStyle, 3)

    -- Network all non-hidden locations
    local visibleLocations = {}
    for locationKey, location in pairs(contractData.locations) do
      if not location.hidden then
        table.insert(visibleLocations, {
          key = locationKey,
          entity = location.entity,
          displayName = location.displayName or "Objective",
          class = location.class
        })
      end
    end

    net.WriteUInt(#visibleLocations, 8) -- Max 255 locations per contract
    for _, location in ipairs(visibleLocations) do
      net.WriteString(location.key)
      net.WriteEntity(location.entity or NULL)
      net.WriteString(location.displayName)
      net.WriteString(location.class)
    end
  end

  net.Send(player)
end

function PLUGIN.forceReselectContract(player)
  -- Lose the contract
  player._VersusContract = nil

  -- Show death screen before showing contract selection again.
  net.Start("versus.contracts.forceReselectContract")
  net.Send(player)

  -- Network existing contracts again
  PLUGIN.networkContractsToPlayer(player)
end

-- TODO: Old
-- --- Returns versus_objective_interaction entities that are currently valid extraction points
-- --- @return table # Table of valid extraction point entities
-- function PLUGIN.getValidExtractionPoints()
--   -- TODO: Later we'll filter which ones are already being used by other players, but for now we'll just return all of them
--   return ents.FindByClass("versus_objective_interaction")
-- end

--- Finds the spawn point (versus_spawn_point) furthest from the given position
--- Used to assign spawn points far away from the extraction point.
--- @param position Vector # The position to find spawn points far away from
--- @return Entity? # The spawn point entity, or nil if none found
function PLUGIN.findFurthestSpawnPoint(position)
  local spawnPoints = ents.FindByClass("versus_spawn_point")
  local furthestSpawn = nil
  local maxDistance = -1

  for _, spawn in ipairs(spawnPoints) do
    if IsValid(spawn) then
      local distance = position:Distance(spawn:GetPos())
      if distance > maxDistance then
        maxDistance = distance
        furthestSpawn = spawn
      end
    end
  end

  return furthestSpawn
end

--- Get all NPC spawn points
function PLUGIN.getSpawnNPCPoints()
  return ents.FindByClass("versus_npc_spawn_point")
end

--- Gets all NPC spawn points that are in between the two positions. This is used to
--- determine spawn points between the player's spawn and the extraction point, so we can spawn enemies there.
--- @param startPos Vector # The first position to compare
--- @param endPos Vector # The second position to compare
--- @param maxWidth? number # Maximum perpendicular distance from the direct line (optional, defaults to infinite)
--- @return table # Table of spawn point entities that are in between the two positions
function PLUGIN.getSpawnNPCPointsBetween(startPos, endPos, maxWidth)
  local spawnPoints = PLUGIN.getSpawnNPCPoints()
  local pointsBetween = {}

  maxWidth = maxWidth or 1024

  for _, spawn in ipairs(spawnPoints) do
    if IsValid(spawn) then
      local spawnPos = spawn:GetPos()

      local lineVec = endPos - startPos
      local pointVec = spawnPos - startPos

      -- Project pointVec onto lineVec to find how far along the line the spawn is
      local t = pointVec:Dot(lineVec) / lineVec:LengthSqr()

      -- If t is between 0 and 1, the spawn point is "between" the two positions
      if t > 0 and t < 1 then
        -- Find the closest point on the line to the spawn point
        local closestPointOnLine = startPos + lineVec * t
        -- Calculate perpendicular distance
        local perpDistance = spawnPos:Distance(closestPointOnLine)

        if perpDistance <= maxWidth then
          table.insert(pointsBetween, spawn)
        end
      end
    end
  end

  return pointsBetween
end

--- Sorts spawn points by distance from extraction and groups them into location categories
--- @param spawnPoints table # Table of spawn point entities
--- @param startPos Vector # Player spawn position
--- @param endPos Vector # Extraction point position
--- @return table # Table with keys ENEMY_NEAR_SPAWN, ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR, ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE, ENEMY_NEAR_EXTRACTION
function PLUGIN.categorizeSpawnPoints(spawnPoints, startPos, endPos)
  -- Sort spawn points by distance to extraction (furthest first)
  table.sort(spawnPoints, function(a, b)
    return a:GetPos():DistToSqr(endPos) > b:GetPos():DistToSqr(endPos)
  end)

  local totalDistance = startPos:Distance(endPos)
  local categorized = {
    [PLUGIN.ENEMY_NEAR_SPAWN] = {},
    [PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR] = {},
    [PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE] = {},
    [PLUGIN.ENEMY_NEAR_EXTRACTION] = {}
  }

  for _, spawn in ipairs(spawnPoints) do
    local spawnPos = spawn:GetPos()
    local distanceFromStart = spawnPos:Distance(startPos)

    -- Calculate what percentage along the path this spawn is
    local percentageAlongPath = distanceFromStart / totalDistance

    if percentageAlongPath < 0.25 then
      -- First quarter - near spawn
      table.insert(categorized[PLUGIN.ENEMY_NEAR_SPAWN], spawn)
    elseif percentageAlongPath < 0.50 then
      -- Second quarter - between spawn and extraction, far from extraction
      table.insert(categorized[PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_FAR], spawn)
    elseif percentageAlongPath < 0.75 then
      -- Third quarter - between spawn and extraction, close to extraction
      table.insert(categorized[PLUGIN.ENEMY_BETWEEN_SPAWN_AND_EXTRACTION_CLOSE], spawn)
    else
      -- Last quarter - near extraction
      table.insert(categorized[PLUGIN.ENEMY_NEAR_EXTRACTION], spawn)
    end
  end

  return categorized
end

function PLUGIN.setupEnemiesForPlayerContract(player, contract, contractID)
  local start = contract.spawnPoint:GetPos()
  local extraction = contract.extractionPoint:GetPos()
  local points = PLUGIN.getSpawnNPCPointsBetween(start, extraction)
  local sortedPoints = PLUGIN.categorizeSpawnPoints(points, start, extraction)

  local contractEnemies = contract.enemies

  if not contractEnemies then
    ErrorNoHalt("Contract " .. contractID .. " has no enemy data defined\n")
    return
  end

  -- Iterate through each enemy group defined in the contract
  for _, enemyGroup in ipairs(contractEnemies) do
    local npcClass = enemyGroup.class
    local location = enemyGroup.location
    local count = enemyGroup.count

    -- Get the spawn points for this location category
    local availableSpawns = sortedPoints[location]

    -- If no spawns in this category, find nearest available spawns from other categories
    if not availableSpawns or #availableSpawns == 0 then
      print("[Contract] Warning: No spawn points available for location category " ..
        location .. ", using nearest available")

      -- Collect all spawn points from all categories
      local allSpawns = {}
      for _, categorySpawns in pairs(sortedPoints) do
        for _, spawn in ipairs(categorySpawns) do
          table.insert(allSpawns, spawn)
        end
      end

      -- Determine the target position for this category
      local targetPos
      if location == PLUGIN.ENEMY_NEAR_SPAWN then
        targetPos = start
      elseif location == PLUGIN.ENEMY_NEAR_EXTRACTION then
        targetPos = extraction
      else
        -- For middle categories, use midpoint
        targetPos = (start + extraction) / 2
      end

      -- Sort all spawns by distance to target position
      table.sort(allSpawns, function(a, b)
        return a:GetPos():DistToSqr(targetPos) < b:GetPos():DistToSqr(targetPos)
      end)

      availableSpawns = allSpawns
    end

    if availableSpawns and #availableSpawns > 0 then
      -- Distribute enemies across available spawn points
      local spawnsPerPoint = math.ceil(count / #availableSpawns)
      local remaining = count

      for _, spawnPoint in ipairs(availableSpawns) do
        if remaining <= 0 then break end

        local spawnCount = math.min(spawnsPerPoint, remaining)
        local npcs = versus.npc.spawnNPCsAroundPoint(
          npcClass,
          spawnPoint:GetPos(),
          spawnCount,
          enemyGroup.weapons,
          player
        )

        -- Will have them go towards the player's spawn (but might run past them if the player detours)
        for _, npc in ipairs(npcs) do
          npc:SetEnemy(player)
          npc:UpdateEnemyMemory(player, player:GetPos())

          if (enemyGroup.lootTable) then
            versus.npc.attachLootSpawner(npc, function(npc, attacker, inflictor)
              PLUGIN.produceLootAtPosition(attacker, enemyGroup.lootTable, npc:GetPos())
            end)
          end

          if (enemyGroup.model) then
            npc:SetModel(enemyGroup.model)
          end

          if (enemyGroup.skin) then
            npc:SetSkin(enemyGroup.skin)
          end

          if (enemyGroup.bodygroups) then
            for group, value in pairs(enemyGroup.bodygroups) do
              npc:SetBodygroup(group, value)
            end
          end

          if (enemyGroup.health) then
            if (istable(enemyGroup.health)) then
              local health = math.random(enemyGroup.health[1], enemyGroup.health[2])
              npc:SetHealth(health)
            else
              npc:SetHealth(enemyGroup.health)
            end
          end
        end

        remaining = remaining - spawnCount
      end
    end
  end
end

function PLUGIN.produceLootAtPosition(attacker, lootTable, position, angles)
  if (isfunction(lootTable)) then
    lootTable = lootTable(attacker, position, angles)
  end

  -- Roll for each item independently based on its percentage chance
  for itemID, chance in pairs(lootTable) do
    local roll = math.random()

    if (roll <= chance) then
      local item = versus.item.createInstance(itemID)

      if (not item) then
        ErrorNoHalt("[NPC Spawner] Invalid item ID in loot table: " .. tostring(itemID) .. "\n")
        continue
      end

      local itemEntity = versus.item.make(item, position + Vector(0, 0, 30), angles or AngleRand(-180, 180))
      itemEntity:DropToFloor()

      if (IsValid(attacker) and attacker:IsPlayer()) then
        attacker._VersusLootItems = attacker._VersusLootItems or {}
        table.insert(attacker._VersusLootItems, itemEntity)
      end

      hook.Run("VersusNPCLootProduced", item, itemEntity)
    end
  end
end
