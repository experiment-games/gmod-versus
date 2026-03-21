local PLUGIN = PLUGIN

PLUGIN.name = "Holiday: Easter"
PLUGIN.description = "Happy Easter! Find the Easter Eggs."

--- Returns the month and day of Easter Sunday for the given year,
--- using the Meeus/Jones/Butcher algorithm.
--- @param year number
--- @return number month, number day
function PLUGIN.getEasterSunday(year)
  local a = year % 19
  local b = math.floor(year / 100)
  local c = year % 100
  local d = math.floor(b / 4)
  local e = b % 4
  local f = math.floor((b + 8) / 25)
  local g = math.floor((b - f + 1) / 3)
  local h = (19 * a + b - d - g + 15) % 30
  local i = math.floor(c / 4)
  local k = c % 4
  local l = (32 + 2 * e + 2 * i - h - k) % 7
  local m = math.floor((a + 11 * h + 22 * l) / 451)
  local month = math.floor((h + l - 7 * m + 114) / 31)
  local day = ((h + l - 7 * m + 114) % 31) + 1
  return month, day
end

function PLUGIN.isEaster()
  local t = os.date("*t")
  local year, month, day = t.year, t.month, t.day

  local easterMonth, easterDay = PLUGIN.getEasterSunday(year)

  local today = os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })
  local easterSunday = os.time({ year = year, month = easterMonth, day = easterDay, hour = 0, min = 0, sec = 0 })

  -- Easter period: Palm Sunday (7 days before Easter) through Easter Monday (1 day after).
  local diffDays = (today - easterSunday) / 86400
  return diffDays >= -7 and diffDays <= 1
end

function PLUGIN.hook:ModifyContractLootTable(npc, loot, attacker, position, angles)
  if not PLUGIN.isEaster() then
    return
  end

  loot["easter_egg"] = 1 / 100
end

function PLUGIN.hook:ModifyEnduranceWaveLootTable(loot, spawnID, waveNumber, multiplier)
  if not PLUGIN.isEaster() then
    return
  end

  loot["easter_egg"] = 2 / 100
end

-- Register a dynamic news article with the news plugin so that, on the 5th of
-- November, players automatically see an event article about the holiday drops.
function PLUGIN.hook:ModifyVersusNewsArticles(articles)
  if not PLUGIN.isEaster() then
    return
  end

  local year = tonumber(os.date("%Y"))
  local easterMonth, easterDay = PLUGIN.getEasterSunday(year)
  -- Start the news on Palm Sunday, 7 days before Easter Sunday.
  local startDate = os.time({ year = year, month = easterMonth, day = easterDay - 7, hour = 0, min = 0, sec = 0 })

  table.insert(articles, 1, {
    id          = "holiday-easter",
    type        = "event",
    title       = "Happy Easter!",
    date        = startDate,
    headerImage = "versus/holidays/easter.png",
    content     = [[<h2>Happy Easter!</h2>
<p>Diana has painted Easter Eggs, but sadly the mischievous Jack has hidden them around the city! Can you find them all?</p>
<p>Easter Eggs have a chance to drop throughout the Easter period:</p>
<ul>
  <li><b>Contracts</b> &ndash; 1% drop chance per NPC</li>
  <li><b>Endurance Waves</b> &ndash; 2% drop chance per wave</li>
</ul>
<p>Turn in your Easter Eggs to Diana for a special reward! Happy hunting!</p>]],
  })
end
