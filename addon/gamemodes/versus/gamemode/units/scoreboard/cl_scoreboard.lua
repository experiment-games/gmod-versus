local UNIT = UNIT

surface.CreateFont("ScoreboardHeader", {
  font = "coolvetica",
  size = 32,
  weight = 500,
  antialias = true,
  additive = false,
})
surface.CreateFont("ScoreboardSubtitle", {
  font = "coolvetica",
  size = 22,
  weight = 500,
  antialias = true,
  additive = false,
})

local texGradient = surface.GetTextureID("gui/center_gradient")
local matLogo = Material("versus/versus_logo.png")

local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  SCOREBOARD = self

  self.Hostname = vgui.Create("DLabel", self)
  self.Hostname:SetText(GetHostName())

  self.Description = vgui.Create("DLabel", self)
  self.Description:SetText(GAMEMODE.Name .. " - " .. GAMEMODE.Author)

  self.PlayerFrame = vgui.Create("PlayerFrame", self)

  self.PlayerRows = {}

  self:UpdateScoreboard()

  self.lblPing = vgui.Create("DLabel", self)
  self.lblPing:SetText("Ping")

  self.lblKills = vgui.Create("DLabel", self)
  self.lblKills:SetText("Kills")

  self.lblDeaths = vgui.Create("DLabel", self)
  self.lblDeaths:SetText("Deaths")
end

function PANEL:AddPlayerRow(ply)
  local button = vgui.Create("ScorePlayerRow", self.PlayerFrame:GetCanvas())
  button:SetPlayer(ply)
  self.PlayerRows[ply] = button
end

function PANEL:GetPlayerRow(ply)
  return self.PlayerRows[ply]
end

function PANEL:Paint()
  GAMEMODE:DrawRoundedBox(0, 0, self:GetWide(), self:GetTall(), Color(170, 170, 170, 255))
  surface.SetTexture(texGradient)
  surface.SetDrawColor(255, 255, 255, 50)
  surface.DrawTexturedRect(0, 0, self:GetWide(), self:GetTall())

  -- White Inner Box
  GAMEMODE:DrawRoundedBox(4, self.Description.y - 4, self:GetWide() - 8, self:GetTall() - self.Description.y - 4,
    Color(230, 230, 230, 200))
  surface.SetTexture(texGradient)
  surface.SetDrawColor(255, 255, 255, 50)
  surface.DrawTexturedRect(4, self.Description.y - 4, self:GetWide() - 8, self:GetTall() - self.Description.y - 4)

  -- Sub Header
  GAMEMODE:DrawRoundedBox(5, self.Description.y - 3, self:GetWide() - 10, self.Description:GetTall() + 5,
    Color(150, 200, 50, 200))
  surface.SetTexture(texGradient)
  surface.SetDrawColor(255, 255, 255, 50)
  surface.DrawTexturedRect(4, self.Description.y - 4, self:GetWide() - 8, self.Description:GetTall() + 8)

  -- Logo
  surface.SetMaterial(matLogo)
  surface.SetDrawColor(255, 255, 255, 255)
  surface.DrawTexturedRect(0, 0, 100, 100)

  --GAMEMODE:DrawRoundedBox(10, self.Description.y + self.Description:GetTall() + 6, self:GetWide() - 20, 12, Color(0, 0, 0, 50))
end

function PANEL:PerformLayout()
  self.Hostname:SizeToContents()
  self.Hostname:SetPos(110, 16)

  self.Description:SizeToContents()
  self.Description:SetPos(110, 64)

  local iTall = self.PlayerFrame:GetCanvas():GetTall() + self.Description.y + self.Description:GetTall() + 30
  iTall = math.Clamp(iTall, 100, ScrH() * 0.9)
  local iWide = math.Clamp(ScrW() * 0.8, 700, ScrW() * 0.6)

  self:SetSize(iWide, iTall)
  self:SetPos((ScrW() - self:GetWide()) / 2, (ScrH() - self:GetTall()) / 4)

  self.PlayerFrame:SetPos(5, self.Description.y + self.Description:GetTall() + 20)
  self.PlayerFrame:SetSize(self:GetWide() - 10, self:GetTall() - self.PlayerFrame.y - 10)

  local y = 0

  local PlayerSorted = {}

  for _, playerRow in pairs(self.PlayerRows) do
    table.insert(PlayerSorted, playerRow)
  end

  table.sort(PlayerSorted, function(a, b) return a:HigherOrLower(b) end)

  for _, playerRow in ipairs(PlayerSorted) do
    playerRow:SetPos(0, y)
    playerRow:SetSize(self.PlayerFrame:GetWide(), playerRow:GetTall())

    self.PlayerFrame:GetCanvas():SetSize(self.PlayerFrame:GetCanvas():GetWide(), y + playerRow:GetTall())

    y = y + playerRow:GetTall() + 1
  end

  self.Hostname:SetText(GetHostName())

  self.lblPing:SizeToContents()
  self.lblKills:SizeToContents()
  self.lblDeaths:SizeToContents()

  self.lblPing:SetPos(self:GetWide() - 50 - self.lblPing:GetWide() / 2, self.PlayerFrame.y - self.lblPing:GetTall() - 3)
  self.lblDeaths:SetPos(self:GetWide() - 50 * 2 - self.lblDeaths:GetWide() / 2,
    self.PlayerFrame.y - self.lblPing:GetTall() - 3)
  self.lblKills:SetPos(self:GetWide() - 50 * 3 - self.lblKills:GetWide() / 2,
    self.PlayerFrame.y - self.lblPing:GetTall() - 3)

  --self.lblKills:SetFont("DefaultSmall")
  --self.lblDeaths:SetFont("DefaultSmall")
end

function PANEL:ApplySchemeSettings()
  self.Hostname:SetFont("ScoreboardHeader")
  self.Description:SetFont("ScoreboardSubtitle")

  self.Hostname:SetTextColor(color_black_alpha)
  self.Description:SetTextColor(color_white)

  self.lblPing:SetFont("DefaultSmall")
  self.lblKills:SetFont("DefaultSmall")
  self.lblDeaths:SetFont("DefaultSmall")

  self.lblPing:SetTextColor(Color(0, 0, 0, 100))
  self.lblKills:SetTextColor(Color(0, 0, 0, 100))
  self.lblDeaths:SetTextColor(Color(0, 0, 0, 100))
end

function PANEL:UpdateScoreboard(force)
  if (not force and (not IsValid(self) or not self:IsVisible())) then return end

  for index, playerRow in pairs(self.PlayerRows) do
    if (not index:IsValid()) then
      playerRow:Remove()
      self.PlayerRows[index] = nil
    end
  end

  local playerList = player.GetAll()

  for id, pl in pairs(playerList) do
    if (not self:GetPlayerRow(pl)) then
      self:AddPlayerRow(pl)
    end
  end

  -- Always invalidate the layout so the order gets updated
  self:InvalidateLayout()
end

function PANEL:Think()
  if (self._NextUpdatePlayerList and self._NextUpdatePlayerList > CurTime()) then
    return
  end

  self._NextUpdatePlayerList = CurTime() + 1

  self:UpdateScoreboard()
end

vgui.Register("versus_Scoreboard", PANEL, "Panel")
