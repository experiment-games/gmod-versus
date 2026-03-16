local PLUGIN = PLUGIN

PLUGIN.name = "Holiday: Easter"
PLUGIN.description = "Happy Easter! Find the Easter Eggs."

function PLUGIN.isEaster()
  local t = os.date("*t") -- Get the current date and time as a table.
  local month, day = t.month, t.day

  -- Easter falls on the first Sunday after the first full moon on or after March 21st.
  -- This means Easter can fall between March 22nd and April 25th.
  if month == 3 and day >= 22 then
    return true
  elseif month == 4 and day <= 25 then
    return true
  end

  return false
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

  local startDate = os.time({ year = os.date("%Y"), month = 3, day = 22 })

  table.insert(articles, 1, {
    id          = "holiday-easter",
    type        = "event",
    title       = "Happy Easter!",
    date        = startDate,
    headerImage = "versus/holidays/easter.png",
    content     = [[<h2>Happy Easter!</h2>
<p>Diana has painted Easter Eggs, but sadly the mischievous Jack has hidden them around the city! Can you find them all?</p>
<p>The Easter Egg has a chance to drop throughout the Easter period:</p>
<ul>
  <li><b>Contracts</b> &ndash; 1% drop chance per NPC</li>
  <li><b>Endurance Waves</b> &ndash; 2% drop chance per wave</li>
</ul>
<p>Turn in your Easter Eggs to Diana for a special reward! Happy hunting!</p>]],
  })
end
