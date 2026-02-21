local PLUGIN = PLUGIN

--- Opens the suggestion box panel. If it is already open, closes it instead.
function PLUGIN.openSuggestionBox()
  if IsValid(PLUGIN.suggestionPanel) then
    PLUGIN.suggestionPanel:Close()
    return
  end

  PLUGIN.suggestionPanel = vgui.Create("versus_SuggestionBox")
end

--[[
  Net Messages
--]]

-- Triggered by the suggestion box entity on the server
net.Receive("versus.suggestions.open", function()
  PLUGIN.openSuggestionBox()
end)

-- Result of submitting a suggestion
net.Receive("versus.suggestions.submitResult", function()
  local ok = net.ReadBool()
  local message = net.ReadString()

  if ok then
    PLUGIN.suggestionPanel:Clear()
  end

  versus.message.notify(
    message or (ok and "Suggestion submitted successfully!" or "Failed to submit suggestion. Please try again."),
    ok and NOTIFY_HINT or NOTIFY_ERROR
  )
end)

-- Admin list of suggestions received from the server
net.Receive("versus.suggestions.adminListResult", function()
  local count   = net.ReadUInt(16)
  local entries = {}

  for i = 1, count do
    table.insert(entries, {
      filename = net.ReadString(),
      suggestionType = net.ReadString(),
      playerName = net.ReadString(),
      steamID = net.ReadString(),
      timestamp = net.ReadUInt(32),
    })
  end

  if IsValid(PLUGIN.suggestionPanel) then
    PLUGIN.suggestionPanel:OnAdminListResult(entries)
  end
end)

-- Full suggestion content loaded for admin inspection
versus.network.receiveUnbounded("versus.suggestions.adminLoadResult", function(message)
  local content = message:readString()
  local record  = util.JSONToTable(content)

  if IsValid(PLUGIN.suggestionPanel) and record then
    PLUGIN.suggestionPanel:OnAdminLoadResult(record)
  end
end)
