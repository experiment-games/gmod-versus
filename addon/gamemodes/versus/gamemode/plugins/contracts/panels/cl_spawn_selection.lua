local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)

    self.contentAlpha = 0
    self.animStart = CurTime()
    self.animDuration = 0.4

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = Color(80, 140, 220, 255)
    self.disabledColor = Color(141, 153, 174)
    self.textColor = Color(220, 230, 240, 255)

    self.titleLabel = vgui.Create("DLabel", self)
    self.titleLabel:SetFont("VersusHeadingHuge")
    self.titleLabel:SetTextColor(self.textColor)
    self.titleLabel:SetText(("Select Contract"):upper())
    self.titleLabel:SetContentAlignment(5)
    self.titleLabel:Dock(TOP)
    self.titleLabel:DockMargin(GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING, GAMEMODE.SPACING)
    self.titleLabel:SizeToContents()

    self.mapContainer = vgui.Create("EditablePanel", self)
    self.mapContainer:Dock(FILL)
    self.mapContainer:DockMargin(GAMEMODE.SPACING, 0, GAMEMODE.SPACING, GAMEMODE.SPACING)
    local mapMaterial = self:FindBestMapImage()

    -- TODO: These should be loaded from a json or something on the server, not hardcoded here
    self.mapOverview = versus.mapOverview.new({
      scale = 12,
      pos_x = -5314,
      pos_y = 6662,
      mapTexture = mapMaterial,
      mapSize = 1024,
      zoom = 1.0,
      followAngle = false,
      rotateMap = false
    })

    self.spawnButtons = {}

    self:RefreshSpawnPoints()
  end

  -- Finds the best map image for the current map, trying an exact match first, then falling back to partial matches
  function PANEL:FindBestMapImage()
    local mapName = game.GetMap()
    local exactPath = "versus/map_overviews/" .. mapName .. ".png"

    if file.Exists("materials/" .. exactPath, "GAME") then
      return Material(exactPath, "smooth")
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
      return Material("versus/map_overviews/" .. bestMatch, "smooth")
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

  function PANEL:RefreshSpawnPoints()
    -- Clear existing buttons
    for _, button in ipairs(self.spawnButtons) do
      if IsValid(button) then
        button:Remove()
      end
    end

    self.spawnButtons = {}

    -- Find all spawn points
    local spawnPoints = ents.FindByClass("versus_spawn_point")

    for _, spawnPoint in ipairs(spawnPoints) do
      if not IsValid(spawnPoint) then
        continue
      end

      local button = vgui.Create("versus_SpawnSelectionButton", self.mapContainer)
      button:SetSize(32, 32)
      button:Setup(spawnPoint)

      table.insert(self.spawnButtons, button)
    end

    self:PositionSpawnButtons()
  end

  function PANEL:PositionSpawnButtons()
    if not self.mapOverview then return end

    local containerW = self.mapContainer:GetWide()
    local containerH = self.mapContainer:GetTall()
    self.mapOverview:SetPanelSize(containerW, containerH)

    for _, button in ipairs(self.spawnButtons) do
      if IsValid(button) and IsValid(button.spawnPoint) then
        local worldPos = button.spawnPoint:GetPos()

        -- Use MapOverview's WorldToPanel method
        local panelX, panelY = self.mapOverview:WorldToPanel(worldPos)

        -- Center the button on the calculated position
        button:SetPos(panelX - button:GetWide() / 2, panelY - button:GetTall() / 2)
      end
    end
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

    -- Reposition buttons on layout changes
    self:PositionSpawnButtons()
  end

  function PANEL:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.animStart)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, w, h)

    if self.contentAlpha < 10 then return end

    local alpha = self.contentAlpha

    local mx, my = self.mapContainer:LocalToScreen(0, 0)
    local mw, mh = self.mapContainer:GetSize()

    if self.mapOverview then
      surface.SetAlphaMultiplier(alpha / 255)

      self.mapOverview:DrawMapTexture(mx, my, mw, mh)

      surface.SetAlphaMultiplier(1)
    end

    -- Draw spawn point labels
    for _, button in ipairs(self.spawnButtons) do
      if IsValid(button) and IsValid(button.spawnPoint) then
        if button.hovered then
          local bx, by = button:LocalToScreen(0, 0)
          local bw, bh = button:GetSize()

          local spawnName = button.spawnPoint:GetSpawnPointName()
          surface.SetFont("VersusDefault")
          local textW, textH = surface.GetTextSize(spawnName)

          local labelX = bx + bw / 2 - textW / 2 - 8
          local labelY = by - textH - 16
          local labelW = textW + 16
          local labelH = textH + 8

          surface.SetDrawColor(ColorAlpha(self.bgColor, alpha * 0.95))
          surface.DrawRect(labelX, labelY, labelW, labelH)

          local labelColor = button.enabled and self.accentColor or self.disabledColor
          surface.SetDrawColor(ColorAlpha(labelColor, alpha))
          surface.DrawOutlinedRect(labelX, labelY, labelW, labelH, 1)

          surface.SetFont("VersusDefault")
          surface.SetTextColor(ColorAlpha(self.textColor, alpha))
          surface.SetTextPos(labelX + 8, labelY + 4)
          surface.DrawText(spawnName)

          if not button.enabled then
            local statusText = "UNAVAILABLE"
            surface.SetFont("VersusDefault")
            local statusW, statusH = surface.GetTextSize(statusText)

            surface.SetTextColor(ColorAlpha(self.disabledColor, alpha))
            surface.SetTextPos(labelX + labelW / 2 - statusW / 2, labelY + labelH + 4)
            surface.DrawText(statusText)
          end
        end
      end
    end
  end

  function PANEL:PerformLayout(w, h)
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
  end

  vgui.Register("versus_SpawnSelection", PANEL, "EditablePanel")
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
    self.accentColor = Color(80, 140, 220, 255)
    self.disabledColor = Color(141, 153, 174)
  end

  function PANEL:Setup(spawnPoint)
    self.spawnPoint = spawnPoint
    self.enabled = spawnPoint:GetEnabled()
  end

  function PANEL:Paint(w, h)
    local alpha = self.contentAlpha

    -- Determine color based on state
    local color
    if not self.enabled then
      color = ColorAlpha(self.disabledColor, alpha * 0.5)
    elseif self.hovered or self:IsDown() then
      color = ColorAlpha(self.accentColor, alpha)
    else
      color = ColorAlpha(self.accentColor, alpha * 0.7)
    end

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
    if self.enabled then
      self:OnSpawnPointSelected(self.spawnPoint)
    end
  end

  function PANEL:OnSpawnPointSelected(spawnPoint)
    -- TODO:
    print("Spawn point selected:", spawnPoint:GetSpawnPointName())
  end

  function PANEL:Think()
    if IsValid(self.spawnPoint) then
      self.enabled = self.spawnPoint:GetEnabled()
    end

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

  vgui.Register("versus_SpawnSelectionButton", PANEL, "DButton")
end

concommand.Add("versus_open_spawn_selection", function()
  if (not LocalPlayer():IsAdmin()) then return end

  if IsValid(PLUGIN.spawnSelectionPanel) then
    PLUGIN.spawnSelectionPanel:Remove()
  end

  PLUGIN.spawnSelectionPanel = vgui.Create("versus_SpawnSelection")
end)

if IsValid(PLUGIN.spawnSelectionPanel) then
  PLUGIN.spawnSelectionPanel:Remove()
end
