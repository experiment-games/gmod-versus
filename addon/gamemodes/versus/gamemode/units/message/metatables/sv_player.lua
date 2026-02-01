local UNIT = UNIT
local playerMeta = FindMetaTable("Player")

function playerMeta:notify(message, class)
  UNIT.notify(self, message, class)
end

function playerMeta:chatMe(text, ...)
  local translatableWords = { ... }
  versus.message.addChatInRadius(self, "me", text, self:GetPos(), versus.config["Talk Radius"], translatableWords)
end
