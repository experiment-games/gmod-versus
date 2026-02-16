local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(800, 120)

    self.experienceGained = 0
    self.currentLevel = 1
    self.experienceToNextLevel = 1000
    self.progressWithinLevel = 0
    self.totalXPForLevel = 1000

    self.bgColor = Color(25, 35, 50, 180)
    self.accentColor = Color(112, 193, 179)
    self.textColor = Color(220, 230, 240, 255)
    self.progressColor = Color(80, 140, 220, 255)
    self.progressBgColor = Color(20, 28, 40, 200)

    self.currentXP = 0
    self.startXP = 0
    self.startLevel = 1
    self.progressPercent = 0
    self.startProgressPercent = 0
    self.leveledUp = false

    self.startTime = CurTime()
  end

  function PANEL:SetExperienceData(xpGained, currentLevel, xpToNextLevel, currentXP, startLevel, startXP)
    self.experienceGained = xpGained or 0
    self.currentLevel = currentLevel or 1
    self.currentXP = currentXP or 0
    self.startLevel = startLevel or currentLevel
    self.startXP = startXP or (currentXP - xpGained)

    -- Check if player leveled up
    self.leveledUp = self.startLevel < self.currentLevel

    -- Calculate ENDING state (current level)
    local xpForCurrentLevel = versus.rewards.getXPForLevel(currentLevel)
    local xpForNextLevel = versus.rewards.getXPForLevel(currentLevel + 1)
    self.progressWithinLevel = self.currentXP - xpForCurrentLevel
    self.totalXPForLevel = xpForNextLevel - xpForCurrentLevel

    -- Calculate STARTING state
    local xpForStartLevel = versus.rewards.getXPForLevel(self.startLevel)
    local xpForStartNextLevel = versus.rewards.getXPForLevel(self.startLevel + 1)
    self.startProgressWithinLevel = self.startXP - xpForStartLevel
    self.startTotalXPForLevel = xpForStartNextLevel - xpForStartLevel

    -- Store for display
    self.experienceToNextLevel = xpToNextLevel or 0

    -- Calculate progress percentages
    if self.totalXPForLevel > 0 then
      self.progressPercent = math.Clamp(self.progressWithinLevel / self.totalXPForLevel, 0, 1)
    else
      self.progressPercent = 0
    end

    if self.startTotalXPForLevel > 0 then
      self.startProgressPercent = math.Clamp(self.startProgressWithinLevel / self.startTotalXPForLevel, 0, 1)
    else
      self.startProgressPercent = 0
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

    -- Animation timing
    local elapsed = CurTime() - self.startTime
    local animDurationSeconds = 3
    local animPercent = math.ease.OutQuad(math.Clamp(elapsed / animDurationSeconds, 0, 1))

    -- Determine which level and progress to display based on animation
    local displayLevel = self.startLevel
    local displayProgress = 0
    local displayProgressWithinLevel = self.startProgressWithinLevel
    local displayTotalXPForLevel = self.startTotalXPForLevel

    if self.leveledUp then
      -- Calculate how many levels we gained
      local levelsGained = self.currentLevel - self.startLevel

      -- Create animation segments: one for each level we pass through
      local segmentCount = levelsGained + 1
      local segmentDuration = 1.0 / segmentCount

      -- Figure out which segment we're in
      local currentSegment = math.floor(animPercent / segmentDuration)
      currentSegment = math.Clamp(currentSegment, 0, segmentCount - 1)

      -- Animation progress within the current segment
      local segmentProgress = (animPercent - (currentSegment * segmentDuration)) / segmentDuration
      segmentProgress = math.Clamp(segmentProgress, 0, 1)

      -- Determine which level to display based on segment
      displayLevel = self.startLevel + currentSegment

      -- Which segment are we animating?
      local totalSegments = levelsGained + 1

      if currentSegment == 0 then
        -- First segment: animate starting level from current progress to 100%
        displayTotalXPForLevel = self.startTotalXPForLevel
        displayProgressWithinLevel = self.startProgressWithinLevel +
            (displayTotalXPForLevel - self.startProgressWithinLevel) * segmentProgress
        displayProgress = self.startProgressPercent + (1 - self.startProgressPercent) * segmentProgress
      elseif currentSegment < totalSegments - 1 then
        -- Middle segments: show intermediate levels filling from 0% to 100%
        -- We need the NEXT level's XP thresholds, not the current one
        local intermediateLevel = self.startLevel + currentSegment
        local xpForThisLevel = versus.rewards.getXPForLevel(intermediateLevel)
        local xpForNextLevel = versus.rewards.getXPForLevel(intermediateLevel + 1)
        displayTotalXPForLevel = xpForNextLevel - xpForThisLevel
        displayProgressWithinLevel = displayTotalXPForLevel * segmentProgress
        displayProgress = segmentProgress
      else
        -- Final segment: show final level filling from 0% to actual progress
        displayTotalXPForLevel = self.totalXPForLevel
        displayProgressWithinLevel = self.progressWithinLevel * segmentProgress
        displayProgress = self.progressPercent * segmentProgress
      end
    else
      -- No level up, just animate progress within the same level
      displayLevel = self.currentLevel
      displayTotalXPForLevel = self.totalXPForLevel
      -- Animate XP value from starting amount to ending amount
      displayProgressWithinLevel = self.startProgressWithinLevel +
          (self.progressWithinLevel - self.startProgressWithinLevel) * animPercent
      displayProgress = self.startProgressPercent + (self.progressPercent - self.startProgressPercent) * animPercent
    end

    -- Level text above progress bar
    local levelText = "LEVEL " .. displayLevel
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
    local fillWidth = progressBarWidth * displayProgress

    if fillWidth > 0 then
      draw.RoundedBox(4, progressBarX, progressBarY, fillWidth, progressBarHeight, self.progressColor)
    end

    -- XP text on progress bar (show currently animating level's values)
    local xpProgressText = string.Comma(math.floor(displayProgressWithinLevel)) .. " / " ..
        string.Comma(displayTotalXPForLevel)
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
    local nextLevelText = "Next: Level " .. (displayLevel + 1)
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
