local UNIT = UNIT

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)

    self:SetSize(UNIT.width, UNIT.height - 8)

    -- Create a panel list to store the items.
    self.itemsList = vgui.Create("versus_ScrollPanel", self)

    -- Create the text for this category.
    local text = vgui.Create("versus_Rules_Text", self)

    -- Set the help for this category.
    text:SetText(string.Explode("\n", versus.config["Rules"]))

    -- Add the text to the item list.
    self.itemsList:AddItem(text)
  end

  function PANEL:PerformLayout()
    self:StretchToParent(0, 22, 0, 0)
    self.itemsList:StretchToParent(0, 0, 0, 0)
  end

  vgui.Register("versus_Rules", PANEL, "Panel")
end

do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)
    self.labels = {}
  end

  -- Set Text.
  function PANEL:SetText(text)
    for _, label in pairs(self.labels) do
      label:Remove()
    end

    -- Define our x and y positions.
    local y = 5

    for _, rule in pairs(text) do
      local label = vgui.Create("DLabel", self)

      label:SetFont("VersusDefault")

      -- Set the text of the label.
      label:SetText(rule)
      label:SetTextColor(color_white)
      label:SizeToContents()

      -- Insert the label into our labels table.
      table.insert(self.labels, label)

      -- Increase the y position.
      y = y + label:GetTall() + 8
    end

    -- Set the size of the panel.
    self:SetSize(UNIT.width, y)
  end

  function PANEL:PerformLayout()
    local y = 5

    for i, label in pairs(self.labels) do
      --self.labels[k]:SetPos(self:GetWide() / 2 - self.labels[k]:GetWide() / 2, y)
      self.labels[i]:SetPos(5, y)

      -- Increase the y position.
      y = y + self.labels[i]:GetTall() + 8
    end
  end

  vgui.Register("versus_Rules_Text", PANEL, "EditablePanel")
end
