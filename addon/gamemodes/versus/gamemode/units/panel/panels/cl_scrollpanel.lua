local UNIT = UNIT
local PANEL = {}

function PANEL:Init()
  local vBar = self:GetVBar()

  vBar:SetWide(8)
  vBar.Paint = function(slf, w, h)
    draw.RoundedBox(0, 0, 0, w, h, Color(20, 28, 40, 100))
  end
  vBar.btnUp.Paint = function() end
  vBar.btnDown.Paint = function() end
  vBar.btnGrip.Paint = function(slf, w, h)
    draw.RoundedBox(0, 2, 0, w - 4, h, Color(80, 140, 220, 150))
  end
end

vgui.Register("versus_ScrollPanel", PANEL, "DScrollPanel")
