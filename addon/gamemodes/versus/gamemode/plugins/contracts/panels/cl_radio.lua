local PLUGIN = PLUGIN

-- Design Constants
local PANEL_WIDTH = 500
local PANEL_HEIGHT = 100
local PORTRAIT_SIZE = 80
local PADDING = 20

-- Colors
local COLOR_BG_MAIN = Color(15, 20, 25, 240)
local COLOR_TEXT_PRIMARY = Color(220, 230, 240, 255)
local COLOR_TEXT_SECONDARY = Color(140, 160, 180, 255)
local COLOR_ACCENT = Color(80, 160, 200, 255)
local COLOR_WAVEFORM = Color(60, 140, 180, 180)

do
  local PANEL = {}

  DEFINE_BASECLASS("DSizeToContents")

  function PANEL:Init()
    self:SetSizeX(false)
    self:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    self:Dock(TOP)
    self:DockPadding(PADDING, PADDING, PADDING, PADDING)

    -- Initialize values
    self.speakerName = ""
    self.messageText = ""
    self.portraitMaterial = nil
    self.alpha = 0
    self.targetAlpha = 0
    self.animProgress = 0

    -- Waveform animation
    self.waveformBars = {}
    for i = 1, 8 do
      self.waveformBars[i] = math.random(0.3, 1.0)
    end
    self.waveformTime = 0

    -- Sliding animation
    self.slideOffset = -50
    self.targetSlideOffset = 0

    -- Header label
    self.headerLabel = vgui.Create("DLabel", self)
    self.headerLabel:Dock(TOP)
    self.headerLabel:DockMargin(PORTRAIT_SIZE + PADDING, 0, 0, 0)
    self.headerLabel:SetFont("VersusDefaultOutlined")
    self.headerLabel:SetText("INCOMING TRANSMISSION")
    self.headerLabel:SetTextColor(COLOR_TEXT_SECONDARY)
    self.headerLabel:SetContentAlignment(4) -- Left align
    self.headerLabel:SetTall(14)

    -- Speaker name label
    self.nameLabel = vgui.Create("DLabel", self)
    self.nameLabel:Dock(TOP)
    self.nameLabel:DockMargin(PORTRAIT_SIZE + PADDING, 2, 0, 0)
    self.nameLabel:SetFont("VersusDefaultOutlined")
    self.nameLabel:SetText("")
    self.nameLabel:SetTextColor(COLOR_ACCENT)
    self.nameLabel:SetContentAlignment(4) -- Left align
    self.nameLabel:SetTall(18)

    -- Message label with wrapping
    self.messageLabel = vgui.Create("DLabel", self)
    self.messageLabel:Dock(TOP)
    self.messageLabel:DockMargin(PORTRAIT_SIZE + PADDING, 2, 0, 0)
    self.messageLabel:SetFont("VersusDefault")
    self.messageLabel:SetText("")
    self.messageLabel:SetTextColor(COLOR_TEXT_PRIMARY)
    self.messageLabel:SetContentAlignment(7) -- Top-left align
    self.messageLabel:SetWrap(true)
    self.messageLabel:SetAutoStretchVertical(true)
  end

  function PANEL:SetMessage(speakerName, messageText, portraitPath)
    self.speakerName = speakerName or ""
    self.messageText = messageText or ""

    -- Update labels
    self.nameLabel:SetText(self.speakerName)

    -- Load portrait material
    if portraitPath and portraitPath ~= "" then
      self.portraitMaterial = Material(portraitPath, "smooth")
    else
      self.portraitMaterial = nil
    end

    -- Trigger show animation
    self:Show()
  end

  function PANEL:Show()
    self.targetAlpha = 255
    self.targetSlideOffset = 0
    self.animProgress = 0

    -- A bit quieter
    EmitSound(
      "ambient/levels/prison/radio_random1.wav",
      LocalPlayer():GetPos(),
      -1,
      CHAN_AUTO,
      0.25,
      nil,
      nil,
      math.random(90, 110)
    )
  end

  function PANEL:Hide()
    self.targetAlpha = 0
    self.targetSlideOffset = -50
  end

  function PANEL:Think()
    -- Smooth alpha animation
    self.alpha = Lerp(FrameTime() * 8, self.alpha, self.targetAlpha)

    -- Smooth slide animation
    self.slideOffset = math.ceil(Lerp(FrameTime() * 10, self.slideOffset, self.targetSlideOffset))

    -- Animation progress
    if self.targetAlpha > 0 then
      self.animProgress = math.min(self.animProgress + FrameTime() * 3, 1)
    else
      self.animProgress = math.max(self.animProgress - FrameTime() * 3, 0)
    end

    -- Update message text with typing animation
    local visibleChars = math.floor(#self.messageText * math.min(self.animProgress * 1.5, 1))
    local displayText = string.sub(self.messageText, 1, visibleChars)
    self.messageLabel:SetText(displayText)

    -- Update text colors with alpha
    self.headerLabel:SetTextColor(Color(COLOR_TEXT_SECONDARY.r, COLOR_TEXT_SECONDARY.g, COLOR_TEXT_SECONDARY.b,
      self.alpha * 0.7))
    self.nameLabel:SetTextColor(Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, self.alpha))
    self.messageLabel:SetTextColor(Color(COLOR_TEXT_PRIMARY.r, COLOR_TEXT_PRIMARY.g, COLOR_TEXT_PRIMARY.b, self.alpha))

    -- Update waveform animation
    self.waveformTime = self.waveformTime + FrameTime()
    if self.waveformTime > 0.05 then
      self.waveformTime = 0
      for i = 1, 8 do
        if self.targetAlpha > 0 then
          self.waveformBars[i] = Lerp(0.3, self.waveformBars[i], math.random(0.2, 1.0))
        else
          self.waveformBars[i] = Lerp(0.3, self.waveformBars[i], 0.3)
        end
      end
    end
  end

  function PANEL:Paint(w, h)
    if self.alpha < 1 then return end

    local x, y = self.slideOffset, 0

    -- Main background
    surface.SetDrawColor(COLOR_BG_MAIN.r, COLOR_BG_MAIN.g, COLOR_BG_MAIN.b, self.alpha * 0.94)
    surface.DrawRect(x, y, w, h)

    -- Portrait
    if not self.portraitMaterial or self.portraitMaterial:IsError() then
      self.portraitMaterial = Material("versus/npc/unknown.png", "smooth")
    end

    surface.SetDrawColor(255, 255, 255, self.alpha * math.sin(CurTime() * 4) * 0.3 + self.alpha * 0.7)
    surface.SetMaterial(self.portraitMaterial)
    surface.DrawTexturedRect(PADDING, PADDING, PORTRAIT_SIZE, PORTRAIT_SIZE)

    -- Waveform visualization (top right)
    local waveX = x + w - PADDING - 60
    local waveY = y + PADDING + 12
    local barWidth = 3
    local barSpacing = 5

    for i = 1, 8 do
      local barHeight = self.waveformBars[i] * 12
      surface.SetDrawColor(COLOR_WAVEFORM.r, COLOR_WAVEFORM.g, COLOR_WAVEFORM.b, self.alpha * self.waveformBars[i])
      surface.DrawRect(
        waveX + (i - 1) * (barWidth + barSpacing),
        waveY - barHeight,
        barWidth,
        barHeight
      )
    end
  end

  function PANEL:PerformLayout()
    BaseClass.PerformLayout(self)

    -- Ensure the panel is always tall enough to fit the portrait + padding
    local minHeight = PORTRAIT_SIZE + PADDING * 2
    if self:GetTall() < minHeight then
      self:SetTall(minHeight)
    end
  end

  vgui.Register("versus_RadioPanel", PANEL, "DSizeToContents")
end

-- Hint Panel for dismiss instructions and queue indicator
do
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(35)
    self:Dock(TOP)
  end

  function PANEL:Paint(w, h)
    local parent = self:GetParent()
    if not IsValid(parent) then return end

    local panel = parent.currentPanel
    if not panel or not IsValid(panel) then return end

    local alpha = panel.alpha
    if alpha < 1 then return end

    local padding = 4

    -- Background
    surface.SetDrawColor(ColorAlpha(COLOR_BG_MAIN, alpha * 0.8))
    surface.DrawRect(0, 0, w, h)

    -- Draw hold progress indicator if holding
    if parent.isHolding then
      local holdProgress = math.min((CurTime() - parent.holdStartTime) / parent.HOLD_TIME, 1)

      -- Progress fill
      surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, alpha * .25)
      surface.DrawRect(0, 0, w * holdProgress, h)
    end

    -- Draw hint text
    surface.SetFont("VersusDefault")
    local sprintKey = versus.message.lookupBinding("speed") or "SPRINT"
    local useKey = versus.message.lookupBinding("use") or "USE"
    local hintText = string.format("Hold %s + %s to dismiss", sprintKey, useKey)

    surface.SetTextColor(COLOR_TEXT_SECONDARY.r, COLOR_TEXT_SECONDARY.g, COLOR_TEXT_SECONDARY.b, alpha * 0.7)
    surface.SetTextPos(PADDING, padding)
    surface.DrawText(hintText)

    -- Draw queue indicator if multiple messages
    local queueCount = parent:GetQueueCount()
    if queueCount > 1 then
      -- Draw queue counter "1/5"
      local counterText = string.format("1/%d", queueCount)
      surface.SetFont("VersusDefaultOutlined")
      local textW, textH = draw.SimpleText(
        counterText,
        "VersusDefaultOutlined",
        w - PADDING,
        padding,
        Color(COLOR_TEXT_SECONDARY.r, COLOR_TEXT_SECONDARY.g, COLOR_TEXT_SECONDARY.b, alpha * 0.8),
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_TOP
      )

      -- Draw dots next to counter
      local dotX = w - textW - PADDING - 8
      local dotSize = 10
      local dotY = (h / 2) - (dotSize / 2)
      local dotSpacing = dotSize + 4
      local maxDots = math.min(queueCount, 5) -- Show max 5 dots

      for i = 1, maxDots do
        if i == maxDots then
          -- Current message - filled dot
          surface.SetDrawColor(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, alpha)
        else
          -- Queued messages - hollow dot
          surface.SetDrawColor(COLOR_TEXT_SECONDARY.r, COLOR_TEXT_SECONDARY.g, COLOR_TEXT_SECONDARY.b, alpha * 0.5)
        end

        surface.DrawRect(dotX - i * dotSpacing, dotY, dotSize, dotSize)
      end

      -- Draw "+" if more than 5 messages
      if queueCount > 5 then
        surface.SetTextColor(COLOR_TEXT_SECONDARY.r, COLOR_TEXT_SECONDARY.g, COLOR_TEXT_SECONDARY.b, alpha * 0.7)
        surface.SetTextPos(dotX + maxDots * dotSpacing + 2, padding)
        surface.DrawText("+")
      end
    end
  end

  vgui.Register("versus_RadioHintPanel", PANEL, "EditablePanel")
end

-- Radio Panel Stack Manager
do
  local PANEL = {}

  -- Seconds to hold keys before dismissing
  PANEL.HOLD_TIME = 0.75

  function PANEL:Init()
    self:SetSizeX(false)
    self.messageQueue = {}
    self.currentPanel = nil
    self.holdStartTime = 0
    self.isHolding = false
    self.sprintKey = input.GetKeyCode(input.LookupBinding("speed")) or KEY_LSHIFT
    self.useKey = input.GetKeyCode(input.LookupBinding("use")) or KEY_E

    -- Position halfway down left side of screen
    local scrW, scrH = ScrW(), ScrH()
    self:SetPos(GAMEMODE.SPACING, scrH * 0.5 - PANEL_HEIGHT / 2)

    self:SetWide(PANEL_WIDTH)
    self:ParentToHUD()

    -- Create hint panel
    self.hintPanel = vgui.Create("versus_RadioHintPanel", self)
  end

  -- Add a message to the queue
  function PANEL:QueueMessage(speakerName, messageText, portraitPath)
    table.insert(self.messageQueue, {
      speaker = speakerName,
      message = messageText,
      portrait = portraitPath
    })

    -- If no message is currently showing, show this one
    if not self.currentPanel or not IsValid(self.currentPanel) then
      self:ShowNextMessage()
    else
      surface.PlaySound("ambient/levels/prison/radio_random11.wav")
    end
  end

  -- Show the next message in the queue
  function PANEL:ShowNextMessage()
    if #self.messageQueue == 0 then
      -- No more messages, clean up current panel
      if self.currentPanel and IsValid(self.currentPanel) then
        self.currentPanel:Hide()

        timer.Simple(0.5, function()
          if IsValid(self.currentPanel) then
            self.currentPanel:Remove()
            self.currentPanel = nil
          end
        end)
      end

      return
    end

    -- Get next message
    local nextMessage = table.remove(self.messageQueue, 1)

    -- Create or reuse panel
    if not self.currentPanel or not IsValid(self.currentPanel) then
      self.currentPanel = vgui.Create("versus_RadioPanel", self)
      self.currentPanel:MoveToBack()
    end

    -- Set the message
    self.currentPanel:SetMessage(nextMessage.speaker, nextMessage.message, nextMessage.portrait)
    self.currentPanel:InvalidateLayout(true)
    self:InvalidateChildren(true)
  end

  -- Dismiss current message and show next
  function PANEL:DismissCurrentMessage()
    self:ShowNextMessage()
    self.holdStartTime = 0
    self.isHolding = false
  end

  -- Get queue count (including current message)
  function PANEL:GetQueueCount()
    local count = #self.messageQueue
    if self.currentPanel and IsValid(self.currentPanel) and self.currentPanel.alpha > 0 then
      count = count + 1
    end
    return count
  end

  -- Get current position (always 1 if showing)
  function PANEL:GetCurrentPosition()
    if self.currentPanel and IsValid(self.currentPanel) and self.currentPanel.alpha > 0 then
      return 1
    end
    return 0
  end

  function PANEL:Think()
    if not self.currentPanel or not IsValid(self.currentPanel) then
      return
    end

    -- Check if both keys are held
    local sprintHeld = input.IsKeyDown(self.sprintKey)
    local useHeld = input.IsKeyDown(self.useKey)
    local bothHeld = sprintHeld and useHeld

    if bothHeld then
      if not self.isHolding then
        -- Just started holding
        self.isHolding = true
        self.holdStartTime = CurTime()
      else
        -- Check if held long enough
        local holdDuration = CurTime() - self.holdStartTime
        if holdDuration >= self.HOLD_TIME then
          self:DismissCurrentMessage()
        end
      end
    else
      -- Keys released, reset
      self.isHolding = false
      self.holdStartTime = 0
    end
  end

  function PANEL:Paint(w, h)
    if not self.currentPanel or not IsValid(self.currentPanel) then
      return
    end

    local panel = self.currentPanel
    local alpha = panel.alpha
    if alpha < 1 then return end

    local x, y = self:LocalToScreen(0, 0)

    render.SetScissorRect(x, y, x + w, y + h, true)

    versus.util.drawBlur(self, 1, nil, alpha)

    render.SetScissorRect(0, 0, 0, 0, false)
  end

  vgui.Register("versus_RadioPanelStack", PANEL, "DSizeToContents")
end

concommand.Add("versus_test_radio", function()
  if (PLUGIN.radioStack and IsValid(PLUGIN.radioStack)) then
    PLUGIN.radioStack:Remove()
    PLUGIN.radioStack = nil
  end

  local stack = vgui.Create("versus_RadioPanelStack")

  -- Queue multiple messages to test the stack
  stack:QueueMessage(
    "Commander Shepard",
    "We have a situation here. I repeat, we have a situation. The Reapers are attacking and we need immediate assistance.",
    "versus/npc/song_jeffrey.png"
  )

  stack:QueueMessage(
    "Unknown Sender",
    "This is a test of the emergency broadcast system. If this had been an actual emergency, you would be instructed to follow the on-screen prompts.",
    "versus/npc/unknown.png"
  )

  stack:QueueMessage(
    "Control Tower",
    "All units be advised: weather conditions are deteriorating. Recommend returning to base immediately.",
    "versus/npc/song_jeffrey.png"
  )

  stack:QueueMessage(
    "Medical Bay",
    "We're running low on supplies. .",
    "versus/npc/unknown.png"
  )

  PLUGIN.radioStack = stack
end)

net.Receive("versus.contracts.showRadioMessage", function()
  local speaker = net.ReadString()
  local message = net.ReadString()
  local hasPortrait = net.ReadBool()
  local portrait = hasPortrait and net.ReadString() or nil

  if (not PLUGIN.radioStack or not IsValid(PLUGIN.radioStack)) then
    PLUGIN.radioStack = vgui.Create("versus_RadioPanelStack")
  end

  PLUGIN.radioStack:QueueMessage(speaker, message, portrait)
end)
