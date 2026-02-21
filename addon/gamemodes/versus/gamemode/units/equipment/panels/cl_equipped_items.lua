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

    self.modelPanel.OnMousePressed = function(_, keyCode)
      self:OnMousePressed(keyCode)
    end
    self.modelPanel.OnMouseReleased = function(_, keyCode)
      self:OnMouseReleased(keyCode)
    end

    local slotCapitalized = #slot >= 2 and (slot:sub(1, 1):upper() .. slot:sub(2)) or slot:upper()

    self.unequipBtn = vgui.Create("versus_Button", self)
    self.unequipBtn:SetText("Unequip " .. slotCapitalized)
    self.unequipBtn:SizeToContents()
    self.unequipBtn.DoClick = onUnequip
  end

  function PANEL:PerformLayout(width, height)
    local btnH = IsValid(self.unequipBtn) and self.unequipBtn:GetTall() or 0

    if IsValid(self.modelPanel) then
      self.modelPanel:SetPos(0, 0)
      self.modelPanel:SetSize(width, height - btnH)
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

  function PANEL:PaintOver(width, height)
    if (not self.item) then
      return
    end

    if (self.wrappedName == nil) then
      self.wrappedName = {}
      versus.message.wrapText(self.item.name, "VersusDefaultOutlined", self:GetWide(), nil, self.wrappedName)
    end

    local y = SPACING
    local rarityID = self.item.rarity
    local rarity = versus.item.getRarity(rarityID)
    local color = rarity and rarity.color or color_white

    self.nameTextY = y

    for _, text in pairs(self.wrappedName) do
      draw.DrawText(text, "VersusDefaultOutlined", width * .5, y, color, TEXT_ALIGN_CENTER)
      y = y + 20
    end

    self.textHeight = y

    versus.item.drawRarityBadge(rarityID, width / 2, (self.textHeight or SPACING) + 8)

    if (self.item.onPaintOver) then
      self.item:onPaintOver(self, width, height)
    end
  end

  function PANEL:Think()
    -- Detect drag start based on hold time + movement threshold
    if self.dragStartTime and not self.isDragging then
      if not input.IsMouseDown(MOUSE_FIRST) then
        self.dragStartTime = nil
        return
      end

      if SysTime() - self.dragStartTime > 0.1 then
        local x, y = self:LocalCursorPos()
        local distance = math.sqrt((x - self.dragStartX) ^ 2 + (y - self.dragStartY) ^ 2)

        if distance > 5 then
          self:StartDragging()
        end
      end
    end

    -- Keep ghost panel under the cursor
    if IsValid(self.ghostPanel) and self.isDragging then
      local x, y = input.GetCursorPos()
      self.ghostPanel:SetPos(x - 64, y - 64)
    end
  end

  function PANEL:OnMousePressed(mouse)
    if mouse ~= MOUSE_FIRST then return end

    if self.item then
      self.dragStartTime = SysTime()
      self.dragStartX, self.dragStartY = self:LocalCursorPos()
    end
  end

  function PANEL:OnMouseReleased(mouse)
    if mouse ~= MOUSE_FIRST then return end

    if self.isDragging then
      if UNIT.unequipZoneHovering then
        net.Start("versus.equipment.unequip")
        net.WriteString(self.slot)
        net.SendToServer()
      end

      self:StopDragging()
    end

    self.dragStartTime = nil
  end

  function PANEL:StartDragging()
    if self.isDragging then return end

    self.isDragging = true
    self:SetAlpha(100)
    self:MouseCapture(true)

    local ghost = vgui.Create("versus_Inventory_ItemGhost")
    ghost:SetItem(self.item)
    ghost:SetSize(128, 128)
    ghost:SetZPos(9999)
    ghost:SetMouseInputEnabled(false)
    ghost:SetKeyboardInputEnabled(false)
    ghost:SetPaintedManually(true)
    self.ghostPanel = ghost

    UNIT.draggingEquippedItem = { item = self.item, slot = self.slot, panel = self }
  end

  function PANEL:StopDragging()
    if not self.isDragging then return end

    self.isDragging = false
    self:SetAlpha(255)
    self:MouseCapture(false)

    if IsValid(self.ghostPanel) then
      self.ghostPanel:Remove()
      self.ghostPanel = nil
    end

    UNIT.draggingEquippedItem = nil
    UNIT.unequipZoneHovering = false
  end

  function PANEL:OnRemove()
    if self.isDragging then
      self:StopDragging()
    end
    self.dragStartTime = nil
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
