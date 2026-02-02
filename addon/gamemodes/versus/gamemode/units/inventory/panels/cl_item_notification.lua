local UNIT = UNIT
local NOTIFICATION_WIDTH = 320
local NOTIFICATION_HEIGHT = 64
local NOTIFICATION_SPACING = 8
local NOTIFICATION_LIFETIME = 4 -- seconds
local ITEM_MERGE_WINDOW_SECONDS = NOTIFICATION_LIFETIME * .25
local FADE_IN_TIME = 0.15
local FADE_OUT_TIME = 0.3
local SLIDE_DISTANCE = 50

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT)

    self.item = nil
    self.amount = 1
    self.alpha = 0
    self.slideProgress = 0

    self.modelPanel = vgui.Create("versus_ItemModelPanel", self)
    self.modelPanel:SetSize(NOTIFICATION_HEIGHT, NOTIFICATION_HEIGHT)
    self.modelPanel:SetAmbientLight(Color(200, 200, 200, 255))

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = Color(80, 140, 220, 255)
    self.textColor = Color(220, 230, 240, 255)
    self.amountColor = Color(150, 170, 200, 255)
  end

  function PANEL:SetItem(item)
    self.item = item

    self.modelPanel:SetItem(item)
    self.modelPanel:SetFOV(item.notificationFov or 60)
  end

  function PANEL:GetItem()
    return self.item
  end

  function PANEL:SetAmount(amount)
    self.amount = math.max(1, amount)
  end

  function PANEL:GetAmount()
    return self.amount
  end

  function PANEL:SetAlpha(alpha)
    self.alpha = math.Clamp(alpha, 0, 255)
  end

  function PANEL:GetAlpha()
    return self.alpha
  end

  function PANEL:SetSlideProgress(progress)
    self.slideProgress = math.Clamp(progress, 0, 1)
  end

  function PANEL:GetSlideProgress()
    return self.slideProgress
  end

  function PANEL:Paint(w, h)
    if not self.item then return end

    local alpha = self.alpha

    -- Background with rounded corners
    local bgColor = ColorAlpha(self.bgColor, alpha)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, w, h)

    -- Left accent line
    local accentColor = ColorAlpha(self.accentColor, alpha)
    surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, accentColor.a)
    surface.DrawRect(0, 0, self.modelPanel:GetWide() + 4, h)

    -- Item name
    surface.SetFont("VersusDefault")
    local itemName = self.item.name or "Unknown Item"
    local textColor = ColorAlpha(self.textColor, alpha)
    surface.SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)

    local textX = self.modelPanel:GetWide() + 12
    local textY = h * .5

    draw.SimpleText(
      itemName,
      "VersusDefault",
      textX,
      textY,
      textColor,
      TEXT_ALIGN_LEFT,
      TEXT_ALIGN_CENTER
    )

    surface.SetFont("VersusButton")
    local amountText = "+" .. self.amount
    local amountW, amountH = surface.GetTextSize(amountText)

    local amountColor = ColorAlpha(self.amountColor, alpha)
    surface.SetTextColor(amountColor.r, amountColor.g, amountColor.b, amountColor.a)
    surface.SetTextPos(w - amountW - 20, (h - amountH) / 2)
    surface.DrawText(amountText)
  end

  vgui.Register("versus_ItemNotification", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(NOTIFICATION_WIDTH, ScrH())
    self:SetPos(ScrW() - NOTIFICATION_WIDTH - 20, 20)

    self.notifications = {}
    self.itemTracker = {} -- Tracks recent items by itemID
    self.maxNotifications = 10
  end

  function PANEL:ShowGainedItem(item)
    if not item or not item.itemID then return end

    local currentTime = CurTime()

    -- Check if this item was shown recently
    local recentNotif = self.itemTracker[item.itemID]
    if recentNotif and (currentTime - recentNotif.lastTime) < ITEM_MERGE_WINDOW_SECONDS then
      -- Increment amount on existing notification
      local notif = recentNotif.notification
      if IsValid(notif) then
        notif:SetAmount(notif:GetAmount() + 1)
        recentNotif.lastTime = currentTime
        return
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
    local notif = vgui.Create("versus_ItemNotification", self)
    notif:SetItem(item)
    notif:SetAmount(1)

    local notifData = {
      panel = notif,
      spawnTime = currentTime,
      fadeOutStart = nil,
      targetY = 0
    }

    table.insert(self.notifications, notifData)

    -- Track this item
    self.itemTracker[item.itemID] = {
      notification = notif,
      lastTime = currentTime
    }

    -- Update layout
    self:UpdateLayout()

    -- Set initial position (slide in from right, at correct Y)
    notif:SetPos(SLIDE_DISTANCE, notifData.targetY)
    notif:SetSlideProgress(0)
    notif:SetAlpha(0)
  end

  function PANEL:UpdateLayout()
    local yOffset = 0

    for i, data in ipairs(self.notifications) do
      if IsValid(data.panel) then
        data.targetY = yOffset
        yOffset = yOffset + NOTIFICATION_HEIGHT + NOTIFICATION_SPACING
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

      -- Handle automatic fade out after lifetime
      if lifetime > NOTIFICATION_LIFETIME and not data.fadeOutStart then
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

      -- Clear from item tracker
      if IsValid(data.panel) and data.panel:GetItem() then
        local itemID = data.panel:GetItem().itemID
        if self.itemTracker[itemID] and self.itemTracker[itemID].notification == data.panel then
          self.itemTracker[itemID] = nil
        end
      end

      table.remove(self.notifications, idx)
    end

    -- Update layout if notifications changed
    if #toRemove > 0 then
      self:UpdateLayout()
    end

    -- Clean up old item tracker entries
    for itemID, data in pairs(self.itemTracker) do
      if not IsValid(data.notification) or (currentTime - data.lastTime) > 2 then
        self.itemTracker[itemID] = nil
      end
    end
  end

  function PANEL:PerformLayout(w, h)
    -- Keep position at top-right
    self:SetPos(ScrW() - NOTIFICATION_WIDTH - GAMEMODE.SPACING, GAMEMODE.SPACING)
  end

  vgui.Register("versus_ItemNotificationStack", PANEL, "EditablePanel")
end

concommand.Add("versus_test_item_notification", function()
  local testItems = {}

  table.insert(testItems, versus.item.find("ammo_pistol"))
  table.insert(testItems, versus.item.find("health_vial"))
  table.insert(testItems, versus.item.find("health_vial"))
  table.insert(testItems, versus.item.find("ammo_shotgun"))

  -- Simulate receiving items
  timer.Create("VersusTestItemNotifications", 0.1, 10, function()
    local randomItem = testItems[math.random(1, #testItems)]
    UNIT.itemGainedStackPanel:ShowGainedItem(randomItem)
  end)
end)
