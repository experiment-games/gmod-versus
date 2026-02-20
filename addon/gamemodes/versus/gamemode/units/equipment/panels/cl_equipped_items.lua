local UNIT = UNIT

-- Individual row showing one equipped item with its slot label, item name, and an unequip button.
do
  local PANEL = {}

  function PANEL:Init()
    self.slotLabel = vgui.Create("DLabel", self)
    self.slotLabel:SetFont("VersusSmall")
    self.slotLabel:SetTextColor(Color(120, 140, 170))

    self.nameLabel = vgui.Create("DLabel", self)
    self.nameLabel:SetFont("VersusDefault")
    self.nameLabel:SetTextColor(Color(210, 220, 235))

    self.unequipBtn = vgui.Create("versus_Button", self)
    self.unequipBtn:SetText("UNEQUIP")
    self.unequipBtn:SizeToContents()
  end

  --- @param slot string The slot name (e.g. "hat")
  --- @param item VersusItem The item table for the equipped item
  --- @param onUnequip function Called when the unequip button is clicked
  function PANEL:Setup(slot, item, onUnequip)
    self.slotLabel:SetText(slot:upper())
    self.slotLabel:SizeToContents()

    self.nameLabel:SetText(item.name)
    self.nameLabel:SizeToContents()

    self.unequipBtn.DoClick = onUnequip
  end

  function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, Color(20, 30, 46, 210))

    return true
  end

  function PANEL:PerformLayout(w, h)
    local padding = 16

    self.slotLabel:SetPos(padding, padding)
    self.slotLabel:SizeToContents()

    local nameY = padding + self.slotLabel:GetTall() + 2
    self.nameLabel:SetPos(padding, nameY)
    self.nameLabel:SizeToContents()

    local desiredH = nameY + self.nameLabel:GetTall() + padding

    local btnW, btnH = self.unequipBtn:GetSize()
    self.unequipBtn:SetPos(w - btnW - padding, (desiredH - btnH) / 2)

    if (desiredH ~= h) then
      self:SetTall(desiredH)
    end
  end

  vgui.Register("versus_Equipment_Row", PANEL, "EditablePanel")
end

-- Container listing all currently equipped items, used in the character screen left panel.
do
  local PANEL = {}

  AccessorFunc(PANEL, "characterPanel", "CharacterPanel")

  function PANEL:Init()
    self.rows = {}
  end

  --- Rebuilds the list of equipped item rows from the current equipped state.
  function PANEL:Refresh()
    for _, row in ipairs(self.rows) do
      if (IsValid(row)) then
        row:Remove()
      end
    end

    self.rows = {}

    local equippedItems = versus.equipment.getEquippedItems(LocalPlayer())
    local hasAny = false

    for slot, item in SortedPairs(equippedItems) do
      if (not item) then
        continue
      end

      hasAny = true

      local row = vgui.Create("versus_Equipment_Row", self)
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, 4)
      row:Setup(slot, item, function()
        net.Start("versus.equipment.unequip")
        net.WriteString(slot)
        net.SendToServer()
      end)

      table.insert(self.rows, row)
    end

    if (not hasAny) then
      local empty = vgui.Create("DLabel", self)
      empty:Dock(TOP)
      empty:SetFont("VersusDefault")
      empty:SetTextColor(Color(100, 115, 145))
      empty:SetText("Nothing equipped.")
      empty:SizeToContents()

      table.insert(self.rows, empty)
    end

    if (IsValid(self.characterPanel)) then
      self.characterPanel:UpdateModel()
    end

    self:InvalidateLayout(true)
  end

  function PANEL:PerformLayout(w, h)
    local totalH = 0

    for _, row in ipairs(self.rows) do
      if (IsValid(row)) then
        totalH = totalH + row:GetTall() + 4
      end
    end

    self:SetTall(math.max(totalH, 1))
  end

  vgui.Register("versus_EquippedItems", PANEL, "EditablePanel")
end
