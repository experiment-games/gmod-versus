local UNIT = UNIT
local playerMeta = FindMetaTable("Player")

function playerMeta:getVersusID()
  return SERVER and self.versus.id or self:GetNWInt("versus_ID", -1)
end

function playerMeta:getCharacterName()
  return self:GetNWString("versus_Name", "Connecting...")
end

local blockedSteamNames = {
  ["the administrator"] = true,
  ["administrator"] = true,
  ["the admin"] = true,
  ["admin"] = true,
  ["the owner"] = true,
  ["owner"] = true,
  ["the moderator"] = true,
  ["a moderator"] = true,
  ["moderator"] = true,
  ["mod"] = true,
}

function playerMeta:getCombinedName()
  local steamName = " (" .. self:Nick() .. ")"

  if (blockedSteamNames[self:Nick():lower()]) then
    steamName = " [" .. self:getSteamID64() .. "]"
  end

  return self:getCharacterName() .. steamName
end

function playerMeta:getSteamID64()
  return self:SteamID64() or "singleplayer"
end

---@return A vaild entity if the player is ragdolled, NULL else.
function playerMeta:GetRagdollEntity()
  return self:GetNWEntity("versus_Ragdoll")
end
