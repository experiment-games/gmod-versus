local PLUGIN          = PLUGIN

local color_bg        = Color(20, 28, 40, 255)
local color_header_bg = Color(15, 22, 32, 255)
local color_border    = Color(40, 55, 75, 255)
local color_text      = Color(220, 230, 240, 255)
local color_dim       = Color(140, 155, 170, 255)
local color_accent    = Color(80, 140, 220, 255)
local color_row_even  = Color(25, 36, 52, 200)
local color_row_odd   = Color(20, 28, 40, 200)
local color_row_hover = Color(42, 60, 88, 220)
local color_gold      = Color(255, 215, 0, 255)
local color_silver    = Color(192, 192, 192, 255)
local color_bronze    = Color(205, 127, 50, 255)

-- Column widths for row layout (matches the header paint below)
local COL_RANK        = 56
local COL_LEVEL       = 90
local COL_XP          = 120
local COL_MONEY       = 130
local ROW_H           = 44

--[[
  Individual leaderboard row
--]]

do
  local ROW = {}

  function ROW:Init()
    self:SetTall(ROW_H)
    self.rank       = 0
    self.rankColor  = color_dim
    self.playerName = ""
    self.level      = 1
    self.xp         = 0
    self.money      = 0
    self.isEven     = false
    self.hovered    = false
  end

  function ROW:SetData(rank, playerName, level, xp, money, isEven)
    self.rank       = rank
    self.playerName = playerName
    self.level      = level
    self.xp         = xp
    self.money      = money
    self.isEven     = isEven

    if rank == 1 then
      self.rankColor = color_gold
    elseif rank == 2 then
      self.rankColor = color_silver
    elseif rank == 3 then
      self.rankColor = color_bronze
    else
      self.rankColor = color_dim
    end
  end

  function ROW:OnCursorEntered() self.hovered = true end

  function ROW:OnCursorExited() self.hovered = false end

  function ROW:Paint(w, h)
    local bg = self.hovered and color_row_hover
        or (self.isEven and color_row_even or color_row_odd)

    draw.RoundedBox(4, 0, 0, w, h, bg)

    local sp = GAMEMODE.SPACING
    local cy = h / 2

    -- Rank
    draw.SimpleText(
      "#" .. tostring(self.rank),
      "VersusButton",
      sp + COL_RANK * 0.5, cy,
      self.rankColor,
      TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )

    -- Player name (fills the middle stretch)
    draw.SimpleText(
      self.playerName,
      "VersusDefault",
      sp + COL_RANK + sp, cy,
      color_text,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    -- XP (left edge of the right-hand columns)
    local xpX = w - COL_MONEY - sp - COL_XP - sp - COL_LEVEL
    draw.SimpleText(
      string.Comma(self.xp),
      "VersusDefault",
      xpX, cy,
      color_dim,
      TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    -- Level
    draw.SimpleText(
      "Lv. " .. tostring(self.level),
      "VersusDefault",
      w - COL_MONEY - sp, cy,
      color_accent,
      TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
    )

    -- Money
    draw.SimpleText(
      versus.util.formatMoney(self.money),
      "VersusDefault",
      w - sp, cy,
      color_text,
      TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
    )
  end

  vgui.Register("versus_LeaderboardRow", ROW, "EditablePanel")
end

--[[
  Main leaderboard panel
--]]

do
  local PANEL = {}

  local SORTS = {
    { key = "xp",    label = "XP / LEVEL" },
    { key = "money", label = "MONEY" },
  }

  function PANEL:Init()
    local w = math.max(ScrW() * 0.55, 720)
    local h = ScrH()

    self:SetSize(w, h)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.contentAlpha    = 0
    self.animStart       = CurTime()
    self.animDuration    = 0.35
    self.closing         = false
    self.closeStart      = 0

    self.sortBy          = "xp"
    self.currentPage     = 1
    self.totalRows       = 0
    self.loading         = false

    -- Page cache: cache[sortBy][page] = { total, entries }
    self.cache           = {}

    -- Tracks the single request currently in flight to the server so we never
    -- fire a duplicate net message for the same sort+page.
    self.inflightRequest = nil

    local sp             = GAMEMODE.SPACING
    self:DockPadding(sp, sp, sp, sp)

    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(color_text)
    self.titleLabel:SetText("LEADERBOARD")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, sp * 0.5)

    self.tabBar = vgui.Create("EditablePanel", self)
    self.tabBar:Dock(TOP)
    self.tabBar:SetTall(48)
    self.tabBar:DockMargin(0, 0, 0, sp * 0.5)
    self.tabBar.Paint = function() end

    self.tabButtons = {}

    for _, sort in ipairs(SORTS) do
      local btn = vgui.Create("versus_Button", self.tabBar)
      btn:Dock(LEFT)
      btn:DockMargin(0, 0, sp * 0.5, 0)
      btn:SetWide(180)
      btn:SetText(sort.label)
      btn:SetType(sort.key == self.sortBy and "primary" or "default")

      local sortKey = sort.key
      btn.DoClick = function()
        self:SetSortBy(sortKey)
      end

      self.tabButtons[sort.key] = btn
    end

    self.findMeButton = vgui.Create("versus_Button", self.tabBar)
    self.findMeButton:Dock(RIGHT)
    self.findMeButton:SetWide(140)
    self.findMeButton:SetText("◎ FIND ME")
    self.findMeButton:SetType("default")
    self.findMeButton.DoClick = function()
      self:FindMe()
    end

    self.findMeInFlight = false

    self.columnHeader = vgui.Create("EditablePanel", self)
    self.columnHeader:Dock(TOP)
    self.columnHeader:SetTall(48)
    self.columnHeader:DockMargin(0, 0, 0, 2)
    self.columnHeader.Paint = function(pnl, pw, ph)
      draw.RoundedBox(4, 0, 0, pw, ph, color_header_bg)

      local psp = GAMEMODE.SPACING
      local cy  = ph / 2

      draw.SimpleText(
        "RANK",
        "VersusButton",
        psp + COL_RANK * 0.5, cy,
        color_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
      )
      draw.SimpleText(
        "PLAYER",
        "VersusButton",
        psp + COL_RANK + psp, cy,
        color_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
      )
      draw.SimpleText(
        "XP",
        "VersusButton",
        pw - COL_MONEY - psp - COL_LEVEL - psp - COL_XP, cy,
        color_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
      )
      draw.SimpleText(
        "LVL",
        "VersusButton",
        pw - COL_MONEY - psp, cy,
        color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
      )
      draw.SimpleText(
        "CASH",
        "VersusButton",
        pw - psp, cy,
        color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
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

    self.navBar = vgui.Create("EditablePanel", self)
    self.navBar:Dock(BOTTOM)
    self.navBar:SetTall(48)
    self.navBar:DockMargin(0, sp * 0.5, 0, 0)
    self.navBar.Paint = function() end

    self.prevButton = vgui.Create("versus_Button", self.navBar)
    self.prevButton:SetSize(120, 48)
    self.prevButton:SetPos(0, 0)
    self.prevButton:SetText("◄ PREV")
    self.prevButton.DoClick = function()
      if self.currentPage > 1 then
        self:GotoPage(self.currentPage - 1)
      end
    end

    self.pageLabel = vgui.Create("DLabel", self.navBar)
    self.pageLabel:SetFont("VersusButton")
    self.pageLabel:SetTextColor(color_dim)
    self.pageLabel:SetText("Page 1 of 1")
    self.pageLabel:SizeToContents()

    self.nextButton = vgui.Create("versus_Button", self.navBar)
    self.nextButton:SetSize(120, 48)
    self.nextButton:SetText("NEXT ►")
    self.nextButton.DoClick = function()
      local maxPages = math.max(1, math.ceil(self.totalRows / PLUGIN.PAGE_SIZE))
      if self.currentPage < maxPages then
        self:GotoPage(self.currentPage + 1)
      end
    end

    self.rowList = vgui.Create("versus_ScrollPanel", self)
    self.rowList:Dock(FILL)
    self.rowList:DockMargin(0, 0, 0, 0)

    -- Request the first page
    self:GotoPage(1)
  end

  --- Switch sort column and reset to page 1.
  function PANEL:SetSortBy(sortBy)
    if self.sortBy == sortBy then return end

    self.sortBy = sortBy

    for key, btn in pairs(self.tabButtons) do
      btn:SetType(key == sortBy and "primary" or "default")
    end

    self.currentPage = 1
    self.totalRows   = 0

    self:GotoPage(1)
  end

  --- Ask the server for the local player's rank under the current sort, then
  --- jump to the page that contains their entry.
  function PANEL:FindMe()
    if self.findMeInFlight then return end

    self.findMeInFlight = true

    if IsValid(self.findMeButton) then
      self.findMeButton:SetEnabled(false)
    end

    net.Start("versus.leaderboard.findPlayer")
    net.WriteString(self.sortBy)
    net.SendToServer()
  end

  --- Called by cl_init when the server replies to a find-me request.
  function PANEL:OnFindMeResult(sortBy, rank)
    self.findMeInFlight = false

    if IsValid(self.findMeButton) then
      self.findMeButton:SetEnabled(true)
    end

    if rank == 0 then
      -- Player has no database row yet; nothing to navigate to.
      return
    end

    -- Switch to the sort column that was searched (in case it changed while
    -- the request was in flight).
    if self.sortBy ~= sortBy then
      self.sortBy    = sortBy
      self.totalRows = 0

      for key, btn in pairs(self.tabButtons) do
        btn:SetType(key == sortBy and "primary" or "default")
      end
    end

    local page = math.max(1, math.ceil(rank / PLUGIN.PAGE_SIZE))
    self:GotoPage(page)
  end

  --- Navigate to the given page, using the cache when available.
  function PANEL:GotoPage(page)
    self.currentPage = page

    local cached = self.cache[self.sortBy] and self.cache[self.sortBy][page]
    if cached then
      self:DisplayPage(self.sortBy, page, cached.total, cached.entries)
      return
    end

    -- If we already have an identical request in flight, just wait for it.
    if self.inflightRequest
        and self.inflightRequest.sortBy == self.sortBy
        and self.inflightRequest.page == page then
      return
    end

    self.inflightRequest = { sortBy = self.sortBy, page = page }
    self:SetLoading(true)

    net.Start("versus.leaderboard.requestPage")
    net.WriteString(self.sortBy)
    net.WriteUInt(page, 16)
    net.SendToServer()
  end

  --- Called by cl_init when the server sends back a page of data.
  function PANEL:OnPageData(sortBy, page, total, entries)
    -- Store in cache
    if not self.cache[sortBy] then
      self.cache[sortBy] = {}
    end

    self.cache[sortBy][page] = { total = total, entries = entries }

    -- Clear the in-flight marker so subsequent navigation can fire again.
    if self.inflightRequest
        and self.inflightRequest.sortBy == sortBy
        and self.inflightRequest.page == page then
      self.inflightRequest = nil
    end

    -- Only render if this response is still relevant to the current view.
    if self.sortBy == sortBy and self.currentPage == page then
      self:DisplayPage(sortBy, page, total, entries)
    end
  end

  --- Rebuild the row list with the supplied data and update navigation.
  function PANEL:DisplayPage(sortBy, page, total, entries)
    self:SetLoading(false)

    self.totalRows = total

    local sp       = GAMEMODE.SPACING
    local offset   = (page - 1) * PLUGIN.PAGE_SIZE

    if #entries == 0 then
      local emptyLabel = vgui.Create("DLabel", self.rowList)
      emptyLabel:SetFont("VersusDefault")
      emptyLabel:SetTextColor(color_dim)
      emptyLabel:SetText("No players found.")
      emptyLabel:SizeToContents()
      emptyLabel:Dock(TOP)
      emptyLabel:DockMargin(sp, sp, sp, 0)
    else
      for i, entry in ipairs(entries) do
        local row = vgui.Create("versus_LeaderboardRow", self.rowList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 2)
        row:SetData(
          offset + i,
          entry.name,
          entry.level,
          entry.xp,
          entry.money,
          (i % 2 == 0)
        )
      end
    end

    -- Page navigation label
    local maxPages = math.max(1, math.ceil(total / PLUGIN.PAGE_SIZE))
    self.pageLabel:SetText("Page " .. page .. " of " .. maxPages)
    self.pageLabel:SizeToContents()

    self.prevButton:SetEnabled(page > 1)
    self.nextButton:SetEnabled(page < maxPages)

    -- Re-centre the label (PerformLayout will also do this, but do it now too)
    self:InvalidateLayout()
  end

  --- Show or hide a loading spinner inside the row list.
  --- While loading, the prev/next buttons are disabled so the user cannot
  --- queue up additional server requests.
  function PANEL:SetLoading(loading)
    self.loading = loading

    -- Disable navigation while a request is in flight so the user can't
    -- accidentally fire extra requests by clicking rapidly.
    if IsValid(self.prevButton) then
      self.prevButton:SetEnabled(not loading)
    end

    if IsValid(self.nextButton) then
      self.nextButton:SetEnabled(not loading)
    end

    if IsValid(self.findMeButton) then
      self.findMeButton:SetEnabled(not loading and not self.findMeInFlight)
    end

    self.rowList:Clear()

    if loading then
      local loadingPanel = vgui.Create("EditablePanel", self.rowList)
      loadingPanel:Dock(TOP)
      loadingPanel:SetTall(300)
      loadingPanel.Paint = function() end

      local indicator = vgui.Create("versus_LoadingIndicator", loadingPanel)
      indicator:SetSize(80, 80)
      indicator:Center()
    end
  end

  --- Begin the close animation.
  function PANEL:Close()
    if self.closing then return end

    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:OnKeyCodeTyped(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Close()
      return true
    end
  end

  function PANEL:Think()
    if self.closing then
      local pct = math.Clamp((CurTime() - self.closeStart) / self.animDuration, 0, 1)
      self.contentAlpha = 255 * (1 - math.ease.OutQuad(pct))

      if pct >= 1 then
        PLUGIN.leaderboardPanel = nil
        self:Remove()
      end
    else
      self.contentAlpha = 255 * math.ease.OutQuad(
        math.Clamp((CurTime() - self.animStart) / self.animDuration, 0, 1)
      )
    end

    self:SetAlpha(self.contentAlpha)
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)

    surface.SetDrawColor(ColorAlpha(color_bg, self.contentAlpha))
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self:Center()

    -- Keep page label centred in the nav bar
    if IsValid(self.navBar) and IsValid(self.pageLabel) then
      local nbW = self.navBar:GetWide()
      local nbH = self.navBar:GetTall()

      self.pageLabel:SetPos(
        nbW / 2 - self.pageLabel:GetWide() / 2,
        nbH / 2 - self.pageLabel:GetTall() / 2
      )

      if IsValid(self.nextButton) then
        self.nextButton:SetPos(nbW - 120, 0)
      end
    end
  end

  vgui.Register("versus_Leaderboard", PANEL, "EditablePanel")
end
