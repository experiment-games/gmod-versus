local UNIT = UNIT

util.AddNetworkString("versus.inventory.dropMultiple")

-- Called before a players' data is loaded, when default values are to be
-- set
function UNIT.hook:PlayerPreDataLoad(player)
  player:setCharacter("inventory", {})
end

-- Called when unknown table data needs to be prepared for saving to the database
function UNIT.hook:PlayerPrepareTableData(player, key)
  if (key == "inventory") then
    return UNIT.makeSafeInventoryString(player:getCharacter("inventory"))
  end
end

-- Called when a players' data is loading and needs to be converted or
-- requires further loading
function UNIT.hook:PlayerDataLoading(player, rawPlayerData)
  if (not rawPlayerData) then
    for itemID, amount in pairs(versus.config["Default Inventory"]) do
      for i = 1, amount do
        local item = versus.item.createInstance(itemID)

        UNIT.giveItem(player, item, nil, true)
      end
    end

    UNIT.networkEntireInventory(player)

    return
  end

  local inventory = UNIT.convertInventoryString(rawPlayerData.inventory)

  for _, itemData in pairs(inventory) do
    local item = versus.item.restoreInstance(itemData)

    UNIT.giveItem(player, item, nil, true)
  end

  UNIT.networkEntireInventory(player)
end

function UNIT.hook:PlayerPickedUpItem(player, entity, item)
  if (entity.allowedPlayers) then
    if (not table.HasValue(entity.allowedPlayers, player)) then
      versus.message.notify(player, "You are not allowed to pickup this item!", NOTIFY_ERROR)
      return false
    end
  end

  if (entity.chargeOnPickup) then
    if (IsValid(entity.chargeOnPickup.receiver) and entity.chargeOnPickup.receiver == player) then
      -- Allowed to pickup for free
      return
    end

    local canAfford, deficit = versus.finance.canAfford(player, entity.chargeOnPickup.amount)

    if (not canAfford) then
      versus.message.notify(player,
        "You need another " .. versus.util.formatMoney(deficit) ..
        " to pickup this item!", NOTIFY_ERROR)
      return false
    end

    -- TODO: Ask for confirmation before they pickup the item!
    versus.finance.takeMoney(player, entity.chargeOnPickup.amount, "Picked up " .. item.name)
    versus.finance.giveMoney(entity.chargeOnPickup.receiver, entity.chargeOnPickup.amount,
      player:getCombinedName() .. " picked up " .. item.name)
  end
end

net.Receive("versus.inventory.dropMultiple", function(len, player)
  local itemID = net.ReadString()
  local amount = net.ReadUInt(8)

  if (amount > 5) then
    versus.message.notify(
      player,
      "You can only drop up to 5 items at a time!",
      NOTIFY_ERROR
    )
    return
  end

  local position = player:GetEyeTraceNoCursor().HitPos + Vector(0, 0, 10)

  if (not versus.entity.isNearPosition(player, position, 256)) then
    versus.message.notify(player, "You cannot drop the items that far away!", NOTIFY_ERROR)
    return false
  end

  local items = {}

  for i = 1, amount do
    local item, key = versus.inventory.getAnyItem(player, itemID)

    if (not key) then
      versus.message.notify(
        player,
        "You do not have enough " .. item.name .. " to drop " .. amount .. "!",
        NOTIFY_ERROR
      )
      break
    end

    table.insert(items, item)
    versus.inventory.takeItem(player, item.itemID)
  end

  versus.item.makeShipment(items, position)
end)
