local UNIT = UNIT
UNIT.libraryKey = "finance"
UNIT.NO_CATEGORY = -1
UNIT.RECUR_FOREVER = -1
UNIT.transactionTypes = UNIT.transactionTypes or {}
UNIT.categories = UNIT.categories or {}

versus.includePrefixed("cl_hooks.lua")
versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

--- Get all transactionTypes
function UNIT.getTransactionTypes()
  return UNIT.transactionTypes
end

--- Get a sorted copy of the transactionTypes array
function UNIT.getSortedTransactionTypes()
  local copy = table.Copy(UNIT.transactionTypes)

  table.SortByMember(copy, "order", true)

  return copy
end

--- Get a transactionType by its index
function UNIT.getTransactionType(index)
  return UNIT.transactionTypes[index]
end

--- Find a transactionType by it's key
function UNIT.findTransactionType(key)
  for index, transactionType in pairs(UNIT.transactionTypes) do
    if (transactionType.key == key) then
      return index
    end
  end
end

--- Register a transactionType or return it's index it it already exists
function UNIT.registerTransactionType(key, name, color, format, order, callback)
  local foundIndex = UNIT.findTransactionType(key)

  return foundIndex or table.insert(UNIT.transactionTypes, {
    key = key,
    name = name,
    order = order or 99,
    color = color or color_white,
    format = format or "%15s",
    callback = callback,
  })
end

--- Get a category by its index
function UNIT.getCategory(index)
  return UNIT.categories[index]
end

--- Find a category by label
function UNIT.findCategory(categoryLabel)
  for index, category in pairs(UNIT.categories) do
    if (category == categoryLabel) then
      return index
    end
  end
end

--- Register a category or return it's index it it already exists
function UNIT.registerCategory(categoryLabel)
  local foundIndex = UNIT.findCategory(categoryLabel)

  return foundIndex or table.insert(UNIT.categories, categoryLabel)
end
