local PLUGIN = PLUGIN

do
  --- @class versus_NewsEditor : EditablePanel
  --- Full-screen admin editor for creating and updating news articles.
  --- Opens with PLUGIN.openNewsEditor() and pre-populates fields when an
  --- existing article table is passed via :LoadArticle(article).
  local PANEL        = {}

  local COLOR_BG     = Color(12, 18, 28, 252)
  local COLOR_PANEL  = Color(18, 26, 40, 255)
  local COLOR_LABEL  = Color(140, 160, 180, 255)
  local COLOR_TEXT   = Color(220, 230, 240, 255)
  local COLOR_BORDER = Color(40, 60, 90, 200)
  local COLOR_ERROR  = Color(255, 90, 80, 255)

  local TYPE_COLORS  = {
    update = Color(60, 130, 230),
    event  = Color(200, 80, 180),
  }

  --- Thin section-header label above a field.
  --- @param parent Panel
  --- @param text string
  --- @return DLabel
  local function makeFieldLabel(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:SetFont("VersusSmall")
    label:SetTextColor(COLOR_LABEL)
    label:SetText(text)
    label:SizeToContents()
    label:Dock(TOP)
    label:DockMargin(0, 0, 0, 3)
    return label
  end

  --- Styled single-line text entry.
  --- @param parent Panel
  --- @return DTextEntry
  local function makeTextEntry(parent)
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetFont("VersusDefault")
    entry:SetTextColor(COLOR_TEXT)
    entry:SetTall(28)
    entry:Dock(TOP)
    entry:DockMargin(0, 0, 0, 10)

    entry.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, COLOR_PANEL)
      surface.SetDrawColor(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 200)
      surface.DrawOutlinedRect(0, 0, w, h, 1)
      pnl:DrawTextEntryText(COLOR_TEXT, Color(60, 130, 230, 200), COLOR_TEXT)
    end

    return entry
  end

  function PANEL:Init()
    self:SetSize(math.max(ScrW() * 0.85, 700), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.bgAlpha      = 0
    self.contentAlpha = 0
    self.animStart    = CurTime()
    self.animDuration = 0.3

    self.closing      = false
    self.closeStart   = 0

    local sp          = GAMEMODE.SPACING

    self:DockPadding(sp, sp, sp, sp)

    -- Title bar
    local titleBar = vgui.Create("EditablePanel", self)
    titleBar:Dock(TOP)
    titleBar:SetTall(36)
    titleBar:DockMargin(0, 0, 0, sp)

    self.editorTitleLabel = vgui.Create("DLabel", titleBar)
    self.editorTitleLabel:SetFont("VersusHeading2")
    self.editorTitleLabel:SetTextColor(COLOR_TEXT)
    self.editorTitleLabel:SetText("New Article")
    self.editorTitleLabel:SizeToContents()
    self.editorTitleLabel:Dock(LEFT)

    -- Left column: metadata fields
    self.leftColumn = vgui.Create("EditablePanel", self)
    self.leftColumn:Dock(LEFT)

    -- Article ID
    makeFieldLabel(self.leftColumn, "ARTICLE ID")
    self.idEntry = makeTextEntry(self.leftColumn)
    self.idEntry:SetPlaceholderText("e.g. update-1-0-5")

    -- Title
    makeFieldLabel(self.leftColumn, "TITLE")
    self.titleEntry = makeTextEntry(self.leftColumn)
    self.titleEntry:SetPlaceholderText("e.g. Version 1.0.5 Released")

    -- Date (Unix timestamp)
    makeFieldLabel(self.leftColumn, "DATE  (Unix timestamp, leave blank for now)")
    self.dateEntry = makeTextEntry(self.leftColumn)
    self.dateEntry:SetPlaceholderText("e.g. 1710000000  (leave blank = current time)")
    self.dateEntry:SetNumeric(true)

    -- Type selector
    makeFieldLabel(self.leftColumn, "TYPE")
    local typeRow = vgui.Create("EditablePanel", self.leftColumn)
    typeRow:Dock(TOP)
    typeRow:SetTall(28)
    typeRow:DockMargin(0, 0, 0, 10)

    self.selectedType = "update"

    local btnUpdate = vgui.Create("versus_Button", typeRow)
    btnUpdate:SetText("UPDATE")
    btnUpdate:SetType("primary")
    btnUpdate:SetWide(100)
    btnUpdate:Dock(LEFT)
    btnUpdate:DockMargin(0, 0, math.Round(sp * 0.5), 0)

    local btnEvent = vgui.Create("versus_Button", typeRow)
    btnEvent:SetText("EVENT")
    btnEvent:SetType("secondary")
    btnEvent:SetWide(100)
    btnEvent:Dock(LEFT)

    local function refreshTypeButtons()
      btnUpdate:SetType(self.selectedType == "update" and "primary" or "secondary")
      btnEvent:SetType(self.selectedType == "event" and "primary" or "secondary")
    end

    btnUpdate.DoClick = function()
      self.selectedType = "update"
      refreshTypeButtons()
    end
    btnEvent.DoClick = function()
      self.selectedType = "event"
      refreshTypeButtons()
    end

    -- Header image path
    makeFieldLabel(self.leftColumn, "HEADER IMAGE  (material path, optional)")
    self.headerImageEntry = makeTextEntry(self.leftColumn)
    self.headerImageEntry:SetPlaceholderText("e.g. versus/news/banner  (leave blank for none)")

    -- Error label
    self.errorLabel = vgui.Create("DLabel", self.leftColumn)
    self.errorLabel:SetFont("VersusDefault")
    self.errorLabel:SetTextColor(COLOR_ERROR)
    self.errorLabel:SetText("")
    self.errorLabel:SetWrap(true)
    self.errorLabel:SetAutoStretchVertical(true)
    self.errorLabel:Dock(TOP)
    self.errorLabel:DockMargin(0, 0, 0, sp)

    -- Action buttons at the bottom of the left column
    local actionRow = vgui.Create("EditablePanel", self.leftColumn)
    actionRow:Dock(BOTTOM)
    actionRow:SetTall(36)

    self.deleteButton = vgui.Create("versus_Button", actionRow)
    self.deleteButton:SetText("DELETE ARTICLE")
    self.deleteButton:SetType("secondary")
    self.deleteButton:SetWide(160)
    self.deleteButton:Dock(LEFT)
    self.deleteButton:DockMargin(0, 0, math.Round(sp * 0.5), 0)
    self.deleteButton.DoClick = function()
      Derma_Query(
        "Are you sure you want to delete this article? This action cannot be undone.",
        "Confirm Deletion",
        "Delete", function()
          if (not self.articleID or #self.articleID < 1) then
            self.errorLabel:SetText("Cannot delete article: missing or invalid article ID.")
            return
          end

          net.Start("versus.news.admin.delete")
          net.WriteString(self.articleID or "")
          net.SendToServer()
          self:Close()
        end,
        "Cancel", function() end
      )
    end

    ---@type any
    self.saveButton = vgui.Create("versus_Button", actionRow)
    self.saveButton:SetText("SAVE ARTICLE")
    self.saveButton:SetType("primary")
    self.saveButton:SetWide(160)
    self.saveButton:Dock(LEFT)
    self.saveButton:DockMargin(0, 0, math.Round(sp * 0.5), 0)
    self.saveButton.DoClick = function()
      self:Submit()
    end

    ---@type any
    local cancelButton = vgui.Create("versus_Button", actionRow)
    cancelButton:SetText("CANCEL")
    cancelButton:SetType("secondary")
    cancelButton:SetWide(100)
    cancelButton:Dock(LEFT)
    cancelButton.DoClick = function()
      self:Close()
    end

    -- Right column: HTML content editor
    self.rightColumn = vgui.Create("EditablePanel", self)
    self.rightColumn:Dock(FILL)
    self.rightColumn:DockPadding(sp, 0, 0, 0)

    makeFieldLabel(self.rightColumn, "CONTENT  (HTML)")

    self.contentEntry = vgui.Create("DTextEntry", self.rightColumn)
    self.contentEntry:Dock(FILL)
    self.contentEntry:SetFont("VersusDefault")
    self.contentEntry:SetTextColor(COLOR_TEXT)
    self.contentEntry:SetMultiline(true)
    self.contentEntry:SetAllowNonAsciiCharacters(true)
    self.contentEntry:SetPlaceholderText("<p>Write your article content here as HTML...</p>")

    self.contentEntry.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, COLOR_PANEL)
      surface.SetDrawColor(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 200)
      surface.DrawOutlinedRect(0, 0, w, h, 1)
      pnl:DrawTextEntryText(COLOR_TEXT, Color(60, 130, 230, 200), COLOR_TEXT)
    end
  end

  --- Pre-populate all fields with data from an existing article for editing.
  --- @param article table
  function PANEL:LoadArticle(article)
    self.articleID = article.id or ""

    self.editorTitleLabel:SetText("Edit Article")
    self.editorTitleLabel:SizeToContents()

    self.idEntry:SetText(article.id or "")
    self.titleEntry:SetText(article.title or "")
    self.dateEntry:SetText(tostring(article.date or ""))
    self.contentEntry:SetText(article.content or "")
    self.headerImageEntry:SetText(article.headerImage or "")
    self.selectedType = (article.type == "event") and "event" or "update"
  end

  --- Validate fields, then send a save net message to the server.
  function PANEL:Submit()
    self.errorLabel:SetText("")

    local id          = self.idEntry:GetValue():Trim()
    local title       = self.titleEntry:GetValue():Trim()
    local dateStr     = self.dateEntry:GetValue():Trim()
    local content     = self.contentEntry:GetValue()
    local headerImage = self.headerImageEntry:GetValue():Trim()

    if not id:match("^[%w%-%_%.]+$") then
      self.errorLabel:SetText("Article ID must be non-empty and use only alphanumerics, hyphens, underscores, or dots.")
      return
    end

    if #title < 1 then
      self.errorLabel:SetText("Title must not be empty.")
      return
    end

    local date = (dateStr ~= "" and tonumber(dateStr)) or os.time()

    local article = {
      id          = id,
      type        = self.selectedType,
      title       = title,
      date        = date,
      headerImage = (#headerImage > 0) and headerImage or nil,
      content     = content,
    }

    local json = util.TableToJSON(article, false)

    if #json > PLUGIN.MAX_PAYLOAD_SIZE then
      self.errorLabel:SetText("Content is too large (max " .. PLUGIN.MAX_PAYLOAD_SIZE .. " bytes).")
      return
    end

    net.Start("versus.news.admin.save")
    net.WriteString(json)
    net.SendToServer()

    self:Close()
  end

  function PANEL:Close()
    if self.closing then return end
    self.closing    = true
    self.closeStart = CurTime()
  end

  function PANEL:OnRemove()
    if PLUGIN.editorPanel == self then
      PLUGIN.editorPanel = nil
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

    -- Left column is 38% of the usable width (after padding).
    local sp     = GAMEMODE.SPACING
    local usable = w - sp * 2
    self.leftColumn:SetWide(math.floor(usable * 0.38))
  end

  function PANEL:OnKeyCodeTyped(keyCode)
    if keyCode == KEY_ESCAPE then
      self:Close()
      return true
    end
  end

  vgui.Register("versus_NewsEditor", PANEL, "EditablePanel")
end
