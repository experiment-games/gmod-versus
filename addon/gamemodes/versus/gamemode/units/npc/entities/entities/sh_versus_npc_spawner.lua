ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "NPC Spawner"
ENT.Author = "" -- joker
ENT.Spawnable = false
ENT.AdminSpawnable = false

if (not SERVER) then
  function ENT:Draw()
    -- Invisible
  end

  return
end

function ENT:Initialize()
  self:SetModel("models/props_c17/oildrum001.mdl")
  self:SetMoveType(MOVETYPE_NONE)
end

function ENT:SetMobType(mobType)
  self._MobType = mobType
end

function ENT:GetMobType()
  return self._MobType
end

function ENT:SetSpawnRate(rate)
  self._SpawnRate = rate
end

function ENT:GetSpawnRate()
  return self._SpawnRate or 10
end

function ENT:SetMaxMobs(maxMobs)
  self._MaxMobs = maxMobs
end

function ENT:GetMaxMobs()
  return self._MaxMobs or 5
end

function ENT:GetCurrentMobs()
  return #self._CurrentMobs or 0
end

function ENT:AddMob(mob)
  self._CurrentMobs = self._CurrentMobs or {}
  table.insert(self._CurrentMobs, mob)
end

function ENT:RemoveMob(mob)
  self._CurrentMobs = self._CurrentMobs or {}

  for i, currentMob in ipairs(self._CurrentMobs) do
    if (currentMob == mob) then
      table.remove(self._CurrentMobs, i)
      return
    end
  end
end

function ENT:Think()
  self._CurrentMobs = self._CurrentMobs or {}

  -- Clean up invalid mobs
  for i = #self._CurrentMobs, 1, -1 do
    if (not IsValid(self._CurrentMobs[i])) then
      table.remove(self._CurrentMobs, i)
    end
  end

  -- Spawn new mobs if under max
  if (#self._CurrentMobs < self:GetMaxMobs()) then
    if (not self._NextSpawnTime or CurTime() >= self._NextSpawnTime) then
      local mobType = self:GetMobType()

      if (mobType) then
        local npc = ents.Create(mobType)

        if (IsValid(npc)) then
          npc:SetCustomCollisionCheck(true)
          npc:SetPos(self:GetRandomValidPosition())
          npc:Spawn()
          npc:CallOnRemove("RemoveFromSpawner", function()
            self:RemoveMob(npc)
          end)

          self:AddMob(npc)
        else
          ErrorNoHalt("[NPC Spawner] Failed to create NPC of type: " .. tostring(mobType) .. "\n")
        end
      end

      self._NextSpawnTime = CurTime() + self:GetSpawnRate()
    end
  end

  self:NextThink(CurTime() + 1)
  return true
end

function ENT:GetRandomValidPosition()
  local origin = self:GetPos()
  local radius = 100

  for i = 1, 10 do
    local randomOffset = Vector(
      math.Rand(-radius, radius),
      math.Rand(-radius, radius),
      0
    )

    local testPos = origin + randomOffset
    local tr = util.TraceLine({
      start = testPos + Vector(0, 0, 50),
      endpos = testPos - Vector(0, 0, 50),
      filter = self
    })

    if (tr.Hit and tr.HitNormal.z > 0.7) then
      return tr.HitPos
    end
  end

  return origin
end
