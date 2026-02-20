local UNIT = UNIT
local PANEL = {}

DEFINE_BASECLASS("DModelPanel")

function PANEL:Init()
  BaseClass.Init(self)

  self.isInteractable = true
  self.drawLocalPacOutfit = true
  self.currentYaw = 200
  self.isDragging = false
  self.lastMouseX = 0

  self:SetAmbientLight(Color(200, 200, 200, 255))
  self:Dock(FILL)
  self:SetFOV(45)
  self:SetLookAng(Angle(20, 0, 0))
  self:SetCamPos(Vector(-70, 0, 60))

  self:RefreshPlayerModel()
end

function PANEL:SetInteractable(isInteractable)
  self.isInteractable = isInteractable
end

function PANEL:SetDrawLocalPacOutfit(drawLocalPacOutfit)
  self.drawLocalPacOutfit = drawLocalPacOutfit
end

function PANEL:OnMousePressed(mouseCode)
  if (not self.isInteractable) then
    return
  end

  if (mouseCode == MOUSE_LEFT) then
    self.isDragging = true
    self.lastMouseX = gui.MouseX()
  end

  BaseClass.OnMousePressed(self, mouseCode)
end

function PANEL:OnMouseReleased(mouseCode)
  if (not self.isInteractable) then
    return
  end

  if (mouseCode == MOUSE_LEFT) then
    self.isDragging = false
  end

  BaseClass.OnMouseReleased(self, mouseCode)
end

function PANEL:OnCursorMoved(x, y)
  if (not self.isDragging) then
    return
  end

  local mouseX = gui.MouseX()
  local delta = mouseX - self.lastMouseX
  self.lastMouseX = mouseX
  self.currentYaw = (self.currentYaw + delta) % 360
end

function PANEL:LayoutEntity(entity)
  if (self.bAnimated) then
    self:RunAnimation()
  end

  entity:SetAngles(Angle(0, self.currentYaw, 0))
end

function PANEL:Paint(w, h)
  local entity = self:GetEntity()
  -- TODO: This looks directly at a models face. So needs improvement for hip/leg/etc attachments
  local cam_ang = self:GetLookAng()
  local cam_pos = self:GetCamPos()
  local cam_fov = self:GetFOV()

  -- TODO: Would be nice if we could freeze this image, the breathing animation is kind of ominous in large quantities
  -- TODO: None of the BaseAnimatingOverlay functions work here sadly, finding a sequence without the breath layer here would be wonderful: https://github.com/robotboy655/gmod-animations/blob/1ec11d7d92f23fe1359319421301ea0f97eb24d5/gm_anims.qci
  -- NOTE: T-pose idle anim: ent:ResetSequence(ent:LookupSequence("body_rot"))

  render.SuppressEngineLighting(true)

  self:LayoutEntity(entity)

  --DModelPanel.Paint(self,w,h)
  local x, y = self:LocalToScreen(0, 0)

  pac.DrawEntity2D(entity, x, y, w, h, cam_pos, cam_ang, cam_fov)

  render.SuppressEngineLighting(false)
end

function PANEL:UpdateBodygroup(bodygroups, bodygroupName)
  local bodygroupID = self.Entity:FindBodygroupByName(bodygroupName)
  local bodygroupKeys = table.GetKeys(bodygroups)
  local key = self.bodygroups[bodygroupName]

  self.Entity:SetBodygroup(bodygroupID, bodygroupKeys[key])
  return bodygroups[bodygroupKeys[key]]
end

function PANEL:UpdateModel(model)
  self.model = model
  self:SetModel(self.model)

  if (self.drawLocalPacOutfit) then
    local ent = self:GetEntity()

    if (IsValid(ent)) then
      hook.Run("CharacterLocalModelPanelUpdating", self, ent)
    end
  end

  local options = versus.player.getDefaultBodygroupOptions()

  for bodygroupName, bodygroup in pairs(versus.player.getDefaultBodygroups()) do
    if (options[bodygroupName]) then
      self:UpdateBodygroup(options[bodygroupName], bodygroupName)
    else
      local bodygroupID = self.Entity:FindBodygroupByName(bodygroupName)
      self.Entity:SetBodygroup(bodygroupID, bodygroup)
    end
  end

  return UNIT.getBaseModelNameFromModel(self.model)
end

function PANEL:SetBodygroupsTable(bodygroups)
  self.bodygroups = bodygroups
end

function PANEL:RefreshPlayerModel()
  local player = LocalPlayer()
  self.model = player:GetModel()
  self.bodygroups = {}

  -- TODO: This was taken from the character creator. I think there may be a bug in here if we use it for anything else, since we use getDefaultBodygroupOptions
  for bodygroupName, bodygroups in pairs(versus.player.getDefaultBodygroupOptions()) do
    local bodygroupKeys = table.GetKeys(bodygroups)
    self.bodygroups[bodygroupName] = 1

    local currentBodygroup = player["appearanceBodygroup_" .. bodygroupName]

    for i, key in pairs(bodygroupKeys) do
      if (key == currentBodygroup) then
        self.bodygroups[bodygroupName] = i
        break
      end
    end
  end
end

function PANEL:PerformLayout(width, height)
  BaseClass.PerformLayout(self, width, height)
end

vgui.Register("versus_Character_Model", PANEL, "DModelPanel")
