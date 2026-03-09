local PLUGIN = PLUGIN

local COLOR_BG       = Color(25, 35, 50, 220)
local COLOR_BG_DARK  = Color(20, 28, 40, 200)
local COLOR_FULL     = Color(130, 210, 80, 255)   -- green: plenty of stamina
local COLOR_LOW      = Color(230, 180, 40, 255)   -- amber: below 30 %
local COLOR_EMPTY    = Color(210, 70, 70, 255)    -- red: depleted
local COLOR_DIM      = Color(160, 170, 180, 255)

local BAR_H    = 28   -- shorter than the standard 42-pixel health bar
local NUM_PIPS = 10   -- number of sprint-pip segments

-- Draw the stamina bar as a row of sprint pips below the ammo widget.
function PLUGIN.hook:DrawBottomBars(bar)
  local client = LocalPlayer()
  if not IsValid(client) or not client:Alive() then return end

  -- Only show when the player has the stamina resource defined.
  if not versus.resource.getDefinition(PLUGIN.resourceKey) then return end

  local fraction = versus.resource.get(client, PLUGIN.resourceKey) / versus.resource.getMax(PLUGIN.resourceKey)
  fraction = math.Clamp(fraction, 0, 1)

  -- Choose accent colour based on how full stamina is.
  local accentColor
  if fraction <= 0 then
    accentColor = COLOR_EMPTY
  elseif fraction < 0.3 then
    accentColor = COLOR_LOW
  else
    accentColor = COLOR_FULL
  end

  local x = bar.x
  local y = bar.y
  local w = bar.width

  -- Background panel
  surface.SetDrawColor(COLOR_BG)
  surface.DrawRect(x, y, w, BAR_H)

  -- Left accent strip
  surface.SetDrawColor(accentColor)
  surface.DrawRect(x, y, 4, BAR_H)

  -- Label
  surface.SetFont("VersusDefault")
  local labelText = "STAMINA"
  local _, labelH = surface.GetTextSize(labelText)
  surface.SetTextColor(ColorAlpha(COLOR_DIM, 200))
  surface.SetTextPos(x + 16, y + (BAR_H / 2) - (labelH / 2))
  surface.DrawText(labelText)

  -- Sprint pips (small vertical segments)
  local pipAreaStart = x + 110
  local pipAreaEnd   = x + w - 16
  local pipAreaW     = pipAreaEnd - pipAreaStart
  local pipSpacing   = 3
  local totalSpacing = pipSpacing * (NUM_PIPS - 1)
  local pipW         = math.floor((pipAreaW - totalSpacing) / NUM_PIPS)
  local pipH         = 14
  local pipY         = y + (BAR_H / 2) - (pipH / 2)

  local filledPips = math.ceil(fraction * NUM_PIPS)

  for i = 1, NUM_PIPS do
    local px = pipAreaStart + (i - 1) * (pipW + pipSpacing)

    if i <= filledPips then
      surface.SetDrawColor(accentColor)
      surface.DrawRect(px, pipY, pipW, pipH)
    else
      surface.SetDrawColor(COLOR_BG_DARK)
      surface.DrawRect(px, pipY, pipW, pipH)
      surface.SetDrawColor(Color(50, 60, 75, 100))
      surface.DrawOutlinedRect(px, pipY, pipW, pipH)
    end
  end

  -- Advance bar position for elements drawn above this one.
  bar.y = bar.y - BAR_H - 8
end
