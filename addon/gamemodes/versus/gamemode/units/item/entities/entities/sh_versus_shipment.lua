ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Shipment"
ENT.Author = "" -- joker
ENT.Model = "models/items/item_item_crate.mdl"
ENT.Spawnable = false
ENT.AdminSpawnable = false

if (not SERVER) then
  return
end

function ENT:Initialize()
  self:SetModel(self.Model)
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

function ENT:SetItems(items)
  self._Items = items

  local size = 0
  local MAX_SIZE = 199
  local AND_MORE = "and more..."
  local itemCounts = {}

  for _, item in pairs(items) do
    size = size + item.size

    itemCounts[item.itemID] = (itemCounts[item.itemID] or 0) + 1
  end

  local itemsString = ""

  for itemID, count in pairs(itemCounts) do
    local item = versus.item.get(itemID)

    if (itemsString ~= "") then
      itemsString = itemsString .. ", "
    end

    itemsString = itemsString .. count .. "× " .. item.name

    if (#itemsString > MAX_SIZE) then
      itemsString = string.sub(itemsString, 1, MAX_SIZE - #AND_MORE) .. AND_MORE
      break
    end
  end

  self:SetNWString("versus_Name", itemsString)
  self:SetNWInt("versus_Size", size)
  self._ItemsSize = size
end

function ENT:GetItems()
  return self._Items
end

function ENT:Use(activator, caller)
  if (not activator:IsPlayer()) then
    return
  end

  -- Reverse so we can remove from the end without issues
  for i = #self._Items, 1, -1 do
    local item = self._Items[i]

    if (not versus.inventory.canFit(activator, item.size)) then
      versus.message.notify(activator, "You have no inventory space for this", NOTIFY_ERROR)
      return
    end

    if (hook.Run("PlayerPickedUpItem", activator, self, item) == false) then
      return
    end

    versus.inventory.giveItem(activator, item)
    table.remove(self._Items, i)
  end

  if (#self._Items == 0) then
    self:Remove()
  end
end
