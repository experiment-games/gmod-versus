local UNIT = UNIT
local PANEL = {}

function PANEL:Init()
  versus.panel.initPanelSkin(self)

  self.InfoLabels = {}
  self.InfoLabels[1] = {}
  self.InfoLabels[2] = {}

  self.btnKick = vgui.Create("PlayerKickButton", self)
  self.btnBan = vgui.Create("PlayerBanButton", self)
  self.btnPBan = vgui.Create("PlayerPermBanButton", self)
end

function PANEL:SetInfo(column, k, v)
  if (not v or v == "") then v = "N/A" end

  if (not self.InfoLabels[column][k]) then
    self.InfoLabels[column][k] = {}
    self.InfoLabels[column][k].Key = vgui.Create("DLabel", self)
    self.InfoLabels[column][k].Key:SetTextColor(color_black_alpha)
    self.InfoLabels[column][k].Key:SetText(k)
    self.InfoLabels[column][k].Value = vgui.Create("DLabel", self)
    self.InfoLabels[column][k].Value:SetTextColor(color_black_alpha)
    self:InvalidateLayout()
  end

  self.InfoLabels[column][k].Value:SetText(v)

  return true
end

function PANEL:SetPlayer(ply)
  self.Player = ply
  self:UpdatePlayerData()
end

function PANEL:UpdatePlayerData()
  if (not self.Player) then return end
  if (not self.Player:IsValid()) then return end

  local steamID = self.Player:getSteamID64()

  self:SetInfo(1, "Versus ID:", self.Player:getVersusID())
  self:SetInfo(1, "SteamID:", steamID)

  hook.Run("ScoreboardSetPlayerInfo", self, self.Player)
  -- TODO: Add a plugin that does uses AccessorFunc to do something like:
  -- self:SetInfo(1, "Discord:", self.Player:GetDiscord())

  self:SetInfo(2, "Props:",
    self.Player:GetCount("props") + self.Player:GetCount("ragdolls") + self.Player:GetCount("effects"))
  --self:SetInfo(2, "HoverBalls:", self.Player:GetCount("hoverballs"))
  --self:SetInfo(2, "Thrusters:", self.Player:GetCount("thrusters"))
  --self:SetInfo(2, "Balloons:", self.Player:GetCount("balloons"))
  self:SetInfo(2, "Buttons:", self.Player:GetCount("buttons"))
  --self:SetInfo(2, "Dynamite:", self.Player:GetCount("dynamite"))
  self:SetInfo(2, "SENTs:", self.Player:GetCount("vehicles"))

  self:InvalidateLayout()
end

function PANEL:ApplySchemeSettings()
  for _, columns in pairs(self.InfoLabels) do
    for __, column in pairs(columns) do
      column.Key:SetTextColor(Color(0, 0, 0, 100))
      column.Value:SetTextColor(Color(0, 70, 0, 200))
    end
  end
end

function PANEL:Think()
  if (self.PlayerUpdate and self.PlayerUpdate > CurTime()) then return end
  self.PlayerUpdate = CurTime() + 0.25

  self:UpdatePlayerData()
end

function PANEL:GetDesiredHeight()
  local tallestColumnY = 0

  for _, columns in pairs(self.InfoLabels) do
    local y = 0

    for __, column in pairs(columns) do
      column.Key:SizeToContentsY()
      y = y + column.Key:GetTall() + 2

      if (y > tallestColumnY) then
        tallestColumnY = y
      end
    end
  end

  return tallestColumnY
end

function PANEL:PerformLayout()
  local x = 5

  for _, columns in pairs(self.InfoLabels) do
    local y = 0
    local RightMost = 0

    for __, column in pairs(columns) do
      column.Key:SetPos(x, y)
      column.Key:SizeToContents()

      column.Value:SetPos(x + 70, y)
      column.Value:SizeToContents()

      y = y + column.Key:GetTall() + 2

      RightMost = math.max(RightMost, column.Value.x + column.Value:GetWide())
    end

    --x = RightMost + 10
    x = x + 300
  end

  if (not self.Player or
        self.Player == LocalPlayer() or
        not LocalPlayer():IsAdmin()) then
    self.btnKick:SetVisible(false)
    self.btnBan:SetVisible(false)
    self.btnPBan:SetVisible(false)
  else
    self.btnKick:SetVisible(true)
    self.btnBan:SetVisible(true)
    self.btnPBan:SetVisible(true)

    self.btnKick:SetPos(self:GetWide() - 52 * 3, 80)
    self.btnKick:SetSize(48, 20)

    self.btnBan:SetPos(self:GetWide() - 52 * 2, 80)
    self.btnBan:SetSize(48, 20)

    self.btnPBan:SetPos(self:GetWide() - 52 * 1, 80)
    self.btnPBan:SetSize(48, 20)
  end
end

function PANEL:Paint()
  return true
end

vgui.Register("ScorePlayerInfoCard", PANEL, "Panel")
