local UNIT = UNIT
local gamemodeFolder = GM.FolderName

UNIT.libraryKey = "item"

UNIT.genericCategory = "General"

UNIT.stored = UNIT.stored or {}
UNIT.index = UNIT.index or {}
UNIT.pendingBaseResolutions = UNIT.pendingBaseResolutions or {}
UNIT.rarities = UNIT.rarities or {}
UNIT.sortedRarities = UNIT.sortedRarities or {}

versus.includePrefixed("sh_hooks.lua")

function UNIT.restoreInstance(instanceData)
  return setmetatable({}, FindMetaTable("VersusItemInstance")):init(instanceData)
end

--- Get an item by it's itemID written in several ways.
--- @param itemNameOrID string The item name or itemID to search for.
--- @return VersusItem? # The found item, or nil if not found.
function UNIT.find(itemNameOrID)
  if (UNIT.stored[itemNameOrID] ~= nil) then
    return UNIT.stored[itemNameOrID]
  end

  for _, itemTable in pairs(UNIT.stored) do
    if (string.find(string.lower(itemTable.name), string.lower(itemNameOrID), nil, true)) then
      return itemTable
    end
  end
end

-- Get all items by the value of one of their attributes
function UNIT.findAllBy(attributeKey, value, exactMatch)
  local items = {}

  if (exactMatch == nil) then
    exactMatch = false
  end

  for _, itemTable in pairs(UNIT.stored) do
    local attribute = itemTable[attributeKey]

    if (attribute) then
      if ((exactMatch and string.find(attribute, value, nil, true) ~= nil)
            or string.find(string.lower(attribute), string.lower(value), nil, true) ~= nil) then
        table.insert(items, itemTable)
      end
    end
  end

  return items
end

-- Get all items by the item it's based on
function UNIT.findAllByBase(base)
  local items = {}

  for _, itemTable in pairs(UNIT.stored) do
    if (itemTable:isBasedOf(base)) then
      table.insert(items, itemTable)
    end
  end

  return items
end

-- Sort the given items by their their categories
function UNIT.groupByCategories(items)
  local categories = {}
  local genericCategory = UNIT.genericCategory

  for key, itemTable in pairs(items) do
    local category = itemTable.category or genericCategory

    categories[category] = categories[category] or {}
    categories[category][key] = itemTable
  end

  return categories
end

-- Get all items
function UNIT.all()
  return UNIT.stored
end

-- Get an item by it's exact itemID.
function UNIT.get(itemID)
  return UNIT.stored[itemID]
end

-- Get an item by it's path.
function UNIT.getByPath(path)
  local itemID = UNIT.index[path:lower()]

  return UNIT.get(itemID)
end

function UNIT.loadItems(itemsPath)
  itemsPath = itemsPath:Trim("/") .. "/"
  local itemFiles = file.Find(itemsPath .. "*.lua", "LUA")

  for _, itemFile in pairs(itemFiles) do
    local path = itemsPath .. itemFile
    local item = UNIT.getByPath(path)

    if (item == nil) then
      item = UNIT.getAndResetOrCreateItem()
    else
      item:reset()
    end

    item.itemID = itemFile:sub(4, -5)
    item.path = path

    local oldITEM = ITEM
    ITEM = item
    versus.includePrefixed(itemFile, itemsPath)
    ITEM = oldITEM

    UNIT.registerItem(item)
  end
end

--- Use this to create a new item (or get an existing one and reset it) when manually
--- calling versus.item.registerItem.
--- NOTE: You must set itemID manually before registering the item.
--- @param itemID? string Optional itemID to look for an existing item.
--- @return VersusItem # The new or reset item.
function UNIT.getAndResetOrCreateItem(itemID)
  if (itemID) then
    local item = UNIT.get(itemID)

    if (item) then
      item:reset()
      return item
    end
  end

  return setmetatable({}, FindMetaTable("VersusItem")):init()
end

function UNIT.registerItem(item)
  if (item.itemID == nil) then
    error("Tried to register an item without an itemID! Found in: " .. tostring(item.path))
    return
  end

  item:registerHooks()

  if (not item.sellValue and item.cost) then
    item.sellValue = item.cost * .5
  end

  item.batch = item.batch or 1

  if (item.name ~= nil) then
    if (item.plural == nil) then
      item.plural = item.name .. "s"
    end

    UNIT.index[item.path:lower()] = item.itemID
    UNIT.stored[item.itemID] = item
  elseif (SERVER) then
    ServerLog("[Warning] Item with itemID " .. item.itemID ..
      " has no name! Not registering it. Found in: " .. item.path .. "\n")
  end

  UNIT.resolveBaseItem(item)
end

--- Resolve base items for the given item, or any items pending resolution of
--- this item as their base.
--- @param itemTable VersusItem The item to resolve base items for.
function UNIT.resolveBaseItem(itemTable)
  if (isstring(itemTable.base)) then
    local baseItem = UNIT.get(itemTable.base)

    if (baseItem == nil) then
      UNIT.pendingBaseResolutions[itemTable.base] = UNIT.pendingBaseResolutions[itemTable.base] or {}
      table.insert(UNIT.pendingBaseResolutions[itemTable.base], itemTable)

      return
    end

    itemTable.baseItem = baseItem
  end

  local pendingItems = UNIT.pendingBaseResolutions[itemTable.itemID]

  if (pendingItems) then
    for _, pendingItem in pairs(pendingItems) do
      pendingItem.baseItem = itemTable
    end

    UNIT.pendingBaseResolutions[itemTable.itemID] = nil
  end
end

-- Helper function to compare two tables deeply
function UNIT.dataEqual(t1, t2)
  if t1 == t2 then return true end
  if type(t1) ~= "table" or type(t2) ~= "table" then return false end

  local keys1 = {}
  for k in pairs(t1) do
    keys1[k] = true
  end

  for k, v2 in pairs(t2) do
    local v1 = t1[k]
    if v1 == nil then return false end

    if type(v1) == "table" and type(v2) == "table" then
      if not UNIT.dataEqual(v1, v2) then return false end
    elseif v1 ~= v2 then
      return false
    end

    keys1[k] = nil
  end

  -- Check if t1 has any keys that t2 doesn't have
  for k in pairs(keys1) do
    return false
  end

  return true
end

--- @alias RarityData { id?: string, color: Color, chance: number, modifier: number }

--- @param rarityID string The ID of the rarity to register.
--- @param rarityData RarityData The data for the rarity.
function UNIT.registerRarity(rarityID, rarityData)
  rarityData.id = rarityID
  UNIT.rarities[rarityID] = rarityData

  -- Rebuild sorted rarities
  UNIT.sortedRarities = {}

  for id, data in pairs(UNIT.rarities) do
    table.insert(UNIT.sortedRarities, { id = id, data = data })
  end

  table.sort(UNIT.sortedRarities, function(a, b)
    return a.data.chance < b.data.chance
  end)
end

--- @param rarityID string The ID of the rarity to get.
--- @return RarityData? # The data for the rarity, or nil if not found.
function UNIT.getRarity(rarityID)
  if (not rarityID) then
    return nil
  end

  return UNIT.rarities[rarityID:lower()]
end

--- Gets a rarity by rolling against the chances of all registered rarities.
--- @return RarityData? # The rolled rarity data, or nil if no rarity was rolled.
function UNIT.rollRarity()
  local chance = math.random()

  for _, rarityEntry in ipairs(UNIT.sortedRarities) do
    if (chance <= rarityEntry.data.chance) then
      return rarityEntry.data
    end
  end
end

UNIT.registerRarity("uncommon", {
  color = Color(112, 193, 179),
  chance = 0.25,
  modifier = 1.1,
})

UNIT.registerRarity("rare", {
  color = Color(36, 123, 160),
  chance = 0.1,
  modifier = 1.25,
})

UNIT.registerRarity("epic", {
  color = Color(208, 196, 223),
  chance = 0.04,
  modifier = 1.5,
})

UNIT.registerRarity("legendary", {
  color = Color(255, 224, 102),
  chance = 0.01,
  modifier = 2,
})
