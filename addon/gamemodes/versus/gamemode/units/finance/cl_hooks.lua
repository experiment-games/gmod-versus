local UNIT = UNIT

net.Receive("versus.finance.initialize", function(len)
  LocalPlayer()._VersusMoney = net.ReadUInt(32)

  net.Start("versus.finance.initialized")
  net.SendToServer()
end)

net.Receive("versus.finance.changeMoney", function(len)
  local isReceiving = net.ReadBool()
  local amount = net.ReadUInt(32)
  local reason = net.ReadString()
  local currentMoney = net.ReadUInt(32)
  local changedAt = net.ReadFloat()
  local text = string.format("%s %s (%s)", isReceiving and "Gained" or "Lost",
    versus.util.formatMoney(amount), reason)

  if (isReceiving) then
    versus.message.notify(text, NOTIFY_MONEY_GAINED)
  else
    versus.message.notify(text, NOTIFY_MONEY_LOST)
  end

  if (not LocalPlayer()._LastMoneyChange or changedAt > LocalPlayer()._LastMoneyChange) then
    LocalPlayer()._LastMoneyChange = changedAt
    LocalPlayer()._VersusMoney = currentMoney
  end
end)
