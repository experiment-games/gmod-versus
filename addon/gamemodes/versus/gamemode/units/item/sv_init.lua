local UNIT = UNIT

function UNIT.createInstance(itemOrID)
  local itemID = itemOrID

  if (type(itemOrID) == "table") then
    itemID = itemOrID.itemID
  end

  return setmetatable({}, FindMetaTable("VersusItemInstance")):init({
    itemID = itemID
  })
end

function UNIT.use(player, item)
  if (not item.onUse) then
    return false
  end

  if (item:onUse(player) == false) then
    return false
  end

  return true
end

function UNIT.destroy(player, item)
  if (not item.onDestroy) then
    return false
  end

  if (item:onDestroy(player) == false) then
    return false
  end

  return true
end

-- Spawns an item entity at the specified position.
function UNIT.make(item, position)
  local entity = ents.Create("versus_item")

  entity:SetItem(item)
  entity:SetPos(position)
  entity:Spawn()

  return entity
end

function UNIT.spawn(player, item, position)
  if (not item.onDrop) then
    return false
  end

  local onDropEntity = item:onDrop(player, position)

  if (onDropEntity == false) then
    return false
  end

  if (IsValid(onDropEntity)) then
    return true, onDropEntity
  end

  if (not position) then
    position = player:GetEyeTraceNoCursor().HitPos

    position.z = position.z + 16
  end

  local entity = UNIT.make(item, position)

  if (item.onDropped) then
    item:onDropped(player, entity)
  end

  return true, entity
end

--- Spawns an shipment entity at the specified position.
--- @param items VersusItemInstance[]
--- @param position Vector
--- @return Entity
function UNIT.makeShipment(items, position)
  local entity = ents.Create("versus_shipment")

  entity:SetItems(items)
  entity:SetPos(position)
  entity:Spawn()

  return entity
end

function UNIT.spawnShipment(player, items, position)
  if (not position) then
    position = player:GetEyeTraceNoCursor().HitPos

    position.z = position.z + 16
  end

  local entity = UNIT.makeShipment(items, position)

  return entity
end

function UNIT.hook:PlayerPickedUpVersusItem(player, entity, item)
  player:EmitSound("items/itempickup.wav", 75, 100, 1, CHAN_ITEM)
end
