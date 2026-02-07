local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetTall(80)
    self.text = "SELECT YOUR CONTRACT"
    self.bgColor = Color(255, 204, 0, 255)  -- Yellow
    self.textColor = Color(20, 20, 20, 255) -- Dark text
    self.angleWidth = 20                    -- Width of the angled left side
  end

  function PANEL:SetText(text)
    self.text = text
  end

  function PANEL:GetText()
    return self.text
  end

  function PANEL:Paint(w, h)
    local paraOffset = 60

    -- Draw angled yellow background
    local poly = {
      { x = paraOffset,                   y = 0 },
      { x = w,                            y = 0 },
      { x = w,                            y = h },
      { x = paraOffset + self.angleWidth, y = h }
    }

    draw.NoTexture()
    surface.SetDrawColor(self.bgColor)
    surface.DrawPoly(poly)

    -- First (larger) parallelogram to left of the main background
    local para1Offset = 5
    local para1 = {
      { x = self.angleWidth + para1Offset,       y = 0 },
      { x = paraOffset * .7,                     y = 0 },
      { x = paraOffset * .7 + self.angleWidth,   y = h },
      { x = (self.angleWidth * 2) + para1Offset, y = h },
    }

    surface.DrawPoly(para1)

    -- Second (smaller) parallelogram, creating a layered effect
    local para2 = {
      { x = 0,                                  y = 0 },
      { x = paraOffset * .15,                   y = 0 },
      { x = paraOffset * .15 + self.angleWidth, y = h },
      { x = self.angleWidth,                    y = h },
    }
    surface.DrawPoly(para2)

    -- Draw text
    draw.SimpleText(
      self.text,
      "VersusHeading1",
      w * .5,
      h * .5,
      self.textColor,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end

  vgui.Register("versus_ContractHeader", PANEL, "EditablePanel")
end
