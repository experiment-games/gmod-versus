local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(800, 120)

    self.experienceGained = 0
    self.currentLevel = 1
    self.experienceToNextLevel = 1000

    self.bgColor = Color(25, 35, 50, 180)
    self.accentColor = Color(112, 193, 179)
    self.textColor = Color(220, 230, 240, 255)
    self.progressColor = Color(80, 140, 220, 255)
    self.progressBgColor = Color(20, 28, 40, 200)

    self.currentXP = 0
    self.progressPercent = 0

    self.startTime = CurTime()
  end

  function PANEL:SetExperienceData(xpGained, currentLevel, xpToNextLevel, currentXP)
    self.experienceGained = xpGained or 0
    self.currentLevel = currentLevel or 1
    self.experienceToNextLevel = xpToNextLevel or 1000
    self.currentXP = currentXP or 0

    -- Calculate progress percentage
    if self.experienceToNextLevel > 0 then
      self.progressPercent = math.Clamp(self.currentXP / self.experienceToNextLevel, 0, 1)
    end
  end

  function PANEL:Paint(w, h)
    -- Background
    draw.RoundedBox(8, 0, 0, w, h, self.bgColor)

    -- Left side - XP gained
    local xpText = "XP +" .. string.Comma(self.experienceGained)

    local textWidth, textHeight = draw.SimpleText(
      xpText,
      "VersusHeading1",
      GAMEMODE.SPACING,
      h / 2,
      self.accentColor,
      TEXT_ALIGN_LEFT,
      TEXT_ALIGN_CENTER
    )

    -- Right side - Level and progress
    local rightX = w - GAMEMODE.SPACING
    local progressBarWidth = w * .5

    -- Check if it fits next to the XP text
    if (rightX - progressBarWidth) < (GAMEMODE.SPACING + textWidth + GAMEMODE.SPACING) then
      progressBarWidth = rightX - (GAMEMODE.SPACING + textWidth + GAMEMODE.SPACING)
    end

    local progressBarHeight = GAMEMODE.SPACING
    local progressBarX = rightX - progressBarWidth
    local progressBarY = h / 2 - 10

    -- Level text above progress bar
    local levelText = "LEVEL " .. self.currentLevel
    surface.SetFont("VersusButton")

    draw.SimpleText(
      levelText,
      "VersusButton",
      progressBarX,
      progressBarY - 30,
      self.textColor,
      TEXT_ALIGN_LEFT,
      TEXT_ALIGN_CENTER
    )

    -- Progress bar background
    draw.RoundedBox(4, progressBarX, progressBarY, progressBarWidth, progressBarHeight, self.progressBgColor)

    -- Progress bar fill
    local elapsed = CurTime() - self.startTime
    local animDurationSeconds = 5
    local animPercent = math.ease.OutQuad(math.Clamp(elapsed / animDurationSeconds, 0, 1))
    local fillWidth = progressBarWidth * (self.progressPercent * animPercent)

    if fillWidth > 0 then
      draw.RoundedBox(4, progressBarX, progressBarY, fillWidth, progressBarHeight, self.progressColor)
    end

    -- XP text on progress bar
    local xpProgressText = string.Comma(self.currentXP) .. " / " .. string.Comma(self.experienceToNextLevel)
    surface.SetFont("VersusDefault")

    draw.SimpleText(
      xpProgressText,
      "VersusDefault",
      progressBarX + progressBarWidth / 2,
      progressBarY + progressBarHeight / 2,
      self.textColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    -- Next level indicator below progress bar
    local nextLevelText = "Next: Level " .. (self.currentLevel + 1)
    surface.SetFont("VersusDefault")

    draw.SimpleText(
      nextLevelText,
      "VersusDefault",
      progressBarX + progressBarWidth / 2,
      progressBarY + progressBarHeight + 20,
      Color(141, 153, 174),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end

  vgui.Register("versus_ExperienceDisplay", PANEL, "EditablePanel")
end
