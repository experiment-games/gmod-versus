local UNIT = UNIT

UNIT.pacDataToEntityItemIDMap = UNIT.pacDataToEntityItemIDMap or {}

--[[
	This gets rid of errors like:
	```
	[PAC3] unique id collision between part[group][0 children][151] and part[group][kevlar][23]
	[PAC3] unique id collision between part[model2][error][152] and part[model2][kevlarvest][24]
	```

	TODO:	What are those id's used for? If they are used within a PAC outfit, to reference other
  TODO: parts, then this will break those references.
--]]
local makePartsUnique
function makePartsUnique(partsData)
  for _, v in pairs(partsData) do
    if (istable(v)) then
      if (v.UniqueID) then
        v.UniqueID = pac.Hash()
      end

      makePartsUnique(v)
    end
  end
end

function UNIT.attachPartClone(entity, item, pacData)
  if (pacData) then
    local isCopy = false

    if (item.pacAdjust) then
      pacData = table.Copy(pacData)
      isCopy = true

      makePartsUnique(pacData)

      pacData = item:pacAdjust(pacData, entity)
    end

    if (not isfunction(entity.AttachPACPart)) then
      pac.SetupENT(entity)
    end

    if (not isCopy) then
      pacData = table.Copy(pacData)
      makePartsUnique(pacData)
    end

    UNIT.pacDataToEntityItemIDMap[pacData] = {
      entity = entity,
      itemID = item.itemID,
    }
    entity:AttachPACPart(pacData)
  end
end

--- Adds an item ID to the equipped items list, causing it to be equipped on clients.
--- @param player Player The player equipping the item
--- @param itemID string The ID of the item being equipped
function UNIT.addEquippedItem(player, itemID)
  local equippedItems = player._VersusEquippedItems or {}
  player._VersusEquippedItems = equippedItems

  if (pac) then
    local item = versus.item.get(itemID)

    if (not item) then
      ErrorNoHalt("Tried to equip invalid item ID " .. tostring(itemID) .. "\n")
      return
    end

    local pacData = item.pacData or item.getPacData and item:getPacData(player)

    if (pacData) then
      UNIT.attachPartClone(player, item, pacData)
    end
  end

  table.insert(equippedItems, itemID)
end

--- Removes an item ID from the equipped items list, causing it to be removed from clients.
--- @param player Player The player unequipping the item
--- @param itemID string The ID of the item being unequipped
function UNIT.removeEquippedItem(player, itemID)
  local equippedItems = player._VersusEquippedItems or {}
  player._VersusEquippedItems = equippedItems

  if (pac) then
    local item = versus.item.get(itemID)

    if (not item) then
      ErrorNoHalt("Tried to unequip invalid item ID " .. tostring(itemID) .. "\n")
      return
    end

    if (item.pacData or item.getPacData) then
      if (not isfunction(player.RemovePACPart)) then
        pac.SetupENT(player)
      end

      -- Because the pacData will be a copy of the original pacData, we have to find the copy
      -- of the pacData that is currently equipped on the player by looking through our map of
      -- pacData to item IDs, and checking which one corresponds to this itemID in order to
      -- remove the correct part.
      for pacData, info in pairs(UNIT.pacDataToEntityItemIDMap) do
        if (info.entity == player and info.itemID == itemID) then
          player:RemovePACPart(pacData)
          UNIT.pacDataToEntityItemIDMap[pacData] = nil
        end
      end
    end
  end

  table.RemoveByValue(equippedItems, itemID)
end

--- Get all equipped item IDs for a player.
--- @param player Player The player whose equipped items we want to get
--- @return table # A list of item IDs that the player has equipped
function UNIT.getEquippedItems(player)
  return player._VersusEquippedItems or {}
end

--[[
  Hooks
--]]

function UNIT.hook:CharacterLocalModelPanelUpdating(panel, entity)
  local equippedItems = UNIT.getEquippedItems(LocalPlayer())

  if (#equippedItems == 0) then
    return
  end

  for _, part in pairs(equippedItems) do
    local item = versus.item.get(part)
    local pacData = item and (item.pacData or (item.getPacData and item:getPacData(LocalPlayer())))

    if (item and pacData) then
      UNIT.attachPartClone(entity, item, pacData)
    end
  end
end

function UNIT.hook:EntityRemoved(entity)
  if (pac and isfunction(entity.RemovePACPart)) then
    for pacData, info in pairs(UNIT.pacDataToEntityItemIDMap) do
      if (info.entity == entity) then
        entity:RemovePACPart(pacData)
        UNIT.pacDataToEntityItemIDMap[pacData] = nil
      end
    end
  end
end

-- Fixes an issue where child entities would get detached from their parents when out of PVS
-- Source: https://github.com/Facepunch/garrysmod-issues/issues/861#issuecomment-790967153
UNIT.parentLookup = UNIT.parentLookup or {}

local function cacheParents()
  UNIT.parentLookup = {}

  for _, ent in ents.Iterator() do
    if (ent:EntIndex() ~= -1) then
      continue
    end

    local parent = ent:GetInternalVariable("m_hNetworkMoveParent")
    local children = UNIT.parentLookup[parent]

    if (not children) then
      children = {}
      UNIT.parentLookup[parent] = children
    end

    ent._VersusLocalPos = ent:GetLocalPos()
    ent._VersusLocalAng = ent:GetLocalAngles()
    children[#children + 1] = ent
  end
end

local function fixChildren(parent, transmit)
  local parentLookupTable = UNIT.parentLookup[parent]

  if (not parentLookupTable) then
    return
  end

  for i = 1, #parentLookupTable do
    local child = parentLookupTable[i]

    if (transmit) then
      child:SetNoDraw(false)
      child:SetParent(parent)
      child:SetLocalPos(child._VersusLocalPos or Vector(0, 0, 0))
      child:SetLocalAngles(child._VersusLocalAng or Angle(0, 0, 0))
      fixChildren(child, transmit)
    else
      child:SetNoDraw(true)
      fixChildren(child, transmit)
    end
  end
end

local lastTime = 0
hook.Add("NotifyShouldTransmit", "UNIT.FixUnparentingClientsideModels", function(ent, transmit)
  local time = RealTime()

  if (lastTime < time) then
    cacheParents()
    lastTime = time
  end

  fixChildren(ent, transmit)
end)

--[[
  Net Messages
--]]

net.Receive("versus.equipment.sendEquippedItem", function()
  local player = net.ReadPlayer()
  local itemID = net.ReadString()
  local equipped = net.ReadBool()

  if (equipped) then
    UNIT.addEquippedItem(player, itemID)
  else
    UNIT.removeEquippedItem(player, itemID)
  end
end)

net.Receive("versus.equipment.sendEquippedItems", function()
  local player = net.ReadPlayer()
  local itemCount = net.ReadUInt(16)
  local equippedItems = {}

  for i = 1, itemCount do
    table.insert(equippedItems, net.ReadString())
  end

  for _, itemID in ipairs(equippedItems) do
    UNIT.addEquippedItem(player, itemID)
  end
end)
