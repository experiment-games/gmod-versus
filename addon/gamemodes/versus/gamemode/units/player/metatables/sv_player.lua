local UNIT = UNIT
local playerMeta = FindMetaTable("Player")

-- Needs to be an array or the function will get cleared by the unit loader
UNIT._OldFunction = UNIT._OldFunction or { GetInfoNum = playerMeta.GetInfoNum }

-- Allow server code to override client-side convars and prevent them from
-- being used in addons.
-- ? Example use-case: simfphys has no way to disable turbo on the server,
-- ? except by (amongst other things) blocking this convar
function playerMeta:GetInfoNum(conVarName, default)
  if (UNIT._GetInfoNumOverrides[conVarName]) then
    for _, callback in pairs(UNIT._GetInfoNumOverrides[conVarName]) do
      local result = callback(self, default)

      if (result ~= nil) then
        return result
      end
    end
  end

  return UNIT._OldFunction.GetInfoNum(self, conVarName, default)
end

function playerMeta:getCharacter(key, default)
  return self.versus and (self.versus[key] or default) or default
end

function playerMeta:setCharacter(key, value, clean)
  self.versus[key] = value

  if (not clean) then
    self:setCharacterDirty(true)
    UNIT.saveData(self)
  end
end

--- Set that the character data in-game differs from the last database update
function playerMeta:setCharacterDirty(isDirty)
  self.characterIsDirty = isDirty

  if (isDirty) then
    UNIT.saveData(self)
  end
end

--- Tests if the character data in-game differs from the last database update
function playerMeta:isCharacterDirty()
  return self.characterIsDirty
end
