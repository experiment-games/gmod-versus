local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("takeItems", function(player, bag, data)
  for _, itemData in ipairs(data) do
    versus.inventory.takeItem(player, itemData.itemID, itemData.quantity, true)
  end

  versus.inventory.networkEntireInventory(player)
end)
