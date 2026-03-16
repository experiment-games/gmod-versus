local PLUGIN = PLUGIN

do
  --- @class versus_NewsScreen : EditablePanel
  local PANEL = {}

  local TYPE_COLORS = {
    update = Color(60, 130, 230),
    event  = Color(200, 80, 180),
  }

  local TYPE_LABELS = {
    update = "UPDATE",
    event  = "EVENT",
  }

  --- Format a Unix timestamp as a human-readable date string.
  --- @param timestamp number
  --- @return string
  local function formatDate(timestamp)
    if not isnumber(timestamp) or timestamp <= 0 then return "" end
    return tostring(os.date("%B %d, %Y", timestamp))
  end

  --- Build the full HTML document wrapping the article body with consistent dark-theme styles.
  --- @param content string Raw HTML fragment from the article
  --- @return string
  local function buildHTML(content)
    return string.format([[<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>
  html, body {
    margin: 0;
    padding: 10px 14px;
    font-family: Arial, sans-serif;
    font-size: 14px;
    color: #dce8f0;
    background: #080c12;
    line-height: 1.6;
    box-sizing: border-box;
    overflow-y: auto;
  }
  h1         { color: #ffffff;  font-size: 20px; margin: 0 0 8px; }
  h2         { color: #c0d8f0; font-size: 17px; margin: 12px 0 6px; }
  h3         { color: #a0c0e0; font-size: 15px; margin: 10px 0 4px; }
  p          { margin: 0 0 10px; }
  a          { color: #6ab0ff; text-decoration: none; }
  ul, ol     { padding-left: 22px; margin: 0 0 10px; }
  li         { margin-bottom: 4px; }
  strong, b  { color: #eef4fa; }
  em, i      { color: #c8d8e8; }
  hr         { border: none; border-top: 1px solid #1e2a3a; margin: 12px 0; }
  code       { background: #111a24; border-radius: 3px; padding: 1px 5px;
               font-family: monospace; font-size: 13px; color: #a0e0b8; }
  blockquote { border-left: 3px solid #3c5a80; margin: 0 0 10px;
               padding: 4px 12px; color: #a0b8cc; }
</style></head><body>%s</body></html>]], content or "")
  end

  function PANEL:Init()
    self:SetSize(math.min(ScrW() * 0.60, 1024), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha      = 0
    self.contentAlpha = 0
    self.animStart    = CurTime()
    self.animDuration = 0.35

    self.closing      = false
    self.closeStart   = 0

    self.currentPage  = 1
    self.articles     = {}

    local sp          = GAMEMODE.SPACING

    self:DockPadding(sp, sp, sp, sp)

    -- Type badge
    self.typeBadge = vgui.Create("DLabel", self)
    self.typeBadge:SetFont("VersusDefault")
    self.typeBadge:SetTextColor(TYPE_COLORS.update)
    self.typeBadge:SetText("UPDATE")
    self.typeBadge:SizeToContents()
    self.typeBadge:Dock(TOP)
    self.typeBadge:DockMargin(0, 0, 0, math.Round(sp * 0.25))

    -- Article title
    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading2")
    self.titleLabel:SetTextColor(Color(220, 230, 240))
    self.titleLabel:SetText("")
    self.titleLabel:SetWrap(true)
    self.titleLabel:SetAutoStretchVertical(true)
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, math.Round(sp * 0.25))

    -- Date label
    self.dateLabel = vgui.Create("DLabel", self)
    self.dateLabel:SetFont("VersusSmall")
    self.dateLabel:SetTextColor(Color(110, 140, 165))
    self.dateLabel:SetText("")
    self.dateLabel:SizeToContents()
    self.dateLabel:Dock(TOP)
    self.dateLabel:DockMargin(0, 0, 0, math.Round(sp * 0.5))

    -- Navigation bar (declared before FILL content so BOTTOM docking works)
    self.navBar = vgui.Create("EditablePanel", self)
    self.navBar:Dock(BOTTOM)
    self.navBar:SetTall(48)

    ---@type any
    self.prevButton = vgui.Create("versus_Button", self.navBar)
    self.prevButton:SetText("< PREV")
    self.prevButton:SetType("primary")
    self.prevButton:SetWide(110)
    self.prevButton:Dock(LEFT)
    self.prevButton:DockMargin(0, 0, math.Round(sp * 0.5), 0)
    self.prevButton.DoClick = function()
      self:NavigateTo(self.currentPage - 1)
    end

    -- Close button added to RIGHT before nextButton so it ends up rightmost.
    ---@type any
    self.closeButton = vgui.Create("versus_Button", self.navBar)
    self.closeButton:SetText("CLOSE")
    self.closeButton:SetType("secondary")
    self.closeButton:SetWide(90)
    self.closeButton:Dock(RIGHT)
    self.closeButton.DoClick = function()
      self:Close()
    end

    ---@type any
    self.nextButton = vgui.Create("versus_Button", self.navBar)
    self.nextButton:SetText("NEXT >")
    self.nextButton:SetType("primary")
    self.nextButton:SetWide(110)
    self.nextButton:Dock(RIGHT)
    self.nextButton:DockMargin(0, 0, math.Round(sp * 0.5), 0)
    self.nextButton.DoClick = function()
      self:NavigateTo(self.currentPage + 1)
    end

    self.pageLabel = vgui.Create("DLabel", self.navBar)
    self.pageLabel:SetFont("VersusDefault")
    self.pageLabel:SetTextColor(Color(180, 190, 200))
    self.pageLabel:SetText("1 / 1")
    self.pageLabel:SetContentAlignment(5)
    self.pageLabel:Dock(FILL)

    self.headerImage = vgui.Create("EditablePanel", self)
    self.headerImage:Dock(TOP)
    self.headerImage:SetTall(0)
    self.headerImage._mat = nil
    self.headerImage.Paint = function(pnl, w, h)
      local mat = pnl._mat
      if not mat then
        return
      end
      local imgW = mat:Width()
      local imgH = mat:Height()
      if imgW <= 0 or imgH <= 0 then
        return
      end
      -- Draw full height, scaling the width to maintain aspect ratio
      local drawH = h
      local drawW = math.Round(imgW * (drawH / imgH))

      -- Center the image horizontally within the panel
      local x = math.Round((w - drawW) * 0.5)

      surface.SetMaterial(mat)
      surface.SetDrawColor(255, 255, 255)
      surface.DrawTexturedRect(x, 0, drawW, drawH)
    end

    -- HTML content panel (fills remaining space)
    self.htmlPanel = vgui.Create("DHTML", self)
    self.htmlPanel:Dock(FILL)
    self.htmlPanel:DockMargin(0, 0, 0, math.Round(sp * 0.5))
    self.htmlPanel:SetAllowLua(false)
  end

  --- Set the articles to display and reset to the first page.
  --- @param articles table
  function PANEL:SetArticles(articles)
    self.articles    = articles
    self.currentPage = 1
    self:ShowCurrentArticle()
  end

  --- Refresh all UI elements to reflect self.currentPage.
  function PANEL:ShowCurrentArticle()
    local article = self.articles[self.currentPage]
    if not article then return end

    local count       = #self.articles
    local articleType = article.type or "update"
    local typeColor   = TYPE_COLORS[articleType] or TYPE_COLORS.update
    local sp          = GAMEMODE.SPACING

    -- Page indicator
    self.pageLabel:SetText(self.currentPage .. " / " .. count)

    -- Type badge
    self.typeBadge:SetText(TYPE_LABELS[articleType] or "UPDATE")
    self.typeBadge:SetTextColor(typeColor)
    self.typeBadge:SizeToContents()

    -- Title
    self.titleLabel:SetText(article.title or "")

    -- Date
    self.dateLabel:SetText(formatDate(article.date))
    self.dateLabel:SizeToContents()

    -- Header image: show only when a path is provided
    local hasImage = isstring(article.headerImage) and #article.headerImage > 0

    if hasImage then
      self.headerImage._mat = Material(article.headerImage)
      self.headerImage:SetTall(325)
      self.headerImage:DockMargin(0, 0, 0, math.Round(sp * 0.5))
    else
      self.headerImage._mat = nil
      self.headerImage:SetTall(0)
      self.headerImage:DockMargin(0, 0, 0, 0)
    end

    -- HTML content
    self.htmlPanel:SetHTML(buildHTML(article.content))

    -- Navigation button state
    self.prevButton:SetEnabled(self.currentPage > 1)
    self.nextButton:SetEnabled(self.currentPage < count)

    self:InvalidateLayout(true)
  end

  --- Navigate to the given page index, clamped to valid range.
  --- @param page number
  function PANEL:NavigateTo(page)
    if #self.articles == 0 then return end
    self.currentPage = math.Clamp(page, 1, #self.articles)
    self:ShowCurrentArticle()
  end

  function PANEL:Close()
    if self.closing then return end
    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:OnRemove()
    if PLUGIN.newsPanel == self then
      PLUGIN.newsPanel = nil
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

      if closeElapsed < 0.25 then
        local progress    = 1 - (closeElapsed / 0.25)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self:Remove()
      end
    end

    self:SetAlpha(math.Round(self.contentAlpha))
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)

    surface.SetDrawColor(0, 0, 0, math.Round(self.bgAlpha))
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self:Center()
  end

  --- Allow the Escape key to close the screen.
  function PANEL:OnKeyCodeTyped(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Close()
      return true
    end
  end

  vgui.Register("versus_NewsScreen", PANEL, "EditablePanel")
end
