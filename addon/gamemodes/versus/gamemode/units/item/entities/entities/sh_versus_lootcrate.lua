ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Loot Crate"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.AutomaticFrameAdvance = true

if (not SERVER) then
  return
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
  self._IsOpen = false

  self:ResetSequence(self:LookupSequence("idle"))
end

function ENT:SetItems(items)
  self._Items = items or {}

  PrintTable(self._Items)

  -- Update network variables to show item count
  self:SetNWInt("versus_ItemCount", #self._Items)
end

function ENT:GetItems()
  return self._Items
end

function ENT:GetRemainingItemCount()
  return #self._Items
end

function ENT:Use(activator, caller)
  if (not activator:IsPlayer()) then
    return
  end

  -- Don't allow interaction while opening/closing
  if (self._IsOpening) then
    return
  end

  -- No items left
  if (#self._Items == 0) then
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

  -- Play opening animation
  local openSeq = self:LookupSequence("open")
  self:ResetSequence(openSeq)
  self:SetPlaybackRate(1)

  -- Play satisfying opening sound
  self:EmitSound("items/ammocrate_open.wav", 75, 100, 0.8)

  self:GiveItemsToPlayer(activator)

  timer.Simple(0.2, function()
    if (not IsValid(self)) then
      return
    end
    if (not IsValid(activator)) then
      self._IsOpening = false
      return
    end

    self._IsOpen = true
  end)
end

function ENT:GiveItemsToPlayer(activator)
  local itemsGiven = {}
  local itemsRemaining = {}

  -- Try to give each item to the player
  for i, item in ipairs(self._Items) do
    if (versus.inventory.canFit(activator, item.size)) then
      if (hook.Run("PlayerCanPickupVersusItem", activator, self, item) ~= false) then
        versus.inventory.giveItem(activator, item)
        hook.Run("PlayerPickedUpVersusItem", activator, self, item)
        table.insert(itemsGiven, item)
      else
        table.insert(itemsRemaining, item)
      end
    else
      table.insert(itemsRemaining, item)
    end
  end

  -- Update items list
  self._Items = itemsRemaining
  self:SetNWInt("versus_ItemCount", #self._Items)

  if (#itemsRemaining > 0) then
    versus.message.notify(activator, string.format("%d item%s remaining (no inventory space)",
      #itemsRemaining, #itemsRemaining == 1 and "" or "s"), NOTIFY_ERROR)
  end

  -- Close the crate or remove it
  timer.Simple(0.5, function()
    if (not IsValid(self)) then return end

    if (#self._Items > 0) then
      -- Items remain, close the crate
      self:CloseCrate()
    else
      -- All items taken, play a satisfying closing sound and remove
      self:EmitSound("items/ammocrate_close.wav", 75, 100, 0.6)

      timer.Simple(0.8, function()
        if (IsValid(self)) then
          self:Remove()
        end
      end)
    end
  end)
end

function ENT:CloseCrate()
  -- Play closing animation
  local closeSeq = self:LookupSequence("close")
  self:ResetSequence(closeSeq)
  self:SetPlaybackRate(1)

  -- Play closing sound
  self:EmitSound("items/ammocrate_close.wav", 75, 100, 0.6)

  timer.Simple(1, function()
    if (not IsValid(self)) then return end

    self._IsOpening = false
    self._IsOpen = false

    -- Set to idle/closed state
    self:ResetSequence(self:LookupSequence("idle"))
  end)
end

function ENT:Think()
  -- Handle animation cycling
  if (self._IsOpening and not self._IsOpen) then
    self:NextThink(CurTime())
    return true
  end

  self:NextThink(CurTime() + 0.1)
  return true
end
