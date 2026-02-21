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

    if (item.isWeapon and item.weaponClass) then
      -- Set weapon class in the name so we can find it later to hide/show it when its active
      pacData[1].self.Name = item.weaponClass
    end

    UNIT.pacDataToEntityItemIDMap[pacData] = {
      entity = entity,
      itemID = item.itemID,
    }
    entity:AttachPACPart(pacData)
  end
end

--- Refreshes the equipped items panel in the character screen, if it is open.
function UNIT.refreshEquippedPanel()
  if (IsValid(UNIT.equippedItemsPanel)) then
    UNIT.equippedItemsPanel:Refresh()
  end
end

--- Adds an item to the equipped slot map, attaching its PAC data on the player.
--- @param player Player The player equipping the item
--- @param slot string The equipment slot
--- @param item VersusItemInstance The item being equipped
function UNIT.addEquippedItem(player, slot, item)
  local equippedItems = player._VersusEquippedItems or {}
  player._VersusEquippedItems = equippedItems

  -- Remove any item already in this slot first (handles PAC cleanup)
  if (equippedItems[slot]) then
    UNIT.removeEquippedItem(player, slot)
  end

  if (pac) then
    local pacData = item.pacData or item.getPacData and item:getPacData(player, player)

    if (pacData) then
      UNIT.attachPartClone(player, item, pacData)
    end
  end

  equippedItems[slot] = item
  UNIT.refreshEquippedPanel()
end

--- Removes an equipped item from a slot, clearing its PAC data on the player.
--- @param player Player The player unequipping the item
--- @param slot string The equipment slot to clear
function UNIT.removeEquippedItem(player, slot)
  local equippedItems = player._VersusEquippedItems or {}
  player._VersusEquippedItems = equippedItems

  local item = equippedItems[slot]

  if (pac and item) then
    if (item and (item.pacData or item.getPacData)) then
      if (not isfunction(player.RemovePACPart)) then
        pac.SetupENT(player)
      end

      -- Because the pacData will be a copy of the original pacData, we have to find the copy
      -- of the pacData that is currently equipped on the player by looking through our map of
      -- pacData to item IDs, and checking which one corresponds to this itemID in order to
      -- remove the correct part.
      for pacData, info in pairs(UNIT.pacDataToEntityItemIDMap) do
        if (info.entity == player and info.itemID == item.itemID) then
          player:RemovePACPart(pacData)
          UNIT.pacDataToEntityItemIDMap[pacData] = nil
        end
      end
    end
  end

  equippedItems[slot] = nil
  UNIT.refreshEquippedPanel()
end

--- Get all equipped items for a player as a slot -> itemInstance map.
--- @param player Player The player whose equipped items we want to get
--- @return table # { [slot] = itemInstance, ... }
function UNIT.getEquippedItems(player)
  return player._VersusEquippedItems or {}
end

-- TODO: This could be optimized by having a lookup of pac outfits to weapon classes so we don't have to loop
-- TODO: through all outfits for all players every player draw call.
function UNIT.setShouldDrawWeapon(player, weaponClass, shouldDraw)
  for uniqueID, outfit in pairs(player.pac_outfits or {}) do
    if (outfit.Name == weaponClass) then
      outfit:SetHide(not shouldDraw)
    end
  end
end

--[[
  Hooks
--]]

-- Before the player draws, we check if any of the weapons they have equipped is their active weapon. If so
-- we set that not to draw, while only drawing the weapons on their back.
function UNIT.hook:PrePlayerDraw(player)
  local equippedItems = UNIT.getEquippedItems(player)
  local activeWeapon = player:GetActiveWeapon()

  for slot, item in pairs(equippedItems) do
    if (not item.isWeapon or not item.weaponClass) then
      continue
    end

    local shouldDraw = not IsValid(activeWeapon) or activeWeapon:GetClass() ~= item.weaponClass
    UNIT.setShouldDrawWeapon(player, item.weaponClass, shouldDraw)
  end
end

function UNIT.hook:CharacterLocalModelPanelUpdating(panel, entity)
  local equippedItems = UNIT.getEquippedItems(LocalPlayer())

  if (table.Count(equippedItems) == 0) then
    return
  end

  for slot, item in pairs(equippedItems) do
    local pacData = item and (item.pacData or (item.getPacData and item:getPacData(LocalPlayer(), entity)))

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

-- Refresh the equipment panel whenever the character screen opens.
function UNIT.hook:VersusCharacterBuildLeftPanel(leftPanel, characterPanel)
  local header = vgui.Create("DLabel", leftPanel)
  header:Dock(TOP)
  header:DockMargin(0, 8, 0, 4)
  header:SetFont("VersusHeading3")
  header:SetTextColor(Color(200, 210, 230))
  header:SetText("EQUIPMENT")
  header:SizeToContents()

  local equipList = vgui.Create("versus_EquippedItems", leftPanel)
  equipList:SetCharacterPanel(characterPanel)
  equipList:Dock(TOP)
  equipList:Refresh()

  -- Ensure it's below the experience panel
  header:SetZPos(99)
  equipList:SetZPos(100)

  UNIT.equippedItemsPanel = equipList
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


versus.network.receiveUnbounded("versus.equipment.sendEquippedItem", function(message)
  local player = message:readPlayer()
  local slot = message:readString()
  local isEquipped = message:readBool()
  local itemID = isEquipped and message:readString()
  local overrides = isEquipped and message:readTable()

  if (isEquipped) then
    overrides.itemID = itemID
    local item = versus.item.restoreInstance(overrides)

    if (not item) then
      ErrorNoHalt("Tried to equip invalid item ID " .. tostring(itemID) .. "\n")
      return
    end

    UNIT.addEquippedItem(player, slot, item)
  else
    UNIT.removeEquippedItem(player, slot)
  end
end)

versus.network.receiveUnbounded("versus.equipment.sendEquippedItems", function(message)
  local player = message:readPlayer()
  local model = message:readString()
  local itemCount = message:readUInt(16)

  if (model ~= player:GetModel()) then
    -- Ensure the client is up to date with the server, since some pac data is generated based on the player model.
    player:SetModel(model)
  end

  for i = 1, itemCount do
    local slot = message:readString()
    local itemID = message:readString()
    local overrides = message:readTable()
    local item = versus.item.restoreInstance(overrides)

    if (item) then
      UNIT.addEquippedItem(player, slot, item)
    else
      ErrorNoHalt("Tried to equip invalid item ID " .. tostring(itemID) .. " for player " .. tostring(player) .. "\n")
    end
  end
end)
