local UNIT = UNIT
local gamemodeFolder = GM.FolderName

UNIT.libraryKey = "item"

UNIT.genericCategory = "General"

UNIT.stored = UNIT.stored or {}
UNIT.index = UNIT.index or {}

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sh_hooks.lua")

function UNIT.restoreInstance(instanceData)
  return setmetatable({}, FindMetaTable("VersusItemInstance")):init(instanceData)
end

-- Get an item by it's itemID written in several ways.
function UNIT.find(itemID)
  if (UNIT.stored[itemID] ~= nil) then
    return UNIT.stored[itemID]
  end

  for _, itemTable in pairs(UNIT.stored) do
    if (string.find(string.lower(itemTable.name), string.lower(itemID), nil, true)) then
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

  local oldITEM = ITEM
  local itemFiles = file.Find(itemsPath .. "*.lua", "LUA")

  for _, itemFile in pairs(itemFiles) do
    local path = itemsPath .. itemFile

    local item = UNIT.getByPath(path)
    if (item == nil) then
      item = setmetatable({}, FindMetaTable("VersusItem")):init()
    else
      item:reset()
    end

    item.itemID = itemFile:sub(4, -5)
    item.path = path
    item.batch = 1

    ITEM = item

    versus.includePrefixed(itemFile, itemsPath)

    item:registerHooks()

    if (not item.sellValue and item.cost) then
      item.sellValue = item.cost * .5
    end

    if (item.name ~= nil) then
      if (item.plural == nil) then
        item.plural = item.name .. "s"
      end

      UNIT.index[item.path:lower()] = item.itemID
      UNIT.stored[item.itemID] = item
    elseif (SERVER) then
      ServerLog("[Warning] Item with itemID " .. item.itemID ..
        " has no name! Not registering it. Found in: " .. path .. "\n")
    end
  end

  -- TODO: This now incorreclty runs multiple times since loadItems is called a lot (???)
  for itemID, itemTable in pairs(UNIT.stored) do
    if (isstring(itemTable.base)) then
      local baseItem = UNIT.get(itemTable.base)

      if (baseItem == nil) then
        ErrorNoHaltWithStack(itemID .. " is based of non-existant base item: " .. itemTable.base)
        PrintTable(itemTable)
        return
      end

      itemTable.baseItem = baseItem
    end
  end

  ITEM = oldITEM
end
