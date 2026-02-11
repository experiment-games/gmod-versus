local PLUGIN = PLUGIN

-- TODO: We need to reserve entities so other players cannot get in the way. Now if player A and
-- TODO: player B both have a contract with entity X, one could SetInteractionName to 'Combine Relay' and the other might set it to 'Secret Stash'.
-- TODO: In that case the last one would override the other, while we might want both to exist? Nah we should just reserve it so others cannot use it.
PLUGIN.registerContractPhaseKeyHandler("entities", function(player, bag, data)
  local setupEntity = function(entityData)
    local entity = PLUGIN.getEntityFromReference(player, entityData.entity)

    if not IsValid(entity) then
      error("Failed to find entity for contract phase entities key with location reference: " ..
        util.TableToJSON(entityData.entity))
      return
    end

    if istable(entityData.accessors) then
      for accessorKey, accessorData in pairs(entityData.accessors) do
        -- Special case for InteractionCallback since it needs the player injected as the first parameter to the callback function
        if accessorKey == "InteractionCallback" then
          entity:SetInteractionCallback(player, function()
            PLUGIN.callContractFunction(
              player,
              bag,
              accessorData,
              "Contract phase entities key has InteractionCallback accessor but function is not registered"
            )
          end)
        else
          local setter = entity["Set" .. accessorKey]

          if not setter or type(setter) ~= "function" then
            error("Entity does not have a setter function for accessor: " .. accessorKey)
            continue
          end

          setter(entity, accessorData)
        end
      end
    end
  end

  if (not istable(data)) then
    error("Data for contract phase entities key is not a table: " .. tostring(data))
  end

  for _, entityData in ipairs(data) do
    setupEntity(entityData)
  end
end)
