---@class VersusItem
local itemMeta = {}
itemMeta.__index = function(tab, key)
  if (itemMeta[key] ~= nil) then
    return itemMeta[key]
  end

  local baseItem = rawget(tab, "baseItem")

  if (baseItem ~= nil and baseItem[key] ~= nil and key ~= "isBaseItem") then
    return baseItem[key]
  end

  return rawget(tab, key)
end

function itemMeta:isBasedOf(base)
  if (self.base == base) then
    return true
  end

  local baseItem = self.baseItem

  while (baseItem ~= nil) do
    if (baseItem.base == base) then
      return true
    end

    baseItem = baseItem.baseItem
  end

  return false
end

function itemMeta:init()
  self.hook = {}

  return self
end

function itemMeta:reset()
  -- ! Only functions and hooks can safely be reset, tables may be added at
  -- ! runtime and removing them may have undesired effects
  for member, value in pairs(self) do
    if (isfunction(value)) then
      self[member] = nil
    end
  end

  for eventName, callback in pairs(self.hook) do
    hook.Remove(eventName, self)
    self.hook[eventName] = nil
  end
end

function itemMeta:IsValid()
  return true
end

function itemMeta:registerHooks()
  for eventName, callback in pairs(self.hook) do
    -- Call hook callbacks in a protected manner so one item doesn't break all others
    hook.Add(eventName, self, function(...)
      local success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z = xpcall(
        callback,
        function(errorMessage)
          ErrorNoHaltWithStack(
            string.format(
              "[Item \"%s\"] %s Hook Failed! Error: %q\n",
              self.itemID,
              eventName,
              errorMessage
            )
          )
        end,
        ...
      )

      if (not success) then
        return
      end

      -- Because it's susceptible to bugs we do a sanity check to help
      -- us recognize hooks which return more than 23 varargs (seems
      -- like bad design, just return a table if you must)
      if (x ~= nil or y ~= nil or z ~= nil) then
        ErrorNoHaltWithStack(
          string.format(
            "[Item %q] %s Warning! Hook has unreasonable varargs count! Expect bugs.\n",
            self.itemID,
            eventName
          )
        )
        print(success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z)
      end

      return a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    end)
  end
end

debug.getregistry()["VersusItem"] = itemMeta
