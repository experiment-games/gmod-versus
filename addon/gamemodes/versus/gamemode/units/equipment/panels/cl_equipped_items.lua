local UNIT = UNIT
local SPACING = 16

-- Individual equipped-item cell: shows the item's 3D model, its slot label, and an Unequip button.
-- Mirrors the look of versus_Inventory_Item.
do
  local PANEL = {}

  function PANEL:Init()
    versus.panel.initPanelSkin(self)
  end

  --- @param slot string The slot name (e.g. "hat")
  --- @param item VersusItem The item table for the equipped item
  --- @param onUnequip function Called when the unequip button is clicked
  function PANEL:Setup(slot, item, onUnequip)
    if self.isAlreadyBuilt then return end
    self.isAlreadyBuilt = true

    self.slot = slot
    self.item = item

    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetItem(item)
    self.modelPanel:SetFOV(item.inventoryFov or 80)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))
    self.modelPanel:SetVersusTooltip(function(tooltip)
      local name = tooltip:AddRow("name")
      name:SetText(item.name)
      name:SetImportant(true)
      name:SizeToContents()
      local description = tooltip:AddRow("description")
      description:SetText(item.description)
      description:SizeToContents()
    end)

    self.slotLabel = vgui.Create("DLabel", self)
    self.slotLabel:SetFont("VersusSmall")
    self.slotLabel:SetTextColor(Color(120, 140, 170))
    self.slotLabel:SetText(slot:upper())
    self.slotLabel:SizeToContents()

    self.unequipBtn = vgui.Create("versus_Button", self)
    self.unequipBtn:SetText("Unequip")
    self.unequipBtn:SizeToContents()
    self.unequipBtn.DoClick = onUnequip
  end

  function PANEL:PerformLayout(width, height)
    local btnH = IsValid(self.unequipBtn) and self.unequipBtn:GetTall() or 0

    if IsValid(self.modelPanel) then
      self.modelPanel:SetPos(0, 0)
      self.modelPanel:SetSize(width, height - btnH)
    end

    if IsValid(self.slotLabel) then
      self.slotLabel:SizeToContents()
      self.slotLabel:SetPos(math.floor((width - self.slotLabel:GetWide()) / 2), math.floor(SPACING / 2))
    end

    if IsValid(self.unequipBtn) then
      self.unequipBtn:SetWide(width)
      self.unequipBtn:SetPos(0, height - btnH)
    end
  end

  function PANEL:Paint(width, height)
    local btnH = IsValid(self.unequipBtn) and self.unequipBtn:GetTall() or 0
    GAMEMODE:DrawBackgroundBox(0, 0, width, height - btnH * 0.5, color_background)
    versus.panel.drawButtonGroupBackground(0, height - btnH, width, btnH, 255)
  end

  vgui.Register("versus_Equipment_Item", PANEL, "EditablePanel")
end

-- Container listing all currently equipped items as a vertical list of model panel cells.
do
  local PANEL = {}

  AccessorFunc(PANEL, "characterPanel", "CharacterPanel")

  function PANEL:Init()
    self.itemPanels = {}
  end

  --- Rebuilds the list of equipped item cells from the current equipped state.
  function PANEL:Refresh()
    for _, panel in ipairs(self.itemPanels) do
      if IsValid(panel) then
        panel:Remove()
      end
    end
    self.itemPanels = {}

    local equippedItems = versus.equipment.getEquippedItems(LocalPlayer())
    local hasAny = false

    for slot, item in SortedPairs(equippedItems) do
      if item then
        hasAny = true
        break
      end
    end

    if not hasAny then
      local empty = vgui.Create("DLabel", self)
      empty:Dock(TOP)
      empty:SetFont("VersusDefault")
      empty:SetTextColor(Color(100, 115, 145))
      empty:SetText("Nothing equipped.")
      empty:SizeToContents()
      table.insert(self.itemPanels, empty)
      self:InvalidateLayout(true)
      return
    end

    local itemSize = math.max(self:GetWide(), 1)

    local isFirst = true
    for slot, item in SortedPairs(equippedItems) do
      if not item then continue end

      local cell = vgui.Create("versus_Equipment_Item", self)
      cell:Dock(TOP)
      cell:DockMargin(0, isFirst and 0 or SPACING, 0, 0)
      cell:SetTall(itemSize)
      cell:Setup(slot, item, function()
        net.Start("versus.equipment.unequip")
        net.WriteString(slot)
        net.SendToServer()
      end)

      table.insert(self.itemPanels, cell)
      isFirst = false
    end

    if IsValid(self.characterPanel) then
      self.characterPanel:UpdateModel()
    end

    self:InvalidateLayout(true)
  end

  function PANEL:PerformLayout(w, h)
    local totalH = 0

    for _, panel in ipairs(self.itemPanels) do
      if IsValid(panel) then
        -- First size it to be as tall as it is wide
        panel:SetTall(panel:GetWide())

        totalH = totalH + panel:GetTall() + (totalH > 0 and SPACING or 0)
      end
    end

    self:SetTall(math.max(totalH, 1))
  end

  vgui.Register("versus_EquippedItems", PANEL, "EditablePanel")
end
