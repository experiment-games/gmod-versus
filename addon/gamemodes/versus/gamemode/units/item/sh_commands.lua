local UNIT = UNIT

local COMMAND = versus.command.define("giveitem")
COMMAND.description = "Give an item to a player."
COMMAND.category = "Super Admin Commands"
COMMAND.requiredFlags = "s"

COMMAND:addRequiredParameter(Player, "Receiving Player", "The player to receive the item")
COMMAND:addRequiredParameter(tostring, "Item ID", "(A part of) the ID of the item to give")
COMMAND:addParameter(tonumber, "Amount", "The amount of the item to give", 1)

function COMMAND:onRun(player, target, itemID, amount)
  local item = versus.item.find(itemID)

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
