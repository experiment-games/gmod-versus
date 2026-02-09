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
    300
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
  self.titleLabel:SetText(self:GetTitle() or "Input Required")
  self.titleLabel:SizeToContents()
  self.titleLabel:Dock(TOP)
  self.titleLabel:DockMargin(0, 0, 0, 0)
  self.titleLabel:SetContentAlignment(5)

  -- Message text
  self.textLabel = vgui.Create("DLabel", self.contentPanel)
  self.textLabel:SetFont("VersusDefault")
  self.textLabel:SetTextColor(Color(180, 190, 200, 255))
  self.textLabel:SetText(self:GetText() or "Please enter a value:")
  self.textLabel:SetWrap(true)
  self.textLabel:SetAutoStretchVertical(true)
  self.textLabel:Dock(TOP)
  self.textLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * .5)
  self.textLabel:SetContentAlignment(5)

  -- Text entry
  self.textEntry = vgui.Create("versus_TextEntry", self.contentPanel)
  self.textEntry:Dock(TOP)
  self.textEntry:SetText(self:GetDefaultText() or "")

  self.textEntry.OnEnter = function()
    if self:GetButtonCallback() then
      self:GetButtonCallback()(self.textEntry:GetValue())
    end

    self:Close()
  end

  -- Button container
  self.buttonPanel = vgui.Create("EditablePanel", self.contentPanel)
  self.buttonPanel:Dock(BOTTOM)
  self.buttonPanel:SetTall(48)

  -- Submit button
  self.submitButton = vgui.Create("versus_Button", self.buttonPanel)
  self.submitButton:SetText((self:GetButtonText() or "OK"):upper())
  self.submitButton:Dock(LEFT)
  self.submitButton:SizeToContents()
  self.submitButton:SetType("primary")
  self.submitButton.DoClick = function()
    if self:GetButtonCallback() then
      self:GetButtonCallback()(self.textEntry:GetValue())
    end
    self:Close()
  end

  -- Cancel button
  self.cancelButton = vgui.Create("versus_Button", self.buttonPanel)
  self.cancelButton:SetText((self:GetButtonCancelText() or "CANCEL"):upper())
  self.cancelButton:Dock(RIGHT)
  self.cancelButton:SizeToContents()
  self.cancelButton:SetType("secondary")
  self.cancelButton.DoClick = function()
    if self:GetButtonCancelCallback() then
      self:GetButtonCancelCallback()(self.textEntry:GetValue())
    end
    self:Close()
  end

  -- Focus the text entry
  timer.Simple(0.05, function()
    if IsValid(self.textEntry) then
      self.textEntry:RequestFocus()
      self.textEntry:SelectAll()
    end
  end)
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

function PANEL:SetDefaultText(strDefaultText)
  self.strDefaultText = strDefaultText
  if IsValid(self.textEntry) then
    self.textEntry:SetText(strDefaultText)
  end
end

function PANEL:GetDefaultText()
  return self.strDefaultText
end

function PANEL:SetButtonText(strButtonText)
  self.strButtonText = strButtonText
  if IsValid(self.submitButton) then
    self.submitButton:SetText(strButtonText:upper())
  end
end

function PANEL:GetButtonText()
  return self.strButtonText
end

function PANEL:SetButtonCancelText(strButtonCancelText)
  self.strButtonCancelText = strButtonCancelText
  if IsValid(self.cancelButton) then
    self.cancelButton:SetText(strButtonCancelText:upper())
  end
end

function PANEL:GetButtonCancelText()
  return self.strButtonCancelText
end

function PANEL:SetButtonCallback(fnButtonCallback)
  self.fnButtonCallback = fnButtonCallback
end

function PANEL:GetButtonCallback()
  return self.fnButtonCallback
end

function PANEL:SetButtonCancelCallback(fnButtonCancelCallback)
  self.fnButtonCancelCallback = fnButtonCancelCallback
end

function PANEL:GetButtonCancelCallback()
  return self.fnButtonCancelCallback
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

vgui.Register("versus_StringRequest", PANEL, "EditablePanel")
