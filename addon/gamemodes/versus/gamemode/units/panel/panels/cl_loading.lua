local UNIT = UNIT

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(100, 100)

    self.rectWidth = 8
    self.rectHeight = 32
    self.rectSpacing = 12
    self.numRects = 3

    self.inactiveColor = Color(80, 140, 220, 100)
    self.activeColor = Color(80, 140, 220, 255)

    self.animSpeed = 1.5 -- Seconds per full cycle
    self.startTime = CurTime()
  end

  function PANEL:Paint(w, h)
    -- Calculate total width of all rectangles
    local totalWidth = (self.numRects * self.rectWidth) + ((self.numRects - 1) * self.rectSpacing)
    local startX = (w - totalWidth) / 2
    local centerY = h / 2

    -- Calculate animation progress
    local elapsed = CurTime() - self.startTime
    local cycle = (elapsed / self.animSpeed) % 1
    -- Start the wave before the first rectangle so it grows in smoothly
    local animProgress = (cycle * (self.numRects + 1)) - 0.5

    -- Draw rectangles
    for i = 1, self.numRects do
      local x = startX + ((i - 1) * (self.rectWidth + self.rectSpacing))

      -- Calculate distance from the "wave" center
      local distance = math.abs(animProgress - (i - 1))

      -- Use distance to calculate smooth scale and alpha
      -- When distance is 0, rectangle is fully active
      -- When distance is > 1, rectangle is inactive
      local influence = math.Clamp(1 - distance, 0, 1)
      influence = math.ease.InOutSine(influence)

      -- Calculate scale (1.0 to 1.5)
      local scale = 1 + (0.5 * influence)

      -- Calculate color alpha (100 to 255)
      local alpha = 100 + (155 * influence)
      local color = ColorAlpha(self.activeColor, alpha)

      -- Apply scale
      local scaledHeight = self.rectHeight * scale
      local rectY = centerY - (scaledHeight / 2)

      -- Draw rectangle
      draw.RoundedBox(4, x, rectY, self.rectWidth, scaledHeight, color)
    end
  end

  vgui.Register("versus_LoadingIndicator", PANEL, "EditablePanel")
end
