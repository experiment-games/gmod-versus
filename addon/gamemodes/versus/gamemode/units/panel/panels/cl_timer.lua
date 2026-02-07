local UNIT = UNIT

do
  local PANEL = {}

  AccessorFunc(PANEL, "removeOnExpire", "RemoveOnExpire", FORCE_BOOL)

  function PANEL:Init()
    self.startTime = 0
    self.duration = 0
    self.countDown = true
    self.alpha = 0
    self.targetAlpha = 255

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = Color(100, 200, 255, 255)
    self.textColor = Color(220, 230, 240, 255)
    self.warningColor = Color(255, 150, 80, 255)
    self.criticalColor = Color(255, 80, 80, 255)

    self:DockPadding(GAMEMODE.SPACING * .5, GAMEMODE.SPACING * .25, GAMEMODE.SPACING * .5, GAMEMODE.SPACING * .25)

    -- Time label
    self.timeLabel = vgui.Create("DLabel", self)
    self.timeLabel:Dock(TOP)
    self.timeLabel:SetFont("VersusHeading2")
    self.timeLabel:SetText("0.00")
    self.timeLabel:SetContentAlignment(5) -- Center
    self.timeLabel:SetTextColor(self.textColor)
    self.timeLabel:SizeToContents()

    -- Spacer
    local spacer = vgui.Create("DPanel", self)
    spacer:Dock(TOP)
    spacer:SetTall(4)
    spacer.Paint = function() end

    -- Status label
    self.statusLabel = vgui.Create("DLabel", self)
    self.statusLabel:Dock(TOP)
    self.statusLabel:SetFont("VersusDefault")
    self.statusLabel:SetText("TIME REMAINING")
    self.statusLabel:SetContentAlignment(5) -- Center
    self.statusLabel:SetTextColor(self.accentColor)
    self.statusLabel:SizeToContents()
  end

  function PANEL:SetTimer(duration, countDown, text)
    self.startTime = CurTime()
    self.duration = duration or 0
    self.countDown = countDown ~= false -- default to countdown
    self.targetAlpha = 255

    self.statusLabel:SetText(text or (self.countDown and "TIME REMAINING" or "ELAPSED"))
    self.statusLabel:SizeToContents()
  end

  function PANEL:GetTimeRemaining()
    if self.countDown then
      local elapsed = CurTime() - self.startTime
      return math.max(0, self.duration - elapsed)
    else
      return CurTime() - self.startTime
    end
  end

  function PANEL:IsComplete()
    if self.countDown then
      return self:GetTimeRemaining() <= 0
    end

    return false
  end

  function PANEL:SetTargetAlpha(alpha)
    self.targetAlpha = math.Clamp(alpha, 0, 255)
  end

  function PANEL:GetAccentColor()
    local accentColor = self.accentColor

    if self.countDown and self.duration > 0 then
      local timeRemaining = self:GetTimeRemaining()
      local percentRemaining = timeRemaining / self.duration

      if percentRemaining <= 0.1 then
        accentColor = self.criticalColor
      elseif percentRemaining <= 0.25 then
        accentColor = self.warningColor
      end
    end

    return accentColor
  end

  function PANEL:Think()
    -- Smooth alpha transition
    self.alpha = Lerp(FrameTime() * 8, self.alpha, self.targetAlpha)

    -- Update time display
    local timeRemaining = self:GetTimeRemaining()
    local totalSeconds = math.floor(timeRemaining)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    local milliseconds = math.floor((timeRemaining - totalSeconds) * 100)

    local timeText
    if minutes >= 1 then
      timeText = string.format("%d:%02d.%02d", minutes, seconds, milliseconds)
    else
      timeText = string.format("%d.%02d", seconds, milliseconds)
    end

    if self.timeLabel:GetText() ~= timeText then
      self.timeLabel:SetText(timeText)
      self.timeLabel:SizeToContents()
    end

    -- Update label color based on time
    local accentColor = self:GetAccentColor()
    self.statusLabel:SetTextColor(ColorAlpha(accentColor, self.alpha * 0.7))
    self.timeLabel:SetTextColor(ColorAlpha(self.textColor, self.alpha))

    if self:IsComplete() and self.removeOnExpire then
      self:Remove()
    end
  end

  function PANEL:SizeToContents(minWidth)
    -- Calculate required size based on children
    local wide = math.max(self.timeLabel:GetWide(), self.statusLabel:GetWide())
    local tall = self.timeLabel:GetTall() + 4 + self.statusLabel:GetTall()

    local paddingLeft, paddingTop, paddingRight, paddingBottom = self:GetDockPadding()
    wide = wide + paddingLeft + paddingRight
    tall = tall + paddingTop + paddingBottom

    self:SetSize(
      math.max(wide, minWidth or 0),
      tall
    )
  end

  function PANEL:Paint(w, h)
    local alpha = self.alpha
    if alpha < 1 then
      return
    end

    local accentColor = self:GetAccentColor()

    -- Background
    local bgColor = ColorAlpha(self.bgColor, alpha)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, w, h)

    -- Top accent bar
    local accentColorAlpha = ColorAlpha(accentColor, alpha)
    surface.SetDrawColor(accentColorAlpha)
    surface.DrawRect(0, 0, w, 3)
  end

  function PANEL:MoveToDefaultPosition()
    self:SetPos(ScrW() / 2 - self:GetWide() / 2, ScrH() - self:GetTall() - GAMEMODE.SPACING)
  end

  vgui.Register("versus_Timer", PANEL, "EditablePanel")
end

concommand.Add("versus_test_timer", function()
  if IsValid(UNIT.timerPanel) then
    UNIT.timerPanel:Remove()
  end

  UNIT.timerPanel = vgui.Create("versus_Timer")
  UNIT.timerPanel:SetTimer(30) -- 30 second countdown
  UNIT.timerPanel:SizeToContents(250)
  UNIT.timerPanel:MoveToDefaultPosition()
end)

if (IsValid(UNIT.timerPanel)) then
  UNIT.timerPanel:Remove()
end
