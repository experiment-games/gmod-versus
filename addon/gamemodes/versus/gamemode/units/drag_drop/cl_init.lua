local UNIT = UNIT

UNIT.libraryKey = "dragDrop"

--- Maps sessionId to active drop zones. See registerDropZone.
--- @type table<string, VersusDragDropZoneConfig>
UNIT.dropZones = UNIT.dropZones or {}

--- Maps sessionId to active drag session. See startDragSession.
--- @type table<string, VersusDragSession>
UNIT.dragSessions = UNIT.dragSessions or {}

--- Maps sessionId to the id of the zone currently under the cursor. Updated every frame by DrawOverlay.
--- Read by fireDroppedForSession to dispatch the correct onDropped callback.
--- @type table<string, string>
UNIT.hoveredZones = UNIT.hoveredZones or {}

local STRIPE_WIDTH = 20
local LINE_THICKNESS = 4
local BORDER_THICKNESS = 4
local BORDER_RADIUS = 8
local TEXT_PADDING = 15
local TEXT_Y_OFFSET = -20 -- label sits slightly above vertical centre

--- @class VersusDragDropZoneConfig
--- @field text string Zone label drawn inside the zone (e.g. "EQUIP ITEM")
--- @field color Color Accent colour for stripes, border, and label
--- @field getPanel fun(): Panel The zone rect is taken from this panel's screen position/size.
--- @field getRect fun(sessionId: string, drag: table): number, number, number, number Returns an explicit screen-space rect. Return nil to skip drawing.
--- @field condition fun(sessionId: string, drag: table): boolean Return false to suppress the zone for a given drag session. Optional – the zone is always visible when omitted.
--- @field onHovering fun(sessionId: string, drag: table, isHovering: boolean) Called every frame during any active drag session with the current hover state (true/false). Optional.
--- @field onDropped fun(sessionId: string, drag: table, ...: any) Called by fireDroppedForSession when the player releases the mouse over this zone. Perform the drop action here. Optional.

--- @class VersusDragSession
--- @field ghostPanel Panel The panel created by the drag source to represent the held item
--- @field item table Arbitrary payload from the drag source, e.g. the item being dragged. This is not used by the dragDrop unit itself, but is forwarded to zone conditions and hover callbacks.

--- Register a named drop zone that the dragDrop unit will draw during active
--- drag sessions.
--- @param id string Unique identifier. Registering with the same id replaces the previous entry.
--- @param config VersusDragDropZoneConfig
function UNIT.registerDropZone(id, config)
  UNIT.dropZones[id] = config
end

--- Unregister a previously registered drop zone.
--- @param id string Unique identifier of the zone to remove.
function UNIT.unregisterDropZone(id)
  UNIT.dropZones[id] = nil
end

--- Begin a named drag session. While a session is active the dragDrop unit
--- draws all registered drop zones (filtered by their conditions) and paints
--- the session's ghost panel via DrawOverlay.
--- @param sessionId string Unique identifier, e.g. "inventory" or "equipped".
--- @param drag VersusDragSession Arbitrary payload forwarded to zone callbacks. At minimum supply { ghostPanel = ... }.
function UNIT.startDragSession(sessionId, drag)
  if not drag.ghostPanel or not IsValid(drag.ghostPanel) then
    error("Drag session must include a valid ghostPanel!")
  end

  UNIT.dragSessions[sessionId] = drag
end

--- End a named drag session.
function UNIT.endDragSession(sessionId)
  UNIT.dragSessions[sessionId] = nil
  UNIT.hoveredZones[sessionId] = nil
end

--- Call the `onDropped` handler of whichever zone is currently hovered for the given session.
--- Returns true when a zone handled the drop, false otherwise.
--- Any extra arguments are forwarded to `zone.onDropped` after `sessionId` and `drag`.
--- @param sessionId string
--- @return boolean
function UNIT.fireDroppedForSession(sessionId, ...)
  local zoneId = UNIT.hoveredZones[sessionId]
  if not zoneId then return false end

  local zone = UNIT.dropZones[zoneId]
  if not zone or not zone.onDropped then return false end

  local drag = UNIT.dragSessions[sessionId]
  zone.onDropped(sessionId, drag, ...)
  return true
end

--- Return the active drag-session payload for the given id, or nil.
function UNIT.getDragSession(sessionId)
  return UNIT.dragSessions[sessionId]
end

function UNIT.hook:DrawOverlay()
  -- Bail early when nothing is being dragged
  local anyActive = false

  for _, drag in pairs(UNIT.dragSessions) do
    if drag then
      anyActive = true; break
    end
  end

  if not anyActive then
    return
  end

  for sessionId, drag in pairs(UNIT.dragSessions) do
    if not drag then
      continue
    end

    -- Draw every zone whose condition passes for this session.
    -- Track which zone is hovered so fireDroppedForSession can dispatch correctly.
    UNIT.hoveredZones[sessionId] = nil

    for zoneId, zone in pairs(UNIT.dropZones) do
      local visible = not zone.condition or zone.condition(sessionId, drag)
      local isHovering = false

      if visible then
        local x, y, w, h

        if zone.getPanel then
          local panel = zone.getPanel()
          if IsValid(panel) then
            x, y = panel:LocalToScreen(0, 0)
            w, h = panel:GetWide(), panel:GetTall()
          end
        elseif zone.getRect then
          x, y, w, h = zone.getRect(sessionId, drag)
        end

        if x then
          isHovering = UNIT.drawZone(x, y, w, h, zone.text, zone.color)
        end
      end

      if isHovering then
        UNIT.hoveredZones[sessionId] = zoneId
      end

      if zone.onHovering then
        zone.onHovering(sessionId, drag, isHovering)
      end
    end

    -- Paint the dragging ghost manually so it renders above everything
    if IsValid(drag.ghostPanel) then
      drag.ghostPanel:PaintManual()
    end
  end
end

--- Returns whether the screen cursor is currently within the given rectangle.
--- @param x number Screen left
--- @param y number Screen top
--- @param w number Width
--- @param h number Height
--- @return boolean
function UNIT.isPointerOver(x, y, w, h)
  local mx, my = input.GetCursorPos()
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

--- Draws a striped drop-zone overlay at the given screen rectangle and returns
--- whether the cursor is hovering over it.
---
--- Stripes are drawn in two bands that frame a centred text label, giving each
--- zone a distinct accent colour while re-using the same geometry and style.
---
--- @param x number Screen left
--- @param y number Screen top
--- @param w number Width
--- @param h number Height
--- @param text string Zone label, e.g. "DROP ITEM"
--- @param accentColor Color
--- @return boolean isHovering
function UNIT.drawZone(x, y, w, h, text, accentColor)
  local isHovering = UNIT.isPointerOver(x, y, w, h)
  local alpha = isHovering and 220 or 50

  -- Draw dim background so buttons behind the zone are less distracting from the text
  draw.RoundedBox(BORDER_RADIUS, x, y, w, h, Color(0, 0, 0, 150))

  -- Derive the label position and the exclusion band around it.
  local textY = y + h / 2 + TEXT_Y_OFFSET
  surface.SetFont("VersusDefaultOutlined")
  local _, textH = surface.GetTextSize(text)
  local textTopY = textY - textH / 2 - TEXT_PADDING
  local textBottomY = textY + textH / 2 + TEXT_PADDING

  local numStripes = math.ceil((w + h) / STRIPE_WIDTH) * 2
  surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, alpha)

  -- Top stripe band (above label)
  render.SetScissorRect(
    x + BORDER_THICKNESS, y + BORDER_THICKNESS,
    x + w - BORDER_THICKNESS * 0.2, textTopY - BORDER_THICKNESS * 0.2, true)
  for i = -numStripes, numStripes do
    local offset = i * STRIPE_WIDTH + STRIPE_WIDTH
    for t = 0, LINE_THICKNESS - 1 do
      surface.DrawLine(x + offset + t, y, x + offset - h + t, y + h)
    end
  end
  render.SetScissorRect(0, 0, 0, 0, false)

  -- Bottom stripe band (below label)
  render.SetScissorRect(
    x + BORDER_THICKNESS, textBottomY,
    x + w - BORDER_THICKNESS * 0.2, y + h, true)
  for i = -numStripes, numStripes do
    local offset = i * STRIPE_WIDTH + STRIPE_WIDTH
    for t = 0, LINE_THICKNESS - 1 do
      surface.DrawLine(x + offset + t, y, x + offset - h + t, y + h)
    end
  end
  render.SetScissorRect(0, 0, 0, 0, false)

  -- Accent border
  surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 255)
  versus.util.drawRoundedOutline(BORDER_RADIUS, x, y, w, h, BORDER_THICKNESS)

  -- Label
  draw.SimpleText(text, "VersusHeading2",
    x + w / 2, textY,
    ColorAlpha(accentColor, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

  return isHovering
end
