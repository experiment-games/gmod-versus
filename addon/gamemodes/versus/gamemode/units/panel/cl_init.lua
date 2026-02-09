local UNIT = UNIT

function UNIT.query(strText, strTitle, ...)
  local panel = vgui.Create("versus_Query")
  panel:SetText(strText)
  panel:SetTitle(strTitle)
  panel:AddButtons(...)

  return panel
end

function UNIT.stringRequest(strTitle, strText, strDefaultText, fnEnter, fnCancel, strButtonText, strButtonCancelText)
  local panel = vgui.Create("versus_StringRequest")
  panel:SetTitle(strTitle)
  panel:SetText(strText)
  panel:SetDefaultText(strDefaultText)
  panel:SetButtonText(strButtonText or "OK")
  panel:SetButtonCancelText(strButtonCancelText or "CANCEL")
  panel:SetButtonCallback(fnEnter)
  panel:SetButtonCancelCallback(fnCancel)

  return panel
end
