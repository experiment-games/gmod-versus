local PLUGIN = PLUGIN
PLUGIN.editItemNameOption = "Edit Item (Admin Only)"

function PLUGIN.hook:BuildInventoryItemFunctions(item, key, itemFunctions)
  if (not LocalPlayer():IsSuperAdmin()) then
    return
  end

  table.insert(itemFunctions, PLUGIN.editItemNameOption)
end

function PLUGIN.hook:SortInventoryItemFunctions(item, key, itemFunctions)
  -- Leave all items as is, except sort our option to the end
  table.sort(itemFunctions, function(a, b)
    if (a == PLUGIN.editItemNameOption) then
      return false
    elseif (b == PLUGIN.editItemNameOption) then
      return true
    end

    return false
  end)
end

function PLUGIN.hook:BuildInventoryItemFunction(item, key, menu, originalText, text, itemPanel)
  if (originalText ~= PLUGIN.editItemNameOption) then
    return
  end

  local childMenu = menu:AddOption(text, function()
    Derma_StringRequest(
      "Edit Item Name",
      "Enter a new name for the item:",
      item.name,
      function(newName)
        net.Start("versus.plugin.item_editor.editName")
        net.WriteUInt(key, versus.inventory.bitSizeItemKeys)
        net.WriteString(newName)
        net.SendToServer()
      end,
      nil,
      "OK",
      "Cancel"
    )
  end)
  childMenu:SetIcon("icon16/pencil.png")
end
