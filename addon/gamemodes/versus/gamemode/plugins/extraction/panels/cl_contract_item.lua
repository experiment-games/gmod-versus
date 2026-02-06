local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self.contractName = "[Contract] Name"
    self.difficulty = "EASY"
    self.reward = "LOW"
    self.pvpMode = "BOTH" -- "PvP", "PvE", or "BOTH"
    self.enabled = true
    self.unavailableReason = "RECENTLY EXECUTED"

    self.bgColor = Color(45, 85, 135, 255) -- Saturated blue
    self.bgColorDisabled = Color(45, 85, 135, 50)
    self.textColor = Color(220, 230, 240, 255)
    self.textColorDisabled = Color(141, 153, 174, 50)
    self.unavailableTextColor = Color(220, 100, 100, 255)
    self.angleWidth = 40

    self.hovered = false

    -- Create tag panels
    self.difficultyTag = vgui.Create("versus_Tag", self)
    self.difficultyTag:SetText(self.difficulty)

    self.rewardTag = vgui.Create("versus_Tag", self)
    self.rewardTag:SetText(self.reward)

    self.pvpTag = vgui.Create("versus_Tag", self)
    self.pvpTag:SetText(self.pvpMode)

    self:SetText("")
  end

  function PANEL:SetContract(name, difficulty, reward, pvpMode)
    self.contractName = name
    self.difficulty = difficulty
    self.reward = reward
    self.pvpMode = pvpMode

    self.difficultyTag:SetText(difficulty)
    self.rewardTag:SetText(reward)
    self.pvpTag:SetText(pvpMode)

    -- Set tag colors based on type
    self:UpdateTagColors()
  end

  function PANEL:UpdateTagColors()
    -- Difficulty colors
    if self.difficulty == "EASY" then
      self.difficultyTag:SetColor(Color(100, 200, 100, 255))
    elseif self.difficulty == "MEDIUM" then
      self.difficultyTag:SetColor(Color(255, 180, 50, 255))
    elseif self.difficulty == "HARD" then
      self.difficultyTag:SetColor(Color(220, 80, 80, 255))
    end

    -- Reward colors
    if self.reward == "LOW" then
      self.rewardTag:SetColor(Color(180, 100, 100, 255))
    elseif self.reward == "MEDIUM" then
      self.rewardTag:SetColor(Color(200, 160, 100, 255))
    elseif self.reward == "HIGH" then
      self.rewardTag:SetColor(Color(100, 180, 100, 255))
    end

    -- PvP mode colors
    if self.pvpMode == "PvP" then
      self.pvpTag:SetColor(Color(220, 100, 100, 255))
    elseif self.pvpMode == "PvE" then
      self.pvpTag:SetColor(Color(100, 160, 220, 255))
    elseif self.pvpMode == "BOTH" then
      self.pvpTag:SetColor(Color(255, 200, 50, 255))
    end
  end

  function PANEL:SetEnabled(enabled)
    self.enabled = enabled

    self.difficultyTag:SetAlpha(enabled and 255 or 15)
    self.rewardTag:SetAlpha(enabled and 255 or 15)
    self.pvpTag:SetAlpha(enabled and 255 or 15)
  end

  function PANEL:GetEnabled()
    return self.enabled
  end

  function PANEL:SetUnavailableReason(reason)
    self.unavailableReason = reason
  end

  function PANEL:Paint(w, h)
    local bgColor = self.enabled and self.bgColor or self.bgColorDisabled
    local textColor = self.enabled and self.textColor or self.textColorDisabled
    local alphaModifier = self.enabled and 1 or 0.15

    -- Brighten on hover if enabled
    if self.enabled and self.hovered then
      bgColor = Color(
        math.min(bgColor.r + 20, 255),
        math.min(bgColor.g + 20, 255),
        math.min(bgColor.b + 20, 255),
        bgColor.a * alphaModifier
      )
    end

    -- Draw angled blue background, leaving room on the left for the parallelogram
    local paraOffset = 40
    local poly = {
      { x = paraOffset,                   y = 0 },
      { x = w,                            y = 0 },
      { x = w,                            y = h },
      { x = paraOffset + self.angleWidth, y = h }
    }

    draw.NoTexture()
    surface.SetDrawColor(bgColor)
    surface.DrawPoly(poly)

    -- Draw single parallelogram on the left
    local paraWidth = paraOffset
    local paraSkew = 20

    -- Draw the parallelogram inside the offset area
    local para = {
      { x = 0,                    y = 0 },
      { x = paraWidth - paraSkew, y = 0 },
      { x = paraWidth + paraSkew, y = h },
      { x = paraWidth,            y = h }
    }

    surface.DrawPoly(para)

    -- Draw contract name
    draw.SimpleText(
      self.contractName,
      "VersusHeading3",
      120,
      30,
      textColor,
      TEXT_ALIGN_LEFT,
      TEXT_ALIGN_TOP
    )

    -- Draw labels for tags
    local labelY = 75
    draw.SimpleText("DIFFICULTY", "VersusSmall", 120, labelY, ColorAlpha(textColor, 180 * alphaModifier), TEXT_ALIGN_LEFT,
      TEXT_ALIGN_TOP)
    draw.SimpleText("REWARD", "VersusSmall", 280, labelY, ColorAlpha(textColor, 180 * alphaModifier), TEXT_ALIGN_LEFT,
      TEXT_ALIGN_TOP)
    draw.SimpleText("PvP / PvE", "VersusSmall", 420, labelY, ColorAlpha(textColor, 180 * alphaModifier), TEXT_ALIGN_LEFT,
      TEXT_ALIGN_TOP)

    -- Draw unavailable overlay if disabled
    if not self.enabled then
      local startY = h * .5 - 20
      local textWidth, textHeight = draw.SimpleText(
        "UNAVAILABLE",
        "VersusHeading1",
        w / 2,
        startY,
        self.unavailableTextColor,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )

      draw.SimpleText(
        self.unavailableReason,
        "VersusDefault",
        w / 2,
        startY + textHeight * .5,
        self.unavailableTextColor,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )
    end
  end

  function PANEL:PerformLayout(w, h)
    -- Position tags below their labels
    local tagY = 100
    self.difficultyTag:SetPos(120, tagY)
    self.rewardTag:SetPos(280, tagY)
    self.pvpTag:SetPos(420, tagY)
  end

  function PANEL:OnCursorEntered()
    self.hovered = true
  end

  function PANEL:OnCursorExited()
    self.hovered = false
  end

  function PANEL:DoClick()
    if self.enabled then
      self:OnContractSelected()
    end
  end

  function PANEL:OnContractSelected()
    -- Override this in implementation
    print("Contract selected:", self.contractName)
  end

  vgui.Register("versus_ContractItem", PANEL, "DButton")
end
