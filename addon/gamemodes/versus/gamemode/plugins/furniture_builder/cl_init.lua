local PLUGIN = PLUGIN

--- Open the furniture catalog when the spare2 key (default F4) is pressed inside the player's housing instance.
function PLUGIN.hook:ShowSpare2()
  -- Only open the catalog when in a housing instance
  local instanceID = LocalPlayer():GetNWString("InstanceID", "")

  if (instanceID == "") then
    return
  end

  -- Don't open if there's already a catalog open
  if (IsValid(PLUGIN.catalogPanel)) then
    PLUGIN.catalogPanel:Close()
    PLUGIN.catalogPanel = nil
    return
  end

  PLUGIN.catalogPanel = vgui.Create("versus_FurnitureCatalog")
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
