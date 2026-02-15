local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)

    self.alpha = 0
    self.targetAlpha = 0
    self.fadeInSpeed = 4
    self.fadeOutSpeed = 2.5
    self.displayDuration = 5
    self.startTime = CurTime()
    self.animStartTime = CurTime()

    -- "fadein", "display", "fadeout"
    self.state = "fadein"

    -- Staggered animation delays for elements
    self.titleDelay = 0.15
    self.accentDelay = 0.05
    self.cornerDelay = 0.25

    self.overlayColor = Color(8, 10, 14, 220)
    self.bgColor = Color(18, 22, 28, 245)
    self.bgGradientColor = Color(28, 32, 38, 245)
    self.accentColor = Color(255, 65, 54, 255) -- Vibrant red
    self.accentGlowColor = Color(255, 100, 90, 180)
    self.textColor = Color(245, 248, 252, 255)
    self.subtextColor = Color(160, 170, 185, 255)
    self.cornerColor = Color(200, 210, 220, 255)
    self.scanlineColor = Color(255, 65, 54, 40)

    self.title = "ELIMINATED"
    self.subtitle = ""

    -- Particle system for impact
    self.particles = {}
    for i = 1, 150 do
      table.insert(self.particles, {
        x = math.Rand(-200, 200),
        y = math.Rand(-200, 200),
        vx = math.Rand(-250, 250),
        vy = math.Rand(-250, 250),
        size = math.Rand(1, 4),
        life = math.Rand(1, 5),
        decay = math.Rand(0.6, 1.2)
      })
    end
  end

  function PANEL:SetSubtitle(text)
    self.subtitle = text or ""
  end

  function PANEL:Think()
    local elapsed = CurTime() - self.startTime

    -- State machine for fade in -> display -> fade out
    if self.state == "fadein" then
      self.targetAlpha = 255
      if self.alpha >= 254 then
        self.state = "display"
        self.startTime = CurTime()
      end
    elseif self.state == "display" then
      self.targetAlpha = 255
      if elapsed >= self.displayDuration then
        self.state = "fadeout"
        self.startTime = CurTime()
      end
    elseif self.state == "fadeout" then
      self.targetAlpha = 0
      if self.alpha <= 1 then
        self:Remove()
        return
      end
    end

    -- Smooth alpha transition
    local speed = self.state == "fadeout" and self.fadeOutSpeed or self.fadeInSpeed
    self.alpha = Lerp(FrameTime() * speed, self.alpha, self.targetAlpha)

    -- Update particles
    for _, particle in ipairs(self.particles) do
      particle.x = particle.x + particle.vx * FrameTime()
      particle.y = particle.y + particle.vy * FrameTime()
      particle.life = particle.life - particle.decay * FrameTime()
    end
  end

  function PANEL:Paint(w, h)
    local alpha = self.alpha
    if alpha < 1 then
      return
    end

    local centerX = w / 2
    local centerY = h / 2
    local time = CurTime() - self.animStartTime -- Use separate animation timer

    surface.SetDrawColor(ColorAlpha(self.overlayColor, alpha * 0.95))
    surface.DrawRect(0, 0, w, h)

    -- Subtle scanlines for CRT/tactical display effect
    for i = 0, h, 8 do
      local scanAlpha = alpha * 0.03 * math.sin(time * 8 + i * 0.1) * 0.5
      surface.SetDrawColor(ColorAlpha(self.scanlineColor, math.abs(scanAlpha)))
      surface.DrawRect(0, i, w, 6)
    end

    -- Calculate element alphas with stagger
    local titleAlpha = math.Clamp((time - self.titleDelay) / 0.3, 0, 1) * alpha
    local accentAlpha = math.Clamp((time - self.accentDelay) / 0.4, 0, 1) * alpha
    local cornerAlpha = math.Clamp((time - self.cornerDelay) / 0.35, 0, 1) * alpha

    -- Main title container
    local titleW = 900
    local titleH = 140

    local titleX = centerX - titleW / 2
    local titleY = centerY - titleH / 2

    -- Title text with subtle animation
    local titleYOffset = (1 - titleAlpha / alpha) * 20

    draw.SimpleText(
      self.title,
      "VersusHeadingHuge",
      centerX,
      titleY + titleH / 2 - titleYOffset,
      ColorAlpha(self.textColor, titleAlpha),
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )

    -- Subtitle with tactical mono font feel
    if self.subtitle ~= "" then
      draw.SimpleText(
        self.subtitle,
        "VersusDefault",
        centerX,
        titleY + titleH * 0.75,
        ColorAlpha(self.subtextColor, titleAlpha * 0.9),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
      )
    end

    -- Particle debris effect
    for _, particle in ipairs(self.particles) do
      if particle.life > 0 then
        local px = centerX + particle.x
        local py = centerY + particle.y
        local pAlpha = alpha * math.Clamp(particle.life, 0, 1) * 0.5

        surface.SetDrawColor(ColorAlpha(self.accentColor, pAlpha * 0.6))
        surface.DrawRect(px, py, particle.size, particle.size)
      end
    end

    -- Screen frame corners - properly positioned and opaque
    self:DrawCornerFrame(40, 40, 80, 4, cornerAlpha, false, false)
    self:DrawCornerFrame(w - 40, 40, 80, 4, cornerAlpha, true, false)
    self:DrawCornerFrame(40, h - 40, 80, 4, cornerAlpha, false, true)
    self:DrawCornerFrame(w - 40, h - 40, 80, 4, cornerAlpha, true, true)
  end

  -- Draw corner lines that meet perfectly at the corner point without overlapping
  function PANEL:DrawCornerFrame(x, y, size, thickness, alpha, flipX, flipY)
    -- Vertical line - extends fully to corner
    if flipY then
      surface.SetDrawColor(ColorAlpha(self.cornerColor, alpha * 0.7))
      surface.DrawRect(x - thickness / 2, y - size, thickness, size + thickness / 2)
    else
      surface.SetDrawColor(ColorAlpha(self.cornerColor, alpha * 0.7))
      surface.DrawRect(x - thickness / 2, y - thickness / 2, thickness, size + thickness / 2)
    end

    -- Horizontal line - shortened to not overlap with vertical
    if flipX then
      surface.SetDrawColor(ColorAlpha(self.cornerColor, alpha * 0.7))
      surface.DrawRect(x - size, y - thickness / 2, size - thickness / 2, thickness)
    else
      surface.SetDrawColor(ColorAlpha(self.cornerColor, alpha * 0.7))
      surface.DrawRect(x + thickness / 2, y - thickness / 2, size - thickness / 2, thickness)
    end
  end

  vgui.Register("versus_EliminationScreen", PANEL, "EditablePanel")
end
