local PLUGIN = PLUGIN

do
  local PANEL = {}
  local SPACING = 8

  function PANEL:Init()
    self:SetSize(360, ScrH())

    self.extractionPanel = nil
    self.conditionPanels = {}
    self.visible = false

    -- Position at top-left of screen
    self:SetPos(GAMEMODE.SPACING or 20, GAMEMODE.SPACING or 20)
  end

  function PANEL:SetExtractionPoint(extractionPoint)
    self:Clear()

    if not IsValid(extractionPoint) then return end

    -- Create extraction objective panel
    self.extractionPanel = vgui.Create("versus_ExtractionObjectivePanel", self)
    self.extractionPanel:SetExtractionPoint(extractionPoint)
    self.extractionPanel:SetTargetAlpha(255)

    -- TODO
    local conditions = {}

    -- Create panels for each condition
    for _, condition in ipairs(conditions) do
      local panel = vgui.Create("versus_ConditionObjectivePanel", self)
      panel:SetCondition(condition)
      panel:SetTargetAlpha(255)

      table.insert(self.conditionPanels, panel)
    end

    self.visible = true
    self:InvalidateLayout(true)
  end

  function PANEL:Clear()
    if IsValid(self.extractionPanel) then
      self.extractionPanel:Remove()
      self.extractionPanel = nil
    end

    for _, panel in ipairs(self.conditionPanels) do
      if IsValid(panel) then
        panel:Remove()
      end
    end

    self.conditionPanels = {}
    self.visible = false
  end

  function PANEL:HasContent()
    return IsValid(self.extractionPanel)
  end

  function PANEL:Think()
    -- Resort condition panels if completion status changed
    if self:HasContent() then
      local needsResort = false

      for i = 1, #self.conditionPanels - 1 do
        local current = self.conditionPanels[i]
        local next = self.conditionPanels[i + 1]

        if IsValid(current) and IsValid(next) then
          if current:IsCompleted() and not next:IsCompleted() then
            needsResort = true
            break
          end
        end
      end

      if needsResort then
        table.sort(self.conditionPanels, function(a, b)
          if not IsValid(a) or not IsValid(b) then return false end

          local aCompleted = a:IsCompleted()
          local bCompleted = b:IsCompleted()

          if aCompleted ~= bCompleted then
            return not aCompleted
          end

          if IsValid(a:GetCondition()) and IsValid(b:GetCondition()) then
            return a:GetCondition():EntIndex() < b:GetCondition():EntIndex()
          end

          return false
        end)

        self:InvalidateLayout(true)
      end
    end
  end

  function PANEL:PerformLayout(w, h)
    if not self:HasContent() then return end

    local yPos = 0

    -- Position extraction panel
    if IsValid(self.extractionPanel) then
      self.extractionPanel:SetPos(0, yPos)
      yPos = yPos + self.extractionPanel:GetTall() + SPACING
    end

    -- Add section header if there are conditions
    if #self.conditionPanels > 0 then
      yPos = yPos + SPACING
    end

    -- Position condition panels
    for _, panel in ipairs(self.conditionPanels) do
      if IsValid(panel) then
        panel:SetPos(0, yPos)
        yPos = yPos + panel:GetTall() + SPACING
      end
    end

    -- Update container size
    self:SetTall(yPos)
  end

  vgui.Register("versus_ExtractionHUDContainer", PANEL, "EditablePanel")
end
