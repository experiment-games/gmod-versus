local PLUGIN = PLUGIN

-- Called when the main menu tabs can be built
function PLUGIN.hook:BuildMainMenuTabs(tabs)
  tabs:addTab("Players", vgui.Create("versus_Scoreboard"), "icon16/group.png", 5)
end
