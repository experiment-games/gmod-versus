local PLUGIN = PLUGIN

PLUGIN.name = "Holiday: 5th November"
PLUGIN.description = "Remember, remember the 5th of November! Find the Vendetta mask."

local function isNovember5th()
  local t = os.date("*t") -- Get the current date and time as a table.
  return t.month == 11 and t.day == 5
end

function PLUGIN.hook:ModifyContractLootTable(npc, loot, attacker, position, angles)
  if not isNovember5th() then
    return
  end

  loot["mask_guy_fawkes"] = 0.5 / 100
end

function PLUGIN.hook:ModifyEnduranceWaveLootTable(loot, spawnID, waveNumber, multiplier)
  if not isNovember5th() then
    return
  end

  loot["mask_guy_fawkes"] = 1 / 100
end

-- Register a dynamic news article with the news plugin so that, on the 5th of
-- November, players automatically see an event article about the holiday drops.
function PLUGIN.hook:VersusInitialized()
  versus.news.registerDynamic("holiday-5th-november", function()
    if not isNovember5th() then
      return nil
    end

    return {
      id          = "holiday-5th-november",
      type        = "event",
      title       = "Remember, Remember the 5th of November!",
      date        = os.time(),
      headerImage = "versus/holidays/5th_of_november.png",
      content     = [[<p>Today is the <b>5th of November</b>!
In commemoration of Guy Fawkes Day, the iconic <b>Guy Fawkes Mask</b> has a chance to drop throughout the day:</p>
<ul>
  <li><b>Contracts</b> &ndash; 0.5% drop chance per NPC</li>
  <li><b>Endurance Waves</b> &ndash; 1% drop chance per wave</li>
</ul>
<p>Will you find the mask before midnight? <em>Remember, remember&hellip;</em></p>]],
    }
  end)
end
