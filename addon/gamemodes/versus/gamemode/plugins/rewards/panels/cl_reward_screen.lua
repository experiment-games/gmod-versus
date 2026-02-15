local PLUGIN = PLUGIN
local ITEM_WIDTH = 280
local ITEM_HEIGHT = 280
local ITEM_SPACING = 24

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.title = "Extraction Successful"
    self.subtitle = "Mission Complete"
    self.items = {}

    -- Background overlay
    self.bgAlpha = 0
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    -- Main content container
    self.contentPanel = vgui.Create("DSizeToContents", self)
    self.contentPanel:SetWide(math.min(ScrW() * .7, 900))
    self.contentPanel:SetSizeX(false)

    -- Title label
    self.titleLabel = vgui.Create("DLabel", self.contentPanel)
    self.titleLabel:SetFont("VersusHeadingHuge")
    self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
    self.titleLabel:SetText(self.title)
    self.titleLabel:SetContentAlignment(5)
    self.titleLabel:Dock(TOP)

    -- Subtitle label
    self.subtitleLabel = vgui.Create("DLabel", self.contentPanel)
    self.subtitleLabel:SetFont("VersusButton")
    self.subtitleLabel:SetTextColor(Color(80, 140, 220, 255))
    self.subtitleLabel:SetText(self.subtitle)
    self.subtitleLabel:SetContentAlignment(8)
    self.subtitleLabel:Dock(TOP)
    self.subtitleLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Rewards header container
    self.rewardsHeader = vgui.Create("EditablePanel", self.contentPanel)
    self.rewardsHeader:Dock(TOP)
    self.rewardsHeader:SetTall(40)

    -- Items container
    self.itemsContainer = vgui.Create("EditablePanel", self.contentPanel)
    self.itemsContainer:Dock(TOP)
    self.itemsContainer:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    self.itemsContainer:SetTall(ITEM_HEIGHT)
    self.itemsContainer.PerformLayout = function(pnl, w, h)
      -- Center items horizontally
      local numItems = #self.itemPanels
      if numItems == 0 then return end

      local totalWidth = (numItems * ITEM_WIDTH) + ((numItems - 1) * ITEM_SPACING)
      local startX = (w - totalWidth) / 2

      for i, itemPanel in ipairs(self.itemPanels) do
        if IsValid(itemPanel) then
          local xPos = startX + ((i - 1) * (ITEM_WIDTH + ITEM_SPACING))
          itemPanel:SetPos(xPos, 0)
        end
      end
    end

    self.itemPanels = {}

    -- Experience header container
    self.experienceHeader = vgui.Create("EditablePanel", self.contentPanel)
    self.experienceHeader:Dock(TOP)
    self.experienceHeader:SetTall(40)
    self.experienceHeader:NoClipping(true)
    self.experienceHeader.Paint = function(experienceHeader, w, h)
      -- "Experience" header
      surface.SetFont("VersusHeading2")
      local expHeaderText = "EXPERIENCE"

      draw.SimpleText(
        expHeaderText,
        "VersusHeading2",
        w / 2,
        h / 2,
        ColorAlpha(Color(220, 230, 240, 255), self.contentAlpha),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )

      self:DrawLineUnderHeader(0, 0, w, h, self.contentAlpha)
    end

    -- Experience section (centered container)
    local expContainer = vgui.Create("DSizeToContents", self.contentPanel)
    expContainer:Dock(TOP)
    expContainer:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    expContainer:SetSizeX(false)

    self.experiencePanel = vgui.Create("versus_ExperienceDisplay", expContainer)
    self.experiencePanel:SetSize(800, 150)

    -- Continue button container
    local buttonContainer = vgui.Create("DSizeToContents", self.contentPanel)
    buttonContainer:Dock(TOP)
    buttonContainer:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    buttonContainer:SetSizeX(false)

    self.continueButton = vgui.Create("versus_Button", buttonContainer)
    self.continueButton:SetText("CONTINUE")
    self.continueButton:SetSize(300, 64)
    self.continueButton:SetType("primary")
    self.continueButton.DoClick = function()
      self:OnContinue()
    end
  end

  function PANEL:SetTitle(title)
    self.title = title or "Extraction Successful"
    self.titleLabel:SetText(self.title)
    self.titleLabel:SizeToContents()
  end

  function PANEL:SetSubtitle(subtitle)
    self.subtitle = subtitle or ""
    self.subtitleLabel:SetText(self.subtitle)
    self.subtitleLabel:SizeToContents()
  end

  function PANEL:SetItems(items)
    self.items = items or {}

    -- Clear existing item panels
    for _, panel in ipairs(self.itemPanels) do
      if IsValid(panel) then
        panel:Remove()
      end
    end
    self.itemPanels = {}

    -- Create new item panels
    local numItems = math.min(#self.items, 3)
    if numItems == 0 then
      -- Hide the rewards section if no items
      self.rewardsHeader:SetVisible(false)
      self.rewardsHeader:SetTall(0)
      self.itemsContainer:SetVisible(false)
      self.itemsContainer:SetTall(0)
      return
    end

    -- Show the rewards section if we have items
    self.rewardsHeader:SetVisible(true)
    self.rewardsHeader:SetTall(40)
    self.itemsContainer:SetVisible(true)
    self.itemsContainer:SetTall(ITEM_HEIGHT)

    for i, item in ipairs(self.items) do
      if i > 3 then break end

      local itemPanel = vgui.Create("versus_RewardItem", self.itemsContainer)
      itemPanel:SetItem(item)
      itemPanel:SetSize(ITEM_WIDTH, ITEM_HEIGHT)

      table.insert(self.itemPanels, itemPanel)
    end

    -- Trigger layout update to center items
    self.itemsContainer:InvalidateLayout(true)
  end

  function PANEL:SetExperience(xpGained, currentLevel, xpToNextLevel, currentXP)
    self.experiencePanel:SetExperienceData(xpGained, currentLevel, xpToNextLevel, currentXP)
  end

  function PANEL:OnContinue()
    if (self.closing) then
      return
    end

    -- Close the panel with fade out animation
    self.closing = true
    self.closeStart = CurTime()

    net.Start("versus.rewards.screenContinue")
    net.SendToServer()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    -- Fade in animation
    if not self.closing then
      if elapsed < self.animDuration then
        local progress = elapsed / self.animDuration
        progress = math.ease.InOutQuad(progress)

        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha = 200
        self.contentAlpha = 255
      end
    else
      -- Fade out animation
      local closeElapsed = CurTime() - self.closeStart
      if closeElapsed < 0.3 then
        local progress = 1 - (closeElapsed / 0.3)
        self.bgAlpha = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self:Remove()
      end
    end

    self:SetAlpha(self.contentAlpha)
  end

  function PANEL:Paint(w, h)
    -- Dark overlay background
    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PaintOver(w, h)
    if self.contentAlpha < 10 then return end
    if #self.items == 0 then return end -- Don't draw rewards header if no items

    local alpha = self.contentAlpha

    -- Paint section headers on their respective containers
    local x, y = self.rewardsHeader:LocalToScreen(0, 0)
    local headerW = self.rewardsHeader:GetWide()
    local headerH = self.rewardsHeader:GetTall()

    -- "Extraction Rewards" header
    surface.SetFont("VersusHeading2")
    local headerText = "EXTRACTION REWARDS"

    draw.SimpleText(
      headerText,
      "VersusHeading2",
      x + headerW / 2,
      y + headerH / 2,
      ColorAlpha(Color(220, 230, 240, 255), alpha),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    self:DrawLineUnderHeader(x, y, headerW, headerH, alpha)
  end

  function PANEL:DrawLineUnderHeader(x, y, w, h, alpha)
    -- Decorative line under experience header
    surface.SetDrawColor(ColorAlpha(Color(80, 140, 220, 255), alpha))
    local lineWidth = 600
    surface.DrawRect(x + (w - lineWidth) / 2, y + h / 2 + 20, lineWidth, 2)
  end

  function PANEL:PerformLayout(w, h)
    self.contentPanel:Center()
    self.experiencePanel:CenterHorizontal()
    self.continueButton:CenterHorizontal()
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)
  end

  vgui.Register("versus_RewardScreen", PANEL, "EditablePanel")
end
