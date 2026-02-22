local PLUGIN = PLUGIN

local MONEY_ANIMATION_DURATION = 0.5
local MONEY_LABEL_TEXT = "CASH"

do
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(64)
    self:SetMouseInputEnabled(false)

    self.money = 0
    self.displayMoney = 0
    self.animationStartMoney = 0
    self.animationStartTime = 0
    self.animating = false

    self.bgColor = Color(25, 35, 50, 200)
    self.accentColor = Color(80, 140, 220, 255)
    self.textColor = Color(200, 220, 240, 255)
    self.moneyColor = Color(120, 200, 120, 255)
  end

  function PANEL:SetMoney(amount)
    if self.money ~= (amount or 0) then
      self.animationStartMoney = self.displayMoney
      self.animationStartTime = CurTime()
      self.animating = true
    end
    self.money = amount or 0
  end

  function PANEL:GetMoney()
    return self.money
  end

  function PANEL:Think()
    -- Fixed duration animation
    if self.animating then
      local elapsed = CurTime() - self.animationStartTime
      local progress = math.min(elapsed / MONEY_ANIMATION_DURATION, 1)

      -- Ease out cubic for smooth deceleration
      local easedProgress = 1 - math.pow(1 - progress, 3)

      self.displayMoney = self.animationStartMoney + (self.money - self.animationStartMoney) * easedProgress

      if progress >= 1 then
        self.displayMoney = self.money
        self.animating = false
      end
    end

    -- Auto-update from player's current money
    local currentMoney = versus.finance.getMoney()
    if currentMoney ~= self.money then
      self:SetMoney(currentMoney)
    end
  end

  function PANEL:SizeToContents()
    surface.SetFont("VersusButton")
    local labelW, labelH = surface.GetTextSize(MONEY_LABEL_TEXT)

    local moneyText = versus.util.formatMoney(math.floor(self.displayMoney))
    local moneyW, moneyH = surface.GetTextSize(moneyText)

    -- Width is the larger of the two text widths plus padding
    local maxTextW = math.max(labelW, moneyW)
    self:SetWide(maxTextW + 100)
  end

  function PANEL:Paint(w, h)
    draw.RoundedBox(h, 0, 0, w, h, self.bgColor)

    -- Draw label text
    surface.SetFont("VersusButton")
    local labelW, labelH = surface.GetTextSize(MONEY_LABEL_TEXT)
    local labelY = (h - labelH) / 2 - 8

    surface.SetTextColor(self.textColor)
    surface.SetTextPos((w - labelW) / 2, labelY)
    surface.DrawText(MONEY_LABEL_TEXT)

    -- Draw money amount
    local moneyText = versus.util.formatMoney(math.floor(self.displayMoney))
    local moneyW, moneyH = surface.GetTextSize(moneyText)
    local moneyY = (h - moneyH) / 2 + 8

    surface.SetTextColor(self.moneyColor)
    surface.SetTextPos((w - moneyW) / 2, moneyY)
    surface.DrawText(moneyText)
  end

  vgui.Register("versus_MoneyDisplay", PANEL, "EditablePanel")
end
