local PLUGIN = PLUGIN

--[[
  Client-side spectating state, populated by net messages from the server.
--]]

PLUGIN.spectating = PLUGIN.spectating or {
  active     = false, -- true while this client is in a spectating session
  hasTarget  = false, -- true when a live target is currently being shown
  targetName = "",    -- display name of the spectated player
  index      = 0,     -- 1-based position in the target list
  total      = 0,     -- total number of targets (including dead / not-yet-connected)
}

--[[
  Net message receivers
--]]

net.Receive("versus.spectating.state", function()
  local hasTarget              = net.ReadBool()
  local targetName             = net.ReadString()
  local index                  = net.ReadUInt(4)
  local total                  = net.ReadUInt(4)

  PLUGIN.spectating.active     = true
  PLUGIN.spectating.hasTarget  = hasTarget
  PLUGIN.spectating.targetName = targetName
  PLUGIN.spectating.index      = index
  PLUGIN.spectating.total      = total
end)

net.Receive("versus.spectating.end", function()
  PLUGIN.spectating.active = false
end)

--[[
  Console commands — bound by the player so they can customise the keys.
  Default suggested bindings (shown in the HUD hint):
    bind MOUSE1 versus_spectate_next
    bind MOUSE2 versus_spectate_prev
  Players can set these however they like; we look up the actual binding at draw time.
--]]

concommand.Add("versus_spectate_next", function()
  if not PLUGIN.spectating.active then return end

  net.Start("versus.spectating.cycle")
  net.WriteInt(1, 4)
  net.SendToServer()
end, nil, "Cycle to the next spectate target (use while dead in Endurance mode).")

concommand.Add("versus_spectate_prev", function()
  if not PLUGIN.spectating.active then return end

  net.Start("versus.spectating.cycle")
  net.WriteInt(-1, 4)
  net.SendToServer()
end, nil, "Cycle to the previous spectate target (use while dead in Endurance mode).")

--[[
  Hooks
--]]

-- If the binds are not set, listen to the +attack and +attack2 inputs as a fallback so the player can still use the feature.
function PLUGIN.hook:PlayerBindPress(player, bind, pressed, code)
  if not PLUGIN.spectating.active then return end

  local bindingNext, hasNext = versus.message.lookupBinding("versus_spectate_next")
  local bindingPrev, hasPrev = versus.message.lookupBinding("versus_spectate_prev")

  if (not hasNext and (bind == "+attack" or bind == "attack")) then
    net.Start("versus.spectating.cycle")
    net.WriteInt(1, 4)
    net.SendToServer()
    return true
  end

  if (not hasPrev and (bind == "+attack2" or bind == "attack2")) then
    net.Start("versus.spectating.cycle")
    net.WriteInt(-1, 4)
    net.SendToServer()
    return true
  end
end

--[[
  HUD
--]]

local COLOR_BG     = Color(10, 14, 20, 200)
local COLOR_LABEL  = Color(150, 165, 185, 255)
local COLOR_NAME   = Color(220, 230, 240, 255)
local COLOR_DIM    = Color(110, 125, 145, 255)
local COLOR_KEY    = Color(190, 200, 215, 255)
local COLOR_KEY_BG = Color(35, 45, 60, 220)

local PAD_H        = 14 -- horizontal padding inside the bar
local PAD_V        = 9  -- vertical padding inside the bar
local MARGIN       = 18 -- distance from the bottom of the screen

local FONT_LABEL   = "VersusDefault"
local FONT_NAME    = "VersusHeading2"

--- Returns the key bound to `cmd`, or `fallback` when nothing is bound.
local function boundKey(cmd, fallback)
  local binding, isFound = versus.message.lookupBinding(cmd)

  if not isFound then
    binding = fallback:upper()
  end

  return binding
end

--- Draws a small key-cap badge at (`x`, `y`) centred vertically on `midY`.
--- Returns the total width consumed.
local function drawKeyCap(label, x, midY)
  surface.SetFont(FONT_LABEL)

  local tw, th = surface.GetTextSize(label)
  local bw     = tw + 10
  local bh     = th + 6
  local bx     = x
  local by     = midY - bh / 2

  draw.RoundedBox(4, bx, by, bw, bh, COLOR_KEY_BG)
  surface.SetFont(FONT_LABEL)
  surface.SetTextColor(COLOR_KEY)
  surface.SetTextPos(bx + 5, by + 3)
  surface.DrawText(label)

  return bw
end

function PLUGIN.hook:HUDPaint()
  local state = PLUGIN.spectating

  if not state.active then return end

  local scrW = ScrW()
  local scrH = ScrH()

  surface.SetFont(FONT_LABEL)
  local labelText = "SPECTATING"
  local lw, lh    = surface.GetTextSize(labelText)

  local sepText   = "  ·  "
  local sepW, _   = surface.GetTextSize(sepText)

  local countText = state.hasTarget
      and string.format("(%d / %d)", state.index, state.total)
      or "(no live targets)"
  local cw, _     = surface.GetTextSize(countText)

  surface.SetFont(FONT_NAME)
  local targetText = state.hasTarget and state.targetName or "—"
  local tw, th     = surface.GetTextSize(targetText)

  local keyNext    = boundKey("versus_spectate_next", "MOUSE1")
  local keyPrev    = boundKey("versus_spectate_prev", "MOUSE2")

  surface.SetFont(FONT_LABEL)
  local knw, _  = surface.GetTextSize(keyNext)
  local kpw, _  = surface.GetTextSize(keyPrev)
  local keyCapW = knw + kpw + 10 + 10 + 10 + 10 + 10 -- rough cap sizing
  local capGap  = 12                                 -- gap between key-caps and the rest

  -- Bar height driven by the name font.
  local barH    = th + PAD_V * 2
  local textY   = scrH - MARGIN - barH

  -- Inner content: [keyPrev] gap  "SPECTATING · name · count"  gap [keyNext]
  local innerW  = (kpw + 10) + capGap + lw + sepW + tw + sepW + cw + capGap + (knw + 10)
  local barW    = innerW + PAD_H * 2
  local barX    = (scrW - barW) / 2
  local midY    = textY + barH / 2

  -- Background pill
  draw.RoundedBox(6, barX, textY, barW, barH, COLOR_BG)

  local cursor = barX + PAD_H

  -- Previous key-cap
  local capH = drawKeyCap(keyPrev, cursor, midY)
  cursor = cursor + capH + capGap

  -- "SPECTATING" label
  surface.SetFont(FONT_LABEL)
  surface.SetTextColor(COLOR_LABEL)
  surface.SetTextPos(cursor, midY - lh / 2)
  surface.DrawText(labelText)
  cursor = cursor + lw

  -- Separator
  surface.SetFont(FONT_LABEL)
  surface.SetTextColor(COLOR_DIM)
  surface.SetTextPos(cursor, midY - lh / 2)
  surface.DrawText(sepText)
  cursor = cursor + sepW

  -- Player name (larger font)
  surface.SetFont(FONT_NAME)
  surface.SetTextColor(COLOR_NAME)
  surface.SetTextPos(cursor, midY - th / 2)
  surface.DrawText(targetText)
  cursor = cursor + tw

  -- Separator
  surface.SetFont(FONT_LABEL)
  surface.SetTextColor(COLOR_DIM)
  surface.SetTextPos(cursor, midY - lh / 2)
  surface.DrawText(sepText)
  cursor = cursor + sepW

  -- Count "(index / total)"
  surface.SetFont(FONT_LABEL)
  surface.SetTextColor(COLOR_LABEL)
  surface.SetTextPos(cursor, midY - lh / 2)
  surface.DrawText(countText)
  cursor = cursor + cw + capGap

  -- Next key-cap
  drawKeyCap(keyNext, cursor, midY)
end
