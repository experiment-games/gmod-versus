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

    self:SetText("")

    -- Title label
    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading2")
    self.titleLabel:SetTextColor(self.textColor)
    self.titleLabel:SetText(self.contractName)
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(120, 20, 0, 10)
    self.titleLabel:SetContentAlignment(4) -- Left align
    self.titleLabel:SizeToContents()
    self.titleLabel:SetMouseInputEnabled(false)

    -- Tags container
    self.tagsContainer = vgui.Create("EditablePanel", self)
    self.tagsContainer:Dock(TOP)
    self.tagsContainer:DockMargin(120, 0, 0, 0)
    self.tagsContainer:SetTall(60)
    self.tagsContainer:SetMouseInputEnabled(false)

    -- Difficulty section
    self.difficultyContainer = vgui.Create("EditablePanel", self.tagsContainer)
    self.difficultyContainer:Dock(LEFT)
    self.difficultyContainer:DockMargin(0, 0, 20, 0)
    self.difficultyContainer:SetWide(80)
    self.difficultyContainer:SetMouseInputEnabled(false)

    self.difficultyLabel = vgui.Create("DLabel", self.difficultyContainer)
    self.difficultyLabel:SetFont("VersusSmall")
    self.difficultyLabel:SetTextColor(ColorAlpha(self.textColor, 180))
    self.difficultyLabel:SetText("DIFFICULTY")
    self.difficultyLabel:Dock(TOP)
    self.difficultyLabel:SizeToContents()
    self.difficultyLabel:SetMouseInputEnabled(false)

    self.difficultyTag = vgui.Create("versus_Tag", self.difficultyContainer)
    self.difficultyTag:SetText(self.difficulty)
    self.difficultyTag:Dock(TOP)
    self.difficultyTag:DockMargin(0, 4, 0, 0)
    self.difficultyTag:SetMouseInputEnabled(false)

    -- Reward section
    self.rewardContainer = vgui.Create("EditablePanel", self.tagsContainer)
    self.rewardContainer:Dock(LEFT)
    self.rewardContainer:DockMargin(0, 0, 20, 0)
    self.rewardContainer:SetWide(80)
    self.rewardContainer:SetMouseInputEnabled(false)

    self.rewardLabel = vgui.Create("DLabel", self.rewardContainer)
    self.rewardLabel:SetFont("VersusSmall")
    self.rewardLabel:SetTextColor(ColorAlpha(self.textColor, 180))
    self.rewardLabel:SetText("REWARD")
    self.rewardLabel:Dock(TOP)
    self.rewardLabel:SizeToContents()
    self.rewardLabel:SetMouseInputEnabled(false)

    self.rewardTag = vgui.Create("versus_Tag", self.rewardContainer)
    self.rewardTag:SetText(self.reward)
    self.rewardTag:Dock(TOP)
    self.rewardTag:DockMargin(0, 4, 0, 0)
    self.rewardTag:SetMouseInputEnabled(false)

    -- PvP/PvE section
    self.pvpContainer = vgui.Create("EditablePanel", self.tagsContainer)
    self.pvpContainer:Dock(LEFT)
    self.pvpContainer:SetWide(80)
    self.pvpContainer:SetMouseInputEnabled(false)

    self.pvpLabel = vgui.Create("DLabel", self.pvpContainer)
    self.pvpLabel:SetFont("VersusSmall")
    self.pvpLabel:SetTextColor(ColorAlpha(self.textColor, 180))
    self.pvpLabel:SetText("PvP / PvE")
    self.pvpLabel:Dock(TOP)
    self.pvpLabel:SizeToContents()
    self.pvpLabel:SetMouseInputEnabled(false)

    self.pvpTag = vgui.Create("versus_Tag", self.pvpContainer)
    self.pvpTag:SetText(self.pvpMode)
    self.pvpTag:Dock(TOP)
    self.pvpTag:DockMargin(0, 4, 0, 0)
    self.pvpTag:SetMouseInputEnabled(false)
  end

  function PANEL:SetContract(id, name, spawnPoint, extractionPoint, difficulty, reward, pvpMode)
    self.contractID = id
    self.contractName = name
    self.spawnPoint = spawnPoint
    self.extractionPoint = extractionPoint
    self.difficulty = difficulty
    self.reward = reward
    self.pvpMode = pvpMode

    self.titleLabel:SetText(name)
    self.titleLabel:SizeToContents()
    self.difficultyTag:SetText(difficulty)
    self.difficultyTag:SizeToContents()
    self.rewardTag:SetText(reward)
    self.rewardTag:SizeToContents()
    self.pvpTag:SetText(pvpMode)
    self.pvpTag:SizeToContents()

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

    -- Update text colors
    local textColor = enabled and self.textColor or self.textColorDisabled
    self.titleLabel:SetTextColor(textColor)
    self.difficultyLabel:SetTextColor(ColorAlpha(textColor, 180))
    self.rewardLabel:SetTextColor(ColorAlpha(textColor, 180))
    self.pvpLabel:SetTextColor(ColorAlpha(textColor, 180))

    -- Update tag alphas
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
    local alphaModifier = self.enabled and (self.hovered and 1 or 0.15) or 0.15

    -- Draw angled blue background, leaving room on the left for the parallelogram
    local paraOffset = 40
    local poly = {
      { x = paraOffset,                   y = 0 },
      { x = w,                            y = 0 },
      { x = w,                            y = h },
      { x = paraOffset + self.angleWidth, y = h }
    }

    draw.NoTexture()
    surface.SetDrawColor(ColorAlpha(bgColor, bgColor.a * alphaModifier))
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

    -- Draw unavailable overlay if disabled
    if (not self.enabled) then
      draw.SimpleText(
        "UNAVAILABLE",
        "VersusHeading1",
        w / 2,
        h * .5,
        self.unavailableTextColor,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_BOTTOM
      )

      draw.SimpleText(
        self.unavailableReason,
        "VersusDefault",
        w / 2,
        h * .5,
        self.unavailableTextColor,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_TOP
      )
    end
  end

  function PANEL:OnCursorEntered()
    if (not self.enabled) then
      return
    end

    self.hovered = true
  end

  function PANEL:OnCursorExited()
    if (not self.enabled) then
      return
    end

    self.hovered = false
  end

  function PANEL:DoClick()
    if self.enabled then
      self:OnContractSelected()
    end
  end

  function PANEL:IsHovered()
    return self.hovered
  end

  function PANEL:GetContractID()
    return self.contractID
  end

  function PANEL:OnContractSelected()
    -- Override this in implementation
  end

  vgui.Register("versus_ContractItem", PANEL, "DButton")
end
