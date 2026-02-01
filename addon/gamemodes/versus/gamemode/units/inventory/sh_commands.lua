local UNIT = UNIT

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
