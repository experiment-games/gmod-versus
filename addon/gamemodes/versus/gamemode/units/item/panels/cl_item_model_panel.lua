local PANEL = {}

--- Ensures item.onModelPanelLayoutEntity is called if it exists,
--- and applies skin and bodygroups as needed.
--- @param entity Entity The entity being laid out
function PANEL:LayoutEntity(entity)
  local item = self.item

  if (not item) then
    return
  end

  if (item.onModelPanelLayoutEntity and item:onModelPanelLayoutEntity(self, entity) == false) then
    return
  end

  if (item.skin) then
    entity:SetSkin(item.skin)
  end

  local bodygroups = item.getInventoryBodygroups and item:getInventoryBodygroups() or nil

  if (bodygroups ~= nil) then
    for bodygroupName, bodygroup in pairs(bodygroups) do
      local bodygroupID = entity:FindBodygroupByName(bodygroupName)

      entity:SetBodygroup(bodygroupID, bodygroup)
    end
  end
end

--- Ensures item.onModelPanelPreDraw and PostDraw  are called if they exist, so
--- items can draw extra stuff.
--- This is mostly copied from the default DModelPanel:Paint function:
--- https://github.com/Facepunch/garrysmod/blob/7b8a7fdd2320697a8557a78f20fb90f2b405b10b/garrysmod/lua/vgui/dmodelpanel.lua#L117-L152
--- @param w number Width of the panel
--- @param h number Height of the panel
function PANEL:Paint(w, h)
  if (not IsValid(self.Entity)) then
    return
  end

  local item = self.item

  if (not item) then
    return
  end

  local x, y = self:LocalToScreen(0, 0)

  self:LayoutEntity(self.Entity)

  local ang = self.aLookAngle

  if (not ang) then
    ang = (self.vLookatPos - self.vCamPos):Angle()
  end

  cam.Start3D(self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ)

  render.SuppressEngineLighting(true)
  render.SetLightingOrigin(self.Entity:GetPos())
  render.ResetModelLighting(self.colAmbientLight.r / 255, self.colAmbientLight.g / 255, self.colAmbientLight.b / 255)
  render.SetColorModulation(self.colColor.r / 255, self.colColor.g / 255, self.colColor.b / 255)
  render.SetBlend((self:GetAlpha() / 255) * (self.colColor.a / 255)) -- * surface.GetAlphaMultiplier()

  for i = 0, 6 do
    local col = self.DirectionalLight[i]
    if (col) then
      render.SetModelLighting(i, col.r / 255, col.g / 255, col.b / 255)
    end
  end

  if (item.onModelPanelPreDraw) then
    item:onModelPanelPreDraw(self, w, h, self.Entity)
  end

  self:DrawModel()

  if (item.onModelPanelPostDraw) then
    item:onModelPanelPostDraw(self, w, h, self.Entity)
  end

  render.SuppressEngineLighting(false)
  cam.End3D()

  self.LastPaint = RealTime()
end

--- Initializes the model panel with the given item. Calls item:initModelPanel if it exists.
--- @param item VersusItemInstance The item to set
function PANEL:SetItem(item)
  self.item = item

  if (not item) then
    return
  end

  local model, bone, attachment = item.model, item.modelBone, item.modelAttachment

  if (item.getInventoryModel) then
    model, bone, attachment = item:getInventoryModel()
  end

  self:SetModel(model)

  local targetPosition

  if (bone) then
    local entityBone = self.Entity:LookupBone(bone)
    targetPosition = self.Entity:GetBonePosition(entityBone)
    targetPosition:Add(Vector(0, 0, 1))
  elseif (attachment) then
    local entityAttachment = self.Entity:LookupAttachment(attachment)
    local angPos = self.Entity:GetAttachment(entityAttachment)

    if (angPos) then
      targetPosition = angPos.Pos
    end
  end

  if (targetPosition) then
    self:SetLookAt(targetPosition)
    self:SetCamPos(targetPosition - Vector(-14, 2, -3))
    self.Entity:SetEyeTarget(targetPosition - Vector(-12, -12, 0))
  else
    local minBound, maxBound = self.Entity:GetRenderBounds()
    local size = 0
    size = math.max(size, math.abs(minBound.x) + math.abs(maxBound.x))
    size = math.max(size, math.abs(minBound.y) + math.abs(maxBound.y))
    size = math.max(size, math.abs(minBound.z) + math.abs(maxBound.z))

    self:SetCamPos(Vector(size, size, size))
    self:SetLookAt((minBound + maxBound) * 0.5)
  end

  if (item.initModelPanel) then
    item:initModelPanel(self)
  end
end

vgui.Register("versus_ItemModelPanel", PANEL, "DModelPanel")
