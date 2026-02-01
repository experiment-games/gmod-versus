local UNIT = UNIT
local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)


  self:SetCursor("hand")
end

function PANEL:DoClick(x, y)
  if (not self:GetParent().Player or LocalPlayer() == self:GetParent().Player) then return end

  self:DoCommand(self:GetParent().Player)
  timer.Simple(0.1, function()
    SCOREBOARD:UpdateScoreboard()
  end)
end

function PANEL:Paint()
  local bgColor = Color(0, 0, 0, 10)

  if (self.Selected) then
    bgColor = Color(0, 200, 255, 255)
  elseif (self.Armed) then
    bgColor = Color(255, 255, 0, 255)
  end

  GAMEMODE:DrawRoundedBox(0, 0, self:GetWide(), self:GetTall(), bgColor)

  draw.SimpleText(self.Text, "DefaultSmall", self:GetWide() / 2, self:GetTall() / 2, Color(0, 0, 0, 150),
    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

  return true
end

vgui.Register("SpawnMenuAdminButton", PANEL, "Button")



--[[   PlayerKickButton ]] --

PANEL = {}
PANEL.Text = "Kick"


function PANEL:DoCommand(ply)
  RunConsoleCommand("kickid2", ply:UserID())
end

vgui.Register("PlayerKickButton", PANEL, "SpawnMenuAdminButton")



--[[   PlayerPermBanButton ]] --

PANEL = {}
PANEL.Text = "PermBan"


function PANEL:DoCommand(ply)
  RunConsoleCommand("banid2", "0", ply:UserID())
  RunConsoleCommand("kickid2", ply:UserID(), "Permabanned")
end

vgui.Register("PlayerPermBanButton", PANEL, "SpawnMenuAdminButton")



--[[   PlayerPermBanButton ]] --

PANEL = {}
PANEL.Text = "1hr Ban"


function PANEL:DoCommand(ply)
  RunConsoleCommand("banid2", "60", ply:UserID())
  RunConsoleCommand("kickid2", ply:UserID(), "Banned for 1 hour")
end

vgui.Register("PlayerBanButton", PANEL, "SpawnMenuAdminButton")
