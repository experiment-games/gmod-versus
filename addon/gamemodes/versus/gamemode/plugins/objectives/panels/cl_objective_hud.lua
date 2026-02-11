local PLUGIN = PLUGIN

do
  local PANEL = {}
  local SPACING = 8

  function PANEL:Init()
    self:SetSize(360, ScrH())

    self.objectivePanel = nil
    self.subObjectivePanels = {}
    self.visible = false

    -- Position at top-left of screen
    self:SetPos(GAMEMODE.SPACING or 20, GAMEMODE.SPACING or 20)
  end

  function PANEL:SetObjective(title, description, distance)
    -- Create or update objective panel
    if IsValid(self.objectivePanel) then
      self.objectivePanel:Remove()
    end

    self.objectivePanel = vgui.Create("versus_ObjectivePanel", self)
    self.objectivePanel:SetObjective(title, description, distance)
    self.objectivePanel:SetTargetAlpha(255)

    self.visible = true
    self:InvalidateLayout(true)
  end

  function PANEL:AddSubObjective(id, text, completed, distance)
    -- Check if sub-objective already exists
    for _, panel in ipairs(self.subObjectivePanels) do
      if IsValid(panel) and panel:GetID() == id then
        panel:SetSubObjective(id, text, completed, distance)
        self:InvalidateLayout(true)
        return
      end
    end

    -- Create new sub-objective panel
    local panel = vgui.Create("versus_SubObjectivePanel", self)
    panel:SetSubObjective(id, text, completed, distance)
    panel:SetTargetAlpha(255)

    table.insert(self.subObjectivePanels, panel)
    self:InvalidateLayout(true)
  end

  function PANEL:RemoveSubObjective(id)
    for i, panel in ipairs(self.subObjectivePanels) do
      if IsValid(panel) and panel:GetID() == id then
        panel:Remove()
        table.remove(self.subObjectivePanels, i)
        self:InvalidateLayout(true)
        return
      end
    end
  end

  function PANEL:UpdateSubObjective(id, text, completed, distance)
    for _, panel in ipairs(self.subObjectivePanels) do
      if IsValid(panel) and panel:GetID() == id then
        local currentText = text or panel:GetText()
        panel:SetSubObjective(id, currentText, completed, distance)
        self:InvalidateLayout(true)
        return
      end
    end
  end

  function PANEL:Clear()
    if IsValid(self.objectivePanel) then
      self.objectivePanel:Remove()
      self.objectivePanel = nil
    end

    for _, panel in ipairs(self.subObjectivePanels) do
      if IsValid(panel) then
        panel:Remove()
      end
    end

    self.subObjectivePanels = {}
    self.visible = false
  end

  function PANEL:HasContent()
    return IsValid(self.objectivePanel)
  end

  function PANEL:Think()
    -- Resort sub-objective panels if completion status changed
    if self:HasContent() and #self.subObjectivePanels > 1 then
      local needsResort = false

      for i = 1, #self.subObjectivePanels - 1 do
        local current = self.subObjectivePanels[i]
        local next = self.subObjectivePanels[i + 1]

        if IsValid(current) and IsValid(next) then
          if current:IsCompleted() and not next:IsCompleted() then
            needsResort = true
            break
          end
        end
      end

      if needsResort then
        table.sort(self.subObjectivePanels, function(a, b)
          if not IsValid(a) or not IsValid(b) then return false end

          local aCompleted = a:IsCompleted()
          local bCompleted = b:IsCompleted()

          -- Incomplete objectives first
          if aCompleted ~= bCompleted then
            return not aCompleted
          end

          -- Then sort by ID
          return a:GetID() < b:GetID()
        end)

        self:InvalidateLayout(true)
      end
    end
  end

  function PANEL:PerformLayout(w, h)
    if not self:HasContent() then return end

    local yPos = 0

    -- Position objective panel
    if IsValid(self.objectivePanel) then
      self.objectivePanel:SetPos(0, yPos)
      yPos = yPos + self.objectivePanel:GetTall() + SPACING
    end

    -- Add section header spacing if there are sub-objectives
    if #self.subObjectivePanels > 0 then
      yPos = yPos + SPACING
    end

    -- Position sub-objective panels
    for _, panel in ipairs(self.subObjectivePanels) do
      if IsValid(panel) then
        panel:SetPos(0, yPos)
        yPos = yPos + panel:GetTall() + SPACING
      end
    end

    -- Update container size
    self:SetTall(yPos)
  end

  vgui.Register("versus_ObjectiveHUDContainer", PANEL, "EditablePanel")
end
