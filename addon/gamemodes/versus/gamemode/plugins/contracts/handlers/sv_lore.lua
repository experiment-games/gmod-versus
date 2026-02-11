local PLUGIN = PLUGIN

-- Outputs lore to the player based on the data defined in the contract phase's "lore" key.
-- Currently only supports chat radio messages, but can be expanded in the future to support different types of lore delivery (e.g: audio through earpiece, mission brief panels, etc.)
PLUGIN.registerContractPhaseKeyHandler("lore", function(player, bag, data)
  if data.type == "chat_radio" then
    local totalDelay = 0

    for _, loreEntry in ipairs(data.texts) do
      totalDelay = totalDelay + loreEntry.delayInSeconds

      timer.Simple(totalDelay, function()
        if not IsValid(player) then return end

        local content = loreEntry.content
        if type(content) == "table" then
          content = content[math.random(1, #content)]
        end

        content = string.Replace(content, "%PLAYER_NAME%", player:Nick())

        versus.message.addChat(player, nil, "radio", data.author .. ": " .. content)
      end)
    end
  else
    error("Unsupported lore type: " .. tostring(data.type))
  end
end)
