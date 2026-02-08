local PLUGIN = PLUGIN
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Housing Chest"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.Model = "models/props_forest/footlocker01_closed.mdl"

if not SERVER then
  function ENT:Draw()
    self:DrawModel()

    local min, max = self:GetRenderBounds()
    local pos = self:GetPos() + Vector(0, 0, max.z + 4) -- Position above the entity
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.1)

    local y = 0
    local textWidth, textHeight = draw.SimpleText(
      "Chest",
      "VersusHeading2",
      0,
      y,
      color,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
    y = y + (textHeight * .7)

    cam.End3D2D()
  end

  return
end

function ENT:Initialize()
  self:SetModel(self.Model)
  self:SetSolid(SOLID_VPHYSICS)
  self:SetUseType(SIMPLE_USE)
  self:PhysicsInit(SOLID_VPHYSICS)
  self:SetMoveType(MOVETYPE_VPHYSICS)

  -- Freeze
  local phys = self:GetPhysicsObject()
  if IsValid(phys) then
    phys:EnableMotion(false)
  end
end

function ENT:Use(activator, caller)
  if (versus.util.throttled("housing_chest_use", 1, activator)) then
    return
  end

  self:EmitSound("buttons/button18.wav")

  if not IsValid(activator) or not activator:IsPlayer() then
    return
  end

  if not self._RoomID then
    versus.message.notify(activator, "This chest is not configured!", NOTIFY_ERROR)
    return
  end

  local chestName = self._RoomID
  local namedInventory = versus.inventory.getNamedInventory(activator, chestName)

  -- Create the inventory if it doesn't exist
  if not namedInventory then
    local maxSize = versus.config["Chest Inventory Size"]
    versus.inventory.createNamedInventory(activator, chestName, maxSize)
  end

  -- Network the inventory and open it for the player (with chest position)
  versus.inventory.networkNamedInventory(activator, chestName, self:GetPos())

  net.Start("versus.inventory.namedInventory.open")
  net.WriteString(chestName)
  net.Send(activator)
end

function ENT:SetupRoomID(roomID)
  self._RoomID = roomID
end
