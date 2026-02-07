local UNIT = UNIT

do
  local PANEL = {}

  function PANEL:Init()
    self.text = ""
    self.bgColor = Color(100, 200, 100, 255)
    self.textColor = self:GetDarkVariant(self.bgColor)
    self.padding = 8
  end

  function PANEL:SetText(text)
    self.text = text:upper()
    self:SizeToContents()
  end

  function PANEL:GetText()
    return self.text
  end

  function PANEL:SetColor(color)
    self.bgColor = color
    self.textColor = self:GetDarkVariant(self.bgColor)
  end

  function PANEL:GetColor()
    return self.bgColor
  end

  -- From HSL, darkens L, so it works well for generating a text color that contrasts with the background
  function PANEL:GetDarkVariant(color)
    local h, s, l = ColorToHSV(color)
    l = math.max(0, l - 40)
    return HSVToColor(h, s, l)
  end

  function PANEL:SizeToContents()
    surface.SetFont("VersusSmall")
    local textW, textH = surface.GetTextSize(self.text)
    self:SetSize(textW + self.padding * 2, textH + self.padding)
  end

  function PANEL:Paint(w, h)
    -- Draw rounded rectangle background
    draw.RoundedBox(4, 0, 0, w, h, self.bgColor)

    -- Draw text
    draw.SimpleText(
      self.text,
      "VersusSmall",
      w / 2,
      h / 2,
      self.textColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end

  vgui.Register("versus_Tag", PANEL, "EditablePanel")
end
