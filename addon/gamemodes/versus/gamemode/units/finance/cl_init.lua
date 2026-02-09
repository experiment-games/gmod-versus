local UNIT = UNIT

UNIT.highlightMoneyDuration = 2

-- Check if the local player can afford an amount of money.
function UNIT.canAfford(amount)
  local deficit = LocalPlayer()._VersusMoney - amount

  return deficit >= 0, -deficit
end

-- Get the money the local player has.
function UNIT.getMoney()
  return LocalPlayer()._VersusMoney or 0
end

function UNIT.getMoneyPosition(message, lastY)
  local startX, startY = ScrW() * .5, ScrH() * .75
  local curTime = CurTime()

  if (curTime >= message.timeFade) then
    local fadeTime = message.timeFinish - message.timeFade
    local timeLeft = message.timeFinish - curTime
    local fraction = 1 - (timeLeft / fadeTime)
    local target = UNIT._MoneyLabelPosition

    return Lerp(fraction, startX, target.x), Lerp(fraction, startY, target.y), true
  else
    return startX, lastY or startY, true
  end
end

function UNIT.handleNotificationDecayed(message)
  UNIT._LastMoneyChange = CurTime()
  UNIT._LastMoneyChangeClass = message.class
end
