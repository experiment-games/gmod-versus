local UNIT = UNIT

---@class VersusItemInstance
local itemInstanceMeta = {}

itemInstanceMeta.__index = function(tab, key)
  if (itemInstanceMeta[key] ~= nil) then
    return itemInstanceMeta[key]
  end

  local overrides = rawget(tab, "memberOverrides")

  if (overrides[key] ~= nil) then
    return overrides[key]
  end

  local itemTable = rawget(tab, "itemTable")

  if (not itemTable) then
    ErrorNoHalt(
      "Tried to index item instance with key " ..
      tostring(key) ..
      " but it has no item table for item ID " .. tostring(overrides and overrides.itemID or "nil") .. "\n"
    )
    return nil
  end

  return itemTable[key]
end

itemInstanceMeta.__newindex = function(tab, key, value)
  if (key == "memberOverrides" or key == "itemTable") then
    rawset(tab, key, value)
    return
  end

  tab.memberOverrides[key] = value
end

function itemInstanceMeta:init(instanceData)
  self.memberOverrides = {}

  for key, value in pairs(instanceData) do
    self.memberOverrides[key] = value
  end

  self.itemTable = UNIT.get(instanceData.itemID)

  return self
end

function itemInstanceMeta:IsValid()
  return true
end

function itemInstanceMeta:getSafeData()
  local memberOverrides = table.Copy(self.memberOverrides)

  return memberOverrides
end

function itemInstanceMeta:getNetworkData()
  local memberOverrides = self:getSafeData()

  -- Give listeners a chance to adjust what is actually sent. This allows storing a filename in the memberOverride and then only reading it when it's needed
  hook.Run("AdjustNetworkItemMemberOverrides", self, memberOverrides)

  return memberOverrides
end

debug.getregistry()["VersusItemInstance"] = itemInstanceMeta
