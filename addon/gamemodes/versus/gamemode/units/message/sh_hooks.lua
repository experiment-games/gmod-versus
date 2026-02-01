local UNIT = UNIT

function UNIT.hook:SomeUnitInitialized(unit)
  if (unit ~= UNIT) then
    return
  end

  local classes = setmetatable({}, FindMetaTable("VersusOrderedList")):init()

  -- Generic notifications (1 - 9)
  NOTIFY_INFORMATION = 1
  classes:add({
    _Key = NOTIFY_INFORMATION,
    sound = "buttons/button15.wav",
    icon = Material("icon16/information.png"),
    iconText = "i",
    color = Color(99, 138, 185),
    getPosition = UNIT.getNotificationPosition,
  })

  NOTIFY_LIGHTBULB = 2
  classes:add({
    _Key = NOTIFY_LIGHTBULB,
    sound = "ambient/water/drip2.wav",
    icon = Material("icon16/lightbulb.png"),
    iconText = "?",
    color = Color(245, 222, 104),
    getPosition = UNIT.getNotificationPosition,
  })

  NOTIFY_INCOMING = 3
  classes:add({
    _Key = NOTIFY_INCOMING,
    sound = "buttons/bell1.wav",
    icon = Material("icon16/bell.png"),
    iconText = "o",
    color = Color(232, 176, 55),
    getPosition = UNIT.getNotificationPosition,
  })

  -- Negative notifications (10 - 19)
  NOTIFY_WARNING = 10
  classes:add({
    _Key = NOTIFY_WARNING,
    sound = "buttons/button17.wav",
    icon = Material("icon16/error.png"),
    iconText = "!#",
    color = Color(213, 162, 62),
    getPosition = UNIT.getNotificationPosition,
  })

  NOTIFY_ERROR = 11
  classes:add({
    _Key = NOTIFY_ERROR,
    sound = "buttons/button10.wav",
    icon = Material("icon16/exclamation.png"),
    iconText = "!",
    color = Color(255, 93, 82),
    getPosition = UNIT.getNotificationPosition,
  })

  NOTIFY_CHAT_LIGHTBULB = 12
  classes:add({
    _Key = NOTIFY_CHAT_LIGHTBULB,
    sound = "ambient/water/drip2.wav",
    icon = Material("icon16/lightbulb.png"),
    iconText = "?",
    color = Color(245, 222, 104),
  })

  -- Item gain/loss notifications (20-29)
  NOTIFY_ITEM_GAINED = 20
  classes:add({
    _Key = NOTIFY_ITEM_GAINED,
    sound = {
      path = "physics/cardboard/cardboard_box_impact_hard6.wav",
      volume = 1,
      pitch = 170
    },
    icon = Material("icon16/note_add.png"),
    iconText = "+",
    color = Color(93, 162, 113),
    getPosition = UNIT.getNotificationPosition,
  })

  NOTIFY_ITEM_LOST = 21
  classes:add({
    _Key = NOTIFY_ITEM_LOST,
    sound = {
      path = "physics/cardboard/cardboard_box_impact_hard2.wav",
      volume = 1,
      pitch = 150
    },
    icon = Material("icon16/note_delete.png"),
    iconText = "-",
    color = Color(255, 93, 82),
    getPosition = UNIT.getNotificationPosition,
  })

  -- Called to build additional notification classes
  -- ! Make sure to "namespace" notification enumerations by
  -- ! by choosing a range the enum lives in. Starting from
  -- ! 100. Notification classes cannot have the same _Key.
  hook.Run("BuildNotificationClasses", classes)

  UNIT.notifyClassStyles = classes:getUnsorted()
end
