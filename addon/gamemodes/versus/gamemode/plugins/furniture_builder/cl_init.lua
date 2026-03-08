local PLUGIN = PLUGIN

--[[
  Hooks
--]]

-- Add the Furniture Catalog tab to the housing menu, but only when inside a room.
function PLUGIN.hook:BuildHousingMenuTabs(tabs, isInsideHousing)
  if (not isInsideHousing) then
    return
  end

  tabs:addTab("Furniture", vgui.Create("versus_FurnitureCatalogContent"), 2)
end

--[[
  Net Messages
--]]

net.Receive("versus.furnitureBuilder.showCatalogHint", function()
  local key = versus.message.lookupBinding("gm_showspare2") or "F4"
  versus.message.notify(
    string.format("Press %s to open the Furniture Catalog and build furniture for your hideout.", key),
    NOTIFY_LIGHTBULB
  )
end)
