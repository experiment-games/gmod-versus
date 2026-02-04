local UNIT = UNIT
local NOTIFICATION_WIDTH = 400
local NOTIFICATION_SPACING = 8
local NOTIFICATION_LIFETIME = 6 -- seconds
local MESSAGE_MERGE_WINDOW_SECONDS = 2
local FADE_IN_TIME = 0.2
local FADE_OUT_TIME = 0.4
local SLIDE_DISTANCE = 60
local ICON_SIZE = 16

-- Notification panel
do
  local PANEL = {}

  function PANEL:Init()
    self:SetWide(NOTIFICATION_WIDTH)

    self.message = nil
    self.slideProgress = 0
    self.classData = nil

    self.bgColor = color_background
    self.accentColor = Color(80, 140, 220, 255)
    self.textColor = Color(220, 230, 240, 255)
    self.shadowColor = Color(0, 0, 0, 200)
  end

  function PANEL:SetMessage(message)
    self.message = message

    -- Get class styling
    local class = UNIT.getNotifyClass(message.class or 0)
    self.classData = class or UNIT.getNotifyClass(NOTIFY_INFORMATION)

    -- Set colors based on class
    if self.classData.color then
      self.accentColor = self.classData.color
    end

    -- Recalculate height based on text
    self:RecalculateSize()
  end

  function PANEL:RecalculateSize()
    if not self.message then return end

    surface.SetFont("versus_Chatbox_MainText")

    local maxWidth = NOTIFICATION_WIDTH - ICON_SIZE - 32 -- Padding for icon and margins
    local wrappedLines = {}

    -- Simple word wrapping
    local words = string.Explode(" ", self.message.text)
    local currentLine = ""

    for _, word in ipairs(words) do
      local testLine = currentLine == "" and word or (currentLine .. " " .. word)
      local testWidth = surface.GetTextSize(testLine)

      if testWidth > maxWidth then
        table.insert(wrappedLines, currentLine)
        currentLine = word
      else
        currentLine = testLine
      end
    end

    if currentLine ~= "" then
      table.insert(wrappedLines, currentLine)
    end

    self.wrappedLines = wrappedLines

    -- Calculate new height
    local lineHeight = UNIT.getLineHeight()
    local calculatedHeight = NOTIFICATION_SPACING + (#wrappedLines * (lineHeight + 2)) + NOTIFICATION_SPACING +
        NOTIFICATION_SPACING

    self:SetTall(calculatedHeight)
  end

  function PANEL:GetMessage()
    return self.message
  end

  function PANEL:SetSlideProgress(progress)
    self.slideProgress = math.Clamp(progress, 0, 1)
  end

  function PANEL:GetSlideProgress()
    return self.slideProgress
  end

  function PANEL:Paint(w, h)
    if not self.message then return end

    -- Background with subtle gradient
    local bgColor = self.bgColor
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, w, h)

    -- Left accent line
    local accentColor = self.accentColor
    surface.SetDrawColor(accentColor)
    surface.DrawRect(0, 0, 6, h)

    -- Draw icon if present
    if self.message.icon and self.message.icon[1] then
      surface.SetMaterial(self.message.icon[1])
      surface.SetDrawColor(255, 255, 255, 255)
      surface.DrawTexturedRect(16, (h - ICON_SIZE) / 2, ICON_SIZE, ICON_SIZE)
    elseif self.classData and self.classData.icon then
      surface.SetMaterial(self.classData.icon)
      surface.SetDrawColor(255, 255, 255, 255)
      surface.DrawTexturedRect(16, (h - ICON_SIZE) / 2, ICON_SIZE, ICON_SIZE)
    end

    -- Draw text
    local textX = ICON_SIZE + 22
    local textY = 12

    surface.SetFont("versus_Chatbox_MainText")
    local textColor = self.textColor
    local shadowColor = self.shadowColor

    if self.wrappedLines then
      local lineHeight = UNIT.getLineHeight()

      for i, line in ipairs(self.wrappedLines) do
        local currentY = textY + ((i - 1) * (lineHeight + 2))

        -- Shadow
        draw.SimpleText(
          line,
          "versus_Chatbox_MainText",
          textX + 1,
          currentY + 1,
          shadowColor,
          TEXT_ALIGN_LEFT,
          TEXT_ALIGN_TOP
        )

        -- Main text
        draw.SimpleText(
          line,
          "versus_Chatbox_MainText",
          textX,
          currentY,
          textColor,
          TEXT_ALIGN_LEFT,
          TEXT_ALIGN_TOP
        )
      end
    end
  end

  vgui.Register("versus_NotificationPanel", PANEL, "EditablePanel")
end

-- Notification stack manager
do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(NOTIFICATION_WIDTH, ScrH())
    self:SetPos(ScrW() - NOTIFICATION_WIDTH - 20, 20)

    self.notifications = {}
    self.messageTracker = {} -- Tracks recent messages by text hash
    self.maxNotifications = 20
  end

  function PANEL:ShowNotification(message)
    if not message or not message.text then return end

    local currentTime = CurTime()
    local messageHash = util.CRC(message.text)

    -- Check if this message was shown recently (merge similar messages)
    local recentNotif = self.messageTracker[messageHash]
    if recentNotif and (currentTime - recentNotif.lastTime) < MESSAGE_MERGE_WINDOW_SECONDS then
      -- Just refresh the existing notification's lifetime
      if IsValid(recentNotif.notification) then
        local notifData = nil
        for _, data in ipairs(self.notifications) do
          if data.panel == recentNotif.notification then
            notifData = data
            break
          end
        end

        if notifData then
          notifData.spawnTime = currentTime
          notifData.fadeOutStart = nil
          recentNotif.lastTime = currentTime
          return
        end
      end
    end

    -- Remove oldest notification if at max capacity
    if #self.notifications >= self.maxNotifications then
      local oldest = self.notifications[1]
      if IsValid(oldest.panel) then
        oldest.fadeOutStart = CurTime()
      end
    end

    -- Create new notification
    local notif = vgui.Create("versus_NotificationPanel", self)
    notif:SetMessage(message)

    local notifData = {
      panel = notif,
      spawnTime = currentTime,
      fadeOutStart = nil,
      targetY = 0,
      message = message
    }

    table.insert(self.notifications, notifData)

    -- Track this message
    self.messageTracker[messageHash] = {
      notification = notif,
      lastTime = currentTime
    }

    -- Update layout
    self:UpdateLayout()

    -- Set initial position (slide in from right)
    notif:SetPos(SLIDE_DISTANCE, notifData.targetY)
    notif:SetSlideProgress(0)
    notif:SetAlpha(0)

    -- Play sound if specified
    if message.playSound then
      local class = UNIT.getNotifyClass(message.class or 0)
      if class and class.sound then
        if istable(class.sound) then
          sound.Play(class.sound.path, LocalPlayer():EyePos(), 75, class.sound.pitch or 100, class.sound.volume or 1)
        else
          surface.PlaySound(class.sound)
        end
      end
    end
  end

  function PANEL:UpdateLayout()
    local yOffset = 0

    for i, data in ipairs(self.notifications) do
      if IsValid(data.panel) then
        data.targetY = yOffset
        yOffset = yOffset + data.panel:GetTall() + NOTIFICATION_SPACING
      end
    end
  end

  function PANEL:Think()
    local currentTime = CurTime()
    local toRemove = {}

    for i, data in ipairs(self.notifications) do
      if not IsValid(data.panel) then
        table.insert(toRemove, i)
        continue
      end

      local notif = data.panel
      local lifetime = currentTime - data.spawnTime

      -- Handle fade in
      if lifetime < FADE_IN_TIME and not data.fadeOutStart then
        local fadeProgress = lifetime / FADE_IN_TIME
        notif:SetAlpha(255 * fadeProgress)
        notif:SetSlideProgress(fadeProgress)
      elseif not data.fadeOutStart then
        notif:SetAlpha(255)
        notif:SetSlideProgress(1)
      end

      -- Check for custom lifetime from class
      local lifetimeToUse = NOTIFICATION_LIFETIME
      if data.message.class then
        local class = UNIT.getNotifyClass(data.message.class)
        if class and class.lifeTime then
          lifetimeToUse = class.lifeTime
        end
      end

      -- Handle automatic fade out after lifetime
      if lifetime > lifetimeToUse and not data.fadeOutStart then
        data.fadeOutStart = currentTime
      end

      -- Handle fade out
      if data.fadeOutStart then
        local fadeOutTime = currentTime - data.fadeOutStart
        if fadeOutTime >= FADE_OUT_TIME then
          table.insert(toRemove, i)
          notif:Remove()
        else
          local fadeProgress = 1 - (fadeOutTime / FADE_OUT_TIME)
          notif:SetAlpha(255 * fadeProgress)
        end
      end

      -- Smooth position animation
      local currentX, currentY = notif:GetPos()
      local targetX = (1 - notif:GetSlideProgress()) * SLIDE_DISTANCE
      local newY = Lerp(FrameTime() * 10, currentY, data.targetY)

      notif:SetPos(targetX, newY)
    end

    -- Remove invalid/finished notifications
    for i = #toRemove, 1, -1 do
      local idx = toRemove[i]
      local data = self.notifications[idx]

      -- Clear from message tracker
      if data.message and data.message.text then
        local messageHash = util.CRC(data.message.text)
        if self.messageTracker[messageHash] and self.messageTracker[messageHash].notification == data.panel then
          self.messageTracker[messageHash] = nil
        end
      end

      table.remove(self.notifications, idx)
    end

    -- Update layout if notifications changed
    if #toRemove > 0 then
      self:UpdateLayout()
    end

    -- Clean up old message tracker entries
    for messageHash, data in pairs(self.messageTracker) do
      if not IsValid(data.notification) or (currentTime - data.lastTime) > (MESSAGE_MERGE_WINDOW_SECONDS + 1) then
        self.messageTracker[messageHash] = nil
      end
    end
  end

  function PANEL:PerformLayout(w, h)
    -- Keep position at top-right
    self:SetPos(ScrW() - NOTIFICATION_WIDTH - (GAMEMODE.SPACING or 20), GAMEMODE.SPACING or 20)
  end

  vgui.Register("versus_NotificationStack", PANEL, "EditablePanel")
end

-- Initialize the notification stack
hook.Add("InitPostEntity", "versus.message.CreateNotificationStack", function()
  UNIT:createNotificationStack()
end)

-- Rebuild on Lua auto refresh
if IsValid(UNIT.notificationStack) then
  UNIT:createNotificationStack()
end
