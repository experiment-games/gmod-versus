ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Item"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false

if (not SERVER) then
  return
end

function ENT:Initialize()
  self:SetMoveType(MOVETYPE_VPHYSICS)
  self:PhysicsInit(SOLID_VPHYSICS)
  self:SetSolid(SOLID_VPHYSICS)
  self:SetUseType(SIMPLE_USE)

  local physicsObject = self:GetPhysicsObject()

  if (IsValid(physicsObject)) then
    physicsObject:Wake()
    physicsObject:EnableMotion(true)
  end
end

function ENT:SetItem(item)
  self._Item = item

  self:SetModel(item.model)

  self:SetNWString("versus_Name", item.name)
  self:SetNWInt("versus_Size", item.size)
end

function ENT:GetItem()
  return self._Item
end

function ENT:Use(activator, caller)
  if (not activator:IsPlayer()) then
    return
  end

  if (not versus.inventory.canFit(activator, self._Item.size)) then
    versus.message.notify(activator, "You have no inventory space for this", NOTIFY_ERROR)
    return
  end

  if (hook.Run("PlayerPickedUpItem", activator, self, self._Item) == false) then
    return
  end

  self:Remove()
  versus.inventory.giveItem(activator, self._Item)
  self._Item = nil
end
