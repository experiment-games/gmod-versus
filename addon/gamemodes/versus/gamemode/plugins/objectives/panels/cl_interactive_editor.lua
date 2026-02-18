local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:GetEntity()
    return self.entity
  end

  function PANEL:SetEntity(ent)
    self.entity = ent

    if (not IsValid(ent)) then return end

    self.modelEntry:SetText(ent:GetModel() or "")
    self.skinSlider:SetValue(ent:GetSkin())
    self.scaleSlider:SetValue(ent:GetModelScale())
  end

  function PANEL:Init()
    self:SetTitle("Objective Interaction Editor")
    self:SetDeleteOnClose(true)
    self:DockPadding(8, 32, 8, 8)

    -- Bottom panel: skin, scale, z-offset, apply button
    local bottom = self:Add("DSizeToContents")
    bottom:Dock(BOTTOM)
    bottom:SetSizeX(false)
    bottom:DockPadding(0, 0, 0, 0)

    local skinSlider = bottom:Add("DNumSlider")
    skinSlider:Dock(TOP)
    skinSlider:SetTall(30)
    skinSlider:SetText("Skin")
    skinSlider:SetMin(0)
    skinSlider:SetMax(31)
    skinSlider:SetDecimals(0)
    skinSlider:SetValue(0)
    self.skinSlider = skinSlider

    local scaleSlider = bottom:Add("DNumSlider")
    scaleSlider:Dock(TOP)
    scaleSlider:SetTall(30)
    scaleSlider:SetText("Model Scale")
    scaleSlider:SetMin(0.1)
    scaleSlider:SetMax(5)
    scaleSlider:SetDecimals(2)
    scaleSlider:SetValue(1)
    self.scaleSlider = scaleSlider

    local bumpButtonsPanel = bottom:Add("EditablePanel")
    bumpButtonsPanel:Dock(TOP)
    bumpButtonsPanel:SetTall(30)

    local bumpDownBtn = bumpButtonsPanel:Add("DButton")
    bumpDownBtn:Dock(LEFT)
    bumpDownBtn:SetText("Bump Down")
    bumpDownBtn:DockMargin(0, 0, 4, 0)
    bumpDownBtn.DoClick = function()
      local ent = self:GetEntity()
      if (IsValid(ent)) then
        net.Start("versus.objectives.changeInteractiveEditorBump")
        net.WriteEntity(ent)
        net.WriteFloat(-1)
        net.SendToServer()
      end
    end

    local bumpUpBtn = bumpButtonsPanel:Add("DButton")
    bumpUpBtn:Dock(LEFT)
    bumpUpBtn:SetText("Bump Up")
    bumpUpBtn:DockMargin(4, 0, 0, 0)
    bumpUpBtn.DoClick = function()
      local ent = self:GetEntity()
      if (IsValid(ent)) then
        net.Start("versus.objectives.changeInteractiveEditorBump")
        net.WriteEntity(ent)
        net.WriteFloat(1)
        net.SendToServer()
      end
    end

    local applyBtn = bottom:Add("DButton")
    applyBtn:Dock(TOP)
    applyBtn:SetTall(28)
    applyBtn:DockMargin(0, 6, 0, 0)
    applyBtn:SetText("Apply")
    applyBtn.DoClick = function()
      self:SendChanges()
    end

    -- Model section fills remaining space
    local modelSection = self:Add("EditablePanel")
    modelSection:Dock(FILL)
    modelSection:DockPadding(0, 0, 0, 6)

    local modelRow = modelSection:Add("EditablePanel")
    modelRow:Dock(TOP)
    modelRow:SetTall(24)

    local modelLabel = modelRow:Add("DLabel")
    modelLabel:Dock(LEFT)
    modelLabel:SetText("Model:")
    modelLabel:SetWide(60)
    modelLabel:SetContentAlignment(4)

    local modelEntry = modelRow:Add("DTextEntry")
    modelEntry:Dock(FILL)
    modelEntry:SetPlaceholderText("Model path...")
    self.modelEntry = modelEntry

    -- Search bar at the very top of the browser
    local searchRow = modelSection:Add("EditablePanel")
    searchRow:Dock(TOP)
    searchRow:SetTall(24)
    searchRow:DockMargin(0, 8, 0, 4)

    local searchLabel = searchRow:Add("DLabel")
    searchLabel:Dock(LEFT)
    searchLabel:SetText("Search:")
    searchLabel:SetWide(60)
    searchLabel:SetContentAlignment(4)

    local searchBar = searchRow:Add("DTextEntry")
    searchBar:Dock(FILL)
    searchBar:SetPlaceholderText("Search models...")
    self.modelSearchBar = searchBar

    -- Sub-panel: spawnmenu-style tree (left) + ContentContainer (right)
    local modelBrowser = modelSection:Add("EditablePanel")
    modelBrowser:Dock(FILL)
    modelBrowser:DockPadding(0, 4, 0, 0)

    local viewPanel = modelBrowser:Add("ContentContainer")
    viewPanel:Dock(FILL)
    viewPanel.IconList:SetReadOnly(true)
    self.modelViewPanel = viewPanel

    local modelTree = modelBrowser:Add("DTree")
    modelTree:Dock(LEFT)
    modelTree:SetWide(220)
    modelTree:DockMargin(0, 0, 4, 0)
    self.modelTree = modelTree

    -- Populated by the tree; tracks the last manually-selected folder so
    -- clearing the search restores the previous view.
    local lastFolder, lastPathID = nil, nil

    local function addModelIcon(mdlPath)
      local cp = spawnmenu.GetContentType("model")
      if (not cp) then return end
      local icon = cp(viewPanel, { model = mdlPath })
      if (IsValid(icon)) then
        icon.DoClick = function()
          modelEntry:SetText(mdlPath)
          self.skinSlider:SetValue(0)
        end
        icon.DoRightClick = nil
      end
    end

    local function populateViewPanel(folder, pathid)
      lastFolder, lastPathID = folder, pathid
      viewPanel:Clear()

      local mdls = file.Find(folder .. "/*.mdl", pathid)
      if (not mdls) then return end

      for _, v in ipairs(mdls) do
        addModelIcon(folder .. "/" .. v)
      end
    end

    -- Recursively collect up to maxResults .mdl paths matching query.
    local function searchModels(query, pathid, results, maxResults)
      local function recurse(folder)
        if (#results >= maxResults) then return end
        local files, dirs = file.Find(folder .. "/*", pathid)
        if (files) then
          for _, f in ipairs(files) do
            if (f:EndsWith(".mdl")) then
              local fullPath = folder .. "/" .. f
              if (fullPath:lower():find(query, 1, true)) then
                results[#results + 1] = fullPath
                if (#results >= maxResults) then return end
              end
            end
          end
        end
        if (dirs) then
          for _, d in ipairs(dirs) do
            recurse(folder .. "/" .. d)
            if (#results >= maxResults) then return end
          end
        end
      end
      recurse("models")
    end

    local searchTimerName = "versus_model_search_" .. tostring(SysTime())

    searchBar.OnChange = function(_self)
      local query = _self:GetValue():lower():Trim()
      timer.Remove(searchTimerName)

      if (query == "") then
        -- Restore the folder that was selected before searching
        if (lastFolder and lastPathID) then
          populateViewPanel(lastFolder, lastPathID)
        else
          viewPanel:Clear()
        end
        return
      end

      timer.Create(searchTimerName, 0.4, 1, function()
        if (not IsValid(viewPanel)) then return end
        viewPanel:Clear()

        local seen = {}
        local results = {}
        -- Search across all mounted game paths used by the tree
        local games = engine.GetGames()
        table.insert(games, { folder = "GAME", mounted = true })
        table.insert(games, { folder = "garrysmod", mounted = true })

        for _, game in ipairs(games) do
          if (game.mounted and #results < 200) then
            local batch = {}
            searchModels(query, game.folder, batch, 200 - #results)
            for _, p in ipairs(batch) do
              if (not seen[p]) then
                seen[p] = true
                results[#results + 1] = p
              end
            end
          end
        end

        for _, mdlPath in ipairs(results) do
          addModelIcon(mdlPath)
        end
      end)
    end

    local function installNodeCallbacks(node)
      node.OnNodeSelected = function(_, selectedNode)
        if (not IsValid(selectedNode)) then return end
        populateViewPanel(selectedNode:GetFolder(), selectedNode:GetPathID())
      end
      node.OnNodeAdded = function(_, newNode)
        installNodeCallbacks(newNode)
      end
    end

    local function addGameBrowse(parentNode, name, icon, pathid)
      local modelsNode = parentNode:AddFolder(name, "models", pathid, false)
      modelsNode:SetIcon(icon)
      modelsNode.BrowseContentType = "models"
      modelsNode.BrowseExtension = "*.mdl"
      modelsNode.ContentType = "model"
      modelsNode.GamePathID = pathid
      installNodeCallbacks(modelsNode)
    end

    local games = engine.GetGames()
    table.insert(games, { title = "All", folder = "GAME", icon = "all", mounted = true })
    table.insert(games, { title = "Garry's Mod", folder = "garrysmod", mounted = true })

    local gamesNode = modelTree:AddNode("Games", "icon16/joystick.png")

    for _, game in SortedPairsByMemberValue(games, "title") do
      if (game.mounted) then
        addGameBrowse(
          gamesNode,
          game.title,
          "games/16/" .. (game.icon or game.folder) .. ".png",
          game.folder
        )
      end
    end
  end

  function PANEL:SendChanges()
    local ent = self:GetEntity()
    if (not IsValid(ent)) then return end

    net.Start("versus.objectives.changeInteractiveEditor")
    net.WriteEntity(ent)
    net.WriteString(self.modelEntry:GetValue())
    net.WriteInt(math.Round(self.skinSlider:GetValue()), 8)
    net.WriteFloat(self.scaleSlider:GetValue())
    net.SendToServer()
  end

  vgui.Register("versus_InteractiveEditor", PANEL, "DFrame")
end

net.Receive("versus.objectives.openInteractiveEditor", function()
  local entity = net.ReadEntity()

  if (not IsValid(entity)) then
    ErrorNoHalt("[Objective Editor] Invalid entity for interactive editor")
    return
  end

  local editorPanel = vgui.Create("versus_InteractiveEditor")
  editorPanel:SetSize(620, 620)
  editorPanel:Center()
  editorPanel:MakePopup()
  editorPanel:SetEntity(entity)
end)
