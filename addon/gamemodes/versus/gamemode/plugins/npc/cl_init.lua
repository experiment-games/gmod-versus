local PLUGIN = PLUGIN

local ESCORT_BAR_WIDTH = 160
local ESCORT_BAR_HEIGHT = 22

-- world-space scale; bar ends up ~22 units wide
local ESCORT_SCALE = 0.14

-- units above the NPC's origin (above the head)
local ESCORT_Z_OFFSET = 90

local color_escort_bg = Color(25, 35, 50, 220)
local color_escort_bg_dark = Color(20, 28, 40, 200)

-- matches color_red
local color_escort_health = Color(242, 95, 92)
local color_escort_text = Color(220, 230, 240, 255)

-- distance at which alpha is 255
local ESCORT_FADE_FULL = 512

-- distance at which alpha is 0
local ESCORT_FADE_GONE = 600

function PLUGIN.hook:PostDrawTranslucentRenderables(isDepth, isDrawingViewModel)
  if isDepth or isDrawingViewModel then
    return
  end

  local eyePos = EyePos()
  local selfPos = LocalPlayer():GetPos()

  for _, ent in ipairs(ents.FindInSphere(selfPos, ESCORT_FADE_GONE)) do
    if not IsValid(ent) or not ent:GetNWBool("VersusEscortNPC", false) then
      continue
    end

    local health = ent:Health()
    local maxHealth = ent:GetMaxHealth()

    if maxHealth <= 0 then continue end

    local healthPercent = math.Clamp(health / maxHealth, 0, 1)

    -- Compute distance-based alpha (full at ESCORT_FADE_FULL, zero at ESCORT_FADE_GONE)
    local dist = selfPos:Distance(ent:GetPos())
    local alpha = 255 * (1 - math.Clamp((dist - ESCORT_FADE_FULL) / (ESCORT_FADE_GONE - ESCORT_FADE_FULL), 0, 1))

    if alpha <= 0 then
      continue
    end

    -- Billboard position above the NPC's head
    local pos = ent:GetPos() + Vector(0, 0, ESCORT_Z_OFFSET)

    -- Face the camera
    local ang = (eyePos - pos):Angle()

    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, ESCORT_SCALE)
    local bw = ESCORT_BAR_WIDTH
    local bh = ESCORT_BAR_HEIGHT
    local bx = -bw / 2
    local by = -bh / 2

    -- Background
    surface.SetDrawColor(ColorAlpha(color_escort_bg, color_escort_bg.a * alpha / 255))
    surface.DrawRect(bx, by, bw, bh)

    -- Left accent bar
    surface.SetDrawColor(ColorAlpha(color_escort_health, alpha))
    surface.DrawRect(bx, by, 4, bh)

    -- Inner dark background
    local pad = 4
    local ix = bx + pad + 4
    local iy = by + pad
    local iw = bw - pad * 2 - 4
    local ih = bh - pad * 2

    surface.SetDrawColor(ColorAlpha(color_escort_bg_dark, color_escort_bg_dark.a * alpha / 255))
    surface.DrawRect(ix, iy, iw, ih)

    -- Health fill
    surface.SetDrawColor(ColorAlpha(color_escort_health, alpha))
    surface.DrawRect(ix, iy, iw * healthPercent, ih)

    cam.End3D2D()
  end
end

-- Fade out bodies after death and remove them after a certain time to prevent clutter and lag
function PLUGIN.hook:CreateClientsideRagdoll(entity, ragdoll)
  versus.util.decayEntity(ragdoll, 5)
end

--[[
  Net Messages
--]]

net.Receive("versus.npc.openNPCMenu", function(len, player)
  local menuClass = net.ReadString()
  local argCount = net.ReadUInt(3)
  local args = {}

  for i = 1, argCount do
    table.insert(args, net.ReadType())
  end

  if (hook.Run("OnNPCMenuOpen", player, menuClass, unpack(args)) ~= nil) then
    return
  end

  local menu = vgui.Create(menuClass)

  if (IsValid(menu)) then
    menu:Populate(unpack(args))
    menu:MakePopup()
  else
    print("Failed to create NPC menu: " .. menuClass)
  end
end)
