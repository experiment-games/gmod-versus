local UNIT = UNIT
local g_Player = player

UNIT = UNIT or {}
UNIT.nextPaydayID = UNIT.nextPaydayID or 0
UNIT.cumulativePaid = UNIT.cumulativePaid or 0

util.AddNetworkString("bootleg.finance.changeMoney")

local dataPath = GM.FolderName .. "/payday/"
file.CreateDir(dataPath)

-- Get the amount of money a player has.
function UNIT.getMoney(player)
  return player:getCharacter("money")
end

local function networkMoneyChange(player, amount, reason)
  net.Start("versus.finance.changeMoney")
  net.WriteBool(amount >= 0)
  net.WriteUInt(math.abs(amount), 32)
  net.WriteString(reason or "")
  net.WriteUInt(UNIT.getMoney(player), 32)
  net.WriteFloat(CurTime())
  net.Send(player)
end

-- Set the amount of money a player has.
function UNIT.setMoney(player, amount)
  player:setCharacter("money", math.max(amount, 0))
end

-- Check if a player can afford an amount of money.
function UNIT.canAfford(player, amount)
  local deficit = UNIT.getMoney(player) - amount

  return deficit >= 0, -deficit
end

-- Give a player an amount of money.
function UNIT.giveMoney(player, amount, reason)
  if (amount < 0) then
    UNIT.takeMoney(player, amount, reason)
    return
  end

  UNIT.setMoney(player, UNIT.getMoney(player) + amount)

  networkMoneyChange(player, amount, reason)
end

-- Take an amount of money from a player.
function UNIT.takeMoney(player, amount, reason)
  if (amount < 0) then
    UNIT.giveMoney(player, amount, reason)
    return
  end

  UNIT.setMoney(player, UNIT.getMoney(player) - amount)

  networkMoneyChange(player, -amount, reason)
end
