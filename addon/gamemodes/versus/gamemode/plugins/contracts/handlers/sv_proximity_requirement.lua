local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("proximityRequirement", function(player, bag, data)
  local locationReference = data.location
  local entity = PLUGIN.getEntityFromReference(player, locationReference)

  if not IsValid(entity) then
    error(
      "Failed to find entity for contract phase proximityRequirement key with location reference: "
      .. util.TableToJSON(locationReference)
    )
    return
  end

  -- Ensure the player is within the required distance from the entity
  local entityPos = entity:GetPos()

  versus.objectives.addObjectiveRadiusRender(player, "phaseProximity", entityPos, data.maxDistance)

  PLUGIN.createPhaseTimer(player, bag, "proximityRequirement", 1, 0, function()
    if not IsValid(entity) then
      return
    end

    local playerPos = player:GetPos()
    local entityPos = entity:GetPos()
    local distance = playerPos:Distance(entityPos)

    if (distance <= data.maxDistance) then
      if (bag.phase.proximityWarningGiven) then
        -- Player has returned in range after being out of range, show return message and call return callback
        if (data.returnInRangeMessage) then
          versus.message.addChat(player, nil, "local", data.returnInRangeMessage)
        end

        PLUGIN.callContractFunction(player, bag, data.returnInRangeCallback)
      end

      -- Reset warning
      bag.phase.proximityWarningGiven = false

      return
    end

    -- Only warn once while out of range
    if bag.phase.proximityWarningGiven then
      return
    end

    bag.phase.proximityWarningGiven = true

    -- Player is out of range, show warning and call failure callback
    if (data.warningMessage) then
      versus.message.addChat(player, nil, "local", data.warningMessage)
    end

    PLUGIN.callContractFunction(player, bag, data.outOfRangeCallback)
  end)
end)

PLUGIN.registerContractPhaseKeyHandler("clearProximityRequirement", function(player, bag, data)
  versus.objectives.removeObjectiveRadiusRender(player, "phaseProximity")
  -- Timer will be cleaned up automatically by cleanupPhase
end)
