local UNIT = UNIT

do
  local COMMAND = versus.command.define("givemoney")
  COMMAND.description = "Give money to the player you're looking at"
  COMMAND.requiredFlags = "b"

  COMMAND:addRequiredParameter(tonumber, "Money", "The amount of money to give to this player.")

  function COMMAND:onRun(player, money)
    local target = player:GetEyeTrace().Entity

    if (not target or not target:IsPlayer()) then
      versus.message.notify(player, "You are not looking at a valid player!", NOTIFY_ERROR)
      return
    end

    if (money <= 0) then
      versus.message.notify(player, "This is not a valid amount to give! Provide a number higher than 0.", NOTIFY_ERROR)
      return
    end

    money = math.floor(money)

    local canAfford, deficit = versus.finance.canAfford(player, money)

    if (not canAfford) then
      versus.message.notify(player,
        "You need another " .. versus.util.formatMoney(deficit) .. " to give this much!",
        NOTIFY_ERROR)
      return
    end

    versus.finance.takeMoney(player, money, "Given " .. target:getCombinedName() .. " some money")
    versus.finance.giveMoney(target, money, player:getCombinedName() .. " has given you some money")
  end
end

do
  local COMMAND = versus.command.define("dropmoney")
  COMMAND.description = "Drop money at where you're looking"
  COMMAND.requiredFlags = "b"

  COMMAND:addRequiredParameter(tonumber, "Money", "The amount of money to drop")

  function COMMAND:onRun(player, money)
    local position = player:GetEyeTrace().HitPos

    if (money < versus.config["Minimum Drop Amount"]) then
      local minimum = versus.util.formatMoney(versus.config["Minimum Drop Amount"])

      versus.message.notify(player,
        string.format("This is not a valid amount to drop! Provide an amount of at least %s.", minimum), NOTIFY_ERROR)
      versus.message.notify(player, "Did you know you can small amounts of money with /givemoney?",
        NOTIFY_CHAT_LIGHTBULB)
      return
    end

    money = math.floor(money)

    local canAfford, deficit = versus.finance.canAfford(player, money)

    if (not canAfford) then
      versus.message.notify(player,
        "You need another " .. versus.util.formatMoney(deficit) .. " to drop this much!",
        NOTIFY_ERROR)
      return
    end

    if (not versus.entity.isNearPosition(player, position, 256)) then
      versus.message.notify(player, "You cannot drop money that far away!", NOTIFY_ERROR)
      return
    end

    versus.finance.takeMoney(player, money, "Dropped some money")

    local entity = ents.Create("versus_money")

    entity:SetAmount(money)
    entity:SetPos(position + Vector(0, 0, 16))

    entity:Spawn()
  end
end

do
  local COMMAND = versus.command.define("increasemoney")
  COMMAND.description = "Increase a player's money amount"
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(Player, "Player", "The player to increase the money of.")
  COMMAND:addRequiredParameter(tonumber, "Money", "The amount of money to increase.")

  function COMMAND:onRun(player, target, money)
    money = math.floor(money)

    if (money <= 0) then
      versus.message.notify(
        player,
        "This is not a valid amount to increase! Provide a number higher than 0.",
        NOTIFY_ERROR
      )
      return
    end

    versus.finance.giveMoney(target, money, player:getCombinedName() .. " has increased your money")
    versus.message.notify(player,
      string.format(
        "You have increased %s's money by %s.",
        target:getCombinedName(),
        versus.util.formatMoney(money)
      ),
      NOTIFY_SUCCESS
    )
  end
end
