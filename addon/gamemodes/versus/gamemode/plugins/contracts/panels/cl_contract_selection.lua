local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)
    self:ParentToHUD()

    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = Color(80, 140, 220, 255)
    self.disabledColor = Color(141, 153, 174)
    self.textColor = Color(255, 204, 0, 255) -- Yellow

    self.contractsContainer = vgui.Create("EditablePanel", self)
    self.contractsContainer:Dock(RIGHT)

    self.contractsPanel = vgui.Create("versus_ContractsList", self.contractsContainer)
    self.contractsPanel:Dock(FILL)
    self.contractsPanel:DockMargin(0, GAMEMODE.SPACING, 0, GAMEMODE.SPACING)

    self.mapContainer = vgui.Create("EditablePanel", self)
    self.mapContainer:Dock(FILL)
    self.mapContainer:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    local mapMaterial, mapFileName = self:FindBestMapImage()
    local overviewInfo = versus.mapOverview.loadMapOverviewConfig(mapFileName)

    if (not overviewInfo) then
      ErrorNoHalt("No overview config found for map " ..
        mapFileName ..
        ", map overview will not be shown. Please create a config file for this map to enable the overview.\n")
      return
    end

    self.mapOverview = versus.mapOverview.new({
      scale = overviewInfo.scale,
      pos_x = overviewInfo.pos_x,
      pos_y = overviewInfo.pos_y,
      mapTexture = mapMaterial,
      mapSize = 1024,
      zoom = 1.0,
      followAngle = false,
      rotateMap = false
    })

    local hideoutServerConVar = GetConVar("versus_hideout_server")
    local hideoutServerAddress = hideoutServerConVar and hideoutServerConVar:GetString() or ""

    if (hideoutServerAddress ~= "") then
      self.connectToHideoutButton = vgui.Create("versus_ButtonAdvert", self)
      self.connectToHideoutButton:SetTitle("GO TO HIDEOUT")
      self.connectToHideoutButton:SetSubtext("Sell loot, meet allies, gear up, and find new contracts in the hideout!")
      self.connectToHideoutButton:SetImage("versus/hideout.png")
      self.connectToHideoutButton:SetSize(550, 130)
      self.connectToHideoutButton.DoClick = function()
        permissions.AskToConnect(hideoutServerAddress)
      end
    end
  end

  function PANEL:SetContracts(contractsData)
    self.contractsPanel:SetContracts(contractsData)
  end

  --- Finds the best map image for the current map, trying an exact match first, then falling back to partial matches
  --- @return Material?, string # The material for the map overview, or nil if none found and the filename of the matched image
  function PANEL:FindBestMapImage()
    local mapName = game.GetMap()
    local exactPath = "versus/map_overviews/" .. mapName .. ".png"

    if file.Exists("materials/" .. exactPath, "GAME") then
      return Material(exactPath, "smooth"), mapName
    end

    -- Loop all files in the map_overviews folder to find partial matches
    local files = file.Find("materials/versus/map_overviews/*.png", "GAME")
    local bestMatch = nil
    local bestScore = 0

    for _, fileName in ipairs(files) do
      local baseName = string.StripExtension(fileName)
      local score = self:CalculateMatchScore(mapName, baseName)

      if score > bestScore then
        bestScore = score
        bestMatch = fileName
      end
    end

    if bestMatch then
      return Material("versus/map_overviews/" .. bestMatch, "smooth"), string.StripExtension(bestMatch)
    end

    return nil
  end

  function PANEL:CalculateMatchScore(mapName, fileName)
    local score = 0

    -- Partial match based on common segments
    local mapSegments = string.Split(mapName, "_")
    local fileSegments = string.Split(fileName, "_")

    for _, mapSeg in ipairs(mapSegments) do
      for _, fileSeg in ipairs(fileSegments) do
        if mapSeg == fileSeg then
          score = score + 10
        end
      end
    end

    return score
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    -- Fade in animation
    if elapsed < self.animDuration then
      local progress = elapsed / self.animDuration
      progress = math.ease.InOutQuad(progress)

      self.contentAlpha = 255 * progress
    else
      self.contentAlpha = 255
    end
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, w, h)

    if self.contentAlpha < 10 then return end

    local alpha = self.contentAlpha

    local mx, my = self.mapContainer:LocalToScreen(0, 0)

    if self.mapOverview then
      surface.SetAlphaMultiplier(alpha / 255)

      self.mapOverview:DrawMapTexture(mx, my)

      surface.SetAlphaMultiplier(1)
    end

    -- Draw locations from hovered contract
    local hoveredContractButton = self.contractsPanel:GetHoveredContract()

    if hoveredContractButton and hoveredContractButton.locations and self.mapOverview then
      for locationKey, location in pairs(hoveredContractButton.locations) do
        if IsValid(location.entity) then
          local worldPos = location.entity:GetPos()
          local panelX, panelY = self.mapOverview:WorldToPanel(worldPos)

          -- Convert to screen coordinates
          local screenX = mx + panelX
          local screenY = my + panelY

          -- Draw location indicator circle
          local radius = 16
          draw.NoTexture()
          surface.SetDrawColor(ColorAlpha(self.accentColor, alpha))
          GAMEMODE:DrawCircle(screenX, screenY, radius)

          -- Draw inner circle (hollow effect)
          surface.SetDrawColor(ColorAlpha(self.bgColor, alpha))
          local innerRadius = radius - 4
          GAMEMODE:DrawCircle(screenX, screenY, innerRadius)

          -- Draw center dot
          surface.SetDrawColor(ColorAlpha(self.accentColor, alpha))
          local dotRadius = 4
          GAMEMODE:DrawCircle(screenX, screenY, dotRadius)

          -- Draw location label
          if location.displayName then
            surface.SetFont("VersusDefault")
            local textW, textH = surface.GetTextSize(location.displayName)

            local labelX = screenX - textW / 2 - 8
            local labelY = screenY - radius - textH - 12

            surface.SetFont("VersusDefault")
            surface.SetTextColor(ColorAlpha(self.textColor, alpha))
            surface.SetTextPos(labelX + 8, labelY + 4)
            surface.DrawText(location.displayName)
          end
        end
      end
    end
  end

  function PANEL:PerformLayout(w, h)
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)

    self.contractsContainer:SetWide(w * 0.45)
    self.contractsPanel:SetWide(self.contractsContainer:GetWide())
    self.contractsPanel:SetPos(0, GAMEMODE.SPACING)
    -- self.contractsPanel:CenterVertical()

    if (self.mapOverview) then
      local containerH = self.mapContainer:GetTall()
      self.mapOverview:SetPanelSize(containerH, containerH)
    end

    if IsValid(self.connectToHideoutButton) then
      self.connectToHideoutButton:SetPos(
        0,
        ScrH() - self.connectToHideoutButton:GetTall() - GAMEMODE.SPACING
      )

      self.mapContainer:DockMargin(
        GAMEMODE.SPACING,
        GAMEMODE.SPACING,
        GAMEMODE.SPACING,
        self.connectToHideoutButton:GetTall() + GAMEMODE.SPACING * 2
      )
    end
  end

  vgui.Register("versus_ContractSelection", PANEL, "EditablePanel")
end

do
  local PANEL = {}

  function PANEL:Init()
    self:SetText("")
    self.hovered = false

    self.contentAlpha = 0
    self.animDuration = 0.3
    self.animStart = CurTime()

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = Color(255, 204, 0, 255) -- Yellow
    self.disabledColor = Color(141, 153, 174)
  end

  function PANEL:Setup(entity)
    self.entity = entity
  end

  function PANEL:Paint(w, h)
    local alpha = self.contentAlpha

    -- Determine color based on state
    local color = self.accentColor

    -- Draw outer circle
    draw.NoTexture()
    surface.SetDrawColor(color)

    local cx, cy = w / 2, h / 2
    local radius = w / 2 - 2

    GAMEMODE:DrawCircle(cx, cy, radius)

    -- Draw inner circle (hollow effect)
    surface.SetDrawColor(ColorAlpha(self.bgColor, alpha))
    local innerRadius = radius - 4
    GAMEMODE:DrawCircle(cx, cy, innerRadius)

    -- Draw center dot
    surface.SetDrawColor(color)
    local dotRadius = 4
    GAMEMODE:DrawCircle(cx, cy, dotRadius)
  end

  function PANEL:OnCursorEntered()
    self.hovered = true
  end

  function PANEL:OnCursorExited()
    self.hovered = false
  end

  function PANEL:DoClick()
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.animStart

    -- Fade in animation
    if elapsed < self.animDuration then
      local progress = elapsed / self.animDuration
      progress = math.ease.InOutQuad(progress)

      self.contentAlpha = 255 * progress
    else
      self.contentAlpha = 255
    end
  end

  vgui.Register("versus_ContractSelectionButton", PANEL, "DButton")
end

concommand.Add("versus_test_contract_selection", function()
  if (not LocalPlayer():IsAdmin()) then return end

  if IsValid(PLUGIN.contractSelectionPanel) then
    PLUGIN.contractSelectionPanel:Remove()
  end

  PLUGIN.contractSelectionPanel = vgui.Create("versus_ContractSelection")

  -- Run with some test data
  local spawnPoints = ents.FindByClass("versus_spawn_point")
  local extractionPoints = ents.FindByClass("versus_objective_interaction")
  local contracts = {
    {
      enabled   = true,
      type      = "extract",
      locations = {
        spawn = {
          entity = spawnPoints[1],
          displayName = "Deployment",
          class = "versus_spawn_point"
        },
        extraction = {
          entity = extractionPoints[1],
          displayName = "Extraction",
          class = "versus_objective_interaction"
        }
      },
      name      = "[Sabotage] The Nexus Core",
      tags      = {
        { label = "boss", color = Color(220, 80, 80) },
      },
    },
    {
      enabled   = true,
      type      = "extract",
      locations = {
        spawn = {
          entity = spawnPoints[2],
          displayName = "Deployment",
          class = "versus_spawn_point"
        },
        extraction = {
          entity = extractionPoints[2],
          displayName = "Extraction",
          class = "versus_objective_interaction"
        }
      },
      name      = "[Defend] City 18 Rebel Hideout",
      tags      = {
        { label = "defend", color = Color(100, 160, 220) },
      },
    },
    {
      enabled           = false,
      type              = "extract",
      locations         = {
        spawn = {
          entity = spawnPoints[2],
          displayName = "Deployment",
          class = "versus_spawn_point"
        },
        extraction = {
          entity = extractionPoints[2],
          displayName = "Extraction",
          class = "versus_objective_interaction"
        }
      },
      name              = "[Defend] City 18 Rebel Hideout",
      tags              = {},
      unavailableReason = "RECENTLY EXECUTED"
    }
  }
  hook.Run("PlayerReceivedContracts", PLUGIN.getLocalContracts() or contracts)
end)

if IsValid(PLUGIN.contractSelectionPanel) then
  PLUGIN.contractSelectionPanel:Remove()
end
