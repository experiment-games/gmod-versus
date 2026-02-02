--[[
	Pickup mostly by Lexi: https://github.com/Lexicality/applejack/tree/master/entities/weapons/cider_hands
--]]

SWEP.PrintName = "Actions"
SWEP.Author = ""
SWEP.Contact = ""

SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = ""

-- Set the animation prefix and some other settings.
SWEP.AnimPrefix = "admire"
SWEP.Spawnable = false
SWEP.AdminSpawnable = false

SWEP.DelayLong = 0.5
SWEP.DelayShort = 0.25

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Primary.Refire = 1
SWEP.Primary.Damage = 0
SWEP.Primary.Force = 0

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.IronSightPos = Vector(0, 0, 0)
SWEP.IronSightAng = Vector(0, 0, 0)
SWEP.NoIronSightFovChange = true
SWEP.NoIronSightAttack = true

function SWEP:Initialize()
  self.Primary.NextSwitch = CurTime()
  self:SetWeaponHoldType("normal")

  if (CLIENT) then
    self.Instructions = string.format(
      self.Instructions,
      versus.message.lookupBinding('+attack'),
      versus.message.lookupBinding('+attack2'),
      versus.message.lookupBinding('+speed'), versus.message.lookupBinding('+attack'),
      versus.message.lookupBinding('+speed'), versus.message.lookupBinding('+attack2'))
  end
end

function SWEP:PrimaryAttack()
  local trace = self:GetOwner():GetEyeTrace()

  self:SetNextPrimaryFire(CurTime() + self.DelayLong)

  if (trace.HitWorld or not trace.Hit or trace.StartPos:Distance(trace.HitPos) > 128) then
    return
  end

  if (not versus.door.isDoor(trace.Entity)) then
    return
  end

  if (not SERVER) then
    return
  end

  if (self:GetOwner():KeyDown(IN_SPEED)) then
    if (versus.door.isKnockable(trace.Entity, self:GetOwner())) then
      self:SetNextPrimaryFire(CurTime() + self.DelayShort)
      trace.Entity:EmitSound("physics/wood/wood_crate_impact_hard2.wav")
      self:SendWeaponAnim(ACT_VM_HITCENTER)
    end
  else
    -- Try to lock
    self:SetNextPrimaryFire(CurTime() + self.DelayShort)
    self:SetNextSecondaryFire(CurTime() + self.DelayShort)
    self:SendWeaponAnim(ACT_VM_HITCENTER)

    if (not versus.door.getPlayerHasAccess(trace.Entity, self:GetOwner())) then
      versus.message.notify(self:GetOwner(), "You do not have access to that lock!", NOTIFY_ERROR)
      return
    end

    if (not versus.door.isLocked(trace.Entity)) then
      versus.door.lockDoor(trace.Entity, true)
    end
  end
end

function SWEP:SecondaryAttack()
  self:SetNextSecondaryFire(CurTime() + self.DelayLong)

  -- Get a trace from the owner's eyes.
  local trace = self:GetOwner():GetEyeTrace()

  if (not IsValid(trace.Entity) or trace.HitWorld) then
    return
  end

  if (not versus.entity.isNearPosition(self:GetOwner(), trace.HitPos, 128)) then
    return
  end

  if (not SERVER) then
    return
  end

  if (self:GetOwner():KeyDown(IN_SPEED)) then
    self:PickUp(trace.Entity, trace)
  else
    -- Try to unlock
    self:SetNextPrimaryFire(CurTime() + self.DelayShort)
    self:SetNextSecondaryFire(CurTime() + self.DelayShort)
    self:SendWeaponAnim(ACT_VM_HITCENTER)

    if (not versus.door.isDoor(trace.Entity)) then
      return
    end

    if (not versus.door.getPlayerHasAccess(trace.Entity, self:GetOwner())) then
      versus.message.notify(self:GetOwner(), "You do not have access to that lock!", NOTIFY_ERROR)
      return
    end

    if (versus.door.isLocked(trace.Entity)) then
      versus.door.unlockDoor(trace.Entity, true)
    end
  end
end

function SWEP:PickUp(entity, trace)
  if (not SERVER) then
    return
  end

  if (entity:IsPlayerHolding()) then
    versus.message.notify(self:GetOwner(), "Someone else is already holding that!", NOTIFY_ERROR)
    return
  end

  local success, message = versus.player.CanPickupObject(self:GetOwner(), entity, 60, 200)

  if (not success) then
    versus.message.notify(self:GetOwner(), message, NOTIFY_ERROR)
    return
  end

  -- TODO: What happens if you pickup a ragdoll?
  --       If it doesn't work, then make a small prop, weld that to the physbone and then pickup that.
  self.PickupAttempt = entity
end

function SWEP:Think()
  if (not SERVER) then
    return
  end

  if (self.PickupAttempt) then
    if (self:GetOwner():KeyDown(IN_ATTACK2)) then
      -- While the guy holds the right mouse button down, they'll drop the object instantly.
      return
    elseif (IsValid(self.PickupAttempt) and not self.PickupAttempt:IsPlayerHolding()) then
      self:GetOwner():PickupObject(self.PickupAttempt)

      if (self.PickupAttempt:IsPlayerHolding()) then
        self:SetDTBool(1, true)
      end
    end

    self.PickupAttempt = nil
  elseif (self:GetDTBool(1)) then
    self:SetDTBool(1, false)
  end
end
