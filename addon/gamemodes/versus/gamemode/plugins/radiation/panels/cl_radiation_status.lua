local PLUGIN = PLUGIN

do
  local PANEL = {}

  local barBgColor = Color(40, 40, 40, 200)
  local bgColor = Color(255, 204, 0, 255) -- Yellow
  local safeColor = Color(80, 200, 80, 255)
  local warningColor = Color(200, 200, 80, 255)
  local dangerColor = Color(200, 80, 80, 255)
  local textColor = color_black
  local lockColor = Color(220, 100, 100, 255)

  local function getLevelColor(level, threshold)
    local frac = level / threshold
    if frac < 0.5 then
      return safeColor
    elseif frac < 0.875 then
      return warningColor
    else
      return dangerColor
    end
  end

  function PANEL:Paint(w, h)
    local level     = PLUGIN.getLocalRadiationLevel()
    local threshold = PLUGIN.contractThreshold
    local maxLevel  = PLUGIN.maxLevel
    local locked    = level >= threshold

    -- Background
    surface.SetDrawColor(bgColor)
    surface.DrawRect(6, 6, w - 12, h - 12)

    -- Outline
    surface.DrawOutlinedRect(0, 0, w, h, 3)

    local padding = 10
    local barH    = 10
    local barY    = h - padding - barH
    local labelY  = padding

    -- "RADIATION" heading
    surface.SetFont("VersusDefaultOutlined")
    surface.SetTextColor(textColor)
    surface.SetTextPos(padding, labelY)
    surface.DrawText("RADIATION WARNING!")

    -- Numeric level
    local levelText = tostring(level) .. " / " .. tostring(maxLevel)
    local tw, _     = surface.GetTextSize(levelText)
    surface.SetTextPos(w - padding - tw, labelY)
    surface.DrawText(levelText)

    -- Progress bar
    local barW = w - padding * 2
    surface.SetDrawColor(barBgColor)
    surface.DrawRect(padding, barY, barW, barH)

    local barColor = getLevelColor(level, threshold)
    local fillFrac = level / maxLevel
    local fillW    = math.max(0, math.Round(barW * fillFrac))

    surface.SetDrawColor(barColor)
    surface.DrawRect(padding, barY, fillW, barH)

    -- Threshold marker
    local markerX = padding + math.Round(barW * (threshold / maxLevel))
    surface.SetDrawColor(220, 220, 220, 200)
    surface.DrawRect(markerX - 1, barY - 2, 2, barH + 4)

    -- Status line
    local statusY = labelY + 18
    surface.SetTextColor(locked and lockColor or textColor)

    if locked then
      surface.SetFont("VersusDefaultOutlined")
      surface.SetTextPos(padding, statusY)
      surface.DrawText("CONTRACTS LOCKED")
    elseif PLUGIN.mapIsRadiated() then
      -- Time until the threshold is reached
      local remaining = threshold - level
      local secsLeft  = remaining * PLUGIN.accumulationRate
      local mins      = math.floor(secsLeft / 60)
      local secs      = secsLeft % 60

      local timeText
      if mins > 0 then
        timeText = string.format("Map Contracts Lock in %dm %ds", mins, secs)
      else
        timeText = string.format("Map Contracts Lock in %ds", secs)
      end

      surface.SetFont("VersusDefaultOutlined")
      surface.SetTextPos(padding, statusY)
      surface.DrawText(timeText)
    end
  end

  vgui.Register("versus_RadiationStatus", PANEL, "EditablePanel")
end
