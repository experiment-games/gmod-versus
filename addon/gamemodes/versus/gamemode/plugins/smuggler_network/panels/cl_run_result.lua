local PLUGIN = PLUGIN

local color_bg = Color(15, 20, 30, 240)
local color_panel = Color(20, 28, 40, 255)
local color_text = Color(220, 230, 240, 255)
local color_dim = Color(140, 155, 170, 255)

local outcomeConfig = {
  success = {
    title = "Run Successful",
    titleColor = Color(70, 190, 90),
    flavour = "Your runner made it through clean. The goods are safe and the money is yours.",
  },
  partial = {
    title = "Partial Success",
    titleColor = Color(210, 180, 40),
    flavour = "Things got messy out there. Your runner salvaged what they could.",
  },
  burned = {
    title = "Run Burned",
    titleColor = Color(220, 60, 60),
    flavour = "The runner walked into a trap. Everything was lost — and the heat will be felt for a while.",
  },
}

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(math.min(ScrW() * 0.45, 640), ScrH() * 0.55)
    self:Center()
    self:ParentToHUD()
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)

    self.animStart = CurTime()
    self.animDuration = 0.3
    self.bgAlpha = 0

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    -- Outcome title
    self.outcomeLabel = vgui.Create("DLabel", self)
    self.outcomeLabel:SetFont("VersusHeading1")
    self.outcomeLabel:SetTextColor(color_text)
    self.outcomeLabel:SetText("")
    self.outcomeLabel:SetContentAlignment(5)
    self.outcomeLabel:SetAutoStretchVertical(true)
    self.outcomeLabel:Dock(TOP)
    self.outcomeLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    -- Flavour text
    self.flavourLabel = vgui.Create("DLabel", self)
    self.flavourLabel:SetFont("VersusDefault")
    self.flavourLabel:SetTextColor(color_dim)
    self.flavourLabel:SetText("")
    self.flavourLabel:SetWrap(true)
    self.flavourLabel:SetAutoStretchVertical(true)
    self.flavourLabel:Dock(TOP)
    self.flavourLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING * 0.5)

    -- Run details
    self.detailsLabel = vgui.Create("DLabel", self)
    self.detailsLabel:SetFont("VersusDefault")
    self.detailsLabel:SetTextColor(color_text)
    self.detailsLabel:SetText("")
    self.detailsLabel:SetWrap(true)
    self.detailsLabel:SetAutoStretchVertical(true)
    self.detailsLabel:Dock(TOP)
    self.detailsLabel:DockMargin(0, 0, 0, GAMEMODE.SPACING)

    -- Continue button
    local continueBtn = vgui.Create("versus_Button", self)
    continueBtn:SetText("CONTINUE")
    continueBtn:Dock(BOTTOM)
    continueBtn:SetType("primary")
    continueBtn.DoClick = function()
      self:Close()
    end
  end

  function PANEL:SetResult(outcome, routeName, runnerName, cashReward)
    local config = outcomeConfig[outcome] or outcomeConfig.burned

    self.outcomeLabel:SetText(config.title)
    self.outcomeLabel:SetTextColor(config.titleColor)
    self.flavourLabel:SetText(config.flavour)

    local detailsText = "Route: " .. routeName .. "\nRunner: " .. runnerName

    if(cashReward > 0)then
      detailsText = detailsText .. "\nEarned: " .. versus.util.formatMoney(cashReward)
    else
      detailsText = detailsText .. "\nEarned: Nothing"
    end

    self.detailsLabel:SetText(detailsText)
  end

  function PANEL:Close()
    if(self.closing)then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    if(not self.closing)then
      self.bgAlpha = 200 * math.min(elapsed / self.animDuration, 1)
    else
      local closeElapsed = CurTime() - self.closeStart

      if(closeElapsed < 0.25)then
        local progress = 1 - (closeElapsed / 0.25)
        self.bgAlpha = 200 * progress
        self:SetAlpha(255 * progress)
      else
        self:Remove()
      end
    end
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)
    surface.SetDrawColor(ColorAlpha(color_bg, self.bgAlpha))
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(color_panel)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self:Center()
  end

  vgui.Register("versus_RunResult", PANEL, "EditablePanel")
end
