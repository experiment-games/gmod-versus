local PLUGIN = PLUGIN

--- Handler: fireInputs
---
--- Fires inputs on all entities within a radius of each specified location. Each
--- entry in the table defines a separate location/range/input combination,
--- allowing multiple independent inputs to be fired in a single phase key.
--- This could be used to trigger traps, open doors, or anything else that can be
--- done with inputs.
---
--- Schema:
--- {
---   {
---     location = PLUGIN.referToContractLocation("someKey"), -- location
---     range    = number, -- radius around the location to search for inputs to fire
---     input    = string, -- name of the input to fire on all entities in the area
---     param    = any?, -- optional param to send with the input (default "")
---     delay    = number?, -- optional delay in seconds before firing the inputs (default 0)
---   },
---   { ... }
--- }
PLUGIN.registerContractPhaseKeyHandler("fireInputs", function(player, bag, data)
  for _, entry in ipairs(data) do
    local locationReference = entry.location
    local entity = PLUGIN.getEntityFromReference(player, locationReference)

    if (not IsValid(entity)) then
      error(
        "Failed to find entity for contract phase fireInputs key with location reference: "
        .. util.TableToJSON(locationReference)
      )
    end

    local inputName = entry.input
    local range = entry.range
    local inputParam = entry.param or ""
    local delay = entry.delay or 0
    local entities = ents.FindInSphere(entity:GetPos(), range)

    for _, ent in ipairs(entities) do
      ent:Fire(inputName, inputParam, delay)
    end
  end
end)
