local UNIT = UNIT
local PANEL = {}

function PANEL:Init()
  self:SetSize(ScrW(), ScrH())
  self:MakePopup()
  self:SetKeyboardInputEnabled(true)
  self:SetMouseInputEnabled(true)
  self:ParentToHUD()

  self.bgAlpha = 0
  self.contentAlpha = 0
  self.animStart = CurTime()
  self.animDuration = 0.4

  -- Main content container
  self.contentPanel = vgui.Create("EditablePanel", self)
  self.contentPanel:SetSize(
    math.min(ScrW() * 0.4, 400),
    250
  )
  self.contentPanel:DockPadding(
    GAMEMODE.SPACING,
    GAMEMODE.SPACING,
    GAMEMODE.SPACING,
    GAMEMODE.SPACING
  )

  -- Title
  self.titleLabel = vgui.Create("DLabel", self.contentPanel)
  self.titleLabel:SetFont("VersusHeading2")
  self.titleLabel:SetTextColor(Color(220, 230, 240, 255))
  self.titleLabel:SetText(self:GetTitle() or "Confirm")
  self.titleLabel:SizeToContents()
  self.titleLabel:Dock(TOP)
  self.titleLabel:DockMargin(0, 0, 0, 0)
  self.titleLabel:SetContentAlignment(5)

  -- Message text
  self.textLabel = vgui.Create("DLabel", self.contentPanel)
  self.textLabel:SetFont("VersusDefault")
  self.textLabel:SetTextColor(Color(180, 190, 200, 255))
  self.textLabel:SetText(self:GetText() or "Are you sure?")
  self.textLabel:SetWrap(true)
  self.textLabel:SetAutoStretchVertical(true)
  self.textLabel:Dock(TOP)
  self.textLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)
  self.textLabel:SetContentAlignment(5)

  -- Button container
  self.buttonPanel = vgui.Create("EditablePanel", self.contentPanel)
  self.buttonPanel:Dock(BOTTOM)
  self.buttonPanel:SetTall(48)

  self.buttons = {}
end

function PANEL:SetText(strText)
  self.strText = strText
  if IsValid(self.textLabel) then
    self.textLabel:SetText(strText)
  end
end

function PANEL:GetText()
  return self.strText
end

function PANEL:SetTitle(strTitle)
  self.strTitle = strTitle
  if IsValid(self.titleLabel) then
    self.titleLabel:SetText(strTitle)
  end
end

function PANEL:GetTitle()
  return self.strTitle
end

function PANEL:AddButtons(...)
  local numOptions = 0
  local buttonWidth = 0

  -- Create buttons from varargs
  for k = 1, 8, 2 do
    local txt = select(k, ...)
    if txt == nil then break end

    local func = select(k + 1, ...) or function() end

    local button = vgui.Create("versus_Button", self.buttonPanel)
    button:Dock(LEFT)
    button:DockMargin(k == 1 and 0 or GAMEMODE.SPACING * .5, 0, 0, 0)
    button:SetText(txt:upper())
    button:SizeToContents()

    -- First button is primary, rest are secondary
    if numOptions == 0 then
      button:SetType("primary")
    else
      button:SetType("secondary")
    end

    button.DoClick = function()
      func()
      self:Close()
    end

    table.insert(self.buttons, button)
    numOptions = numOptions + 1
    buttonWidth = buttonWidth + button:GetWide()
  end

  if numOptions == 0 then
    self:Close()
    Error("UNIT.Query: Created Query with no options!")
    return
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

  -- Dark overlay
  surface.SetDrawColor(0, 0, 0, self.bgAlpha)
  surface.DrawRect(0, 0, w, h)
end

function PANEL:PerformLayout(w, h)
  self.contentPanel:Center()
end

vgui.Register("versus_Query", PANEL, "EditablePanel")
