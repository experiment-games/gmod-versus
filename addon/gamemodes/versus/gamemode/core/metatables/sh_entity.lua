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

if (SERVER) then
  util.AddNetworkString("versus.playerBodyGroupChanged")
  util.AddNetworkString("versus.playerBodyGroupsChanged")

  META.versusSetBodygroup = META.versusSetBodygroup or META.SetBodygroup
  META.versusSetBodyGroups = META.versusSetBodyGroups or META.SetBodyGroups

  --[[
		Override the bodygroup functions to call hooks
	--]]

  --- @param index number
  --- @param value number
  function META:SetBodygroup(index, value)
    if (self:IsPlayer()) then
      local oldValue = self:GetBodygroup(index)
      hook.Run("PlayerBodyGroupChanged", self, index, value, oldValue)

      net.Start("versus.playerBodyGroupChanged")
      net.WritePlayer(self)
      net.WriteUInt(index, 32)
      net.WriteUInt(value, 32)
      net.WriteUInt(oldValue, 32)
      net.Broadcast()
    end

    self:versusSetBodygroup(index, value)
  end

  --- @param index number
  --- @param value number
  function META:SetBodyGroup(index, value)
    self:SetBodygroup(index, value)
  end

  --- @param bodygroups string # Body groups to set. Each character in the string represents a separate bodygroup. (0 to 9, a to z being (10 to 35))
  function META:SetBodyGroups(bodygroups)
    if (self:IsPlayer()) then
      local oldBodygroups = ""

      for i = 1, 9 do
        local bodygroup = self:GetBodygroup(i)
        oldBodygroups = oldBodygroups .. bodygroup
      end

      hook.Run("PlayerBodyGroupsChanged", self, bodygroups, oldBodygroups)

      net.Start("versus.playerBodyGroupsChanged")
      net.WritePlayer(self)
      net.WriteString(bodygroups)
      net.WriteString(oldBodygroups)
      net.Broadcast()
    end

    self:versusSetBodyGroups(bodygroups)
  end
else
  net.Receive("versus.playerBodyGroupChanged", function()
    local player = net.ReadPlayer()
    local index = net.ReadUInt(32)
    local value = net.ReadUInt(32)
    local oldValue = net.ReadUInt(32)

    hook.Run("PlayerBodyGroupChanged", player, index, value, oldValue)
  end)

  net.Receive("versus.playerBodyGroupsChanged", function()
    local player = net.ReadPlayer()
    local bodygroups = net.ReadString()
    local oldBodygroups = net.ReadString()

    hook.Run("PlayerBodyGroupsChanged", player, bodygroups, oldBodygroups)
  end)
end
