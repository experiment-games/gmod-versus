ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Loot Crate"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true

if (not SERVER) then
  return
end

--- Returns the unique chest name used for this crate's world inventory.
function ENT:GetChestName()
  return "lootcrate_" .. self:EntIndex()
end

function ENT:Initialize()
  self:SetModel("models/items/ammocrate_grenade.mdl")
  self:SetMoveType(MOVETYPE_VPHYSICS)
  self:PhysicsInit(SOLID_VPHYSICS)
  self:SetSolid(SOLID_VPHYSICS)
  self:SetUseType(SIMPLE_USE)

  local physicsObject = self:GetPhysicsObject()

  if (IsValid(physicsObject)) then
    physicsObject:Wake()
    physicsObject:EnableMotion(true)
  end

  self._Items = self._Items or {}
  self._IsOpening = false

  -- Create a world (unsaved) named inventory and populate it with preset items.
  local chestName = self:GetChestName()
  local maxSize = 0

  for _, item in ipairs(self._Items) do
    maxSize = maxSize + (item.size or 1)
  end

  versus.inventory.createNamedInventory(nil, chestName, maxSize)

  for _, item in ipairs(self._Items) do
    versus.inventory.giveItemToNamedInventory(nil, chestName, item)
  end

  self:SetNWInt("versus_ItemCount", #self._Items)
  self:ResetSequence(self:LookupSequence("idle"))

  -- Watch for items being taken so we can remove the crate when it is empty.
  local hookName = "versus_lootcrate_" .. self:EntIndex()

  hook.Add("PlayerItemTakenFromNamedInventory", hookName, function(owner, takenChestName, item)
    if (not IsValid(self)) then
      hook.Remove("PlayerItemTakenFromNamedInventory", hookName)
      return
    end

    if (takenChestName ~= chestName) then
      return
    end

    local remaining = self:GetRemainingItemCount()
    self:SetNWInt("versus_ItemCount", remaining)

    if (remaining == 0) then
      self:EmitSound("items/ammocrate_close.wav", 75, 100, 0.6)

      -- 0.8s allows the closing sound to finish before the entity is removed.
      timer.Simple(0.8, function()
        if (IsValid(self)) then
          self:Remove()
        end
      end)
    end
  end)
end

function ENT:SetItems(items)
  self._Items = items or {}
end

function ENT:GetItems()
  return self._Items
end

function ENT:GetRemainingItemCount()
  local namedInventory = versus.inventory.getNamedInventory(nil, self:GetChestName())

  if (not namedInventory) then
    return 0
  end

  return table.Count(namedInventory.inventory)
end

function ENT:Use(activator, caller)
  if (not activator:IsPlayer()) then
    return
  end

  -- Don't allow opening while the animation is still playing.
  if (self._IsOpening) then
    return
  end

  if (self:GetRemainingItemCount() == 0) then
    versus.message.notify(activator, "This crate is empty", NOTIFY_ERROR)
    return
  end

  if (hook.Run("PlayerCanOpenVersusCrate", activator, self) == false) then
    return
  end

  self:OpenCrate(activator)
end

function ENT:OpenCrate(activator)
  self._IsOpening = true

  -- Play opening animation and sound.
  local openSeq = self:LookupSequence("open")
  self:ResetSequence(openSeq)
  self:SetPlaybackRate(1)
  self:EmitSound("items/ammocrate_open.wav", 75, 100, 0.8)

  -- Open the world inventory UI for the player once the animation has started.
  -- 0.2s matches the start of the opening animation so the UI appears in sync.
  timer.Simple(0.2, function()
    if (not IsValid(self)) then
      return
    end

    self._IsOpening = false

    if (not IsValid(activator)) then
      return
    end

    versus.inventory.openOrCreateNamedInventory(activator, self:GetChestName(), self, nil)
  end)
end

function ENT:OnRemove()
  local chestName = self:GetChestName()

  hook.Remove("PlayerItemTakenFromNamedInventory", "versus_lootcrate_" .. self:EntIndex())

  if (not versus or not versus.inventory) then
    return
  end

  -- Close the named inventory panel for any player currently viewing this crate.
  local watchers = versus.inventory.getPlayersWatchingInventory(chestName)

  for _, p in ipairs(watchers) do
    versus.inventory.closeNamedInventory(p)
    net.Start("versus.inventory.namedInventory.close")
    net.Send(p)
  end

  -- Clean up the world inventory so it is not kept in memory.
  versus.inventory.worldNamedInventories[chestName] = nil
end

function ENT:Think()
  self:NextThink(CurTime() + 0.1)
  return true
end
