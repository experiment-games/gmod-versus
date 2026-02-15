local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self.item = nil
    self.rarityColor = Color(141, 153, 174)

    -- Model panel for item icon
    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetPos(16, 16)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))

    -- Background colors
    self.bgColor = Color(25, 35, 50, 180)
    self.accentColor = Color(80, 140, 220, 255)
  end

  function PANEL:SetItem(item)
    self.item = item

    if item then
      -- Set the model panel
      if self.modelPanel.SetItem then
        self.modelPanel:SetItem(item)
        self.modelPanel:SetFOV(item.rewardFov or 70)
      end

      -- Determine rarity color
      if item.rarity then
        local rarity = versus.item.getRarity(item.rarity)
        self.rarityColor = rarity and rarity.color or Color(141, 153, 174)
      end
    end
  end

  function PANEL:GetItem()
    return self.item
  end

  function PANEL:PerformLayout(w, h)
    self.modelPanel:SetSize(w - 32, h - 150)
  end

  function PANEL:Paint(w, h)
    if not self.item then return end

    -- Background card
    draw.RoundedBox(8, 0, 0, w, h, self.bgColor)

    -- Top accent line with rarity color
    surface.SetDrawColor(self.rarityColor.r, self.rarityColor.g, self.rarityColor.b, 255)
    surface.DrawRect(0, 0, w, 4)

    -- Item name
    local itemName = self.item.name or "Unknown Item"

    local textWidth, textHeight = draw.SimpleText(
      itemName,
      "VersusHeading3",
      w / 2,
      h - 100,
      self.rarityColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    -- Item type
    local itemType = self.item.type or self.item.category or "Item"

    textWidth, textHeight = draw.SimpleText(
      itemType:upper(),
      "VersusDefault",
      w / 2,
      h - 70,
      ColorAlpha(self.rarityColor, 180),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    versus.item.drawRarityBadge(self.item.rarity, w / 2, h - 70 + textHeight + 4)
  end

  vgui.Register("versus_RewardItem", PANEL, "EditablePanel")
end
