local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(
      math.max(ScrW() * 0.9, 800),
      ScrH()
    )

    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)

    self.bgAlpha = 0
    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)

    -- Create the close button.
    self.close = vgui.Create("versus_Button", self)
    self.close:SetText("Close")
    self.close.DoClick = function(closeButton)
      self:Close()
    end

    self.sideBySide = vgui.Create("versus_Inventory_SideBySide", self)
    self.sideBySide:Dock(FILL)
  end

  function PANEL:SetNamedInventory(chestName)
    self.sideBySide:SetNamedInventory(chestName)
  end

  function PANEL:Close()
    if self.closing then return end

    self.closing = true
    self.closeStart = CurTime()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    -- Fade in animation
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
      -- Fade out animation
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

    -- Dark overlay background
    surface.SetDrawColor(0, 0, 0, self.bgAlpha)
    surface.DrawRect(0, 0, w, h)
  end

  function PANEL:PerformLayout(w, h)
    self:Center()

    -- Set the size and position of the close button.
    self.close:SizeToContents()
    self.close:SetPos(w - self.close:GetWide() - 32, 32)

    self:DockPadding(GAMEMODE.SPACING, GAMEMODE.SPACING + self.close:GetTall(), GAMEMODE.SPACING, GAMEMODE.SPACING)
  end

  vgui.Register("versus_NamedInventory", PANEL, "EditablePanel")
end
