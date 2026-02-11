local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("giveItems", function(player, bag, data)
  for _, itemData in ipairs(data) do
    versus.inventory.giveItem(player, itemData.itemID, itemData.quantity)
  end
end)
