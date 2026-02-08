local UNIT = UNIT

do
  local COMMAND = versus.command.define("inventory")
  COMMAND.description = "Perform inventory action on an item"

  COMMAND:addRequiredParameter({ tonumber, tostring }, "Item key or ID",
    "The key or ID of the item to perform an action on")
  COMMAND:addRequiredParameter({ "destroy|drop|use", tostring }, "Action", "The action to perform on the item")
  COMMAND:addParameter("restrict|charge", "Option", {
    "Restrict picking up the dropped item to a specific player",
    "Charge players for picking up the dropped item"
  })
  COMMAND:addParameter({ tonumber, tonumber }, "Versus ID or Price", {
    "The player ID that can pick up this item if you chose the 'Restrict' option",
    "The price if you specified 'Charge' as the option",
  })

  function COMMAND:onRun(player, keyOrID, action, option, priceOrVersusID)
    local item, key

    if (isstring(keyOrID)) then
      item, key = versus.inventory.getAnyItem(player, keyOrID)
    else
      item = versus.inventory.getItem(player, keyOrID)
      key = keyOrID
    end

    if (not item) then
      versus.message.notify(player, "You do not own this item!", NOTIFY_ERROR)
      return
    end

    local success, takeItem = UNIT.tryPerformItemAction(player, item, action, option, priceOrVersusID)

    if (not success) then
      -- tryPerformItemAction will have notified the player of the error
      return
    end

    if (takeItem) then
      versus.inventory.takeItem(player, item)
    end

    net.Start("versus.inventory.performItemAction")
    net.WriteUInt(key, UNIT.bitSizeItemKeys)
    net.WriteString(action)
    net.WriteBool(takeItem)
    net.Send(player)
  end
end

do
  local COMMAND = versus.command.define("chest")
  COMMAND.description = "Interact with storage inventories"

  COMMAND:addRequiredParameter(tostring, "Chest Name", "The name of the storage chest")
  COMMAND:addRequiredParameter({ "move_to|move_from", tostring }, "Action",
    "The action to perform (move_to, move_from)")
  COMMAND:addParameter({ tonumber, tostring }, "Item Key/ID",
    "Item key/ID when moving items")

  function COMMAND:onRun(player, chestName, action, sizeOrItem)
    if (action == "move_to") then
      if (not sizeOrItem) then
        versus.message.notify(player, "You must specify an item key or ID to move!", NOTIFY_ERROR)
        return
      end

      local item, key

      if (isstring(sizeOrItem)) then
        item, key = versus.inventory.getAnyItem(player, sizeOrItem)
      else
        key = tonumber(sizeOrItem)
        item = versus.inventory.getItem(player, key)
      end

      if (not item or not key) then
        versus.message.notify(player, "You do not own this item!", NOTIFY_ERROR)
        return
      end

      -- Get the stored position for this named inventory
      local position = nil
      if (player._NamedInventoryPositions and player._NamedInventoryPositions[chestName]) then
        position = player._NamedInventoryPositions[chestName]
      end

      if (not versus.inventory.moveItemToNamedInventory(player, key, chestName, position)) then
        versus.message.notify(player, "Failed to move item to storage!", NOTIFY_ERROR)
      end

      return
    end

    if (action == "move_from") then
      if (not sizeOrItem) then
        versus.message.notify(player, "You must specify an item key or ID to move!", NOTIFY_ERROR)
        return
      end

      local namedInventory = versus.inventory.getNamedInventory(player, chestName)

      if (not namedInventory) then
        versus.message.notify(player, "Storage chest '" .. chestName .. "' does not exist!", NOTIFY_ERROR)
        return
      end

      local item, key

      if (isstring(sizeOrItem)) then
        item, key = versus.inventory.getAnyItemFromNamedInventory(player, chestName, sizeOrItem)
      else
        key = tonumber(sizeOrItem)
        item = versus.inventory.getNamedInventoryItem(player, chestName, key)
      end

      if (not item or not key) then
        versus.message.notify(player, "This item is not in the storage chest!", NOTIFY_ERROR)
        return
      end

      -- Get the stored position for this named inventory
      local position = nil
      if (player._NamedInventoryPositions and player._NamedInventoryPositions[chestName]) then
        position = player._NamedInventoryPositions[chestName]
      end

      if (not versus.inventory.moveItemFromNamedInventory(player, chestName, key, position)) then
        versus.message.notify(player, "Failed to move item from storage!", NOTIFY_ERROR)
      end

      return
    end

    versus.message.notify(player, "Unknown action: " .. action, NOTIFY_ERROR)
  end
end
