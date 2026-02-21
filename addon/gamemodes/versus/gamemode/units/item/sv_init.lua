local UNIT = UNIT

function UNIT.createInstance(itemOrID)
  local itemID = itemOrID

  if (type(itemOrID) == "table") then
    itemID = itemOrID.itemID
  end

  -- Try find the item
  if (not UNIT.get(itemID)) then
    error("Tried to create instance of invalid item ID: " .. tostring(itemID))
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

--- Spawns an item entity at the specified position.
--- @param item VersusItemInstance
--- @param position Vector
--- @param angle? Angle
function UNIT.make(item, position, angle)
  local entity = ents.Create("versus_item")

  entity:SetItem(item)
  entity:SetPos(position + Vector(0, 0, 16))
  entity:SetAngles(angle or Angle(0, 0, 0))
  entity:Spawn()

  if (item.modelScale) then
    entity:SetModelScale(item.modelScale)
    entity:Activate()
  end

  entity:DropToFloor()

  if (item.onEntityCreated) then
    item:onEntityCreated(entity)
  end

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

  local toPlayer = (player:GetPos() - position):Angle()
  local rotatedToPlayer = Angle(0, toPlayer.y, 0)
  local entity = UNIT.make(item, position, rotatedToPlayer)

  if (item.onDropped) then
    item:onDropped(player, entity)
  end

  return true, entity
end

--- Spawns an shipment entity at the specified position.
--- @param items VersusItemInstance[]
--- @param position Vector
--- @param angle? Angle
--- @return Entity
function UNIT.makeShipment(items, position, angle)
  local entity = ents.Create("versus_shipment")

  entity:SetItems(items)
  entity:SetPos(position)
  entity:SetAngles(angle or Angle(0, 0, 0))
  entity:Spawn()

  return entity
end

function UNIT.spawnShipment(player, items, position)
  if (not position) then
    position = player:GetEyeTraceNoCursor().HitPos

    position.z = position.z + 16
  end

  local toPlayer = (player:GetPos() - position):Angle()
  local rotatedToPlayer = Angle(0, toPlayer.y, 0)
  local entity = UNIT.makeShipment(items, position, rotatedToPlayer)

  return entity
end

function UNIT.hook:PlayerPickedUpVersusItem(player, entity, item)
  player:EmitSound("items/itempickup.wav", 75, 100, 1, CHAN_ITEM)
end

--- Spawns a loot crate entity at the specified position.
--- @param items VersusItemInstance[]
--- @param position Vector
--- @param angle? Angle
--- @return Entity
function UNIT.makeLootCrate(items, position, angle)
  local entity = ents.Create("versus_lootcrate")

  entity:SetItems(items)
  entity:SetPos(position)
  entity:SetAngles(angle or Angle(0, 0, 0))
  entity:Spawn()

  return entity
end

function UNIT.spawnLootCrate(player, items, position)
  if (not position) then
    position = player:GetEyeTraceNoCursor().HitPos

    position.z = position.z + 16
  end

  local toPlayer = (player:GetPos() - position):Angle()
  local rotatedToPlayer = Angle(0, toPlayer.y, 0)
  local entity = UNIT.makeLootCrate(items, position, rotatedToPlayer)

  return entity
end
