local UNIT = UNIT

surface.CreateFont("ScoreboardPlayerName", {
  font = "coolvetica",
  size = 19,
  weight = 500,
  antialias = true,
  additive = false,
})
surface.CreateFont("ScoreboardPlayerNameBig", {
  font = "coolvetica",
  size = 22,
  weight = 500,
  antialias = true,
  additive = false,
})

local texGradient = surface.GetTextureID("gui/center_gradient")
local BASE_HEIGHT = 36
local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)


  self.Size = BASE_HEIGHT
  self:OpenInfo(false)

  self.infoCard  = vgui.Create("ScorePlayerInfoCard", self)

  self.lblName   = vgui.Create("DLabel", self)
  self.lblFrags  = vgui.Create("DLabel", self)
  self.lblDeaths = vgui.Create("DLabel", self)
  self.lblPing   = vgui.Create("DLabel", self)

  -- If you don't do this it'll block your clicks
  self.lblName:SetMouseInputEnabled(false)
  self.lblFrags:SetMouseInputEnabled(false)
  self.lblDeaths:SetMouseInputEnabled(false)
  self.lblPing:SetMouseInputEnabled(false)

  self.imgAvatar = vgui.Create("AvatarImage", self)

  self:SetCursor("hand")
end

function PANEL:Paint()
  if (not IsValid(self.Player)) then return end

  local color = team.GetColor(self.Player:Team())

  if (self.Open or self.Size ~= self.TargetSize) then
    GAMEMODE:DrawRoundedBox(0, 16, self:GetWide(), self:GetTall() - 16, color)
    GAMEMODE:DrawRoundedBox(2, 16, self:GetWide() - 4, self:GetTall() - 16 - 2, Color(250, 250, 245, 255))

    surface.SetTexture(texGradient)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(2, 16, self:GetWide() - 4, self:GetTall() - 16 - 2)
  end

  GAMEMODE:DrawRoundedBox(0, 0, self:GetWide(), BASE_HEIGHT, color)

  surface.SetTexture(texGradient)
  surface.SetDrawColor(255, 255, 255, 50)
  surface.DrawTexturedRect(0, 0, self:GetWide(), BASE_HEIGHT)

  return true
end

function PANEL:SetPlayer(ply)
  self.Player = ply

  self.infoCard:SetPlayer(ply)
  self.imgAvatar:SetPlayer(ply)

  self:UpdatePlayerData()
end

function PANEL:UpdatePlayerData()
  if (not self.Player) then return end
  if (not self.Player:IsValid()) then return end


  self.lblName:SetText(self.Player:getCombinedName())
  self.lblName:SizeToContents()
  self.lblFrags:SetText(self.Player:Frags())
  self.lblDeaths:SetText(self.Player:Deaths())
  self.lblPing:SetText(self.Player:Ping())

  hook.Run("ScoreboardPlayerRowUpdate", self.Player, self)
end

function PANEL:ApplySchemeSettings()
  self.lblName:SetFont("ScoreboardPlayerNameBig")
  self.lblFrags:SetFont("ScoreboardPlayerName")
  self.lblDeaths:SetFont("ScoreboardPlayerName")
  self.lblPing:SetFont("ScoreboardPlayerName")

  self.lblName:SetTextColor(color_white)
  self.lblFrags:SetTextColor(color_white)
  self.lblDeaths:SetTextColor(color_white)
  self.lblPing:SetTextColor(color_white)
end

function PANEL:DoClick(x, y)
  if (self.Open) then
    surface.PlaySound("ui/buttonclickrelease.wav")
  else
    surface.PlaySound("ui/buttonclick.wav")
  end

  self:OpenInfo(not self.Open)
end

function PANEL:OpenInfo(bool)
  local baseHeight = BASE_HEIGHT

  if (bool) then
    self.TargetSize = BASE_HEIGHT + self.infoCard:GetDesiredHeight() + 10 -- (10 = 2 * 5 for padding top and bottom)
  else
    self.TargetSize = BASE_HEIGHT
  end

  self.Open = bool
end

function PANEL:Think()
  if (self.Size ~= self.TargetSize) then
    self.Size = math.Approach(self.Size, self.TargetSize, (math.abs(self.Size - self.TargetSize) + 1) * 10 * FrameTime())
    self:PerformLayout()
    SCOREBOARD:InvalidateLayout()
    --	self:GetParent():InvalidateLayout()
  end

  if (not self.PlayerUpdate or self.PlayerUpdate < CurTime()) then
    self.PlayerUpdate = CurTime() + 0.5
    self:UpdatePlayerData()
  end
end

function PANEL:PerformLayout()
  self.imgAvatar:SetPos(2, 2)
  self.imgAvatar:SetSize(32, 32)

  self:SetSize(self:GetWide(), self.Size)

  self.lblName:SizeToContents()
  self.lblName:SetPos(24, 2)
  self.lblName:MoveRightOf(self.imgAvatar, 8)

  local COLUMN_SIZE = 50

  self.lblPing:SetPos(self:GetWide() - COLUMN_SIZE * 1, 0)
  self.lblDeaths:SetPos(self:GetWide() - COLUMN_SIZE * 2, 0)
  self.lblFrags:SetPos(self:GetWide() - COLUMN_SIZE * 3, 0)

  if (self.Open or self.Size ~= self.TargetSize) then
    self.infoCard:SetVisible(true)
    self.infoCard:SetPos(4, self.imgAvatar:GetTall() + 10)
    self.infoCard:SetSize(self:GetWide() - 8, self:GetTall() - self.lblName:GetTall() - 10)
  else
    self.infoCard:SetVisible(false)
  end
end

function PANEL:HigherOrLower(row)
  return self.Player:Team() < row.Player:Team()
end

vgui.Register("ScorePlayerRow", PANEL, "Button")
