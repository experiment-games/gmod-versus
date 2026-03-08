local PLUGIN = PLUGIN

local MATERIAL_LABEL_TEXT = "MATERIALS"
local MATERIAL_ANIMATION_DURATION = 0.5
local RAW_FURNITURE_MATERIAL_ID = "raw_furniture_material"

do
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(64)
    self:SetMouseInputEnabled(false)

    self.count = 0
    self.displayCount = 0
    self.animationStartCount = 0
    self.animationStartTime = 0
    self.animating = false

    self.bgColor = Color(25, 35, 50, 200)
    self.accentColor = Color(80, 140, 220, 255)
    self.textColor = Color(200, 220, 240, 255)
    self.countColor = Color(120, 200, 120, 255)
  end

  function PANEL:SetCount(amount)
    if self.count ~= (amount or 0) then
      self.animationStartCount = self.displayCount
      self.animationStartTime = CurTime()
      self.animating = true
    end
    self.count = amount or 0
  end

  function PANEL:Think()
    -- Animate the count changing
    if self.animating then
      local elapsed = CurTime() - self.animationStartTime
      local progress = math.min(elapsed / MATERIAL_ANIMATION_DURATION, 1)
      local easedProgress = 1 - math.pow(1 - progress, 3)

      self.displayCount = self.animationStartCount + (self.count - self.animationStartCount) * easedProgress

      if progress >= 1 then
        self.displayCount = self.count
        self.animating = false
      end
    end

    -- Auto-update from player's current inventory
    local currentCount = versus.inventory.countItem(LocalPlayer(), RAW_FURNITURE_MATERIAL_ID)
    if currentCount ~= self.count then
      self:SetCount(currentCount)
    end
  end

  function PANEL:SizeToContents()
    surface.SetFont("VersusButton")
    local labelW = surface.GetTextSize(MATERIAL_LABEL_TEXT)
    local countW = surface.GetTextSize(tostring(math.floor(self.displayCount)))

    local maxTextW = math.max(labelW, countW)
    self:SetWide(maxTextW + 100)
  end

  function PANEL:Paint(w, h)
    draw.RoundedBox(h, 0, 0, w, h, self.bgColor)

    surface.SetFont("VersusButton")
    local labelW, labelH = surface.GetTextSize(MATERIAL_LABEL_TEXT)
    local labelY = (h - labelH) / 2 - 8

    surface.SetTextColor(self.textColor)
    surface.SetTextPos((w - labelW) / 2, labelY)
    surface.DrawText(MATERIAL_LABEL_TEXT)

    local countText = tostring(math.floor(self.displayCount))
    local countW, countH = surface.GetTextSize(countText)
    local countY = (h - countH) / 2 + 8

    surface.SetTextColor(self.countColor)
    surface.SetTextPos((w - countW) / 2, countY)
    surface.DrawText(countText)
  end

  vgui.Register("versus_MaterialDisplay", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    self:Dock(TOP)
    self:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)

    self.isHovered = false
    self:SetMouseInputEnabled(true)

    -- Left container for the 3D model
    self.leftContainer = vgui.Create("EditablePanel", self)
    self.leftContainer:Dock(LEFT)
    self.leftContainer:SetMouseInputEnabled(false)

    -- 3D Model Panel
    self.itemModel = vgui.Create("DModelPanel", self.leftContainer)
    self.itemModel:Dock(FILL)
    self.itemModel:SetMouseInputEnabled(false)
    self.itemModel:SetFOV(60)

    -- Right container for the build button
    self.rightContainer = vgui.Create("EditablePanel", self)
    self.rightContainer:SetWide(200)
    self.rightContainer:Dock(RIGHT)
    self.rightContainer:DockPadding(0, 10, 10, 10)

    -- Center container for item info
    self.centerContainer = vgui.Create("EditablePanel", self)
    self.centerContainer:Dock(FILL)
    self.centerContainer:DockPadding(10, 10, 10, 10)

    -- Item Name label
    self.itemNameLabel = vgui.Create("DLabel", self.centerContainer)
    self.itemNameLabel:SetFont("VersusHeading3")
    self.itemNameLabel:SetTextColor(Color(220, 230, 240, 255))
    self.itemNameLabel:SetText("Loading...")
    self.itemNameLabel:Dock(TOP)
    self.itemNameLabel:SizeToContents()

    -- Item Category label
    self.categoryLabel = vgui.Create("DLabel", self.centerContainer)
    self.categoryLabel:SetFont("VersusDefault")
    self.categoryLabel:SetTextColor(Color(180, 190, 200, 255))
    self.categoryLabel:Dock(TOP)
    self.categoryLabel:DockMargin(0, 10, 0, 0)
    self.categoryLabel:SetVisible(false)

    -- Build button
    self.buildButton = vgui.Create("versus_Button", self.rightContainer)
    self.buildButton:SetText("BUILD")
    self.buildButton:Dock(BOTTOM)
    self.buildButton:DockMargin(0, 0, 0, 0)
    self.buildButton:SetType("primary")

    -- Cost label
    self.costLabel = vgui.Create("DLabel", self.rightContainer)
    self.costLabel:SetFont("VersusDefault")
    self.costLabel:SetTextColor(Color(120, 200, 120, 255))
    self.costLabel:Dock(TOP)
    self.costLabel:SetVisible(false)
    self.costLabel:SetContentAlignment(5)
  end

  function PANEL:SetCatalogItem(catalogItem)
    self.catalogItem = catalogItem

    if not catalogItem then return end

    -- Set up the 3D model
    self.itemModel:SetModel(catalogItem.model)

    local minBound, maxBound = self.itemModel.Entity:GetRenderBounds()
    local size = 0
    size = math.max(size, math.abs(minBound.x) + math.abs(maxBound.x))
    size = math.max(size, math.abs(minBound.y) + math.abs(maxBound.y))
    size = math.max(size, math.abs(minBound.z) + math.abs(maxBound.z))

    self.itemModel:SetCamPos(Vector(size, size, size))
    self.itemModel:SetLookAt((minBound + maxBound) * 0.5)

    -- Set item name
    self.itemNameLabel:SetText(catalogItem.name or "Unknown")
    self.itemNameLabel:SizeToContents()

    -- Set category
    if catalogItem.category then
      self.categoryLabel:SetText(tostring(catalogItem.category))
      self.categoryLabel:SetVisible(true)
      self.categoryLabel:SizeToContents()
    end

    -- Set cost label
    local cost = catalogItem.materialCost or 0
    self.costLabel:SetText(cost .. "x Raw Furniture Material")
    self.costLabel:SetVisible(true)
    self.costLabel:SizeToContents()

    -- Setup build button
    self.buildButton.DoClick = function()
      self:OnBuild()
    end

    self.DoClick = function()
      self:OnBuild()
    end

    self:UpdateAffordability()
    self:SizeToContents()
  end

  function PANEL:UpdateAffordability()
    if not self.catalogItem then return end

    local cost = self.catalogItem.materialCost or 0
    local materialCount = versus.inventory.countItem(LocalPlayer(), "raw_furniture_material")

    if materialCount >= cost then
      self.costLabel:SetTextColor(Color(120, 200, 120, 255))
      self.buildButton:SetEnabled(true)
    else
      self.costLabel:SetTextColor(Color(220, 80, 80, 255))
      self.buildButton:SetEnabled(false)
    end
  end

  function PANEL:OnBuild()
    if not self.catalogItem then return end

    net.Start("versus.furnitureBuilder.build")
    net.WriteString(self.catalogItem.id)
    net.SendToServer()

    surface.PlaySound("buttons/button14.wav")
  end

  function PANEL:Think()
    if self.catalogItem and (not self.nextAffordCheck or CurTime() > self.nextAffordCheck) then
      self:UpdateAffordability()
      self.nextAffordCheck = CurTime() + 0.5
    end
  end

  function PANEL:Paint(w, h)
    local bgColor = self.isHovered and Color(40, 45, 52, 220) or Color(30, 35, 40, 200)
    draw.RoundedBox(16, 0, 0, w, h, bgColor)

    local accentColor = self.isHovered and Color(90, 160, 240, 230) or Color(80, 140, 220, 200)
    draw.RoundedBoxEx(16, 0, 0, self.leftContainer:GetWide(), h, accentColor, true, false, true, false)
  end

  function PANEL:OnMousePressed()
    if not self:IsEnabled() then return end
    self.pressed = true
  end

  function PANEL:OnMouseReleased()
    if self.pressed and self.isHovered then
      self:DoClick()
    end
    self.pressed = false
  end

  function PANEL:OnCursorEntered()
    if not self:IsEnabled() then return end

    self.buildButton:SetHovered(true)
    self.isHovered = true
  end

  function PANEL:OnCursorExited()
    if not self:IsEnabled() then return end

    self.buildButton:SetHovered(false)
    self.isHovered = false
  end

  -- Size based on the title, category, and cost labels, with a minimum height to accommodate the model and button
  function PANEL:SizeToContents()
    local titleHeight = self.itemNameLabel:GetTall()
    local categoryHeight = self.categoryLabel:GetTall()
    local costHeight = self.costLabel:GetTall()

    local titleLeft, titleTop, titleRight, titleBottom = self.itemNameLabel:GetDockMargin()
    local categoryLeft, categoryTop, categoryRight, categoryBottom = self.categoryLabel:GetDockMargin()
    local costLeft, costTop, costRight, costBottom = self.costLabel:GetDockMargin()

    local centerPaddingTop, centerPaddingBottom = 10, 10

    local contentHeight = titleHeight + categoryHeight + costHeight
        + titleTop + titleBottom
        + categoryTop + categoryBottom
        + costTop + costBottom
        + centerPaddingTop + centerPaddingBottom

    self.leftContainer:SetWide(contentHeight)
    self:SetTall(contentHeight)
  end

  vgui.Register("versus_FurnitureCatalogItem", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    self:SetMouseInputEnabled(true)

    local headingContainer = vgui.Create("EditablePanel", self)
    headingContainer:Dock(TOP)
    headingContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    self.titleLabel = vgui.Create("DLabel", headingContainer)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText("FURNITURE CATALOG")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(FILL)
    self.titleLabel:DockMargin(0, 0, 0, 0)

    headingContainer:SetTall(self.titleLabel:GetTall())

    self.materialDisplay = vgui.Create("versus_MaterialDisplay", headingContainer)
    self.materialDisplay:Dock(RIGHT)
    self.materialDisplay:DockMargin(GAMEMODE.SPACING, 0, 0, 0)
    self.materialDisplay:SizeToContents()

    self.filterContainer = vgui.Create("DHorizontalScroller", self)
    self.filterContainer:Dock(TOP)
    self.filterContainer:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.filterContainer:SetTall(45)
    self.filterContainer:SetOverlap(-(GAMEMODE.SPACING * 0.5))

    self.filterButtons = {}
    self.activeFilter = nil

    self.catalogItemsContainer = vgui.Create("versus_ScrollPanel", self)
    self.catalogItemsContainer:Dock(FILL)

    self:Populate()
  end

  function PANEL:Populate()
    self.catalogItemsContainer:Clear()

    local allItems = PLUGIN.catalogItems

    local categories = {}
    for _, item in pairs(allItems) do
      if item.category and not table.HasValue(categories, item.category) then
        table.insert(categories, item.category)
      end
    end
    table.sort(categories)

    self:CreateFilterButtons(categories)

    local sortedItems = {}
    for _, item in pairs(allItems) do
      table.insert(sortedItems, item)
    end
    table.sort(sortedItems, function(a, b)
      if a.materialCost == b.materialCost then
        return a.name < b.name
      end

      return a.materialCost < b.materialCost
    end)

    self.allItems = sortedItems
    self:RefreshItems()
  end

  function PANEL:CreateFilterButtons(categories)
    for _, btn in pairs(self.filterButtons) do
      btn:Remove()
    end
    self.filterButtons = {}

    local allButton = vgui.Create("versus_Button", self.filterContainer)
    allButton:SetText("ALL")
    allButton:Dock(LEFT)
    allButton:SizeToContents()
    allButton:DockMargin(0, 0, GAMEMODE.SPACING * 0.5, 0)
    allButton:SetType(self.activeFilter == nil and "primary" or "secondary")
    allButton.DoClick = function()
      self:SetFilter(nil)
    end
    self.filterContainer:AddPanel(allButton)
    table.insert(self.filterButtons, allButton)

    for _, category in ipairs(categories) do
      local btn = vgui.Create("versus_Button", self.filterContainer)
      btn:SetText(string.upper(tostring(category)))
      btn:Dock(LEFT)
      btn:SizeToContents()
      btn:DockMargin(0, 0, GAMEMODE.SPACING * 0.5, 0)
      btn:SetType(self.activeFilter == category and "primary" or "secondary")
      btn.DoClick = function()
        self:SetFilter(category)
      end
      self.filterContainer:AddPanel(btn)
      table.insert(self.filterButtons, btn)
    end
  end

  function PANEL:SetFilter(category)
    self.activeFilter = category

    for i, btn in ipairs(self.filterButtons) do
      if i == 1 then
        btn:SetType(category == nil and "primary" or "secondary")
      else
        local btnCategory = string.lower(btn:GetText())
        local activeCategory = category and string.lower(tostring(category)) or nil
        btn:SetType(btnCategory == activeCategory and "primary" or "secondary")
      end
    end

    self:RefreshItems()
  end

  function PANEL:RefreshItems()
    self.catalogItemsContainer:Clear()

    if not self.allItems then return end

    local itemsToShow = {}

    for _, item in ipairs(self.allItems) do
      if self.activeFilter == nil or item.category == self.activeFilter then
        table.insert(itemsToShow, item)
      end
    end

    for _, item in ipairs(itemsToShow) do
      local itemPanel = vgui.Create("versus_FurnitureCatalogItem", self.catalogItemsContainer)
      itemPanel:SetCatalogItem(item)
      self.catalogItemsContainer:AddItem(itemPanel)
    end
  end

  vgui.Register("versus_FurnitureCatalogContent", PANEL, "EditablePanel")
end
