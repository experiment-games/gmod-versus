local PLUGIN = PLUGIN

local color_text      = Color(220, 230, 240, 255)
local color_dim       = Color(140, 155, 170, 255)
local color_accent    = Color(80, 140, 220, 255)
local color_row_even  = Color(25, 36, 52, 200)
local color_row_odd   = Color(20, 28, 40, 200)
local color_row_hover = Color(42, 60, 88, 220)
local color_error     = Color(220, 80, 80, 255)
local color_success   = Color(80, 200, 120, 255)

-- Contract phase field definitions
local PHASE_FIELDS = {
  { key = "lore",          label = "Lore / Background" },
  { key = "goal",          label = "Goal / Entities to Interact With" },
  { key = "monsters",      label = "Monsters / Waves / Item Drops" },
  { key = "completion",    label = "Completion Condition" },
  { key = "interference",  label = "How Can Another Player Interfere?" },
}

local PHASE_FIELD_H = 70
local PHASE_LABEL_H = 20

--[[
  A single admin suggestion row
--]]

do
  local ROW = {}

  function ROW:Init()
    self:SetTall(44)
    self.hovered = false
    self.entry   = {}
  end

  function ROW:SetEntry(entry, isEven)
    self.entry  = entry
    self.isEven = isEven
  end

  function ROW:OnCursorEntered() self.hovered = true end
  function ROW:OnCursorExited()  self.hovered = false end

  function ROW:Paint(w, h)
    local bg = self.hovered and color_row_hover
        or (self.isEven and color_row_even or color_row_odd)
    draw.RoundedBox(4, 0, 0, w, h, bg)

    local sp = GAMEMODE.SPACING
    local cy = h / 2

    local typeLabel = (self.entry.suggestionType == "feature") and "FEATURE" or "CONTRACT"
    draw.SimpleText(typeLabel, "VersusButton", sp, cy, color_accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tostring(self.entry.playerName or ""), "VersusDefault", sp + 100, cy, color_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local dateStr = self.entry.timestamp > 0
        and os.date("%Y-%m-%d %H:%M", self.entry.timestamp)
        or "Unknown"
    draw.SimpleText(dateStr, "VersusDefault", w - sp, cy, color_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
  end

  function ROW:OnMousePressed(mouseCode)
    if mouseCode ~= MOUSE_LEFT then return end
    if self.DoClick then self:DoClick() end
  end

  vgui.Register("versus_SuggestionAdminRow", ROW, "EditablePanel")
end

--[[
  Main suggestion box panel
--]]

do
  local PANEL = {}

  function PANEL:Init()
    local w = math.max(ScrW() * 0.55, 720)
    local h = ScrH()

    self:SetSize(w, h)
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

    local sp = GAMEMODE.SPACING
    self:DockPadding(sp, sp, sp, sp)

    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading1")
    self.titleLabel:SetTextColor(color_text)
    self.titleLabel:SetText("SUGGESTION BOX")
    self.titleLabel:SizeToContents()
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(0, 0, 0, sp * 0.5)

    self.statusLabel = vgui.Create("DLabel", self)
    self.statusLabel:SetFont("VersusDefault")
    self.statusLabel:SetTextColor(color_success)
    self.statusLabel:SetText("")
    self.statusLabel:SizeToContents()
    self.statusLabel:Dock(BOTTOM)
    self.statusLabel:DockMargin(0, 4, 0, 0)

    self.closeButton = vgui.Create("versus_Button", self)
    self.closeButton:Dock(BOTTOM)
    self.closeButton:DockMargin(0, sp * 0.5, 0, 0)
    self.closeButton:SetText("CLOSE")
    self.closeButton:SetType("secondary")
    self.closeButton.DoClick = function()
      self:Close()
    end

    self.tabPanel = vgui.Create("versus_TabPanel", self)
    self.tabPanel:Dock(FILL)
    self.tabPanel:DockMargin(0, sp * 0.5, 0, 0)

    self:_buildFeatureTab()
    self:_buildContractTab()

    if LocalPlayer():IsAdmin() then
      self:_buildAdminTab()
    end
  end

  --[[  Feature tab  ]]--

  function PANEL:_buildFeatureTab()
    local sp      = GAMEMODE.SPACING
    local content = vgui.Create("EditablePanel")
    content:DockPadding(sp, sp, sp, sp)
    content.Paint = function() end

    local submitBtn = vgui.Create("versus_Button", content)
    submitBtn:Dock(BOTTOM)
    submitBtn:DockMargin(0, sp * 0.5, 0, 0)
    submitBtn:SetText("SUBMIT")
    submitBtn:SetType("primary")
    submitBtn.DoClick = function()
      self:_submitFeature()
    end

    local desc = vgui.Create("DLabel", content)
    desc:SetFont("VersusDefault")
    desc:SetTextColor(color_dim)
    desc:SetText("Describe a feature you'd like to see added to Versus:")
    desc:SizeToContents()
    desc:Dock(TOP)
    desc:DockMargin(0, 0, 0, sp * 0.5)

    self.featureTextArea = vgui.Create("versus_TextArea", content)
    self.featureTextArea:SetPlaceholderText("Write your feature idea here\226\128\166")
    self.featureTextArea:Dock(FILL)

    self.tabPanel:AddTab("Feature", content)
  end

  function PANEL:_submitFeature()
    local data = { featureText = self.featureTextArea:GetText() }
    local ok, err = PLUGIN.validateFeatureSuggestion(data)

    if not ok then
      self:SetStatus(err, false)
      return
    end

    local jsonData = util.TableToJSON(data, false)

    if #jsonData > PLUGIN.MAX_SUGGESTION_SIZE then
      self:SetStatus("Suggestion data exceeds the 60 KB limit.", false)
      return
    end

    net.Start("versus.suggestions.submit")
    net.WriteString("feature")
    net.WriteString(jsonData)
    net.SendToServer()
  end

  --[[  Contract tab  ]]--

  function PANEL:_buildContractTab()
    local sp = GAMEMODE.SPACING

    -- Outer content panel (non-scrolling shell)
    local content = vgui.Create("EditablePanel")
    content:DockPadding(sp, sp, sp, sp)
    content.Paint = function() end

    -- Fixed top section: map input
    local mapLabel = vgui.Create("DLabel", content)
    mapLabel:SetFont("VersusDefault")
    mapLabel:SetTextColor(color_dim)
    mapLabel:SetText("Map:")
    mapLabel:SizeToContents()
    mapLabel:Dock(TOP)
    mapLabel:DockMargin(0, 0, 0, 4)

    self.contractMapEntry = vgui.Create("versus_TextEntry", content)
    self.contractMapEntry:SetPlaceholderText("e.g. gm_flatgrass")
    self.contractMapEntry:Dock(TOP)
    self.contractMapEntry:DockMargin(0, 0, 0, sp)

    local phasesLabel = vgui.Create("DLabel", content)
    phasesLabel:SetFont("VersusDefault")
    phasesLabel:SetTextColor(color_dim)
    phasesLabel:SetText("Phases:")
    phasesLabel:SizeToContents()
    phasesLabel:Dock(TOP)
    phasesLabel:DockMargin(0, 0, 0, 4)

    -- Fixed bottom section: action buttons
    local submitBtn = vgui.Create("versus_Button", content)
    submitBtn:Dock(BOTTOM)
    submitBtn:DockMargin(0, sp * 0.5, 0, 0)
    submitBtn:SetText("SUBMIT CONTRACT SUGGESTION")
    submitBtn:SetType("primary")
    submitBtn.DoClick = function()
      self:_submitContract()
    end

    local addBtn = vgui.Create("versus_Button", content)
    addBtn:Dock(BOTTOM)
    addBtn:DockMargin(0, 4, 0, 0)
    addBtn:SetText("+ ADD PHASE")
    addBtn:SetType("default")
    addBtn.DoClick = function()
      self:_addPhase()
    end
    self.addPhaseButton = addBtn

    -- Scrollable phase list fills remaining space
    self.phasesScroll = vgui.Create("versus_ScrollPanel", content)
    self.phasesScroll:Dock(FILL)
    self.phasesScroll.Paint = function() end

    self.phases = {}

    self.tabPanel:AddTab("Contract", content)

    -- Start with one phase
    self:_addPhase()
  end

  function PANEL:_addPhase()
    if #self.phases >= PLUGIN.MAX_PHASES then
      self:SetStatus("Maximum of " .. PLUGIN.MAX_PHASES .. " phases allowed.", false)
      return
    end

    local sp    = GAMEMODE.SPACING
    local index = #self.phases + 1

    -- Fixed height = padding + header + remove btn + (label + textarea) * N + padding
    local phaseH = sp
      + (PHASE_LABEL_H + 4)
      + 48 + 4
      + (#PHASE_FIELDS * (PHASE_LABEL_H + 4 + PHASE_FIELD_H + 4))
      + sp

    local phasePanel = vgui.Create("EditablePanel", self.phasesScroll)
    phasePanel:Dock(TOP)
    phasePanel:DockMargin(0, 0, 0, 8)
    phasePanel:SetTall(phaseH)
    phasePanel:DockPadding(sp, sp, sp, sp)
    phasePanel.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(20, 28, 40, 160))
    end

    local headerLabel = vgui.Create("DLabel", phasePanel)
    headerLabel:SetFont("VersusButton")
    headerLabel:SetTextColor(color_accent)
    headerLabel:SetText("PHASE " .. index)
    headerLabel:SizeToContents()
    headerLabel:Dock(TOP)
    headerLabel:DockMargin(0, 0, 0, 4)

    local phaseData = { fields = {}, panel = phasePanel, header = headerLabel }

    local removeBtn = vgui.Create("versus_Button", phasePanel)
    removeBtn:Dock(TOP)
    removeBtn:DockMargin(0, 0, 0, 4)
    removeBtn:SetText("REMOVE PHASE")
    removeBtn:SetType("secondary")
    removeBtn.DoClick = function()
      self:_removePhase(phaseData)
    end

    for _, fieldDef in ipairs(PHASE_FIELDS) do
      local lbl = vgui.Create("DLabel", phasePanel)
      lbl:SetFont("VersusDefault")
      lbl:SetTextColor(color_dim)
      lbl:SetText(fieldDef.label .. ":")
      lbl:SizeToContents()
      lbl:Dock(TOP)
      lbl:DockMargin(0, 0, 0, 4)

      local ta = vgui.Create("versus_TextArea", phasePanel)
      ta:SetTall(PHASE_FIELD_H)
      ta:Dock(TOP)
      ta:DockMargin(0, 0, 0, 4)

      phaseData.fields[fieldDef.key] = ta
    end

    table.insert(self.phases, phaseData)
  end

  function PANEL:_removePhase(phaseData)
    for i, p in ipairs(self.phases) do
      if p == phaseData then
        table.remove(self.phases, i)
        break
      end
    end

    phaseData.panel:Remove()
    self:_refreshPhaseNumbers()
  end

  function PANEL:_refreshPhaseNumbers()
    for i, p in ipairs(self.phases) do
      if IsValid(p.header) then
        p.header:SetText("PHASE " .. i)
        p.header:SizeToContents()
      end
    end
  end

  function PANEL:_submitContract()
    local map = self.contractMapEntry:GetText()
    local phases = {}

    for _, phaseData in ipairs(self.phases) do
      local phase = {}

      for key, ta in pairs(phaseData.fields) do
        phase[key] = ta:GetText()
      end

      table.insert(phases, phase)
    end

    local data = { map = map, phases = phases }
    local ok, err = PLUGIN.validateContractSuggestion(data)

    if not ok then
      self:SetStatus(err, false)
      return
    end

    local jsonData = util.TableToJSON(data, false)

    if #jsonData > PLUGIN.MAX_SUGGESTION_SIZE then
      self:SetStatus("Suggestion data exceeds the 60 KB limit.", false)
      return
    end

    net.Start("versus.suggestions.submit")
    net.WriteString("contract")
    net.WriteString(jsonData)
    net.SendToServer()
  end

  --[[  Admin tab  ]]--

  function PANEL:_buildAdminTab()
    local sp      = GAMEMODE.SPACING
    local content = vgui.Create("EditablePanel")
    content:DockPadding(sp, sp, sp, sp)
    content.Paint = function() end

    local refreshBtn = vgui.Create("versus_Button", content)
    refreshBtn:Dock(TOP)
    refreshBtn:DockMargin(0, 0, 0, sp * 0.5)
    refreshBtn:SetText("\226\134\187 REFRESH LIST")
    refreshBtn:SetType("default")
    refreshBtn.DoClick = function()
      self:_adminRefresh()
    end

    -- Detail panel (bottom, fixed height) shown when a suggestion is selected
    self.adminDetail = vgui.Create("versus_ScrollPanel", content)
    self.adminDetail:Dock(BOTTOM)
    self.adminDetail:SetTall(ScrH() * 0.35)
    self.adminDetail.Paint = function(pnl, w, h)
      draw.RoundedBox(4, 0, 0, w, h, Color(15, 22, 32, 200))
    end

    local placeholderLbl = vgui.Create("DLabel", self.adminDetail)
    placeholderLbl:SetFont("VersusDefault")
    placeholderLbl:SetTextColor(color_dim)
    placeholderLbl:SetText("Select a suggestion to view its content.")
    placeholderLbl:Dock(TOP)
    placeholderLbl:DockMargin(sp, sp, sp, sp)
    placeholderLbl:SetWrap(true)
    placeholderLbl:SetAutoStretchVertical(true)

    -- Suggestion list (fills remaining space)
    self.adminList = vgui.Create("versus_ScrollPanel", content)
    self.adminList:Dock(FILL)
    self.adminList:DockMargin(0, 0, 0, sp * 0.5)

    self.tabPanel:AddTab("Admin", content)

    self:_adminRefresh()
  end

  function PANEL:_adminRefresh()
    if IsValid(self.adminList) then
      self.adminList:Clear()
    end

    net.Start("versus.suggestions.adminList")
    net.SendToServer()
  end

  function PANEL:OnAdminListResult(entries)
    if not IsValid(self.adminList) then return end

    self.adminList:Clear()

    if #entries == 0 then
      local lbl = vgui.Create("DLabel", self.adminList)
      lbl:SetFont("VersusDefault")
      lbl:SetTextColor(color_dim)
      lbl:SetText("No suggestions found.")
      lbl:SizeToContents()
      lbl:Dock(TOP)
      lbl:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, 0)
      return
    end

    for i, entry in ipairs(entries) do
      local row = vgui.Create("versus_SuggestionAdminRow", self.adminList)
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, 4)
      row:SetEntry(entry, i % 2 == 0)
      row.DoClick = function()
        self:_adminLoadSuggestion(entry.suggestionType, entry.filename)
      end
    end
  end

  function PANEL:_adminLoadSuggestion(suggestionType, filename)
    if IsValid(self.adminDetail) then
      self.adminDetail:Clear()

      local sp  = GAMEMODE.SPACING
      local lbl = vgui.Create("DLabel", self.adminDetail)
      lbl:SetFont("VersusDefault")
      lbl:SetTextColor(color_dim)
      lbl:SetText("Loading\226\128\166")
      lbl:SizeToContents()
      lbl:Dock(TOP)
      lbl:DockMargin(sp, sp, sp, sp)
    end

    net.Start("versus.suggestions.adminLoad")
    net.WriteString(suggestionType)
    net.WriteString(filename)
    net.SendToServer()
  end

  function PANEL:OnAdminLoadResult(record)
    if not IsValid(self.adminDetail) then return end

    self.adminDetail:Clear()

    local sp = GAMEMODE.SPACING

    local function addField(label, value)
      local lbl = vgui.Create("DLabel", self.adminDetail)
      lbl:SetFont("VersusButton")
      lbl:SetTextColor(color_accent)
      lbl:SetText(label)
      lbl:SizeToContents()
      lbl:Dock(TOP)
      lbl:DockMargin(sp, sp * 0.5, sp, 2)

      local val = vgui.Create("DLabel", self.adminDetail)
      val:SetFont("VersusDefault")
      val:SetTextColor(color_text)
      val:SetText(tostring(value or ""))
      val:Dock(TOP)
      val:DockMargin(sp, 0, sp, 4)
      val:SetWrap(true)
      val:SetAutoStretchVertical(true)
    end

    addField("Player", (record.playerName or "Unknown") .. " (" .. (record.steamID or "") .. ")")

    local dateStr = (record.timestamp and record.timestamp > 0)
        and os.date("%Y-%m-%d %H:%M:%S", record.timestamp)
        or "Unknown"
    addField("Submitted", dateStr)
    addField("Type", tostring(record.type or ""))

    local data = record.data

    if record.type == "feature" then
      addField("Feature Description", data and data.featureText or "")
    elseif record.type == "contract" then
      addField("Map", data and data.map or "")

      if data and type(data.phases) == "table" then
        local phaseFieldLabels = {
          { key = "lore",         label = "Lore" },
          { key = "goal",         label = "Goal" },
          { key = "monsters",     label = "Monsters" },
          { key = "completion",   label = "Completion" },
          { key = "interference", label = "Interference" },
        }

        for i, phase in ipairs(data.phases) do
          local divider = vgui.Create("DLabel", self.adminDetail)
          divider:SetFont("VersusButton")
          divider:SetTextColor(color_dim)
          divider:SetText("-- Phase " .. i .. " --")
          divider:SizeToContents()
          divider:Dock(TOP)
          divider:DockMargin(sp, sp * 0.5, sp, 2)

          for _, fd in ipairs(phaseFieldLabels) do
            addField(fd.label, phase[fd.key] or "")
          end
        end
      end
    end
  end

  --[[  Common  ]]--

  function PANEL:OnSubmitResult(ok, message)
    self:SetStatus(message, ok)

    if ok and IsValid(self.featureTextArea) then
      self.featureTextArea:SetText("")
    end
  end

  function PANEL:SetStatus(message, isSuccess)
    if not IsValid(self.statusLabel) then return end

    self.statusLabel:SetTextColor(isSuccess and color_success or color_error)
    self.statusLabel:SetText(message or "")
    self.statusLabel:SizeToContents()
  end

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
    local elapsed = CurTime() - self.animStart

    if not self.closing then
      if elapsed < self.animDuration then
        local progress = math.ease.InOutQuad(elapsed / self.animDuration)
        self.bgAlpha      = 200 * progress
        self.contentAlpha = 255 * progress
      else
        self.bgAlpha      = 200
        self.contentAlpha = 255
      end
    else
      local closeElapsed = CurTime() - self.closeStart

      if closeElapsed < 0.3 then
        local progress = 1 - (closeElapsed / 0.3)
        self.bgAlpha      = 200 * progress
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
    self:Center()
  end

  vgui.Register("versus_SuggestionBox", PANEL, "EditablePanel")
end
