local PLUGIN = PLUGIN

local color_header_bg = Color(15, 22, 32, 255)
local color_text = Color(220, 230, 240, 255)
local color_dim = Color(140, 155, 170, 255)
local color_accent = Color(80, 140, 220, 255)
local color_row_even = Color(25, 36, 52, 200)
local color_row_odd = Color(20, 28, 40, 200)
local color_row_hover = Color(42, 60, 88, 220)

local COL_LEVEL = 90
local BTN_W = 32
local BTN_GAP = 16

--[[
  Individual scoreboard row
--]]

do
  local ROW = {}

  function ROW:Init()
    self:SetTall(48)
    self.playerName = ""
    self.level = 1
    self.isEven = false
    self.hovered = false
    self.player = nil
    self.muted = false

    local spacing = GAMEMODE.SPACING
    local padding = (48 - BTN_W) / 2

    self:DockPadding(spacing, 0, spacing, 0)

    -- Right cluster: level label + mute button
    local rightW = COL_LEVEL + BTN_GAP + BTN_W
    self.rightPanel = vgui.Create("EditablePanel", self)
    self.rightPanel:Dock(RIGHT)
    self.rightPanel:SetWide(rightW)
    self.rightPanel:DockPadding(0, padding, 0, padding)
    self.rightPanel.Paint = function(_, pw, ph)
      draw.SimpleText(
        "Lv. " .. tostring(self.level),
        "VersusDefault",
        COL_LEVEL / 2, ph / 2,
        color_accent,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
      )
    end

    -- Mute / unmute button
    self.muteBtn = vgui.Create("DImageButton", self.rightPanel)
    self.muteBtn:Dock(RIGHT)
    self.muteBtn:SetWide(BTN_W)
    self.muteBtn:DockMargin(BTN_GAP, 0, 0, 0)
    self.muteBtn:SetMouseInputEnabled(true)
    self.muteBtn.DoClick = function()
      if not IsValid(self.player) then return end
      if self.player == LocalPlayer() then return end
      self.player:SetMuted(not self.player:IsMuted())
    end
  end

  function ROW:SetData(ply, level, isEven)
    self.player     = ply
    self.playerName = IsValid(ply) and ply:Nick() or "Unknown"
    self.level      = level
    self.isEven     = isEven

    -- Hide mute button for local player (can't mute yourself)
    local isLocal   = IsValid(ply) and ply == LocalPlayer()
    self.muteBtn:SetVisible(not isLocal)

    self:UpdateMuteIcon()
  end

  function ROW:UpdateMuteIcon()
    if not IsValid(self.player) then
      return
    end
    if self.player == LocalPlayer() then
      return
    end
    if self.player:IsMuted() then
      self.muteBtn:SetImage("versus/icons/muted.png")
    else
      self.muteBtn:SetImage("versus/icons/unmuted.png")
    end
  end

  function ROW:Think()
    if not IsValid(self.player) then
      return
    end
    if self.player == LocalPlayer() then
      return
    end
    local muted = self.player:IsMuted()
    if muted ~= self.muted then
      self.muted = muted
      self:UpdateMuteIcon()
    end
  end

  function ROW:OnMousePressed(mouseCode)
    if not IsValid(self.player) then
      return
    end

    local ply = self.player
    local menu = DermaMenu()

    menu:AddOption("Send Personal Message", function()
      versus.menu.hide()
      versus.message.showChat()
      versus.message.setChatText(
        string.format(
          "/pm %s ",
          versus.player.getBestIdentifier(ply)
        )
      )
    end)

    menu:AddOption("View Profile", function()
      gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
    end)

    menu:AddOption("Copy SteamID64", function()
      SetClipboardText(ply:SteamID64())
    end)

    menu:Open()
  end

  function ROW:OnCursorEntered() self.hovered = true end

  function ROW:OnCursorExited() self.hovered = false end

  function ROW:Paint(w, h)
    local bg = self.hovered and color_row_hover
        or (self.isEven and color_row_even or color_row_odd)

    draw.RoundedBox(4, 0, 0, w, h, bg)

    local sp = GAMEMODE.SPACING
    local cy = h / 2

    -- Player name (fills the left side, inset by DockPadding)
    draw.SimpleText(
      self.playerName,
      "VersusDefault",
      sp, cy,
      color_text,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )
  end

  vgui.Register("versus_ScoreboardRow", ROW, "EditablePanel")
end

--[[
  Main scoreboard panel (lives inside a main menu tab)
--]]

do
  local PANEL = {}

  local SORTS = {
    { key = "level", label = "LEVEL" },
    { key = "name",  label = "NAME" },
  }

  function PANEL:Init()
    self.sortBy = "level"
    self.nextRefresh = 0

    local spacing = GAMEMODE.SPACING

    self:DockPadding(0, spacing * .5, 0, spacing)

    -- Sort / header bar
    self.sortBar = vgui.Create("EditablePanel", self)
    self.sortBar:Dock(TOP)
    self.sortBar:SetTall(48)
    self.sortBar:DockMargin(0, 0, 0, spacing * 0.5)
    self.sortBar.Paint = function() end

    self.sortLabel = vgui.Create("DLabel", self.sortBar)
    self.sortLabel:SetFont("VersusButton")
    self.sortLabel:SetTextColor(color_dim)
    self.sortLabel:SetText("Sort by:")
    self.sortLabel:SizeToContents()
    self.sortLabel:Dock(LEFT)
    self.sortLabel:DockMargin(0, 0, spacing * 0.5, 0)

    self.sortButtons = {}

    for _, sort in ipairs(SORTS) do
      local btn = vgui.Create("versus_Button", self.sortBar)
      btn:Dock(LEFT)
      btn:DockMargin(0, 0, spacing * 0.5, 0)
      btn:SetText(sort.label)
      btn:SetType(sort.key == self.sortBy and "primary" or "default")
      btn:SizeToContents()

      local sortKey = sort.key
      btn.DoClick = function()
        self:SetSortBy(sortKey)
      end

      self.sortButtons[sort.key] = btn
    end

    -- Online count label, right-aligned in the sort bar
    self.countLabel = vgui.Create("DLabel", self.sortBar)
    self.countLabel:SetFont("VersusButton")
    self.countLabel:SetTextColor(color_dim)
    self.countLabel:SetText("0 players online")
    self.countLabel:SizeToContents()
    self.countLabel:Dock(RIGHT)

    -- Column header
    self.columnHeader = vgui.Create("EditablePanel", self)
    self.columnHeader:Dock(TOP)
    self.columnHeader:SetTall(40)
    self.columnHeader:DockMargin(0, 0, 0, 8)
    self.columnHeader.Paint = function(pnl, pw, ph)
      draw.RoundedBox(4, 0, 0, pw, ph, color_header_bg)

      local psp  = GAMEMODE.SPACING
      local cy   = ph / 2
      -- x that lines up with the centre of the level column in each row:
      -- row has DockPadding(psp) on each side; rightPanel = COL_LEVEL + gap + BTN_W wide
      local lvlX = pw - psp - (BTN_GAP + BTN_W) - COL_LEVEL / 2

      draw.SimpleText(
        "PLAYER",
        "VersusButton",
        psp, cy,
        color_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
      )
      draw.SimpleText(
        "LVL",
        "VersusButton",
        lvlX, cy,
        color_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
      )
    end

    -- Scrollable row list
    self.rowList = vgui.Create("versus_ScrollPanel", self)
    self.rowList:Dock(FILL)

    -- Hint that player rows can be clicked for more options
    local hintLabel = vgui.Create("DLabel", self)
    hintLabel:SetFont("VersusDefault")
    hintLabel:SetTextColor(color_dim)
    hintLabel:SetText("Click player rows for more options")
    hintLabel:SizeToContents()
    hintLabel:SetContentAlignment(5)
    hintLabel:Dock(BOTTOM)
    hintLabel:DockMargin(spacing, spacing, spacing, 0)

    self:Rebuild()
  end

  --- Switch the active sort column and immediately rebuild the list.
  function PANEL:SetSortBy(sortBy)
    if self.sortBy == sortBy then return end

    self.sortBy = sortBy

    for key, btn in pairs(self.sortButtons) do
      btn:SetType(key == sortBy and "primary" or "default")
    end

    self:Rebuild()
  end

  --- Clear and repopulate the row list from the current player list.
  function PANEL:Rebuild()
    self.rowList:Clear()

    local players = player.GetAll()

    -- Sort
    if self.sortBy == "level" then
      table.sort(players, function(a, b)
        local la = a:GetNWInt("versus_Level", 1)
        local lb = b:GetNWInt("versus_Level", 1)

        if la ~= lb then return la > lb end

        return a:Nick() < b:Nick()
      end)
    else
      table.sort(players, function(a, b)
        return a:Nick() < b:Nick()
      end)
    end

    -- Update count label
    local count = #players
    self.countLabel:SetText(count .. " player" .. (count == 1 and "" or "s") .. " online")
    self.countLabel:SizeToContents()

    if count == 0 then
      local emptyLabel = vgui.Create("DLabel", self.rowList)
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(color_dim)
      emptyLabel:SetText("No players online.")
      emptyLabel:SizeToContents()
      emptyLabel:Dock(TOP)
      emptyLabel:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, 0)

      return
    end

    for i, ply in ipairs(players) do
      local row = vgui.Create("versus_ScoreboardRow", self.rowList)
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, 8)
      row:SetData(ply, ply:GetNWInt("versus_Level", 1), i % 2 == 0)
    end
  end

  --- Rebuild once per second while the panel is alive.
  function PANEL:Think()
    if CurTime() >= self.nextRefresh then
      self.nextRefresh = CurTime() + 1
      self:Rebuild()
    end
  end

  --- Triggered by the menu when this tab becomes visible — rebuild immediately.
  function PANEL:OnMenuShown()
    self.nextRefresh = 0
  end

  vgui.Register("versus_Scoreboard", PANEL, "EditablePanel")
end
