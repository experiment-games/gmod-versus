local PLUGIN = PLUGIN

--- Returns the local player's current radiation level (0–100).
--- @return number
function PLUGIN.getLocalRadiationLevel()
  if not IsValid(LocalPlayer()) then return 0 end
  return LocalPlayer()._versusRadiationLevel or 0
end

--[[
  Radiation status panel for the contract selection screen
--]]

do
  local PANEL = {}

  local barBgColor  = Color(40, 40, 40, 200)
  local bgColor     = Color(25, 35, 50, 210)
  local safeColor   = Color(80, 200, 80, 255)
  local warningColor = Color(200, 200, 80, 255)
  local dangerColor = Color(200, 80, 80, 255)
  local textColor   = Color(220, 230, 240, 255)
  local lockColor   = Color(220, 100, 100, 255)

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
    surface.DrawRect(0, 0, w, h)

    local padding = 10
    local barH    = 10
    local barY    = h - padding - barH
    local labelY  = padding

    -- "RADIATION" heading
    surface.SetFont("VersusDefault")
    surface.SetTextColor(textColor)
    surface.SetTextPos(padding, labelY)
    surface.DrawText("RADIATION")

    -- Numeric level
    local levelText = tostring(level) .. " / " .. tostring(maxLevel)
    local tw, _     = surface.GetTextSize(levelText)
    surface.SetTextPos(w - padding - tw, labelY)
    surface.DrawText(levelText)

    -- Progress bar
    local barW = w - padding * 2
    surface.SetDrawColor(barBgColor)
    surface.DrawRect(padding, barY, barW, barH)

    local barColor  = getLevelColor(level, threshold)
    local fillFrac  = level / maxLevel
    local fillW     = math.max(0, math.Round(barW * fillFrac))

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
      surface.SetFont("VersusDefault")
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
        timeText = string.format("Lock in %dm %ds", mins, secs)
      else
        timeText = string.format("Lock in %ds", secs)
      end

      surface.SetFont("VersusDefault")
      surface.SetTextPos(padding, statusY)
      surface.DrawText(timeText)
    end
  end

  vgui.Register("versus_RadiationStatus", PANEL, "EditablePanel")
end

--[[
  Helpers: attach radiation UI to the contract selection screen
--]]

--- Updates the enabled state of all contracts in the open selection panel.
local function updateContractPanelAvailability()
  local contractPlugin = versus and versus.contracts
  if not contractPlugin then return end

  local selectionPanel = contractPlugin.contractSelectionPanel
  if not IsValid(selectionPanel) then return end

  local contractsList = selectionPanel.contractsPanel
  if not IsValid(contractsList) then return end

  local level  = PLUGIN.getLocalRadiationLevel()
  local locked = PLUGIN.mapIsRadiated() and level >= PLUGIN.contractThreshold

  if not locked then return end

  local updates = {}

  for _, contractPanel in ipairs(contractsList.contracts) do
    if IsValid(contractPanel) then
      table.insert(updates, {
        id                = contractPanel:GetContractID(),
        enabled           = false,
        unavailableReason = "TOO IRRADIATED",
      })
    end
  end

  contractsList:UpdateContractAvailability(updates)
end

--- Attaches (or refreshes) the radiation status panel inside the contract
--- selection screen's map container.
local function attachRadiationPanel()
  if not PLUGIN.mapIsRadiated() then return end

  local contractPlugin = versus and versus.contracts
  if not contractPlugin then return end

  local selectionPanel = contractPlugin.contractSelectionPanel
  if not IsValid(selectionPanel) then return end

  local mapContainer = selectionPanel.mapContainer
  if not IsValid(mapContainer) then return end

  -- Create only once per selection panel.
  if IsValid(selectionPanel._radiationStatusPanel) then return end

  local radPanel = vgui.Create("versus_RadiationStatus", mapContainer)
  radPanel:SetSize(260, 72)
  radPanel:SetPos(GAMEMODE.SPACING, GAMEMODE.SPACING)

  selectionPanel._radiationStatusPanel = radPanel
end

--[[
  Hooks
--]]

function PLUGIN.hook:PlayerReceivedContracts(contracts)
  attachRadiationPanel()
  updateContractPanelAvailability()
end

-- Update contract availability in real-time if radiation crosses the threshold
-- while the contract selection panel is already open.
function PLUGIN.hook:LocalPlayerReceivedVariable(key, value, oldValue)
  if key ~= "_versusRadiationLevel" then return end
  updateContractPanelAvailability()
end

--[[
  HUD radiation indicator
--]]

local barBgHUD   = Color(30, 30, 30, 200)
local bgHUD      = Color(20, 28, 42, 200)
local textHUD    = Color(220, 230, 240, 255)
local greenHUD   = Color(80, 200, 80, 255)
local yellowHUD  = Color(200, 200, 80, 255)
local redHUD     = Color(200, 80, 80, 255)

local function getHUDBarColor(level, threshold)
  local frac = level / threshold
  if frac < 0.5 then
    return greenHUD
  elseif frac < 0.875 then
    return yellowHUD
  else
    return redHUD
  end
end

function PLUGIN.hook:HUDPaint()
  if not PLUGIN.mapIsRadiated() then return end

  local level = PLUGIN.getLocalRadiationLevel()
  if level <= 0 then return end

  local threshold = PLUGIN.contractThreshold
  local maxLevel  = PLUGIN.maxLevel

  local w, h   = 180, 38
  local margin = 8
  local x      = ScrW() - w - margin
  local y      = ScrH() * 0.5 - h * 0.5  -- Right side, vertically centered

  -- Pulse when close to or at threshold
  local alpha = 255
  if level >= threshold then
    local pulseBase      = 180
    local pulseAmplitude = 75
    local pulseFrequency = 2
    alpha = math.Round(pulseBase + pulseAmplitude * math.abs(math.sin(RealTime() * pulseFrequency)))
  end

  -- Background
  surface.SetDrawColor(ColorAlpha(bgHUD, alpha))
  surface.DrawRect(x, y, w, h)

  -- Left accent strip coloured by severity
  local barColor = getHUDBarColor(level, threshold)
  surface.SetDrawColor(ColorAlpha(barColor, alpha))
  surface.DrawRect(x, y, 4, h)

  local padding = 8
  local barH    = 8
  local barY    = y + h - padding - barH

  -- Label
  surface.SetFont("VersusDefault")
  surface.SetTextColor(ColorAlpha(textHUD, alpha))
  surface.SetTextPos(x + padding + 4, y + padding)
  surface.DrawText("RADIATION")

  -- Level text
  local levelText = tostring(level) .. "/" .. tostring(maxLevel)
  local tw, _    = surface.GetTextSize(levelText)
  surface.SetTextPos(x + w - padding - tw, y + padding)
  surface.DrawText(levelText)

  -- Progress bar track
  local barX = x + padding + 4
  local barW = w - (padding + 4) * 2
  surface.SetDrawColor(ColorAlpha(barBgHUD, alpha))
  surface.DrawRect(barX, barY, barW, barH)

  -- Progress bar fill
  local fillFrac = level / maxLevel
  local fillW    = math.max(0, math.Round(barW * fillFrac))
  surface.SetDrawColor(ColorAlpha(barColor, alpha))
  surface.DrawRect(barX, barY, fillW, barH)
end
