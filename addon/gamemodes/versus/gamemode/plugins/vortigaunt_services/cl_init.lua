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

function PLUGIN.hook:InventoryItemGivenNetworked(item)
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end

function PLUGIN.hook:InventoryItemTakenNetworked(itemKey)
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end

function PLUGIN.hook:InventoryEntireInventoryNetworked()
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end

function PLUGIN.hook:InventoryItemOverridesNetworked(item)
  if IsValid(PLUGIN.vortigauntPanel) then
    PLUGIN.vortigauntPanel:Populate()
  end
end
