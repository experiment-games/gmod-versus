local PLUGIN = PLUGIN

-- Register the unified Play tab in the main menu
function PLUGIN.hook:BuildMainMenuTabs(tabs)
  tabs:addTab("Play", vgui.Create("versus_ServerSelectionTab"), 4)
end
