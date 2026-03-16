local PLUGIN = PLUGIN
local EGG_LABEL_TEXT = "Easter Eggs Returned"

do
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(64)
    self:SetMouseInputEnabled(false)

    self.count = 0

    self.bgColor = Color(25, 35, 50, 200)
    self.accentColor = Color(80, 140, 220, 255)
    self.textColor = Color(200, 220, 240, 255)
    self.countColor = Color(120, 200, 120, 255)
  end

  function PANEL:SetCount(amount)
    self.count = amount or 0
  end

  function PANEL:SizeToContents()
    surface.SetFont("VersusButton")
    local labelW = surface.GetTextSize(EGG_LABEL_TEXT)
    local countW = surface.GetTextSize(tostring(math.floor(self.count)))

    local maxTextW = math.max(labelW, countW)
    self:SetWide(maxTextW + 100)
  end

  function PANEL:Paint(w, h)
    draw.RoundedBox(h, 0, 0, w, h, self.bgColor)

    surface.SetFont("VersusButton")
    local labelW, labelH = surface.GetTextSize(EGG_LABEL_TEXT)
    local labelY = (h - labelH) / 2 - 8

    surface.SetTextColor(self.textColor)
    surface.SetTextPos((w - labelW) / 2, labelY)
    surface.DrawText(EGG_LABEL_TEXT)

    local countText = tostring(math.floor(self.count))
    local countW, countH = surface.GetTextSize(countText)
    local countY = (h - countH) / 2 + 8

    surface.SetTextColor(self.countColor)
    surface.SetTextPos((w - countW) / 2, countY)
    surface.DrawText(countText)
  end

  vgui.Register("versus_Easter_EggDisplay", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    PLUGIN.easterPanel = self

    self:SetSize(
      math.max(ScrW() * 0.5, 700),
      ScrH()
    )

    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha = 0
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    self.contentPanel = vgui.Create("EditablePanel", self)
    self.contentPanel:DockPadding(
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING,
      GAMEMODE.SPACING
    )
  end

  function PANEL:Populate(data)
    if self.closing then return end

    self.data = data
    self.contentPanel:Clear()

    local titleLabel = vgui.Create("DLabel", self.contentPanel)
    titleLabel:SetFont("VersusHeading1")
    titleLabel:SetTextColor(PLUGIN.XEN_COLOR)
    titleLabel:SetText("DIANA")
    titleLabel:SizeToContents()
    titleLabel:Dock(TOP)
    titleLabel:DockMargin(0, 0, 0, 0)

    -- Close button anchored to the bottom before any FILL panel is docked
    local buttonContainer = vgui.Create("EditablePanel", self.contentPanel)
    buttonContainer:Dock(BOTTOM)
    buttonContainer:SetTall(50)

    self.cancelButton = vgui.Create("versus_Button", buttonContainer)
    self.cancelButton:SetText("CLOSE")
    self.cancelButton:Dock(FILL)
    self.cancelButton:SetType("secondary")
    self.cancelButton.DoClick = function()
      self:Close()
    end

    if not data.isEaster then
      self:BuildOffSeasonScreen()
    elseif data.eggCount >= 10 then
      self:BuildClaimMaskScreen()
    else
      self:BuildEggHuntScreen()
      self.inventoryPanel:Refresh()
    end
  end

  function PANEL:BuildOffSeasonScreen()
    local infoLabel = vgui.Create("DLabel", self.contentPanel)
    infoLabel:SetFont("VersusDefault")
    infoLabel:SetTextColor(Color(180, 190, 200, 255))
    infoLabel:SetText(
      "It's been weeks since I've seen daylight down here in the bunker."
      .. " Jack keeps pulling the most ridiculous pranks! Yesterday he replaced all my"
      .. " paintbrushes with rubber snakes. I don't know how I put up with him, honestly."
    )
    infoLabel:SetWrap(true)
    infoLabel:SetAutoStretchVertical(true)
    infoLabel:Dock(TOP)
    infoLabel:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, 0)
  end

  function PANEL:BuildClaimMaskScreen()
    local data = self.data

    local infoLabel = vgui.Create("DLabel", self.contentPanel)
    infoLabel:SetFont("VersusDefault")
    infoLabel:SetTextColor(Color(180, 190, 200, 255))
    infoLabel:SetText(
      "You actually found all my Easter Eggs! I can't believe it — Jack is going to be furious."
      .. " You deserve a reward for your trouble. Here, take this as a thank you!"
    )
    infoLabel:SetWrap(true)
    infoLabel:SetAutoStretchVertical(true)
    infoLabel:Dock(TOP)
    infoLabel:DockMargin(0, GAMEMODE.SPACING * 0.5, 0, GAMEMODE.SPACING)

    local headerPanel = vgui.Create("EditablePanel", self.contentPanel)
    headerPanel:Dock(TOP)
    headerPanel:SetTall(64)
    headerPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    self.eggDisplay = vgui.Create("versus_Easter_EggDisplay", headerPanel)
    self.eggDisplay:Dock(RIGHT)
    self.eggDisplay:SetWide(250)
    self.eggDisplay:SetCount(data.eggCount)

    local rewardPanel = vgui.Create("DSizeToContents", self.contentPanel)
    rewardPanel:Dock(TOP)
    rewardPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    rewardPanel:SetSizeX(false)

    local rewardTitle = vgui.Create("DLabel", rewardPanel)
    rewardTitle:SetFont("VersusHeading2")
    rewardTitle:SetTextColor(Color(200, 210, 220, 255))
    rewardTitle:SetText("YOUR REWARD")
    rewardTitle:SizeToContents()
    rewardTitle:Dock(TOP)
    rewardTitle:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    local itemRow = vgui.Create("EditablePanel", rewardPanel)
    itemRow:Dock(TOP)
    itemRow:SetTall(50)

    local maskNameLabel = vgui.Create("DLabel", itemRow)
    maskNameLabel:SetFont("VersusDefault")
    maskNameLabel:SetTextColor(Color(200, 220, 240, 255))
    maskNameLabel:SetText("Easter Bunny Mask")
    maskNameLabel:SetContentAlignment(4)
    maskNameLabel:Dock(FILL)

    self.claimButton = vgui.Create("versus_Button", itemRow)
    self.claimButton:SetWide(160)
    self.claimButton:Dock(RIGHT)
    self.claimButton:DockMargin(GAMEMODE.SPACING, 0, 0, 0)

    if data.hasMask then
      self.claimButton:SetText("CLAIMED")
      self.claimButton:SetEnabled(false)
    else
      self.claimButton:SetText("CLAIM REWARD")
      self.claimButton:SetType("primary")
      self.claimButton.DoClick = function()
        self:ClaimMask()
      end
    end
  end

  function PANEL:BuildEggHuntScreen()
    local data = self.data

    local infoLabel = vgui.Create("DLabel", self.contentPanel)
    infoLabel:SetFont("VersusDefault")
    infoLabel:SetTextColor(Color(180, 190, 200, 255))
    infoLabel:SetText(
      "Oh no! I spent all day painting Easter Eggs and now Jack has hidden them around the map!"
      .. " If I get my hands on him, I'll make sure he regrets it!"
      .. " Can you help me find them? I'll reward you with something special once you find 10!"
    )
    infoLabel:SetWrap(true)
    infoLabel:SetAutoStretchVertical(true)
    infoLabel:Dock(TOP)
    infoLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    local headerPanel = vgui.Create("EditablePanel", self.contentPanel)
    headerPanel:Dock(TOP)
    headerPanel:SetTall(64)
    headerPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    self.eggDisplay = vgui.Create("versus_Easter_EggDisplay", headerPanel)
    self.eggDisplay:Dock(RIGHT)
    self.eggDisplay:SetWide(250)
    self.eggDisplay:SetCount(data.eggCount)

    self.inventoryPanel = vgui.Create("versus_Inventory", self.contentPanel)
    self.inventoryPanel:Dock(FILL)
    self.inventoryPanel:DockMargin(0, 0, 0, GAMEMODE.SPACING)
    self.inventoryPanel:SetDisableSettings(true)
    self.inventoryPanel:SetItemsPerRow(3)

    self.inventoryPanel.header:SetVisible(false)

    self.inventoryPanel:SetItemFilter(function(item)
      return item.itemID == "easter_egg"
    end)

    self.inventoryPanel:SetOverrideItemActions(function(stackData)
      return self:CreateTurnInMenu(stackData)
    end)

    self.inventoryPanel:SetOverrideItemPrimaryAction({
      label = "Turn In",
      callback = function(stackData)
        self:TurnIn(stackData.keys[1], stackData.count)
      end
    })
  end

  function PANEL:CreateTurnInMenu(stackData)
    local menu = DermaMenu()

    if not stackData or not stackData.item then
      return
    end

    local item = stackData.item

    if item.itemID ~= "easter_egg" then
      return
    end

    -- Turn in single item
    menu:AddOption("Turn in 1x", function()
      self:TurnIn(stackData.keys[1], 1)
    end)

    -- Turn in all items in stack
    if stackData.count > 1 then
      menu:AddOption("Turn in All (" .. stackData.count .. "x)", function()
        self:TurnIn(stackData.keys[1], stackData.count)
      end)

      -- Turn in half
      local halfAmount = math.ceil(stackData.count * 0.5)
      menu:AddOption("Turn in Half (" .. halfAmount .. "x)", function()
        self:TurnIn(stackData.keys[1], halfAmount)
      end)

      -- Turn in custom amount
      menu:AddOption("Turn in Amount...", function()
        versus.panel.stringRequest(
          "Turn In Amount",
          "Enter the amount to turn in:",
          "",
          function(text)
            local amount = tonumber(text)

            if amount and amount > 0 and amount <= stackData.count then
              self:TurnIn(stackData.keys[1], amount)
            else
              versus.message.notify("Invalid amount entered!", NOTIFY_ERROR)
            end
          end
        )
      end)
    end

    menu:Open()
  end

  function PANEL:TurnIn(itemKey, amount)
    if not itemKey then return end

    net.Start("versus.npc.easter.turnIn")
    net.WriteUInt(itemKey, 16)
    net.WriteUInt(amount, 16)
    net.SendToServer()

    surface.PlaySound("buttons/button14.wav")
  end

  function PANEL:ClaimMask()
    net.Start("versus.npc.easter.claimMask")
    net.SendToServer()

    surface.PlaySound("buttons/button14.wav")

    if IsValid(self.claimButton) then
      self.claimButton:SetEnabled(false)
      self.claimButton:SetText("CLAIMING...")
    end
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

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
    Derma_DrawBackgroundBlur(self, self.animStart)

    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self.contentPanel:SetWide(self:GetWide() - GAMEMODE.SPACING * 2)
    self.contentPanel:SetTall(h)
    self.contentPanel:Center()

    self:Center()
  end

  vgui.Register("versus_Easter", PANEL, "EditablePanel")
end

net.Receive("versus.npc.easter.updateEggCount", function(len, player)
  local newCount = net.ReadUInt(16)
  local hasMask = net.ReadBool()

  if PLUGIN.easterPanel and IsValid(PLUGIN.easterPanel) then
    local panel = PLUGIN.easterPanel
    panel.data.eggCount = newCount
    panel.data.hasMask = hasMask
    panel:Populate(panel.data)
  end
end)

net.Receive("versus.npc.easter.maskClaimed", function()
  if PLUGIN.easterPanel and IsValid(PLUGIN.easterPanel) then
    local panel = PLUGIN.easterPanel
    panel.data.hasMask = true
    panel:Populate(panel.data)
  end
end)
