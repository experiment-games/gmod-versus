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
  local playerPos = player:GetPos()
  local entityPos = entity:GetPos()
  local distance = playerPos:Distance(entityPos)

  if (not bag.phase.networkedProximityRequirement) then
    bag.phase.networkedProximityRequirement = true
    -- Show range we commented in: addon/gamemodes/versus/gamemode/plugins/objectives/cl_hooks.lua
  end

  if (distance <= data.maxDistance) then
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
  versus.message.addChat(player, nil, "warning", data.warningMessage)

  local callbackFunc = PLUGIN.getContractFunction(data.callbackOnFail[1])

  if not callbackFunc then
    error("Contract phase proximityRequirement key has callbackOnFail but function is not registered: " ..
      tostring(data.callbackOnFail[1]))
    return
  end

  local args = { unpack(data.callbackOnFail, 2) }
  callbackFunc(player, bag, unpack(args))
end)
