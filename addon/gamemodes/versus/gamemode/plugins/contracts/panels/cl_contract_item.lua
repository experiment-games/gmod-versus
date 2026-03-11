local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self.contractName = "[Contract] Name"
    self.enabled = true
    self.unavailableReason = "RECENTLY EXECUTED"

    self.bgColor = Color(45, 85, 135, 255) -- Saturated blue
    self.bgColorDisabled = Color(45, 85, 135, 50)
    self.textColor = Color(220, 230, 240, 255)
    self.textColorDisabled = Color(141, 153, 174, 50)
    self.unavailableTextColor = Color(220, 100, 100, 255)

    self.hovered = false
    self.angleSlope = 0.4 -- horizontal pixels per vertical pixel for all diagonal edges

    self:SetText("")

    -- Title label
    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading2")
    self.titleLabel:SetTextColor(self.textColor)
    self.titleLabel:SetText(self.contractName)
    self.titleLabel:SetContentAlignment(4) -- Left align
    self.titleLabel:SizeToContents()
    self.titleLabel:SetMouseInputEnabled(false)

    -- Description label
    self.descriptionLabel = vgui.Create("DLabel", self)
    self.descriptionLabel:SetFont("VersusDefault")
    self.descriptionLabel:SetTextColor(self.textColor)
    self.descriptionLabel:SetText(
      "Contract description goes here. It can be a bit longer and will wrap to multiple lines if needed.")
    self.descriptionLabel:SetWrap(true)
    self.descriptionLabel:SetAutoStretchVertical(true)
    self.descriptionLabel:SetMouseInputEnabled(false)

    -- Tags row container
    self.tagsContainer = vgui.Create("EditablePanel", self)
    self.tagsContainer:SetTall(24)
    self.tagsContainer:SetMouseInputEnabled(false)

    self.tagPanels = {}
  end

  function PANEL:SetContract(id, name, description, image, locations, tags)
    self.contractID = id
    self.contractName = name
    self.contractDescription = description
    self.image = Material(image)
    self.locations = locations

    self.titleLabel:SetText(name)
    self.titleLabel:SizeToContents()
    self.descriptionLabel:SetText(description)
    self.descriptionLabel:SizeToContents()

    -- Rebuild tag panels
    for _, tagPanel in ipairs(self.tagPanels) do
      if IsValid(tagPanel) then tagPanel:Remove() end
    end
    self.tagPanels = {}

    for _, tag in ipairs(tags or {}) do
      local tagPanel = vgui.Create("versus_Tag", self.tagsContainer)
      tagPanel:SetText(tag.label or "")
      tagPanel:SetColor(tag.color or Color(200, 200, 200))
      tagPanel:Dock(LEFT)
      tagPanel:DockMargin(0, 0, 6, 0)
      tagPanel:SetMouseInputEnabled(false)
      table.insert(self.tagPanels, tagPanel)
    end
  end

  function PANEL:SetEnabled(enabled)
    self.enabled = enabled

    -- Update text colors
    local textColor = enabled and self.textColor or self.textColorDisabled
    self.titleLabel:SetTextColor(textColor)
    self.descriptionLabel:SetTextColor(textColor)

    -- Update tag alphas
    for _, tagPanel in ipairs(self.tagPanels) do
      if IsValid(tagPanel) then
        tagPanel:SetAlpha(enabled and 255 or 15)
      end
    end
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
    local paraEdge = 20                    -- fixed width of parallelogram top and bottom edges
    local angleWidth = h * self.angleSlope -- scale with height to keep angle constant

    local poly = {
      { x = paraOffset,              y = 0 },
      { x = w,                       y = 0 },
      { x = w,                       y = h },
      { x = paraOffset + angleWidth, y = h }
    }

    -- Top edge: 0→paraEdge (20px), bottom edge: angleWidth→angleWidth+paraEdge (20px)
    local para = {
      { x = 0,                     y = 0 },
      { x = paraEdge,              y = 0 },
      { x = paraEdge + angleWidth, y = h },
      { x = angleWidth,            y = h }
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
      local u4, v4 = toUV(paraOffset + angleWidth, h)
      surface.DrawPoly({
        { x = paraOffset,              y = 0, u = u1, v = v1 },
        { x = w,                       y = 0, u = u2, v = v2 },
        { x = w,                       y = h, u = u3, v = v3 },
        { x = paraOffset + angleWidth, y = h, u = u4, v = v4 },
      })

      -- Left parallelogram (same UV space = continuous image)
      local p1u, p1v = toUV(0, 0)
      local p2u, p2v = toUV(paraEdge, 0)
      local p3u, p3v = toUV(paraEdge + angleWidth, h)
      local p4u, p4v = toUV(angleWidth, h)
      surface.DrawPoly({
        { x = 0,                     y = 0, u = p1u, v = p1v },
        { x = paraEdge,              y = 0, u = p2u, v = p2v },
        { x = paraEdge + angleWidth, y = h, u = p3u, v = p3v },
        { x = angleWidth,            y = h, u = p4u, v = p4v },
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

  function PANEL:PerformLayout(width, height)
    -- First ensure all text if set with the height of this panel, with spacing
    local spacing = 12
    local y = spacing

    self.titleLabel:SetPos(120, y)
    self.titleLabel:SetWide(self:GetWide() - 120 - spacing)
    self.titleLabel:SizeToContentsY()
    y = y + self.titleLabel:GetTall() + (spacing * .5)

    self.descriptionLabel:SetPos(120, y)
    self.descriptionLabel:SetWide(self:GetWide() - 120 - spacing)
    self.descriptionLabel:SizeToContentsY()
    y = y + self.descriptionLabel:GetTall() + spacing

    self.tagsContainer:SetPos(120, y)
    self.tagsContainer:SetWide(self:GetWide() - 120 - spacing)
    self.tagsContainer:SetTall(24)

    local totalHeight = y + self.tagsContainer:GetTall() + spacing + spacing

    if (totalHeight ~= height) then
      self:SetTall(totalHeight)
    end
  end

  vgui.Register("versus_ContractItem", PANEL, "DButton")
end
