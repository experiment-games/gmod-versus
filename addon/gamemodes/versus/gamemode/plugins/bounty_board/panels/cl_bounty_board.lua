local PLUGIN          = PLUGIN

local color_header_bg = Color(15, 22, 32, 255)
local color_text      = Color(220, 230, 240, 255)
local color_dim       = Color(140, 155, 170, 255)
local color_accent    = Color(80, 140, 220, 255)
local color_reward    = Color(120, 215, 140, 255)
local color_complete  = Color(110, 205, 130, 255)
local color_row_even  = Color(25, 36, 52, 200)
local color_row_odd   = Color(20, 28, 40, 200)
local color_row_hover = Color(42, 60, 88, 220)
local color_bar_bg    = Color(33, 47, 66, 220)
local color_bar_fill  = Color(80, 140, 220, 240)
local color_bar_done  = Color(110, 205, 130, 240)
local color_strikeout = Color(175, 95, 95, 220)

local ROW_H           = 132
local BAR_H           = 8
local BTN_W           = 106
local BTN_H           = 34
local DESC_TOP_OFFSET = 24
local DESC_BAR_GAP    = 8
local BAR_TEXT_GAP    = 6

--[[
  Bounty row
--]]

do
  local ROW = {}

  function ROW:Init()
    self:SetTall(ROW_H)
    self.data    = nil
    self.hovered = false
    self.isEven  = false
  end

  function ROW:SetData(entry, isEven)
    self.data   = entry
    self.isEven = isEven

    -- Turn-in button (only shown when completed and not yet turned in)
    if entry.completed_at > 0 and not entry.turned_in then
      if not IsValid(self.turnInBtn) then
        self.turnInBtn = vgui.Create("versus_Button", self)
      end

      self.turnInBtn:SetText("TURN IN")
      self.turnInBtn:SetType("primary")
      self.turnInBtn:SetSize(BTN_W, BTN_H)
      self.turnInBtn.DoClick = function()
        net.Start("versus.bounty_board.turnIn")
        net.WriteUInt(entry.id, PLUGIN.BIT_BOUNTY_DB_ID)
        net.SendToServer()
      end
    elseif IsValid(self.turnInBtn) then
      self.turnInBtn:Remove()
      self.turnInBtn = nil
    end

    self:InvalidateLayout(true)
  end

  function ROW:OnCursorEntered() self.hovered = true end

  function ROW:OnCursorExited() self.hovered = false end

  function ROW:PerformLayout(w, h)
    if IsValid(self.turnInBtn) then
      local sp = GAMEMODE.SPACING
      self.turnInBtn:SetPos(w - BTN_W - sp, h / 2 - BTN_H / 2)
    end
  end

  function ROW:Paint(w, h)
    local d = self.data
    if not d then return end

    -- Background
    local bg = self.hovered and color_row_hover
        or (self.isEven and color_row_even or color_row_odd)
    draw.RoundedBox(4, 0, 0, w, h, bg)

    local sp         = GAMEMODE.SPACING

    -- Determine state
    local isComplete = d.completed_at > 0
    local isTurnedIn = d.turned_in
    local progress   = math.min(d.progress, d.targetCount)
    local fraction   = d.targetCount > 0 and (progress / d.targetCount) or 0

    -- Name
    local nameColor  = isTurnedIn and color_dim or color_text
    local nameFont   = "VersusHeading2"

    draw.SimpleText(
      d.name,
      nameFont,
      sp, sp * .5,
      nameColor,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    -- Strikethrough for turned-in bounties
    if isTurnedIn then
      surface.SetFont(nameFont)
      local nameW, nameH = surface.GetTextSize(d.name)

      if nameW and nameW > 0 then
        surface.SetDrawColor(color_strikeout)
        surface.DrawRect(sp, sp * .5 + nameH * 0.5, nameW, 2)
      end
    end

    -- Description
    local descY = sp * .5 + DESC_TOP_OFFSET
    draw.SimpleText(
      d.description,
      "VersusDefault",
      sp, descY,
      color_dim,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    -- Progress bar (top-down layout to avoid overlap)
    surface.SetFont("VersusDefault")
    local _, descH = surface.GetTextSize(d.description or "")
    local barY = descY + descH + DESC_BAR_GAP
    local barW = w - sp * 2 - (isComplete and not isTurnedIn and (BTN_W + sp) or 0)

    draw.RoundedBox(3, sp, barY, barW, BAR_H, color_bar_bg)

    local fillColor = isComplete and color_bar_done or color_bar_fill
    draw.RoundedBox(3, sp, barY, math.max(0, math.Round(barW * fraction)), BAR_H, fillColor)

    -- Progress text
    local progressText = string.format("%d / %d", progress, d.targetCount)
    local valueY = barY + BAR_H + BAR_TEXT_GAP
    draw.SimpleText(
      progressText,
      "VersusDefault",
      sp, valueY,
      isComplete and color_complete or color_dim,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    -- Reward
    local rewardText = "$" .. tostring(d.reward)
    draw.SimpleText(
      rewardText,
      "VersusButton",
      w - sp - (isComplete and not isTurnedIn and (BTN_W + sp + 4) or 0),
      valueY,
      color_reward,
      TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP
    )

    -- Status label
    local statusText = ""
    local statusColor = color_dim

    if isTurnedIn then
      statusText  = "COLLECTED"
      statusColor = color_dim
    elseif isComplete then
      statusText  = "READY TO TURN IN"
      statusColor = color_complete
    end

    if statusText ~= "" then
      draw.SimpleText(
        statusText,
        "VersusDefault",
        w - sp - (isComplete and not isTurnedIn and (BTN_W + sp + 110) or 120),
        valueY,
        statusColor,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
      )
    end
  end

  vgui.Register("versus_BountyRow", ROW, "EditablePanel")
end

--[[
  Main panel
--]]

do
  local PANEL = {}

  local function formatResetTime(seconds)
    local remaining = math.max(0, seconds or 0)
    local hours     = math.floor(remaining / 3600)
    local minutes   = math.floor((remaining % 3600) / 60)
    local secs      = math.floor(remaining % 60)

    return string.format("RESETS IN %02d:%02d:%02d", hours, minutes, secs)
  end

  function PANEL:Init()
    local w = math.max(ScrW() * 0.55, 720)
    local h = ScrH()

    self:SetSize(w, h)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha        = 0
    self.contentAlpha   = 0
    self.animStart      = CurTime()
    self.animDuration   = 0.35
    self.closing        = false
    self.closeStart     = 0

    self.timeUntilReset = 0
    self.entries        = {}

    local sp            = GAMEMODE.SPACING
    self:DockPadding(sp, sp, sp, sp)

    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(color_text)
    self.titleLabel:SetText("BOUNTY BOARD")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, sp * 0.5)

    self.infoBar = vgui.Create("EditablePanel", self)
    self.infoBar:Dock(TOP)
    self.infoBar:SetTall(48)
    self.infoBar:DockMargin(0, 0, 0, sp * 0.5)
    self.infoBar.Paint = function() end

    self.subtitleLabel = vgui.Create("DLabel", self.infoBar)
    self.subtitleLabel:Dock(LEFT)
    self.subtitleLabel:SetFont("VersusDefault")
    self.subtitleLabel:SetTextColor(color_dim)
    self.subtitleLabel:SetText("Daily repeatable contracts")
    self.subtitleLabel:DockMargin(0, 0, sp, 0)
    self.subtitleLabel:SizeToContents()

    self.resetLabel = vgui.Create("DLabel", self.infoBar)
    self.resetLabel:Dock(RIGHT)
    self.resetLabel:SetFont("VersusButton")
    self.resetLabel:SetTextColor(color_accent)
    self.resetLabel:SetText(formatResetTime(self.timeUntilReset))
    self.resetLabel:SizeToContents()

    self.columnHeader = vgui.Create("EditablePanel", self)
    self.columnHeader:Dock(TOP)
    self.columnHeader:SetTall(48)
    self.columnHeader:DockMargin(0, 0, 0, 8)
    self.columnHeader.Paint = function(_, pw, ph)
      draw.RoundedBox(4, 0, 0, pw, ph, color_header_bg)

      local psp = GAMEMODE.SPACING
      local cy  = ph / 2

      draw.SimpleText(
        "BOUNTY",
        "VersusButton",
        psp,
        cy,
        color_dim,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
      )

      draw.SimpleText(
        "PROGRESS",
        "VersusButton",
        pw * 0.52,
        cy,
        color_dim,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )

      draw.SimpleText(
        "REWARD",
        "VersusButton",
        pw - psp - BTN_W - 26,
        cy,
        color_dim,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
      )

      draw.SimpleText(
        "STATUS",
        "VersusButton",
        pw - psp,
        cy,
        color_dim,
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
      )
    end

    self.closeButton = vgui.Create("versus_Button", self)
    self.closeButton:Dock(BOTTOM)
    self.closeButton:DockMargin(0, sp * 0.5, 0, 0)
    self.closeButton:SetText("CLOSE")
    self.closeButton:SetType("secondary")
    self.closeButton.DoClick = function()
      self:Close()
    end

    self.rowList = vgui.Create("versus_ScrollPanel", self)
    self.rowList:Dock(FILL)
    self.rowList:DockMargin(0, 0, 0, 0)
  end

  function PANEL:RebuildRows()
    self.rowList:Clear()

    if #self.entries == 0 then
      local spacing = GAMEMODE.SPACING
      local emptyLabel = vgui.Create("DLabel", self.rowList)
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(color_dim)
      emptyLabel:SetText("No bounties available right now. Check back soon!")
      emptyLabel:SizeToContents()
      emptyLabel:Dock(TOP)
      emptyLabel:DockMargin(spacing, spacing, spacing, 0)
      return
    end

    for i, entry in ipairs(self.entries) do
      local row = vgui.Create("versus_BountyRow", self.rowList)
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, 8)
      row:SetData(entry, i % 2 == 0)
    end
  end

  function PANEL:OnBountyData(entries, serverNow)
    self.entries = entries or {}

    -- Calculate time remaining until first expiry (all daily entries share this)
    if self.entries[1] then
      self.timeUntilReset = math.max(0, self.entries[1].expires_at - serverNow)
    end

    if IsValid(self.resetLabel) then
      self.resetLabel:SetText(formatResetTime(self.timeUntilReset))
      self.resetLabel:SizeToContents()
    end

    self:RebuildRows()
  end

  --- Begin the close animation.
  function PANEL:Close()
    if self.closing then return end

    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:OnRemove()
    if PLUGIN.boardPanel == self then
      PLUGIN.boardPanel = nil
    end
  end

  function PANEL:OnKeyCodeTyped(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Close()
      return true
    end
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if not self.closing then
      if elapsed < self.animDuration then
        local progress    = math.ease.InOutQuad(elapsed / self.animDuration)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha      = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart

      if closeElapsed < 0.3 then
        local progress    = 1 - (closeElapsed / 0.3)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self:Remove()
      end
    end

    if self.timeUntilReset > 0 then
      self.timeUntilReset = math.max(0, self.timeUntilReset - FrameTime())

      if IsValid(self.resetLabel) then
        self.resetLabel:SetText(formatResetTime(self.timeUntilReset))
        self.resetLabel:SizeToContents()
      end
    end

    self:SetAlpha(self.contentAlpha)
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)

    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout()
    self:Center()
  end

  vgui.Register("versus_BountyBoard", PANEL, "EditablePanel")
end
