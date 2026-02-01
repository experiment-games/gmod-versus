---@class VersusOrderedList
local orderedListMeta = {}
orderedListMeta.__index = orderedListMeta

function orderedListMeta:init()
  self.unorderedList = {}

  return self
end

function orderedListMeta:IsValid()
  return true
end

function orderedListMeta:add(order, data)
  if (not isnumber(order)) then
    if (istable(order)) then
      data = order
    end

    order = 9999
  end

  data.order = order

  if (data._Key ~= nil) then
    data._Key = table.insert(self.unorderedList, data._Key, data)
  else
    data._Key = table.insert(self.unorderedList, data)
  end

  return data._Key
end

function orderedListMeta:get(index)
  return self.unorderedList[index]
end

function orderedListMeta:getUnsorted()
  return self.unorderedList
end

function orderedListMeta:getSorted()
  local sorted = {}

  for _, value in pairs(self.unorderedList) do
    table.insert(sorted, value)
  end

  table.SortByMember(sorted, "order", true)

  return sorted
end

debug.getregistry()["VersusOrderedList"] = orderedListMeta
