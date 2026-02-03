local UNIT = UNIT

function UNIT.hook:HUDShouldDraw(name)
  if (name == "CHudWeaponSelection") then
    return false
  end
end

do
  local PANEL = {}

  function PANEL:Init()
    self:SetSize(400, 0)

    self.weapons = {}
    self.selectedIndex = 1
    self.alpha = 0
    self.targetAlpha = 0
    self.lastActivity = 0
    self.fadeDelay = 2

    self.bgColor = Color(25, 35, 50, 220)
    self.accentColor = Color(80, 140, 220, 255)
    self.selectedColor = Color(112, 193, 179, 255)
    self.textColor = Color(220, 230, 240, 255)
    self.dimmedColor = Color(141, 153, 174, 255)
    self.activeColor = Color(100, 255, 100, 255)

    self.weaponHeight = 48
    self.spacing = 4
  end

  function PANEL:UpdateWeapons()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    self.weapons = {}

    for _, weapon in pairs(ply:GetWeapons()) do
      if IsValid(weapon) then
        table.insert(self.weapons, weapon)
      end
    end

    -- Sort weapons by slot and slot position
    table.sort(self.weapons, function(a, b)
      local slotA = a:GetSlot()
      local slotB = b:GetSlot()

      if slotA == slotB then
        return (a:GetSlotPos() or 0) < (b:GetSlotPos() or 0)
      end

      return slotA < slotB
    end)

    -- Make sure selected index is valid
    if self.selectedIndex > #self.weapons then
      self.selectedIndex = #self.weapons
    end
    if self.selectedIndex < 1 then
      self.selectedIndex = 1
    end
  end

  function PANEL:GetActiveWeapon()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    return ply:GetActiveWeapon()
  end

  function PANEL:SetToCurrentWeapon()
    local activeWeapon = self:GetActiveWeapon()
    if not IsValid(activeWeapon) then return end

    for i, weapon in ipairs(self.weapons) do
      if weapon == activeWeapon then
        self.selectedIndex = i
        return
      end
    end
  end

  function PANEL:NextWeapon()
    if #self.weapons == 0 then return end

    self.selectedIndex = self.selectedIndex + 1
    if self.selectedIndex > #self.weapons then
      self.selectedIndex = 1
    end

    self.lastActivity = CurTime()
    self.targetAlpha = 255
    surface.PlaySound("ui/buttonrollover.wav")
  end

  function PANEL:PreviousWeapon()
    if #self.weapons == 0 then return end

    self.selectedIndex = self.selectedIndex - 1
    if self.selectedIndex < 1 then
      self.selectedIndex = #self.weapons
    end

    self.lastActivity = CurTime()
    self.targetAlpha = 255
    surface.PlaySound("ui/buttonrollover.wav")
  end

  function PANEL:ConfirmSelection()
    if #self.weapons == 0 then return end

    local weapon = self.weapons[self.selectedIndex]
    if IsValid(weapon) then
      input.SelectWeapon(weapon)
      self.targetAlpha = 0
    end
  end

  function PANEL:Think()
    self:UpdateWeapons()

    -- Smooth alpha transition
    self.alpha = Lerp(FrameTime() * 10, self.alpha, self.targetAlpha)

    -- Auto-fade after inactivity
    if self.targetAlpha > 0 and CurTime() - self.lastActivity > self.fadeDelay then
      self.targetAlpha = 0
    end

    -- Update position to stay anchored to bottom-right
    self:SetTall(#self.weapons * (self.weaponHeight + self.spacing) - self.spacing + 16)
    self:SetPos(ScrW() - self:GetWide() - (GAMEMODE.SPACING or 20), ScrH() - self:GetTall() - (GAMEMODE.SPACING or 20))
  end

  function PANEL:Paint(w, h)
    if self.alpha < 1 then return end

    local yPos = 0
    local activeWeapon = self:GetActiveWeapon()

    -- Draw weapons
    for i, weapon in ipairs(self.weapons) do
      yPos = self:DrawWeapon(weapon, i, yPos, w, activeWeapon)
    end
  end

  function PANEL:DrawWeapon(weapon, index, yPos, w, activeWeapon)
    if not IsValid(weapon) then return yPos end

    local isSelected = (self.selectedIndex == index)
    local isActive = (activeWeapon == weapon)

    -- Weapon background
    local weaponBgColor = isSelected and ColorAlpha(Color(35, 45, 65, 255), self.alpha) or
        ColorAlpha(Color(30, 40, 55, 255), self.alpha * 0.8)
    surface.SetDrawColor(weaponBgColor)
    surface.DrawRect(8, yPos, w - 16, self.weaponHeight)

    -- Selection/Active indicator
    local indicatorColor
    if isActive then
      indicatorColor = ColorAlpha(self.activeColor, self.alpha)
    elseif isSelected then
      indicatorColor = ColorAlpha(self.selectedColor, self.alpha)
    else
      indicatorColor = ColorAlpha(Color(60, 70, 85, 255), self.alpha * 0.5)
    end

    surface.SetDrawColor(indicatorColor)
    surface.DrawRect(8, yPos, 3, self.weaponHeight)

    -- Active weapon pulse effect
    if isActive then
      local pulse = math.abs(math.sin(CurTime() * 3)) * 0.3 + 0.7
      surface.SetDrawColor(ColorAlpha(self.activeColor, self.alpha * pulse * 0.3))
      surface.DrawRect(8, yPos, w - 16, self.weaponHeight)
    end

    -- Selected weapon highlight
    if isSelected then
      local highlightColor = ColorAlpha(self.selectedColor, self.alpha * 0.2)
      surface.SetDrawColor(highlightColor)
      surface.DrawRect(8, yPos, w - 16, self.weaponHeight)
    end

    -- Weapon slot indicator (small number on left)
    local slot = weapon:GetSlot() + 1
    surface.SetFont("VersusDefault")
    local slotText = tostring(slot)
    local slotW, slotH = surface.GetTextSize(slotText)

    local slotColor = ColorAlpha(self.dimmedColor, self.alpha * 0.6)
    surface.SetTextColor(slotColor)
    surface.SetTextPos(20, yPos + self.weaponHeight / 2 - slotH / 2)
    surface.DrawText(slotText)

    -- Weapon name
    surface.SetFont("VersusDefault")
    local weaponName = weapon:GetPrintName() or weapon:GetClass()
    local nameW, nameH = surface.GetTextSize(weaponName)

    local nameColor = isActive and ColorAlpha(self.activeColor, self.alpha) or
        (isSelected and ColorAlpha(self.textColor, self.alpha) or ColorAlpha(self.dimmedColor, self.alpha))
    surface.SetTextColor(nameColor)
    surface.SetTextPos(44, yPos + self.weaponHeight / 2 - nameH / 2)
    surface.DrawText(weaponName)

    -- Ammo display
    if weapon.Primary and weapon:Clip1() >= 0 then
      surface.SetFont("VersusDefault")
      local ammoText = string.format("%d / %d", weapon:Clip1(),
        LocalPlayer():GetAmmoCount(weapon:GetPrimaryAmmoType() or -1))
      local ammoW, ammoH = surface.GetTextSize(ammoText)

      local ammoColor = ColorAlpha(self.textColor, self.alpha)
      surface.SetTextColor(ammoColor)
      surface.SetTextPos(w - ammoW - 24, yPos + self.weaponHeight / 2 - ammoH / 2)
      surface.DrawText(ammoText)
    end

    return yPos + self.weaponHeight + self.spacing
  end

  vgui.Register("versus_WeaponSelection", PANEL, "EditablePanel")
end

function UNIT:CreateWeaponSelection()
  if IsValid(self.weaponSelection) then
    self.weaponSelection:Remove()
  end

  self.weaponSelection = vgui.Create("versus_WeaponSelection")
end

function UNIT:ShowWeaponSelection()
  if not IsValid(self.weaponSelection) then
    self:CreateWeaponSelection()
  end

  self.weaponSelection:SetToCurrentWeapon()
  self.weaponSelection.targetAlpha = 255
  self.weaponSelection.lastActivity = CurTime()
end

function UNIT:HideWeaponSelection()
  if IsValid(self.weaponSelection) then
    self.weaponSelection.targetAlpha = 0
  end
end

-- Hook into weapon slot selection
function UNIT.hook:PlayerBindPress(ply, bind, pressed, code)
  if not pressed then return end

  -- Slot selection (1-6) - show menu at current weapon
  local slot = string.match(bind, "slot(%d)")
  if slot then
    UNIT:ShowWeaponSelection()
    return
  end

  -- Weapon cycling
  if bind == "invnext" then
    if not IsValid(UNIT.weaponSelection) then
      UNIT:CreateWeaponSelection()
    end

    if UNIT.weaponSelection.targetAlpha == 0 then
      UNIT:ShowWeaponSelection()
    end

    UNIT.weaponSelection:NextWeapon()
    return true
  elseif bind == "invprev" then
    if not IsValid(UNIT.weaponSelection) then
      UNIT:CreateWeaponSelection()
    end

    if UNIT.weaponSelection.targetAlpha == 0 then
      UNIT:ShowWeaponSelection()
    end

    UNIT.weaponSelection:PreviousWeapon()
    return true
  end

  -- Confirm selection with attack
  if IsValid(UNIT.weaponSelection) and UNIT.weaponSelection.targetAlpha > 0 then
    if bind == "+attack" then
      UNIT.weaponSelection:ConfirmSelection()
      return true
    end
  end
end

-- Initialize on client spawn
function UNIT.hook:InitPostEntity()
  UNIT:CreateWeaponSelection()
end

UNIT:CreateWeaponSelection()
