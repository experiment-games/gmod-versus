local UNIT = UNIT

function UNIT.hook:VersusInitialized()
  -- TODO: Rename these (currently in dutch so I can keep track of changes)
  -- Better: income and expenditure
  UNIT.INCOME = self.registerTransactionType("income", "Income", Color(85, 190, 47, 255), nil, 1,
    function(balance, amount)
      return balance + amount
    end)
  UNIT.EXPENDITURE = self.registerTransactionType("expenditure", "Expenditure", Color(255, 93, 82, 255), nil, 9,
    function(balance, amount)
      return balance - amount
    end)

  hook.Run("RegisterFinancialTransactionTypes")

  hook.Run("RegisterFinancialCategories")
end

function UNIT.hook:BuildNotificationClasses(classes)
  NOTIFY_MONEY_GAINED = 100
  classes:add({
    _Key = NOTIFY_MONEY_GAINED,
    sound = {
      path = "physics/metal/metal_chainlink_impact_soft2.wav",
      volume = 1,
      pitch = 170
    },
    icon = Material("icon16/coins_add.png"),
    iconText = "+" .. versus.config["Money Symbol"],
    color = Color(93, 162, 113),
    getPosition = UNIT.getMoneyPosition,
    onDecayed = UNIT.handleNotificationDecayed,
  })

  NOTIFY_MONEY_LOST = 101
  classes:add({
    _Key = NOTIFY_MONEY_LOST,
    sound = {
      path = "physics/metal/metal_chainlink_impact_soft2.wav",
      volume = 1,
      pitch = 150
    },
    icon = Material("icon16/coins_delete.png"),
    iconText = "-" .. versus.config["Money Symbol"],
    color = Color(255, 93, 82),
    getPosition = UNIT.getMoneyPosition,
    onDecayed = UNIT.handleNotificationDecayed,
  })
end
