local UNIT = UNIT

do
  local COMMAND = versus.command.define("giveitem")
  COMMAND.description = "Give an item to a player."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Receiving Player", "The player to receive the item")
  COMMAND:addRequiredParameter(tostring, "Item ID", "(A part of) the ID of the item to give")
  COMMAND:addParameter(tonumber, "Amount", "The amount of the item to give", 1)

  function COMMAND:onRun(player, target, itemID, amount)
    local item = UNIT.find(itemID)

    if (not item) then
      versus.message.notify(player, "This is not a valid item ID!", NOTIFY_ERROR)
      return
    end

    if (amount < 1) then
      versus.message.notify(player, "You must give at least one item!", NOTIFY_ERROR)
      return
    end

    if (not versus.inventory.canFit(player, item.size * amount)) then
      versus.message.notify(
        player,
        target:getCombinedName() .. " does not have enough space for " .. amount .. "x this item!",
        NOTIFY_ERROR
      )
      return
    end

    for i = 1, amount do
      versus.inventory.giveItem(target, item.itemID)
    end

    versus.message.notify(
      player,
      "You have given " .. target:getCombinedName() .. " " .. amount .. "x " .. item.name .. ".",
      NOTIFY_CHAT_LIGHTBULB
    )

    if (player ~= target) then
      versus.message.notify(
        target,
        player:getCombinedName() .. " has given you " .. amount .. "x " .. item.name .. ".",
        NOTIFY_CHAT_LIGHTBULB
      )
    end
  end
end

do
  local COMMAND = versus.command.define("spawncrate")
  COMMAND.description = "Spawn a loot crate with items."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"
  COMMAND:addParameter(tostring, "Item IDs", "Comma-separated list of item IDs (e.g. 'item1,item2,item3')", "")
  COMMAND:addParameter(tonumber, "Distance", "Distance from your view to spawn the crate", 100)

  function COMMAND:onRun(player, itemIDsString, distance)
    -- Parse item IDs from comma-separated string
    local items = {}

    if (itemIDsString and itemIDsString ~= "") then
      for itemID in string.gmatch(itemIDsString, "[^,]+") do
        -- Trim whitespace
        itemID = string.Trim(itemID)

        local item = UNIT.find(itemID)
        if (item) then
          table.insert(items, UNIT.createInstance(item.itemID))
        else
          versus.message.notify(
            player,
            "Invalid item ID: '" .. itemID .. "' (skipping)",
            NOTIFY_ERROR
          )
        end
      end
    end

    -- Check if we have any valid items
    if (#items == 0) then
      versus.message.notify(
        player,
        "No valid items specified! Usage: !spawncrate item1,item2,item3",
        NOTIFY_ERROR
      )
      return
    end

    -- Get spawn position
    local trace = player:GetEyeTrace()
    local position = trace.HitPos

    -- If distance is specified, use it from player's view
    if (distance and distance > 0) then
      position = player:GetShootPos() + player:GetAimVector() * distance
      position.z = position.z + 16
    else
      -- Use trace hit position
      position.z = position.z + 16
    end

    -- Spawn the crate
    local entity = UNIT.spawnLootCrate(player, items, position)

    if (IsValid(entity)) then
      versus.message.notify(
        player,
        "Spawned loot crate with " .. #items .. " item" .. (#items == 1 and "" or "s") .. ".",
        NOTIFY_CHAT_LIGHTBULB
      )
    else
      versus.message.notify(
        player,
        "Failed to spawn loot crate!",
        NOTIFY_ERROR
      )
    end
  end
end
