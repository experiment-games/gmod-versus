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
    self.titleLabel:DockMargin(120, 16, 0, 0)
    self.titleLabel:SetContentAlignment(4) -- Left align
    self.titleLabel:SizeToContents()
    self.titleLabel:SetMouseInputEnabled(false)

    -- Description label
    self.descriptionLabel = vgui.Create("DLabel", self)
    self.descriptionLabel:SetFont("VersusDefault")
    self.descriptionLabel:SetTextColor(self.textColor)
    self.descriptionLabel:SetText(
      "Contract description goes here. It can be a bit longer and will wrap to multiple lines if needed.")
    self.descriptionLabel:Dock(TOP)
    self.descriptionLabel:DockMargin(120, 0, 20, 0)
    self.descriptionLabel:SetWrap(true)
    self.descriptionLabel:SetAutoStretchVertical(true)
    self.descriptionLabel:SetMouseInputEnabled(false)

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

    -- Let's hide these for now as they're hard to balance
    self.difficultyContainer:SetVisible(false)
    self.rewardContainer:SetVisible(false)
    self.pvpContainer:SetVisible(false)
  end

  function PANEL:SetContract(id, name, description, image, locations, difficulty, reward, pvpMode)
    self.contractID = id
    self.contractName = name
    self.contractDescription = description
    self.image = Material(image)
    self.locations = locations
    self.difficulty = difficulty
    self.reward = reward
    self.pvpMode = pvpMode

    self.titleLabel:SetText(name)
    self.titleLabel:SizeToContents()
    self.descriptionLabel:SetText(description)
    self.descriptionLabel:SizeToContents()
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
    local paraWidth = paraOffset
    local paraSkew = 20

    local poly = {
      { x = paraOffset,                   y = 0 },
      { x = w,                            y = 0 },
      { x = w,                            y = h },
      { x = paraOffset + self.angleWidth, y = h }
    }

    local para = {
      { x = 0,                    y = 0 },
      { x = paraWidth - paraSkew, y = 0 },
      { x = paraWidth + paraSkew, y = h },
      { x = paraWidth,            y = h }
    }

    draw.NoTexture()
    surface.SetDrawColor(ColorAlpha(bgColor, bgColor.a * alphaModifier))
    surface.DrawPoly(poly)
    surface.DrawPoly(para)

    -- Draw contract image as a continuous texture across both polygons (cover fit)
    if (self.image) then
      local toUV = versus.util.newCoverUVMapper(self.image:Width(), self.image:Height(), w, h)

      surface.SetMaterial(self.image)
      surface.SetDrawColor(255, 255, 255, self.hovered and 125 or 15)

      -- Main background polygon
      local u1, v1 = toUV(paraOffset, 0)
      local u2, v2 = toUV(w, 0)
      local u3, v3 = toUV(w, h)
      local u4, v4 = toUV(paraOffset + self.angleWidth, h)
      surface.DrawPoly({
        { x = paraOffset,                   y = 0, u = u1, v = v1 },
        { x = w,                            y = 0, u = u2, v = v2 },
        { x = w,                            y = h, u = u3, v = v3 },
        { x = paraOffset + self.angleWidth, y = h, u = u4, v = v4 },
      })

      -- Left parallelogram (same UV space = continuous image)
      local p1u, p1v = toUV(0, 0)
      local p2u, p2v = toUV(paraWidth - paraSkew, 0)
      local p3u, p3v = toUV(paraWidth + paraSkew, h)
      local p4u, p4v = toUV(paraWidth, h)
      surface.DrawPoly({
        { x = 0,                    y = 0, u = p1u, v = p1v },
        { x = paraWidth - paraSkew, y = 0, u = p2u, v = p2v },
        { x = paraWidth + paraSkew, y = h, u = p3u, v = p3v },
        { x = paraWidth,            y = h, u = p4u, v = p4v },
      })
    end

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
