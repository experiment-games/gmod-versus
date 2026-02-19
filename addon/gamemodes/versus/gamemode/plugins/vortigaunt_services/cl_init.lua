local PLUGIN = PLUGIN

--- Adds a colored Xen energy row to the item tooltip when the item has been
--- infused by the Vortigaunt.
function PLUGIN.hook:BuildItemTooltipRows(tooltip, item)
  if (not item.xenEnergy) then
    return
  end

  local percent = math.floor(item.xenEnergy * 100)
  local row = tooltip:AddRow("xenEnergy")
  row:SetText(string.format("Xen Energy: %d%%", percent))
  row:SetBackgroundColor(PLUGIN.XEN_COLOR)
  row:SizeToContents()
end
