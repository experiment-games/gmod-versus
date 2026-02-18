local PLUGIN = PLUGIN

util.AddNetworkString("versus.contracts.receiveContracts")
util.AddNetworkString("versus.combat.showServerSelectionScreen")
util.AddNetworkString("versus.contracts.showRadioMessage")
util.AddNetworkString("versus.contracts.updateContractAvailability")
util.AddNetworkString("versus.contracts.rerollContracts")

PLUGIN.contracts = PLUGIN.contracts or {}
PLUGIN.contractFunctions = PLUGIN.contractFunctions or {}
PLUGIN.contractPhaseKeyHandlers = PLUGIN.contractPhaseKeyHandlers or {}
PLUGIN.activeContractInstances = PLUGIN.activeContractInstances or {}
PLUGIN.takenContractInstances = PLUGIN.takenContractInstances or {} -- Maps instance hash -> player

PLUGIN.EXACT = 0
PLUGIN.NEAR_TO_LOCATION = 1
PLUGIN.FAR_FROM_LOCATION = 2

--- Show a radio message to the player with the specified content and author.
--- @param player Player The player to show the message to
--- @param author string The author of the radio message (e.g: "Command", "NPC Name", etc.)
--- @param content string The content of the radio message
--- @param portrait? string Optional path to a portrait image to show with the message
function PLUGIN.showRadioMessage(player, author, content, portrait)
  local hasPortrait = isstring(portrait)

  net.Start("versus.contracts.showRadioMessage")
  net.WriteString(author)
  net.WriteString(content)
  net.WriteBool(hasPortrait)
  if hasPortrait then
    net.WriteString(portrait)
  end
  net.Send(player)
end

--- Remove any contract items from the player inventory
--- @param player Player
function PLUGIN.removeContractItems(player)
  local inventory = player:getCharacter("inventory")

  for key, item in pairs(inventory) do
    if item.category == "Contract" then
      versus.inventory.takeItem(player, item, 1)
    end
  end
end

--- Creates a location definition for use in the contract's "locations" table.
--- @param class string The entity class to search for
--- @param tag any The tag of the specific entity to find (can be nil for random selection)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @param displayName? string Optional. The display name for this location in the UI. Defaults to "Objective".
--- @param reserve? boolean Optional. If true, this location will be reserved when the contract is assigned. Defaults to true.
--- @return table # A location definition table
function PLUGIN.defineLocation(class, tag, hidden, displayName, reserve)
  return {
    class = class,
    tag = tag,
    hidden = hidden or false,
    displayName = displayName or "Objective",
    reserve = reserve == nil and true or reserve,
  }
end

--- Creates a relative location definition that will be resolved based on another location.
--- @param class string The entity class to search for
--- @param relativeToKey string The key of the location this should be relative to
--- @param distance number Distance modifier (NEAR_TO_LOCATION or FAR_FROM_LOCATION)
--- @param hidden? boolean Optional. If true, this location won't be shown on the map preview. Defaults to false.
--- @param displayName? string Optional. The display name for this location in the UI. Defaults to "Objective".
--- @param reserve? boolean Optional. If true, this location will be reserved when the contract is assigned. Defaults to true.
--- @return table # A relative location definition table
function PLUGIN.defineRelativeLocation(class, relativeToKey, distance, hidden, displayName, reserve)
  return {
    class = class,
    relativeToKey = relativeToKey,
    distance = distance,
    hidden = hidden or false,
    displayName = displayName or "Objective",
    reserve = reserve == nil and true or reserve,
  }
end

--- References a location from the contract's locations table.
--- @param locationKey string The key of the location in the contract's locations table
--- @return table # A location reference table
function PLUGIN.referToContractLocation(locationKey)
  return {
    locationKey = locationKey,
  }
end

--- Gets the display name for a location from a player's prepared contract.
--- @param player Player The player whose contract to check
--- @param locationKey string The key of the location to get the display name for
--- @return string # The display name for the location, or "Objective" if not found
function PLUGIN.getLocationDisplayName(player, locationKey)
  if not player._VersusAvailableContracts then return "Objective" end

  local lookupKey = player._VersusCurrentContract and
      (player._VersusCurrentContract.variantKey or player._VersusCurrentContract.id)
  if not lookupKey then return "Objective" end

  local preparedContract = player._VersusAvailableContracts[lookupKey]
  if not preparedContract or not preparedContract.locations then return "Objective" end

  local location = preparedContract.locations[locationKey]
  if not location then return "Objective" end

  return location.displayName or "Objective"
end

--- Generates a unique hash for a contract instance based on its contract ID and entity locations.
--- This allows us to identify when two players have prepared the exact same contract instance.
--- @param contractID string The contract ID
--- @param resolvedLocations table The resolved locations table containing entities
--- @return string # A unique hash string for this contract instance
function PLUGIN.generateContractInstanceHash(contractID, resolvedLocations)
  local entityIDs = {}

  -- Collect all entity IDs from resolved locations
  for locationKey, locationData in pairs(resolvedLocations) do
    if IsValid(locationData.entity) then
      table.insert(entityIDs, locationData.entity:EntIndex())
    end
  end

  -- Sort entity IDs to ensure consistent hashing regardless of iteration order
  table.sort(entityIDs)

  -- Create hash string: contractID + sorted entity IDs
  return contractID .. "_" .. table.concat(entityIDs, "_")
end

--- Marks a contract instance as taken by a player.
--- @param instanceHash string The instance hash from generateContractInstanceHash
--- @param player Player The player who is taking this contract instance
function PLUGIN.markContractInstanceTaken(instanceHash, player)
  PLUGIN.takenContractInstances[instanceHash] = player
end

--- Frees a contract instance, making it available for other players.
--- @param instanceHash string The instance hash to free
function PLUGIN.freeContractInstance(instanceHash)
  PLUGIN.takenContractInstances[instanceHash] = nil
end

--- Checks if a contract instance is currently taken.
--- @param instanceHash string The instance hash to check
--- @return boolean # True if the instance is taken, false otherwise
function PLUGIN.isContractInstanceTaken(instanceHash)
  local reservedBy = PLUGIN.takenContractInstances[instanceHash]

  if not reservedBy then
    return false
  end

  -- Clean up if player is no longer valid
  if not IsValid(reservedBy) then
    PLUGIN.freeContractInstance(instanceHash)
    return false
  end

  return true
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

  PLUGIN.removeContractItems(player)

  -- Notify the player
  versus.message.notify(player, "Contract Failed: " .. reason, NOTIFY_ERROR)

  -- Clean up linkages if this is a subsequent player
  if player._VersusContractLinkedTo and IsValid(player._VersusContractLinkedTo) then
    PLUGIN.unlinkContractInstance(player._VersusContractLinkedTo, player)
  end

  -- Complete all linked subsequent players if this is a first player (they succeeded in interfering)
  if player._VersusContractSubsequents then
    for _, subsequentPlayer in ipairs(player._VersusContractSubsequents) do
      if IsValid(subsequentPlayer) and subsequentPlayer._VersusCurrentContract then
        -- Subsequent players succeed when the first player fails (successful interference)
        local subsequentContract = PLUGIN.getContract(subsequentPlayer._VersusCurrentContract.id)
        if subsequentContract then
          PLUGIN.handleContractCompletion(subsequentPlayer, subsequentContract)
        end
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

  -- Free the contract instance and broadcast availability update
  if player._VersusContractInstanceHash and player._VersusContractRole == "first" then
    PLUGIN.freeContractInstance(player._VersusContractInstanceHash)
    PLUGIN.broadcastContractAvailabilityUpdate(player._VersusContractInstanceHash, true, player)
  end

  -- Clear the contract
  player._VersusCurrentContract = nil
  player._VersusContractRole = nil
  player._VersusContractInstanceID = nil
  player._VersusContractInstanceHash = nil

  if (player:Alive()) then
    player:KillSilent()
    PLUGIN.showEliminationScreen(player, reason)
  end

  timer.Simple(PLUGIN.respawnDelay, function()
    if IsValid(player) then
      PLUGIN.forceReselectContract(player)
    end
  end)

  hook.Run("PlayerContractFailed", player, reason)
end

function PLUGIN.showEliminationScreen(player, message)
  net.Start("versus.contracts.playerEliminated")
  net.WriteString(message)
  net.Send(player)
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
  -- First pass: check if all entities that need reservation are available
  for locationKey, locationData in pairs(resolvedLocations) do
    if IsValid(locationData.entity) and locationData.reserve ~= false then
      if not PLUGIN.isEntityAvailable(locationData.entity, player) then
        return false -- Entity already reserved by another player
      end
    end
  end

  -- Second pass: reserve entities that need reservation
  for locationKey, locationData in pairs(resolvedLocations) do
    if IsValid(locationData.entity) and locationData.reserve ~= false then
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

  local lookupKey = player._VersusCurrentContract.variantKey or player._VersusCurrentContract.id
  local preparedContract = player._VersusAvailableContracts and
      player._VersusAvailableContracts[lookupKey]
  if preparedContract and preparedContract.locations then
    for _, locationData in pairs(preparedContract.locations) do
      if IsValid(locationData.entity) and locationData.reserve ~= false then
        locationData.entity._VersusReservedBy = nil
        locationData.entity._VersusReservedForContract = nil
      end
    end
  end
end

--- Resolves all possible entity combinations for a single location definition.
--- For tagged locations, returns all entities matching the tag.
--- For untagged (random) locations, returns all entities of the class.
--- For relative locations, returns nil (handled in a second pass).
--- @param locationDef table The location definition
--- @return table? # A list of candidate entities, or nil if this is a relative location
local function getCandidateEntities(locationDef)
  if locationDef.relativeToKey then
    return nil -- Relative locations are resolved in a second pass
  end

  local entities = ents.FindByClass(locationDef.class)
  if locationDef.tag == nil then
    -- No tag: all entities of this class are candidates
    return entities
  else
    -- Tagged: collect all entities matching this specific tag
    local matching = {}
    for _, ent in ipairs(entities) do
      if ent.GetTag and ent:GetTag() == locationDef.tag then
        table.insert(matching, ent)
      end
    end
    return matching
  end
end

--- Builds the cartesian product of per-location candidate entity lists.
--- Each element of the result is a table mapping locationKey -> entity.
--- @param locationKeys table Ordered list of location keys
--- @param candidateLists table locationKey -> list of candidate entities
--- @return table # List of {locationKey -> entity} combination tables
local function buildEntityCombinations(locationKeys, candidateLists)
  local results = { {} }

  for _, locationKey in ipairs(locationKeys) do
    local candidates = candidateLists[locationKey]
    local next = {}

    for _, partial in ipairs(results) do
      for _, entity in ipairs(candidates) do
        local combo = {}
        for k, v in pairs(partial) do combo[k] = v end
        combo[locationKey] = entity
        table.insert(next, combo)
      end
    end

    results = next
  end

  return results
end

--- Prepares all possible contract instances for a specific player by enumerating all
--- valid entity combinations for the contract's locations.
--- For each combination of entities (one per tagged location), a separate prepared
--- instance is returned. This allows the player to be shown all variants, with taken
--- ones marked unavailable.
--- NOTE: This does NOT reserve entities - use reserveContractLocations() after player selects the contract.
--- @param player Player The player for whom to prepare the contract
--- @param contractID string The ID of the contract to prepare
--- @return table # A list of prepared contract instances (may be empty if no entities found)
function PLUGIN.prepareContractForPlayer(player, contractID)
  local contract = PLUGIN.getContract(contractID)

  if not contract then
    error("Attempted to prepare invalid contract ID: " .. tostring(contractID))
  end

  -- Separate direct locations from relative ones
  local directLocationKeys = {}
  local candidateLists = {}
  local pendingRelative = {}

  for locationKey, locationDef in pairs(contract.locations) do
    if locationDef.relativeToKey then
      table.insert(pendingRelative, { key = locationKey, def = locationDef })
    else
      local candidates = getCandidateEntities(locationDef)

      if not candidates or #candidates == 0 then
        -- No entities available for this location on this map
        return {}
      end

      table.insert(directLocationKeys, locationKey)
      candidateLists[locationKey] = candidates
    end
  end

  -- Build all combinations of direct-location entities
  local combinations = buildEntityCombinations(directLocationKeys, candidateLists)

  local instances = {}
  local resolvedName = PLUGIN.resolveContractProperty(contract.name)
  local resolvedDescription = PLUGIN.resolveContractProperty(contract.description)

  for _, combo in ipairs(combinations) do
    -- Build resolved locations for this combination
    local resolvedLocations = {}

    for locationKey, entity in pairs(combo) do
      local locationDef = contract.locations[locationKey]
      resolvedLocations[locationKey] = {
        class = locationDef.class,
        tag = entity.GetTag and entity:GetTag() or nil,
        entity = entity,
        position = entity:GetPos(),
        hidden = locationDef.hidden,
        displayName = locationDef.displayName or "Objective",
        reserve = locationDef.reserve,
      }
    end

    -- Second pass: resolve relative locations against this combination's direct locations
    local relativeResolutionFailed = false

    for _, relativeInfo in ipairs(pendingRelative) do
      local locationKey = relativeInfo.key
      local locationDef = relativeInfo.def

      local baseLocation = resolvedLocations[locationDef.relativeToKey]
      if not baseLocation then
        ErrorNoHaltWithStack("Cannot resolve relative location '" ..
          locationKey .. "': base location '" .. locationDef.relativeToKey .. "' not found\n")
        relativeResolutionFailed = true
        break
      end

      local entities = ents.FindByClass(locationDef.class)
      local selectedEntity = nil

      if locationDef.distance == PLUGIN.NEAR_TO_LOCATION then
        local closestDistance = math.huge
        for _, entity in ipairs(entities) do
          local distance = baseLocation.position:Distance(entity:GetPos())
          if distance < closestDistance then
            closestDistance = distance
            selectedEntity = entity
          end
        end
      elseif locationDef.distance == PLUGIN.FAR_FROM_LOCATION then
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
          reserve = locationDef.reserve,
        }
      else
        relativeResolutionFailed = true
        break
      end
    end

    if not relativeResolutionFailed then
      table.insert(instances, {
        id = contractID,
        name = resolvedName,
        description = resolvedDescription,
        locations = resolvedLocations,
        phases = contract.phases,
      })
    end
  end

  return instances
end

--- Resolves a contract property based on the options defined in the contract. If the property is a string, it is
--- returned directly. If it is a table, a random entry is selected and returned.
--- @param propertyOption string|table The property option defined in the contract. Can be a string or a table of strings.
--- @return string # The resolved contract property.
function PLUGIN.resolveContractProperty(propertyOption)
  if type(propertyOption) == "string" then
    return propertyOption
  elseif type(propertyOption) == "table" and #propertyOption > 0 then
    return propertyOption[math.random(1, #propertyOption)]
  else
    error("Invalid contract property option: expected string or non-empty table of strings")
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
    variantKey = preparedContract.variantKey,
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

  -- Mark the contract instance as taken and store hash for cleanup
  local instanceHash = PLUGIN.generateContractInstanceHash(preparedContract.id, preparedContract.locations)
  player._VersusContractInstanceHash = instanceHash

  if role == "first" then
    -- Only first players "own" the instance
    PLUGIN.markContractInstanceTaken(instanceHash, player)

    -- Broadcast to other players that this contract instance is now taken
    PLUGIN.broadcastContractAvailabilityUpdate(instanceHash, false, player)
  end

  PLUGIN.handleContractPhase(player, preparedContract.phases[player._VersusCurrentContract.phaseIndex])

  hook.Run("PlayerSelectedContract", player, preparedContract, preparedContract.id)
end

--- Makes the given contracts available to the player. This should be called when the player first becomes
--- eligible for these contracts (e.g: upon joining the game or completing a previous contract).
--- All valid entity combinations for each contract are generated and stored as separate variant instances,
--- each keyed as "contractID_N". Variants whose entities are taken will appear as unavailable in the UI.
--- @param player Player The player to make the contracts available for.
--- @param contractIDs table A list of contract IDs to make available to the player.
function PLUGIN.makeContractsAvailableToPlayer(player, contractIDs)
  player._VersusAvailableContracts = player._VersusAvailableContracts or {}

  for _, contractID in ipairs(contractIDs) do
    local instances = PLUGIN.prepareContractForPlayer(player, contractID)

    if #instances == 0 then
      -- Can happen if the contract is map-specific and the player is on the wrong map.
      continue
    end

    for variantIndex, preparedContract in ipairs(instances) do
      local variantKey = contractID .. "_" .. variantIndex
      preparedContract.variantKey = variantKey
      player._VersusAvailableContracts[variantKey] = preparedContract
    end
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

  if (bag) then
    PLUGIN.cleanupPhase(player, bag)
    PLUGIN.cleanupContract(player, bag)
  end

  hook.Run("PlayerContractCompleted", player, contract)

  versus.rewards.showContractRewardScreen(
    player,
    "Contract Completed!",
    "You have successfully completed the contract."
  )

  PLUGIN.removeContractItems(player)

  -- TODO: Store ammo
  versus.weapon.holsterAllWeaponItems(player)

  player:KillSilent()

  -- Clean up linkages if this is a subsequent player
  if player._VersusContractLinkedTo and IsValid(player._VersusContractLinkedTo) then
    PLUGIN.unlinkContractInstance(player._VersusContractLinkedTo, player)
  end

  -- Fail all linked subsequent players if this is a first player
  if player._VersusContractSubsequents then
    for _, subsequentPlayer in ipairs(player._VersusContractSubsequents) do
      if IsValid(subsequentPlayer) and subsequentPlayer._VersusCurrentContract then
        -- Recursively fail the subsequent player's contract
        PLUGIN.failContract(subsequentPlayer, "The primary contractor's mission has been completed.")
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

  -- Free the contract instance and broadcast availability update
  if player._VersusContractInstanceHash and player._VersusContractRole == "first" then
    PLUGIN.freeContractInstance(player._VersusContractInstanceHash)
    PLUGIN.broadcastContractAvailabilityUpdate(player._VersusContractInstanceHash, true, player)
  end

  -- Clear the contract
  player._VersusCurrentContract = nil
  player._VersusContractRole = nil
  player._VersusContractInstanceID = nil
  player._VersusContractInstanceHash = nil
end

--- Gets an entity based on a location reference. A location reference is a table that contains a locationKey
--- and a distance modifier (e.g: NEAR_TO_LOCATION, FAR_FROM_LOCATION, or EXACT). This function will resolve
--- the location from the player's prepared contract and return the entity.
--- @see PLUGIN.referToContractLocation for creating location references
--- @param player Player The player for whom we are trying to get the entity.
--- @param locationReference table The location reference table created with PLUGIN.referToContractLocation
--- @return Entity? # The entity that matches the location reference, or nil if no matching entity is found.
function PLUGIN.getEntityFromReference(player, locationReference)
  -- Get the prepared contract instance for this player using the variant key
  local lookupKey = player._VersusCurrentContract.variantKey or player._VersusCurrentContract.id
  local preparedContract = player._VersusAvailableContracts and
      player._VersusAvailableContracts[lookupKey]

  if not preparedContract or not preparedContract.locations then
    error("Player does not have a prepared contract or contract has no locations")
    return nil
  end

  local locationDef = preparedContract.locations[locationReference.locationKey]
  if not locationDef then
    error("Location key not found in prepared contract: " .. tostring(locationReference.locationKey))
    return nil
  end

  -- For prepared contracts, locations are already resolved, so we always return the resolved entity
  -- The distance modifier was used during preparation to select the appropriate entity
  -- Now we just return what was already resolved to ensure consistency
  return locationDef.entity
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
    ErrorNoHaltWithStack("Attempted to complete contract for player who does not have an active contract")
    return
  end

  PLUGIN.handleContractCompletion(player, PLUGIN.getContract(player._VersusCurrentContract.id))
end)

-- Fails the contract with a reason
PLUGIN.registerContractFunction("failContract", function(player, bag, reason)
  if not player._VersusCurrentContract then
    ErrorNoHaltWithStack("Attempted to fail contract for player who does not have an active contract")
    return
  end

  PLUGIN.failContract(player, reason)
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
    -- Give the subsequent entry its own variantKey so getEntityFromReference can find it
    -- We must not mutate the first player's preparedContract, so we create a shallow copy
    local subsequentPrepared = {}
    for k, v in pairs(data.preparedContract) do subsequentPrepared[k] = v end
    subsequentPrepared.variantKey = subsequentID
    player._VersusAvailableContracts[subsequentID] = subsequentPrepared
    player._VersusSubsequentContractData[subsequentID] = data
  end

  -- Pick a random initial display set and network it
  PLUGIN.rollContractsForPlayer(player)
end

--- Randomly selects up to PLUGIN.displayContractCount contracts from the player's full available
--- pool and stores them as the displayed set, then networks them to the client.
--- @param player Player The player to roll contracts for
function PLUGIN.rollContractsForPlayer(player)
  local availableContracts = player._VersusAvailableContracts or {}

  -- Build a shuffled list of all variant keys
  local keys = {}
  for key, _ in pairs(availableContracts) do
    table.insert(keys, key)
  end

  -- Fisher-Yates shuffle
  for i = #keys, 2, -1 do
    local j = math.random(i)
    keys[i], keys[j] = keys[j], keys[i]
  end

  -- Take up to displayContractCount
  local displayed = {}
  for i = 1, math.min(PLUGIN.displayContractCount, #keys) do
    displayed[keys[i]] = true
  end

  player._VersusDisplayedContracts = displayed

  PLUGIN.networkContractsToPlayer(player)
end

--- Networks the player's available contracts to the client
--- @param player Player The player to network contracts to
function PLUGIN.networkContractsToPlayer(player)
  -- Only network the displayed subset (set by rollContractsForPlayer)
  local availableContracts = player._VersusAvailableContracts or {}
  local displayedContracts = player._VersusDisplayedContracts or {}
  local contractList = {}

  -- Convert to list for networking and assign numeric IDs
  local numericID = 1
  player._VersusContractIDMap = player._VersusContractIDMap or {}
  player._VersusContractIDMap = {} -- Reset the map

  for contractID, preparedContract in pairs(availableContracts) do
    if not displayedContracts[contractID] then
      continue
    end
    -- Check if this is a subsequent contract
    local subsequentData = player._VersusSubsequentContractData and player._VersusSubsequentContractData[contractID]
    -- For variant keys ("some_contract_1") and subsequent contracts, the real contract ID is stored on preparedContract.id
    local originalContractID = subsequentData and subsequentData.originalContractID or preparedContract.id
    local contract = PLUGIN.getContract(originalContractID)

    if contract then
      -- Map numeric ID to string ID for this player
      player._VersusContractIDMap[numericID] = contractID

      -- Check if this contract instance is already taken
      -- Use preparedContract.id (the original contract ID) for hashing, not the variant key
      local instanceHash = PLUGIN.generateContractInstanceHash(preparedContract.id, preparedContract.locations)
      local isTaken = PLUGIN.isContractInstanceTaken(instanceHash)

      table.insert(contractList, {
        numericID = numericID,
        id = contractID,
        name = preparedContract.name .. (subsequentData and " [INTERFERENCE]" or ""),
        description = preparedContract.description,
        image = contract.image or "",
        enabled = not isTaken,
        unavailableReason = isTaken and "CONTRACT NO LONGER AVAILABLE" or nil,
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
    net.WriteString(contractData.description)
    net.WriteString(contractData.image)
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
  -- Show death screen before showing contract selection again.
  net.Start("versus.contracts.forceReselectContract")
  net.Send(player)

  -- Network existing contracts again
  PLUGIN.networkContractsToPlayer(player)
end

--- Broadcasts a contract instance availability update to all players except the specified player.
--- This is used when a contract is taken or freed to update other players' UI in real-time.
--- @param instanceHash string The instance hash that changed availability
--- @param isNowAvailable boolean True if the instance is now available, false if it's taken
--- @param excludePlayer? Player Optional player to exclude from the broadcast
function PLUGIN.broadcastContractAvailabilityUpdate(instanceHash, isNowAvailable, excludePlayer)
  local playerIterator = player.Iterator
  local unavailableReason = isNowAvailable and "" or "CONTRACT NO LONGER AVAILABLE"

  for _, ply in playerIterator() do
    if ply == excludePlayer then continue end
    if not ply._VersusAvailableContracts then continue end
    if not ply._VersusContractIDMap then continue end

    -- Find contracts in this player's list that match the instance hash
    local affectedContracts = {}

    for contractID, preparedContract in pairs(ply._VersusAvailableContracts) do
      if preparedContract.locations then
        -- Use preparedContract.id (original contract ID) for hashing, not the variant key
        local contractInstanceHash = PLUGIN.generateContractInstanceHash(preparedContract.id, preparedContract.locations)

        if contractInstanceHash == instanceHash then
          -- Find the numeric ID for this contract
          for numericID, mappedContractID in pairs(ply._VersusContractIDMap) do
            if mappedContractID == contractID then
              table.insert(affectedContracts, {
                numericID = numericID,
                enabled = isNowAvailable
              })
              break
            end
          end
        end
      end
    end

    -- Send update if this player has affected contracts
    if #affectedContracts > 0 then
      net.Start("versus.contracts.updateContractAvailability")
      net.WriteUInt(#affectedContracts, 8)

      for _, contractUpdate in ipairs(affectedContracts) do
        net.WriteUInt(contractUpdate.numericID, PLUGIN.bitCountContractID)
        net.WriteBool(contractUpdate.enabled)

        if not contractUpdate.enabled then
          net.WriteString(unavailableReason)
        end
      end

      net.Send(ply)
    end
  end
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
