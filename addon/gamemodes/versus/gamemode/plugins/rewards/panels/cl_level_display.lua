local PLUGIN = PLUGIN

do
  local PANEL = {}

  local PADDING = 16
  local BAR_HEIGHT = 12

  local accentColor = Color(112, 193, 179)
  local textColor = Color(220, 230, 240, 255)
  local progressColor = Color(80, 140, 220, 255)
  local progressBgColor = Color(20, 28, 40, 200)

  function PANEL:Init()
    self.level = 1
    self.xp = 0
    self.progressPercent = 0
    self.progressWithinLevel = 0
    self.totalXPForLevel = 1000
  end

  function PANEL:Think()
    local lp = LocalPlayer()

    if not IsValid(lp) then return end

    local newLevel = lp:GetNWInt("versus_Level", 1)
    local newXP = lp:GetNWInt("versus_XP", 0)

    if newLevel ~= self.level or newXP ~= self.xp then
      self.level = newLevel
      self.xp = newXP

      local xpForCurrentLevel = versus.rewards.getXPForLevel(newLevel)
      local xpForNextLevel = versus.rewards.getXPForLevel(newLevel + 1)

      self.progressWithinLevel = newXP - xpForCurrentLevel
      self.totalXPForLevel = math.max(1, xpForNextLevel - xpForCurrentLevel)
      self.progressPercent = math.Clamp(self.progressWithinLevel / self.totalXPForLevel, 0, 1)
    end
  end

  function PANEL:Paint(w, h)
    -- Background
    draw.RoundedBox(0, 0, 0, w, h, color_background)

    local centerX = w / 2
    local y = PADDING

    -- Level label
    draw.SimpleText(
      "LEVEL " .. self.level,
      "VersusHeading1",
      centerX,
      y,
      accentColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )

    surface.SetFont("VersusHeading1")
    local _, levelTextH = surface.GetTextSize("LEVEL 0")
    y = y + levelTextH + PADDING

    -- XP bar background
    local barX = PADDING
    local barW = w - PADDING * 2
    draw.RoundedBox(4, barX, y, barW, BAR_HEIGHT, progressBgColor)

    -- XP bar fill
    local fillWidth = barW * self.progressPercent
    if fillWidth > 0 then
      draw.RoundedBox(4, barX, y, fillWidth, BAR_HEIGHT, progressColor)
    end

    y = y + BAR_HEIGHT + PADDING * 0.5

    -- XP progress text
    local xpText = string.Comma(self.progressWithinLevel) .. " / " .. string.Comma(self.totalXPForLevel) .. " XP"
    draw.SimpleText(
      xpText,
      "VersusButton",
      centerX,
      y,
      textColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_TOP
    )
  end

  function PANEL:PerformLayout(w, h)
    -- Calculate desired height based on content
    surface.SetFont("VersusHeading1")
    local _, levelH = surface.GetTextSize("LEVEL 0")

    surface.SetFont("VersusButton")
    local _, xpH = surface.GetTextSize("0")

    local desiredH = PADDING
        + levelH + PADDING
        + BAR_HEIGHT + PADDING * 0.5
        + xpH + PADDING
        + PADDING

    if h ~= desiredH then
      self:SetTall(desiredH)
    end
  end

  vgui.Register("versus_LevelDisplay", PANEL, "EditablePanel")
end
