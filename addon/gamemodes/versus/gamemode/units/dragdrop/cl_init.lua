local UNIT             = UNIT

UNIT.libraryKey        = "dragdrop"

local STRIPE_WIDTH     = 20
local LINE_THICKNESS   = 4
local BORDER_THICKNESS = 4
local BORDER_RADIUS    = 8
local TEXT_PADDING     = 15
local TEXT_Y_OFFSET    = -20 -- label sits slightly above vertical centre

--- Returns whether the screen cursor is currently within the given rectangle.
--- @param x number  Screen left
--- @param y number  Screen top
--- @param w number  Width
--- @param h number  Height
--- @return boolean
function UNIT.isPointerOver(x, y, w, h)
  local mx, my = input.GetCursorPos()
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

--- Draws a striped drop-zone overlay at the given screen rectangle and returns
--- whether the cursor is hovering over it.
---
--- Stripes are drawn in two bands that frame a centred text label, giving each
--- zone a distinct accent colour while re-using the same geometry and style.
---
--- @param x          number  Screen left
--- @param y          number  Screen top
--- @param w          number  Width
--- @param h          number  Height
--- @param text       string  Zone label, e.g. "DROP ITEM"
--- @param accentColor Color
--- @return boolean   isHovering
function UNIT.drawZone(x, y, w, h, text, accentColor)
  local isHovering = UNIT.isPointerOver(x, y, w, h)
  local alpha      = isHovering and 220 or 50

  -- Derive the label position and the exclusion band around it.
  local textY      = y + h / 2 + TEXT_Y_OFFSET
  surface.SetFont("VersusDefaultOutlined")
  local _, textH    = surface.GetTextSize(text)
  local textTopY    = textY - textH / 2 - TEXT_PADDING
  local textBottomY = textY + textH / 2 + TEXT_PADDING

  local numStripes  = math.ceil((w + h) / STRIPE_WIDTH) * 2
  surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, alpha)

  -- Top stripe band (above label)
  render.SetScissorRect(
    x + BORDER_THICKNESS, y + BORDER_THICKNESS,
    x + w - BORDER_THICKNESS * 0.2, textTopY - BORDER_THICKNESS * 0.2, true)
  for i = -numStripes, numStripes do
    local offset = i * STRIPE_WIDTH + STRIPE_WIDTH
    for t = 0, LINE_THICKNESS - 1 do
      surface.DrawLine(x + offset + t, y, x + offset - h + t, y + h)
    end
  end
  render.SetScissorRect(0, 0, 0, 0, false)

  -- Bottom stripe band (below label)
  render.SetScissorRect(
    x + BORDER_THICKNESS, textBottomY,
    x + w - BORDER_THICKNESS * 0.2, y + h, true)
  for i = -numStripes, numStripes do
    local offset = i * STRIPE_WIDTH + STRIPE_WIDTH
    for t = 0, LINE_THICKNESS - 1 do
      surface.DrawLine(x + offset + t, y, x + offset - h + t, y + h)
    end
  end
  render.SetScissorRect(0, 0, 0, 0, false)

  -- Accent border
  surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 255)
  versus.util.drawRoundedOutline(BORDER_RADIUS, x, y, w, h, BORDER_THICKNESS)

  -- Label
  draw.SimpleText(text, "VersusHeading2",
    x + w / 2, textY,
    ColorAlpha(accentColor, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

  return isHovering
end
