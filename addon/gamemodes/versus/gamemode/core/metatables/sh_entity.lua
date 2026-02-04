local entityMeta = FindMetaTable("Entity")

function entityMeta:IsDoor()
  local class = self:GetClass()

  return (class and class:find("door") ~= nil)
end

function entityMeta:IsLocked()
  if (self:IsVehicle()) then
    return self:GetInternalVariable("VehicleLocked")
  end

  return self:GetInternalVariable("m_bLocked")
end

function entityMeta:OpenDoorAwayFrom(position, notSilent, noLockCheck)
  local target = ents.Create("info_target")
  target:SetName(tostring(target))
  target:SetPos(position)
  target:Spawn()

  if (not noLockCheck and self:GetInternalVariable("m_bLocked")) then
    if (notSilent) then
      self:Fire("SetAnimation", "locked", 0)
      self:EmitSound("doors/door_locked2.wav", 75, math.random(95, 105))
    end
  elseif (self:GetInternalVariable("m_eDoorState") == 0) then
    if (notSilent) then
      self:Fire("SetAnimation", "open", 0)
    end
    self:Fire("OpenAwayFrom", tostring(target))
  else
    self:Fire("Close")
  end

  timer.Simple(1, function()
    if (IsValid(target)) then
      target:Remove()
    end
  end)
end
