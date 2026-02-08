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
      item, key = UNIT.getAnyItem(player, keyOrID)
    else
      item = UNIT.getItem(player, keyOrID)
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
      UNIT.takeItem(player, item)
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
  COMMAND:addRequiredParameter({ "move_to|move_from|move_all_to|move_all_from", tostring }, "Action",
    "The action to perform (move_to, move_from, move_all_to, move_all_from)")
  COMMAND:addParameter({ tonumber, tostring }, "Item Key/ID",
    "Item key/ID when moving items")
  COMMAND:addParameter({ tonumber, tostring }, "Amount",
    "The amount to move (only for move_all_to and move_all_from actions)")

  function COMMAND:onRun(player, chestName, action, itemKeyOrID, amount)
    -- Get the stored position for this named inventory
    local position = nil
    if (player._VersusOpenNamedInventory and IsValid(player._VersusOpenNamedInventory.entity)) then
      position = player._VersusOpenNamedInventory.entity:GetPos()
    end

    -- Validate distance if position is provided
    if (position and not versus.entity.isNearPosition(player, position, UNIT.namedInventoryMaxDistance)) then
      versus.message.notify(player, "You are too far away from the storage!", NOTIFY_ERROR)
      return
    end

    if (action == "move_to") then
      if (not itemKeyOrID) then
        versus.message.notify(player, "You must specify an item key or ID to move!", NOTIFY_ERROR)
        return
      end

      local item, key

      if (isstring(itemKeyOrID)) then
        item, key = UNIT.getAnyItem(player, itemKeyOrID)
      else
        key = tonumber(itemKeyOrID)
        item = UNIT.getItem(player, key)
      end

      if (not item or not key) then
        versus.message.notify(player, "You do not own this item!", NOTIFY_ERROR)
        return
      end

      UNIT.moveItemToNamedInventory(player, key, chestName)

      return
    end

    if (action == "move_from") then
      if (not itemKeyOrID) then
        versus.message.notify(player, "You must specify an item key or ID to move!", NOTIFY_ERROR)
        return
      end

      local namedInventory = UNIT.getNamedInventory(player, chestName)

      if (not namedInventory) then
        versus.message.notify(player, "Storage chest '" .. chestName .. "' does not exist!", NOTIFY_ERROR)
        return
      end

      local item, key

      if (isstring(itemKeyOrID)) then
        item, key = UNIT.getAnyItemFromNamedInventory(player, chestName, itemKeyOrID)
      else
        key = tonumber(itemKeyOrID)
        item = UNIT.getNamedInventoryItem(player, chestName, key)
      end

      if (not item or not key) then
        versus.message.notify(player, "This item is not in the storage chest!", NOTIFY_ERROR)
        return
      end

      UNIT.moveItemFromNamedInventory(player, chestName, key)

      return
    end

    if (action == "move_all_to") then
      local count = UNIT.moveCountMatchingToNamedInventory(player, itemKeyOrID, chestName, amount)

      if (count > 0) then
        versus.message.notify(player, "Moved " .. count .. " item(s) to storage!", NOTIFY_GENERIC)
      else
        versus.message.notify(player, "No matching items to move!", NOTIFY_ERROR)
      end

      return
    end

    if (action == "move_all_from") then
      local count = UNIT.moveCountMatchingFromNamedInventory(player, chestName, itemKeyOrID, amount)

      if (count > 0) then
        versus.message.notify(player, "Moved " .. count .. " item(s) from storage!", NOTIFY_GENERIC)
      else
        versus.message.notify(player, "No matching items to move!", NOTIFY_ERROR)
      end

      return
    end

    versus.message.notify(player, "Unknown action: " .. action, NOTIFY_ERROR)
  end
end
