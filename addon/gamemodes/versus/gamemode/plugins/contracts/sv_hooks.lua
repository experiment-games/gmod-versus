local PLUGIN = PLUGIN

local playerIterator = player.Iterator

util.AddNetworkString("versus.contracts.selectContract")
util.AddNetworkString("versus.contracts.selectedContract")
util.AddNetworkString("versus.contracts.forceReselectContract")
util.AddNetworkString("versus.contracts.playerEliminated")
util.AddNetworkString("versus.contracts.closeSelectionPanel")

--[[
  Hooks
--]]

-- On think, we check if players in a certain contract phase should progress to the next phase based on the
-- contract's 'completeCallback' key. This key holds a table where the first value is the function that checks for
-- completion and the other values are arguments to pass to that function.
-- If the function returns true, the player progresses to the next phase.
function PLUGIN.hook:Think()
  for _, player in playerIterator() do
    if not player._VersusCurrentContract then
      continue
    end

    local contract = player._VersusCurrentContract and PLUGIN.getContract(player._VersusCurrentContract.id)

    if not contract then
      continue
    end

    local currentPhase = contract.phases[player._VersusCurrentContract.phaseIndex]

    -- Get the role-appropriate phase
    local role = player._VersusContractRole or "first"
    local actualPhase = PLUGIN.getPhaseForRole(currentPhase, role)

    if not actualPhase.completeCallback then
      -- Some handler will probably force with the 'completePhase' function
      continue
    end

    local isComplete = PLUGIN.callContractFunction(
      player,
      player._VersusCurrentContract.bag,
      actualPhase.completeCallback,
      "Contract phase has 'completeCallback' key but completion function is not registered"
    )

    if not isComplete then
      continue
    end

    PLUGIN.handleContractPhaseCompletion(player)
  end

  -- Auto-progress bots through contract phases for testing
  for _, bot in playerIterator() do
    if not bot:IsBot() or not bot._VersusCurrentContract then
      continue
    end

    -- Skip if already in progress or waiting for something
    if bot._VersusBotContractWaitUntil and CurTime() < bot._VersusBotContractWaitUntil then
      continue
    end

    -- Get current phase
    local contract = PLUGIN.getContract(bot._VersusCurrentContract.id)
    if not contract then continue end

    local phase = contract.phases[bot._VersusCurrentContract.phaseIndex]
    if not phase then continue end

    local role = bot._VersusContractRole or "first"
    local actualPhase = PLUGIN.getPhaseForRole(phase, role)

    -- Auto-complete phases that have completeCallback after a delay
    if actualPhase.completeCallback then
      -- Let the normal Think completion handler deal with it
      continue
    end

    -- For phases without auto-completion, simulate interaction
    -- Look for entities handler and auto-interact
    if actualPhase.entities then
      for _, entityConfig in ipairs(actualPhase.entities) do
        if entityConfig.InteractionCallback then
          local locationRef = entityConfig.location
          local entity = PLUGIN.getEntityFromReference(bot, locationRef)

          if IsValid(entity) and entity:GetPos():Distance(bot:GetPos()) < 200 then
            -- Bot is near, trigger interaction
            PLUGIN.callContractFunction(bot, bot._VersusCurrentContract.bag, entityConfig.InteractionCallback)
            bot._VersusBotContractWaitUntil = CurTime() + 2 -- Wait 2 seconds before next action
            break
          end
        end
      end
    end
  end
end

function PLUGIN.hook:PlayerSelectSpawn(player)
  if (not player._VersusPreferedSpawnPoint) then
    return
  end

  local spawnPoint = player._VersusPreferedSpawnPoint
  player._VersusPreferedSpawnPoint = nil -- Clear it so it doesn't interfere with future spawns

  return spawnPoint
end

-- We stop the player from spawning, up until they select a contract and are ready to play.
-- We must still call :Spawn() on the player to spawn them after setting _VersusCurrentContract.
function PLUGIN.hook:PlayerDeathThink(player)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  if (not player._VersusCurrentContract) then
    return false
  end
end

-- On initialization we generate contracts for the player to select from, and show the contract selection UI.
function PLUGIN.hook:PlayerInitialized(player)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  PLUGIN.generateContractsForPlayer(player)
end

-- For now players cannot try again after death, but will have to take up a new contract.
function PLUGIN.hook:CanPlayerRespawnInTime(player, attacker)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  return false
end

-- When the player dies, we fade and remove any items we spawned specifically for them
function PLUGIN.hook:PostPlayerDeath(player, attacker, inflictor)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  for _, item in ipairs(player._VersusLootItems or {}) do
    if (IsValid(item)) then
      versus.util.decayEntity(item, 5)
    end
  end

  player._VersusLootItems = nil
end

function PLUGIN.hook:PlayerDeath(player, inflictor, attacker)
  if (hook.Run("PlayerShouldSelectContract", player) == false) then
    return
  end

  -- Clean up entity reservations
  PLUGIN.cleanupContractReservations(player)

  -- Fail the player's contract if they have one
  -- This will handle cleanup of linked players, timers, objectives, NPCs, etc.
  if player._VersusCurrentContract then
    local message = "You were eliminated"

    if IsValid(attacker) then
      if attacker:IsPlayer() then
        message = "You were eliminated by " .. attacker:Nick()
      elseif attacker:IsNPC() then
        message = "You were eliminated by hostile forces"
      end
    end

    PLUGIN.showEliminationScreen(player, message)

    PLUGIN.failContract(player, "You died.")
  end
end

-- When a player USEs an escort NPC, start the follow behavior and fire followCallback.
function PLUGIN.hook:PlayerUse(player, entity)
  if not IsValid(entity) or not entity:IsNPC() then
    return
  end

  if entity._VersusEscortOwner ~= player then
    return
  end

  if entity._VersusEscortFollowing then
    -- Commented, so if the NPC loses the player, they won't refuse to follow again.
    -- They will just start following again on next use.
    -- return
  end

  entity._VersusEscortFollowing = true

  versus.npc.setFollow(entity, player)

  local bag = entity._VersusEscortBag
  if entity._VersusEscortFollow then
    PLUGIN.callContractFunction(
      player,
      bag,
      entity._VersusEscortFollow,
      "Contract escortNPC followCallback is set but function is not registered"
    )
  end
end

-- When an escort NPC is killed, fire deathCallback for the owning player.
-- When a killTarget NPC is killed, fire killCallback for the owning player.
function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  if not IsValid(npc) then
    return
  end

  -- escortNPCs handler
  local escortPlayer = npc._VersusEscortOwner
  local escortBag    = npc._VersusEscortBag

  if IsValid(escortPlayer) and escortPlayer._VersusCurrentContract and npc._VersusEscortDeath then
    PLUGIN.callContractFunction(
      escortPlayer,
      escortBag,
      npc._VersusEscortDeath,
      "Contract escortNPC deathCallback is set but function is not registered"
    )
  end

  -- killTarget handler
  local killPlayer = npc._VersusKillTargetOwner
  local killBag    = npc._VersusKillTargetBag

  if IsValid(killPlayer) and killPlayer._VersusCurrentContract and npc._VersusKillTargetCallback then
    PLUGIN.callContractFunction(
      killPlayer,
      killBag,
      npc._VersusKillTargetCallback,
      "Contract killTarget killCallback is set but function is not registered"
    )
  end
end

-- Clean up contract linkages on player disconnect
function PLUGIN.hook:PlayerSaveDisconnect2(player)
  -- Clean up entity reservations
  PLUGIN.cleanupContractReservations(player)

  -- Fail the player's contract if they have one
  -- This will handle cleanup of linked players, timers, objectives, NPCs, etc.
  if player._VersusCurrentContract then
    -- Don't notify the disconnecting player (they won't see it anyway)
    -- But failContract will still handle all the cleanup and notify linked players
    PLUGIN.failContract(player, "disconnected")
  end
end

-- Remove items gained during the contract session before player data is saved on disconnect,
-- so players cannot exploit disconnecting to persist items they should only keep by extracting.
function PLUGIN.hook:PlayerSaveDisconnect(player)
  if not player._VersusCurrentContract then
    return
  end

  local preContractItemKeys = player._VersusCurrentContract.preContractItemKeys or {}
  local inventory = player:getCharacter("inventory")

  for key, item in pairs(inventory) do
    if not preContractItemKeys[key] then
      versus.inventory.takeItem(player, item, 1)
    end
  end
end

--[[
  Console Commands
--]]

concommand.Add("versus_debug_points_between", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  if (not player._VersusContract) then
    versus.message.notify(player, "You must select a contract first to use this command.", NOTIFY_ERROR)
    return
  end

  local start = player._VersusContract.spawnPoint:GetPos()
  local extraction = player._VersusContract.extractionPoint:GetPos()
  local points = PLUGIN.getSpawnNPCPointsBetween(start, extraction)

  -- Draw debug lines to the points for 10 seconds
  for _, pos in ipairs(points) do
    debugoverlay.Cross(pos, 16, 10, Color(255, 0, 0), true)
  end

  local sortedPoints = PLUGIN.categorizeSpawnPoints(points, start, extraction)
  PrintTable(sortedPoints)
end)

concommand.Add("versus_skip_selection", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  player:Spawn()

  net.Start("versus.contracts.closeSelectionPanel")
  net.Send(player)
end)

-- Bot testing commands
concommand.Add("versus_bot_assign_contract", function(player, command, args)
  if not player:IsAdmin() then return end

  local botName = args[1]
  local contractID = args[2]

  if not botName or not contractID then
    versus.message.notify(player, "Usage: versus_bot_assign_contract <botname> <contractID>", NOTIFY_ERROR)
    return
  end

  -- Find bot by name
  local bot = nil
  for _, ply in playerIterator() do
    if ply:IsBot() and string.find(string.lower(ply:Nick()), string.lower(botName)) then
      bot = ply
      break
    end
  end

  if not bot then
    versus.message.notify(player, "Bot not found: " .. botName, NOTIFY_ERROR)
    return
  end

  -- Verify contract exists
  local contract = PLUGIN.getContract(contractID)
  if not contract then
    versus.message.notify(player, "Contract not found: " .. contractID, NOTIFY_ERROR)
    return
  end

  -- Prepare all variants and store them in the bot's available contracts
  PLUGIN.makeContractsAvailableToPlayer(bot, { contractID })

  -- Pick the first available (unreserved) variant
  local preparedContract = nil
  for variantKey, instance in pairs(bot._VersusAvailableContracts or {}) do
    if instance.id == contractID then
      local reserved = PLUGIN.reserveContractLocations(bot, contractID, instance.locations)
      if reserved then
        preparedContract = instance
        break
      end
    end
  end

  if not preparedContract then
    versus.message.notify(
      player,
      "Failed to reserve contract locations (no variants available or all taken)",
      NOTIFY_ERROR
    )

    return
  end

  -- Assign and spawn
  PLUGIN.assignContractToPlayer(bot, preparedContract, "first", nil)

  versus.message.notify(player, "Assigned contract '" .. contractID .. "' to bot: " .. bot:Nick(), NOTIFY_GENERIC)
end)

concommand.Add("versus_bot_progress_phase", function(player, command, args)
  if not player:IsAdmin() then return end

  local botName = args[1]

  if not botName then
    versus.message.notify(player, "Usage: versus_bot_progress_phase <botname>", NOTIFY_ERROR)
    return
  end

  -- Find bot
  local bot = nil
  for _, ply in playerIterator() do
    if ply:IsBot() and string.find(string.lower(ply:Nick()), string.lower(botName)) then
      bot = ply
      break
    end
  end

  if not bot or not bot._VersusCurrentContract then
    versus.message.notify(player, "Bot not found or has no active contract", NOTIFY_ERROR)
    return
  end

  -- Manually trigger phase completion
  PLUGIN.handleContractPhaseCompletion(bot)

  versus.message.notify(player, "Advanced bot to phase " .. bot._VersusCurrentContract.phaseIndex, NOTIFY_GENERIC)
end)

concommand.Add("versus_bot_contract_status", function(player, command, args)
  if not player:IsAdmin() then return end

  local botName = args[1]

  -- Find bot
  for _, bot in playerIterator() do
    if bot:IsBot() and (not botName or string.find(string.lower(bot:Nick()), string.lower(botName))) then
      if bot._VersusCurrentContract then
        local contract = PLUGIN.getContract(bot._VersusCurrentContract.id)
        local role = bot._VersusContractRole or "first"
        local phase = contract.phases[bot._VersusCurrentContract.phaseIndex]
        local actualPhase = PLUGIN.getPhaseForRole(phase, role)

        print(string.format(
          "Bot: %s | Contract: %s | Role: %s | Phase: %d/%d | Interferable: %s",
          bot:Nick(),
          bot._VersusCurrentContract.id,
          role,
          bot._VersusCurrentContract.phaseIndex,
          #contract.phases,
          PLUGIN.isPhaseInterferable(phase) and "YES" or "NO"
        ))

        if PLUGIN.isPhaseInterferable(phase) then
          print("  - maxSubsequent: " .. (phase.maxSubsequent or 1))
          print("  - Current subsequent count: " .. #(bot._VersusContractSubsequents or {}))
        end
      else
        print(string.format("Bot: %s | No active contract", bot:Nick()))
      end

      if not botName then continue else break end
    end
  end
end)

concommand.Add("versus_regenerate_contracts", function(player, command, args)
  if not player:IsAdmin() then return end

  -- Clear existing contracts
  player._VersusAvailableContracts = nil
  player._VersusSubsequentContractData = nil
  player._VersusContractIDMap = nil

  -- Regenerate (will include subsequent contracts from bot contracts)
  PLUGIN.generateContractsForPlayer(player)

  versus.message.notify(player, "Contracts regenerated", NOTIFY_GENERIC)
end)

concommand.Add("versus_progress_phase", function(player, command, args)
  if (not player:IsAdmin()) then
    return
  end

  if (not player._VersusCurrentContract) then
    versus.message.notify(player, "You must have an active contract to use this command.", NOTIFY_ERROR)
    return
  end

  PLUGIN.handleContractPhaseCompletion(player)
end)

concommand.Add("versus_list_contracts", function(player, command, args)
  if not player:IsAdmin() then return end

  print("\n=== Registered Contracts ===")
  local contractList = {}
  for contractID, _ in pairs(PLUGIN.contracts) do
    table.insert(contractList, contractID)
  end
  table.sort(contractList)

  for _, contractID in ipairs(contractList) do
    local contract = PLUGIN.getContract(contractID)
    local name = type(contract.name) == "table" and contract.name[1] or contract.name
    local tagLabels = {}
    for _, tag in ipairs(contract.tags or {}) do
      table.insert(tagLabels, tag.label or "?")
    end
    local tagsText = #tagLabels > 0 and table.concat(tagLabels, ", ") or "none"
    print(string.format("  %s - %s [Tags: %s, Phases: %d]", contractID, name, tagsText,
      #contract.phases))
  end
  print("===========================\n")
end)

concommand.Add("versus_dump_player_contracts", function(player, command, args)
  if not player:IsAdmin() then return end

  -- Resolve target player: first arg is a name substring, defaults to self
  local targetPlayer = player
  if args[1] then
    for _, ply in playerIterator() do
      if string.find(string.lower(ply:Nick()), string.lower(args[1])) then
        targetPlayer = ply
        break
      end
    end
  end

  local available  = targetPlayer._VersusAvailableContracts or {}
  local displayed  = targetPlayer._VersusDisplayedContracts or {}
  local subsequent = targetPlayer._VersusSubsequentContractData or {}

  print(string.format("\n=== Player contracts for %s ===", targetPlayer:Nick()))
  print(string.format("  Available variants : %d", table.Count(available)))
  print(string.format("  Displayed variants : %d", table.Count(displayed)))

  -- Collect and sort keys so output is stable
  local keys = {}
  for key in pairs(available) do table.insert(keys, key) end
  table.sort(keys)

  for _, variantKey in ipairs(keys) do
    local pc          = available[variantKey]
    local isDisplayed = displayed[variantKey] and "[DISPLAYED]" or ""
    local isSubseq    = subsequent[variantKey] and "[SUBSEQUENT]" or ""

    print(string.format("\n  -- %s %s%s", variantKey, isDisplayed, isSubseq))
    print(string.format("     Name        : %s", tostring(pc.name)))
    print(string.format("     Description : %s", tostring(pc.description)))

    if pc.locations and table.Count(pc.locations) > 0 then
      -- Sort location keys for a stable, easy-to-compare listing
      local locKeys = {}
      for k in pairs(pc.locations) do table.insert(locKeys, k) end
      table.sort(locKeys)

      for _, locKey in ipairs(locKeys) do
        local loc = pc.locations[locKey]
        local entIndex = IsValid(loc.entity) and loc.entity:EntIndex() or "INVALID"
        local pos = IsValid(loc.entity) and loc.entity:GetPos() or Vector(0, 0, 0)
        print(string.format(
          "     Location [%s] : EntIndex=%s  class=%-36s  hidden=%-5s  pos=(%.0f, %.0f, %.0f)",
          locKey,
          tostring(entIndex),
          tostring(loc.class),
          tostring(loc.hidden or false),
          pos.x, pos.y, pos.z
        ))
      end
    else
      print("     Locations   : (none)")
    end
  end

  print(string.format("\n=== End of contracts for %s ===\n", targetPlayer:Nick()))
end)

--[[
  Net Messages
--]]

net.Receive("versus.contracts.selectContract", function(len, player)
  local numericContractID = net.ReadUInt(PLUGIN.bitCountContractID)

  -- Convert numeric ID back to string ID
  local contractID = player._VersusContractIDMap and player._VersusContractIDMap[numericContractID]

  if not contractID then
    ErrorNoHalt("Player selected invalid contract ID: " .. tostring(numericContractID) .. "\n")
    return
  end

  -- Get the prepared contract for this player
  local preparedContract = player._VersusAvailableContracts and player._VersusAvailableContracts[contractID]

  if not preparedContract then
    ErrorNoHalt("Player does not have prepared contract: " .. contractID .. "\n")
    return
  end

  -- Check if this is a subsequent contract
  local subsequentData = player._VersusSubsequentContractData and player._VersusSubsequentContractData[contractID]
  local role = subsequentData and "subsequent" or "first"
  local linkedToPlayer = subsequentData and subsequentData.firstPlayer or nil

  -- Verify the first player is still valid for subsequent contracts
  if role == "subsequent" then
    if not IsValid(linkedToPlayer) or not linkedToPlayer._VersusCurrentContract then
      versus.message.notify(player, "This interference contract is no longer available.", NOTIFY_ERROR)
      PLUGIN.generateContractsForPlayer(player) -- Refresh contracts
      return
    end

    -- Subsequent contracts share the first player's entities, so we don't need to reserve
  elseif role == "first" then
    -- NOW we reserve the entities for this player
    -- Use preparedContract.id (the original contract ID, not the variant key) for reservation tracking
    local reserved = PLUGIN.reserveContractLocations(player, preparedContract.id, preparedContract.locations)

    if not reserved then
      -- Some entities are no longer available (another player took them)
      versus.message.notify(player, "This contract is no longer available. Entities are in use.", NOTIFY_ERROR)
      PLUGIN.generateContractsForPlayer(player) -- Refresh contracts with newly available options
      return
    end
  end

  -- Allow other plugins (e.g. radiation) to block contract acceptance.
  local canAccept, message = hook.Run("PlayerCanAcceptContract", player, preparedContract)
  if canAccept == false then
    if (message) then
      versus.message.notify(player, message, NOTIFY_ERROR)
    end

    return
  end

  -- Assign the contract to the player
  PLUGIN.assignContractToPlayer(player, preparedContract, role, linkedToPlayer)

  -- Network the selection back to client
  net.Start("versus.contracts.selectedContract")
  net.WriteUInt(numericContractID, PLUGIN.bitCountContractID)
  net.Send(player)
end)

net.Receive("versus.contracts.rerollContracts", function(len, player)
  if not player._VersusAvailableContracts then return end
  if player._VersusCurrentContract then return end -- already in a contract

  -- Enforce reroll cooldown
  local now = CurTime()
  if player._VersusLastRerollTime and (now - player._VersusLastRerollTime) < PLUGIN.rerollContractTimeout then
    return
  end

  PLUGIN.rollContractsForPlayer(player)
end)
