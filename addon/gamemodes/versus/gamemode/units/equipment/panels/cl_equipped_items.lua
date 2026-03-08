local UNIT = UNIT
local SPACING = 16

-- Individual equipped-item cell: shows the item's 3D model, its slot label, and an Unequip button.
-- Mirrors the look of versus_Inventory_Item.
do
  local PANEL = {}

  DEFINE_BASECLASS("versus_DraggableItem")

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
    self.onUnequip = onUnequip

    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetItem(item)
    self.modelPanel:SetFOV(item.inventoryFov or 80)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))
    self.modelPanel:SetVersusTooltip(function(tooltip)
      local description = tooltip:AddRow("description")
      description:SetText(versus.util.resolve(item.description))
      description:SizeToContents()

      hook.Run("BuildItemTooltipRows", tooltip, item)
    end)

    self.modelPanel.OnMousePressed = function(_, keyCode)
      self:OnMousePressed(keyCode)
    end
    self.modelPanel.OnMouseReleased = function(_, keyCode)
      self:OnMouseReleased(keyCode)
    end

    self:RefreshButtons()

    hook.Add("DoRefreshEquippedItemButtons", self, function()
      self:RefreshButtons()
    end)
  end

  function PANEL:RefreshButtons()
    if IsValid(self.unequipBtn) then
      self.unequipBtn:Remove()
      self.unequipBtn = nil
    end

    if IsValid(self.moreButton) then
      self.moreButton:Remove()
      self.moreButton = nil
    end

    -- Too big if we also show the ... more button.
    -- local slotCapitalized = #slot >= 2 and (slot:sub(1, 1):upper() .. slot:sub(2)) or slot:upper()

    self.unequipBtn = vgui.Create("versus_Button", self)
    self.unequipBtn:SetText("Unequip") -- .. slotCapitalized)
    self.unequipBtn:SizeToContents()
    self.unequipBtn.DoClick = self.onUnequip

    local itemFunctions = {}
    hook.Run("BuildEquippedItemFunctions", self.item, self.slot, itemFunctions)

    if #itemFunctions > 0 then
      self.moreButton = vgui.Create("versus_Button", self)
      self.moreButton:SetText("...")
      self.moreButton:SizeToContents()
      self.moreButton.DoClick = function()
        local menu = self:BuildMoreMenu(itemFunctions)
        menu:Open()
      end
    end
  end

  function PANEL:BuildMoreMenu(itemFunctions)
    local menu = DermaMenu()
    local item = self.item
    local slot = self.slot

    table.sort(itemFunctions)
    hook.Run("SortEquippedItemFunctions", item, slot, itemFunctions)

    for _, text in pairs(itemFunctions) do
      local originalText = text

      if (item.actionTexts ~= nil) then
        text = versus.util.resolve(item.actionTexts[originalText], item) or originalText
      end

      hook.Run("BuildEquippedItemFunction", item, slot, menu, originalText, text, self)
    end

    return menu
  end

  function PANEL:PerformLayout(width, height)
    local btnH = IsValid(self.unequipBtn) and self.unequipBtn:GetTall() or 0

    if IsValid(self.modelPanel) then
      self.modelPanel:SetPos(0, 0)
      self.modelPanel:SetSize(width, height - btnH)
    end

    if IsValid(self.unequipBtn) then
      self.unequipBtn:SetWide(width - (IsValid(self.moreButton) and (self.moreButton:GetWide() + SPACING) or 0))
      self.unequipBtn:SetPos(0, height - btnH)
    end

    if IsValid(self.moreButton) then
      self.moreButton:SetPos(width - self.moreButton:GetWide(), height - self.moreButton:GetTall())
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

    hook.Run("PaintEquippedItemOver", self, width, height)
  end

  function PANEL:GetDragItem()
    return self.item
  end

  function PANEL:OnDragStarted()
    local ghost = vgui.Create("versus_Inventory_ItemGhost")
    ghost:SetItem(self.item)
    ghost:SetSize(128, 128)
    ghost:SetZPos(9999)
    ghost:SetMouseInputEnabled(false)
    ghost:SetKeyboardInputEnabled(false)
    ghost:SetPaintedManually(true)
    self.ghostPanel = ghost

    versus.dragDrop.startDragSession(
      "equipped", {
        item = self.item,
        slot = self.slot,
        ghostPanel = ghost,
      }
    )
  end

  function PANEL:OnDragDropped()
    local handled = versus.dragDrop.fireDroppedForSession("equipped")
    self:_StopDrag(handled)
  end

  function PANEL:OnDragStopped(dropped)
    if IsValid(self.ghostPanel) then
      self.ghostPanel:Remove()
      self.ghostPanel = nil
    end

    versus.dragDrop.endDragSession("equipped")
  end

  function PANEL:Think()
    BaseClass.Think(self)

    -- Keep ghost panel under the cursor while dragging
    if IsValid(self.ghostPanel) and self.isDragging then
      local x, y = input.GetCursorPos()
      self.ghostPanel:SetPos(x - 64, y - 64)
    end
  end

  function PANEL:OnRemove()
    BaseClass.OnRemove(self)
  end

  vgui.Register("versus_Equipment_Item", PANEL, "versus_DraggableItem")
end

-- Container listing all currently equipped items as a vertical list of model panel cells.
do
  local PANEL = {}

  AccessorFunc(PANEL, "characterPanel", "CharacterPanel")

  function PANEL:Init()
    self.itemPanels = {}

    hook.Add("PlayerEquippedItem", "versus_EquippedItemsRefresh", function(player, slot, item)
      if player == LocalPlayer() and IsValid(self) then
        self:Refresh()
      end
    end)

    hook.Add("PlayerUnequippedItem", "versus_EquippedItemsRefresh", function(player, slot, item)
      if player == LocalPlayer() and IsValid(self) then
        self:Refresh()
      end
    end)
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

    if IsValid(self.characterPanel) then
      self.characterPanel:UpdateModel()
    end

    if (IsValid(versus.characterPanel) and versus.characterPanel ~= self.characterPanel) then
      versus.characterPanel:UpdateModel()
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

  function PANEL:OnRemove()
    hook.Remove("PlayerEquippedItem", "versus_EquippedItemsRefresh")
    hook.Remove("PlayerUnequippedItem", "versus_EquippedItemsRefresh")
  end

  vgui.Register("versus_EquippedItems", PANEL, "EditablePanel")
end
