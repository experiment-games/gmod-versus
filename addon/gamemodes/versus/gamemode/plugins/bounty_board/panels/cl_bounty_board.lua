local PLUGIN = PLUGIN

local color_bg        = Color(18, 14, 10, 245)
local color_header_bg = Color(30, 22, 12, 255)
local color_border    = Color(160, 130, 60, 200)
local color_title     = Color(230, 200, 120, 255)
local color_text      = Color(220, 210, 185, 255)
local color_dim       = Color(150, 140, 115, 200)
local color_reward    = Color(100, 220, 100, 255)
local color_complete  = Color(80, 200, 80, 255)
local color_expired   = Color(180, 60, 60, 200)
local color_row_even  = Color(28, 22, 14, 210)
local color_row_odd   = Color(22, 17, 10, 210)
local color_row_hover = Color(50, 38, 18, 230)
local color_bar_bg    = Color(40, 30, 15, 200)
local color_bar_fill  = Color(200, 160, 40, 220)
local color_bar_done  = Color(60, 180, 60, 220)
local color_btn_bg    = Color(60, 45, 15, 240)
local color_btn_hover = Color(100, 76, 20, 255)
local color_btn_text  = Color(240, 210, 100, 255)
local color_strikeout = Color(180, 60, 60, 200)

local PANEL_W    = 560
local PANEL_H    = 560
local ROW_H      = 100
local PAD        = 12
local BAR_H      = 10
local BTN_W      = 90
local BTN_H      = 28

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
      self.turnInBtn:SetSize(BTN_W, BTN_H)
      self.turnInBtn:SetPos(self:GetWide() - BTN_W - PAD, (ROW_H - BTN_H) / 2)
      self.turnInBtn.DoClick = function()
        net.Start("versus.bounty_board.turnIn")
        net.WriteUInt(entry.id, PLUGIN.BIT_BOUNTY_DB_ID)
        net.SendToServer()
      end
    elseif IsValid(self.turnInBtn) then
      self.turnInBtn:Remove()
      self.turnInBtn = nil
    end
  end

  function ROW:OnCursorEntered() self.hovered = true  end
  function ROW:OnCursorExited()  self.hovered = false end

  function ROW:Paint(w, h)
    local d = self.data
    if not d then return end

    -- Background
    local bg = self.hovered and color_row_hover
        or (self.isEven and color_row_even or color_row_odd)
    draw.RoundedBox(4, 0, 0, w, h, bg)

    local sp = PAD
    local cy = h / 2

    -- Determine state
    local isComplete  = d.completed_at > 0
    local isTurnedIn  = d.turned_in
    local progress    = math.min(d.progress, d.targetCount)
    local fraction    = d.targetCount > 0 and (progress / d.targetCount) or 0

    -- Name
    local nameColor = isTurnedIn and color_dim or color_text
    local nameFont  = "VersusHeading2"

    draw.SimpleText(
      d.name,
      nameFont,
      sp, sp,
      nameColor,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    -- Strikethrough for turned-in bounties
    if isTurnedIn then
      local nameW, nameH = surface.GetTextSize(d.name)

      if nameW and nameW > 0 then
        surface.SetDrawColor(color_strikeout)
        surface.DrawRect(sp, sp + nameH * 0.5, nameW, 2)
      end
    end

    -- Description
    draw.SimpleText(
      d.description,
      "VersusDefault",
      sp, sp + 22,
      color_dim,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    -- Progress bar
    local barY = sp + 22 + 18
    local barW = w - sp * 2 - (isComplete and not isTurnedIn and (BTN_W + PAD * 2) or 0)

    draw.RoundedBox(3, sp, barY, barW, BAR_H, color_bar_bg)

    local fillColor = isComplete and color_bar_done or color_bar_fill
    draw.RoundedBox(3, sp, barY, math.max(2, math.Round(barW * fraction)), BAR_H, fillColor)

    -- Progress text
    local progressText = string.format("%d / %d", progress, d.targetCount)
    draw.SimpleText(
      progressText,
      "VersusDefault",
      sp, barY + BAR_H + 4,
      isComplete and color_complete or color_dim,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
    )

    -- Reward
    local rewardText = "$" .. tostring(d.reward)
    draw.SimpleText(
      rewardText,
      "VersusHeading2",
      w - sp - (isComplete and not isTurnedIn and (BTN_W + PAD + 70) or 0),
      h - sp - 18,
      color_reward,
      TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM
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
        sp, h - sp - 18,
        statusColor,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM
      )
    end
  end

  vgui.Register("versus_BountyRow", ROW, "DPanel")
end

--[[
  Main panel
--]]

local BOARD = {}

function BOARD:Init()
  self:SetSize(PANEL_W, PANEL_H)
  self:Center()
  self:MakePopup()
  self:SetTitle("")
  self:ShowCloseButton(false)

  self.closeBtn = vgui.Create("versus_Button", self)
  self.closeBtn:SetText("CLOSE")
  self.closeBtn:SetSize(80, 28)
  self.closeBtn:SetPos(PANEL_W - 80 - PAD, PAD)
  self.closeBtn.DoClick = function() self:Close() end

  -- Scrollable list of bounty rows
  self.scroll = vgui.Create("DScrollPanel", self)
  self.scroll:SetPos(PAD, 56)
  self.scroll:SetSize(PANEL_W - PAD * 2, PANEL_H - 56 - PAD)

  local sbar = self.scroll:GetVBar()
  sbar:SetWide(6)

  self.rows   = {}
  self.timeUntilReset = 0
end

function BOARD:Close()
  PLUGIN.boardPanel = nil
  self:Remove()
end

function BOARD:OnBountyData(entries, serverNow)
  -- Calculate time remaining until first expiry (they all expire at the same time)
  if entries[1] then
    self.timeUntilReset = math.max(0, entries[1].expires_at - serverNow)
  end

  -- Remove old rows
  for _, row in ipairs(self.rows) do
    if IsValid(row) then row:Remove() end
  end
  self.rows = {}

  -- Create rows
  for i, entry in ipairs(entries) do
    local row = vgui.Create("versus_BountyRow", self.scroll)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 4)
    row:SetWide(self.scroll:GetWide())
    row:SetData(entry, i % 2 == 0)
    table.insert(self.rows, row)
  end

  if #entries == 0 then
    local label = vgui.Create("DLabel", self.scroll)
    label:SetText("No bounties available right now. Check back soon!")
    label:SetFont("VersusDefault")
    label:SetTextColor(color_dim)
    label:Dock(TOP)
    label:DockMargin(0, PAD, 0, 0)
    label:SizeToContents()
    table.insert(self.rows, label)
  end
end

function BOARD:Think()
  -- Countdown: each Think frame the time-until-reset decreases by FrameTime
  if self.timeUntilReset > 0 then
    self.timeUntilReset = math.max(0, self.timeUntilReset - FrameTime())
  end
end

function BOARD:Paint(w, h)
  draw.RoundedBox(6, 0, 0, w, h, color_bg)
  draw.RoundedBox(6, 0, 0, w, 50, color_header_bg)
  surface.SetDrawColor(color_border)
  surface.DrawOutlinedRect(0, 0, w, h, 2)

  -- Title
  draw.SimpleText(
    "BOUNTY BOARD",
    "VersusHeading1",
    w / 2, 26,
    color_title,
    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
  )

  -- Reset timer
  local remaining = self.timeUntilReset or 0
  local hours     = math.floor(remaining / 3600)
  local minutes   = math.floor((remaining % 3600) / 60)
  local seconds   = math.floor(remaining % 60)
  local resetStr  = string.format("Resets in: %02d:%02d:%02d", hours, minutes, seconds)

  draw.SimpleText(
    resetStr,
    "VersusDefault",
    PAD, 34,
    color_dim,
    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
  )
end

vgui.Register("versus_BountyBoard", BOARD, "DFrame")
