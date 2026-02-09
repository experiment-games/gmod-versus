local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self.bgColor = Color(45, 85, 135, 255) -- Saturated blue
    self.textColor = Color(220, 230, 240, 255)
    self.subtextColor = Color(141, 153, 174, 255)
    self.angleWidth = 40
    self.hovered = false
    self.imageMaterial = nil
    self.imageAspectRatio = 1

    self:SetText("")
    self:NoClipping(true)

    -- Title label
    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeading2")
    self.titleLabel:SetTextColor(self.textColor)
    self.titleLabel:SetText("Button Title")
    self.titleLabel:Dock(TOP)
    self.titleLabel:SizeToContents()
    self.titleLabel:SetMouseInputEnabled(false)

    -- Subtext label
    self.subtextLabel = vgui.Create("DLabel", self)
    self.subtextLabel:SetFont("VersusDefault")
    self.subtextLabel:SetTextColor(self.subtextColor)
    self.subtextLabel:SetText("Short description text")
    self.subtextLabel:Dock(TOP)
    self.subtextLabel:SizeToContents()
    self.subtextLabel:SetMouseInputEnabled(false)
    self.subtextLabel:SetWrap(true)
    self.subtextLabel:SetAutoStretchVertical(true)
  end

  function PANEL:SetTitle(text)
    self.titleLabel:SetText(text)
    self.titleLabel:SizeToContents()
  end

  function PANEL:SetSubtext(text)
    self.subtextLabel:SetText(text)
    self.subtextLabel:SizeToContents()
  end

  function PANEL:SetImage(materialPath)
    self.imageMaterial = Material(materialPath, "smooth")

    -- Calculate aspect ratio if material is valid
    if self.imageMaterial and not self.imageMaterial:IsError() then
      local width = self.imageMaterial:Width()
      local height = self.imageMaterial:Height()
      if height > 0 then
        self.imageAspectRatio = width / height
      end
    end
  end

  function PANEL:SetBackgroundColor(color)
    self.bgColor = color
  end

  function PANEL:SetTextColor(color)
    self.textColor = color
    self.titleLabel:SetTextColor(color)
  end

  function PANEL:SetSubtextColor(color)
    self.subtextColor = color
    self.subtextLabel:SetTextColor(color)
  end

  function PANEL:Paint(w, h)
    local alphaModifier = self.hovered and 1 or 0.15

    -- Draw main rectangular background
    local paraOffset = 40
    local poly = {
      { x = 0,                                y = 0 },
      { x = w - paraOffset - self.angleWidth, y = 0 },
      { x = w - paraOffset,                   y = h },
      { x = 0,                                y = h }
    }

    draw.NoTexture()
    surface.SetDrawColor(ColorAlpha(self.bgColor, self.bgColor.a * alphaModifier))
    surface.DrawPoly(poly)

    -- Draw parallelogram on the right
    local paraWidth = paraOffset
    local paraSkew = 20

    local para = {
      { x = w - paraWidth - paraSkew, y = 0 },
      { x = w - paraWidth,            y = 0 },
      { x = w,                        y = h },
      { x = w - paraWidth + paraSkew, y = h }
    }

    surface.DrawPoly(para)

    -- Draw image overlay if set
    if self.imageMaterial and not self.imageMaterial:IsError() then
      -- Calculate image dimensions maintaining aspect ratio
      -- Let the image expand beyond the button bounds
      local imageHeight = h * 1.2 -- 20% larger than button height
      local imageWidth = imageHeight * self.imageAspectRatio

      local imageX = 20
      local imageY = (h - imageHeight) * .5

      surface.SetDrawColor(255, 255, 255, 255)
      surface.SetMaterial(self.imageMaterial)
      surface.DrawTexturedRect(imageX, imageY, imageWidth, imageHeight)
    end
  end

  function PANEL:PerformLayout(w, h)
    local imageHeight = h * 1.2
    local imageX = 20
    local imageWidth = imageHeight * self.imageAspectRatio

    self.titleLabel:DockMargin(imageX + imageWidth + imageX, 20, 100, 5)
    self.subtextLabel:DockMargin(imageX + imageWidth + imageX, 0, 100, 20)
  end

  function PANEL:OnCursorEntered()
    self.hovered = true
  end

  function PANEL:OnCursorExited()
    self.hovered = false
  end

  function PANEL:DoClick()
    self:DoClick()
  end

  function PANEL:IsHovered()
    return self.hovered
  end

  function PANEL:DoClick()
    -- Override this in implementation
  end

  vgui.Register("versus_ButtonAdvert", PANEL, "DButton")
end
