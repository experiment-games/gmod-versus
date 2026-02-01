local UNIT = UNIT

-- Sets the scoreboard to visible
function UNIT.hook:ScoreboardShow()
  if (not IsValid(versus.scoreboardPanel)) then
    versus.scoreboardPanel = vgui.Create("versus_Scoreboard")
  end

  if (IsValid(versus.scoreboardPanel)) then
    versus.scoreboardPanel:Show()
    versus.scoreboardPanel:MakePopup()
    versus.scoreboardPanel:SetKeyboardInputEnabled(false)
  end
end

-- Hides the scoreboard
function UNIT.hook:ScoreboardHide()
  if (IsValid(versus.scoreboardPanel)) then
    versus.scoreboardPanel:Hide()
  end
end
