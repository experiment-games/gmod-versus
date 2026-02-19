local PLUGIN = PLUGIN

util.AddNetworkString("versus.vortigaunt.upgradeWeapon")

versus.includeDirectory(PLUGIN.fullPath .. "/npcs")

net.Receive("versus.vortigaunt.upgradeWeapon", function(len, player)
  local itemKey = net.ReadUInt(versus.inventory.bitSizeItemKeys)

  local item = versus.inventory.getItem(player, itemKey)

  if (not item) then
    versus.message.notify(player, "Item not found in inventory!", NOTIFY_ERROR)
    return
  end

  if (not item.isWeapon) then
    versus.message.notify(player, "Only weapons can be infused with Xen energy!", NOTIFY_ERROR)
    return
  end

  if (item.xenEnergy ~= nil) then
    versus.message.notify(player, "This weapon has already been infused with Xen energy!", NOTIFY_ERROR)
    return
  end

  local canAfford, deficit = versus.finance.canAfford(player, PLUGIN.UPGRADE_COST)

  if (not canAfford) then
    versus.message.notify(
      player,
      "You cannot afford this service. You need " .. versus.util.formatMoney(deficit) .. " more.",
      NOTIFY_ERROR
    )
    return
  end

  versus.finance.takeMoney(player, PLUGIN.UPGRADE_COST, "Vortigaunt Xen energy infusion: " .. item.name)

  -- Roll random effectiveness (0.0 to 1.0)
  item.xenEnergy = math.Rand(0, 1)

  player:setCharacterDirty(true)

  versus.inventory.networkItemOverrides(player, item)

  local percent = math.floor(item.xenEnergy * 100)
  versus.message.notify(
    player,
    string.format("Xen energy infused into %s! Effectiveness: %d%%", item.name, percent),
    NOTIFY_GENERIC
  )
end)
