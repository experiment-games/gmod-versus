-- Base VGUI panel that provides the drag-detection lifecycle shared by all
-- draggable item panels in the game.  Subclasses only need to implement the
-- four abstract methods; the boilerplate Think / mouse / remove handlers live
-- here so they never have to be copied again.
--
-- Abstract methods (override in subclass):
--   PANEL:GetDragItem()           → item table, or nil if not draggable right now
--   PANEL:OnDragStarted()         → create ghost, notify parent, etc.
--   PANEL:OnDragDropped()         → check zone hovering, fire action; MUST call _StopDrag
--   PANEL:OnDragStopped(dropped)  → remove ghost, clear parent state, etc.
--
-- The common entry-points _StartDrag / _StopDrag call the abstract callbacks
-- at the right moment.  Direct calls to StartDragging / StopDragging in old
-- code should be replaced with _StartDrag / _StopDrag.

do
  local PANEL = {}

  function PANEL:Init()
    self.isDragging    = false
    self.dragStartTime = nil
  end

  -- Override: return the item currently associated with this panel (or nil).
  function PANEL:GetDragItem()
    return nil
  end

  -- Override: return false to block a drag from starting.
  -- Default: a drag can start whenever GetDragItem returns non-nil.
  function PANEL:CanStartDrag()
    return self:GetDragItem() ~= nil
  end

  -- Override: called immediately after alpha is dimmed and mouse is captured.
  function PANEL:OnDragStarted() end

  -- Override: called when the left mouse button is released while dragging.
  -- Inspect whatever hovering flags your drop-zones set, then call _StopDrag.
  -- Default implementation simply cancels the drag without any action.
  function PANEL:OnDragDropped()
    self:_StopDrag(false)
  end

  -- Override: called after isDragging is cleared and mouse capture is released.
  -- Clean up ghost panels and any parent-panel state here.
  function PANEL:OnDragStopped(dropped) end

  --- Begins a drag session.  Has no effect if already dragging.
  function PANEL:_StartDrag()
    if self.isDragging then return end
    self.isDragging = true
    self:SetAlpha(100)
    self:MouseCapture(true)
    self:OnDragStarted()
  end

  --- Ends the active drag session.  Has no effect when not dragging.
  --- @param dropped boolean  true when an action was successfully performed
  function PANEL:_StopDrag(dropped)
    if not self.isDragging then return end
    self.isDragging = false
    self:SetAlpha(255)
    self:MouseCapture(false)
    self:OnDragStopped(dropped)
  end

  --- Detects when a held mouse button has moved far enough to start a drag.
  --- Call BaseClass.Think(self) from a subclass Think to run this check.
  function PANEL:Think()
    if not self.dragStartTime or self.isDragging then return end

    if not input.IsMouseDown(MOUSE_FIRST) then
      self.dragStartTime = nil
      return
    end

    if SysTime() - self.dragStartTime > 0.1 then
      local x, y = self:LocalCursorPos()
      if math.sqrt((x - self.dragStartX) ^ 2 + (y - self.dragStartY) ^ 2) > 5 then
        self:_StartDrag()
      end
    end
  end

  function PANEL:OnMousePressed(mouse)
    if mouse ~= MOUSE_FIRST then return end
    if self:CanStartDrag() then
      self.dragStartTime = SysTime()
      self.dragStartX, self.dragStartY = self:LocalCursorPos()
    end
  end

  function PANEL:OnMouseReleased(mouse)
    if mouse ~= MOUSE_FIRST then return end
    if self.isDragging then
      self:OnDragDropped()
    end
    self.dragStartTime = nil
  end

  function PANEL:OnRemove()
    if self.isDragging then
      self:_StopDrag(false)
    end
    self.dragStartTime = nil
  end

  vgui.Register("versus_DraggableItem", PANEL, "EditablePanel")
end
