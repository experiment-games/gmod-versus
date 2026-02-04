local UNIT = UNIT

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "NPC Spawner"
ENT.Author = ""
ENT.Category = "Versus"
ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.Editable = true

ENT.VersusWritesToManifest = {
  "MobType",
  "SpawnRate",
  "MaxMobs",
  "LootTable",
}

function ENT:SetupDataTables()
  self:NetworkVar("String", 0, "MobType", {
    KeyName = "MobType",
    Edit = {
      type = "String",
      category = "NPC Spawner",
    },
  })
  self:NetworkVar("Float", 0, "SpawnRate", {
    KeyName = "SpawnRate",
    Edit = {
      type = "Float",
      min = 1,
      max = 300,
      category = "NPC Spawner",
    },
  })
  self:NetworkVar("Int", 1, "MaxMobs", {
    KeyName = "MaxMobs",
    Edit = {
      type = "Int",
      category = "NPC Spawner",
    },
  })

  if (SERVER) then
    -- Default values
    self:SetSpawnRate(10)
    self:SetMaxMobs(5)
    self:SetMobType("npc_zombie")
  end
end

if (not SERVER) then
  function ENT:Draw()
    if (GetConVar("developer"):GetInt() == 0) then
      return
    end

    self:DrawModel()
  end

  return
end

util.AddNetworkString("versus.npc.startAdjustLootTable")
util.AddNetworkString("versus.npc.adjustLootTable")

net.Receive("versus.npc.adjustLootTable", function(len, ply)
  local entity = net.ReadEntity()
  local itemCount = net.ReadUInt(8)
  local lootTable = {}

  for i = 1, itemCount do
    local itemID = net.ReadString()
    local itemChance = net.ReadFloat()
    lootTable[itemID] = itemChance
  end

  if (not ply:IsAdmin()) then
    return
  end

  if (not IsValid(entity) or entity:GetClass() ~= "versus_npc_spawner") then
    versus.message.notify(ply, "Invalid NPC Spawner entity.")
    return
  end

  entity:SetLootTable(lootTable)
  versus.message.notify(ply, "NPC Spawner loot table updated.")
end)

function ENT:Initialize()
  self:SetModel("models/props_c17/oildrum001.mdl")
  self:SetMoveType(MOVETYPE_NONE)
end

function ENT:SetLootTable(lootTable)
  self._LootTable = lootTable
end

function ENT:GetLootTable()
  return self._LootTable
end

function ENT:ProduceLootAtPosition(position, angles)
  local lootTable = self:GetLootTable() or {}

  -- Roll for each item independently based on its percentage chance
  for itemID, chance in pairs(lootTable) do
    local roll = math.Rand(0, 100)

    if (roll <= chance) then
      local item = versus.item.createInstance(itemID)

      if (not item) then
        ErrorNoHalt("[NPC Spawner] Invalid item ID in loot table: " .. tostring(itemID) .. "\n")
        continue
      end

      local itemEntity = versus.item.make(item, position, angles or AngleRand(-180, 180))
      itemEntity:DropToFloor()

      hook.Run("VersusNPCSpawnerLootProduced", self, item, itemEntity)
    end
  end
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
          npc:CallOnRemove("VersusNPCSpawnerCleanup", function()
            if (IsValid(self)) then
              self:RemoveMob(npc)
            end
          end)

          npc._VersusLootSpawner = function()
            if (IsValid(self)) then
              self:ProduceLootAtPosition(npc:GetPos() + Vector(math.random(-10, 10), math.random(-10, 10), 50),
                npc:GetAngles())
            end
          end

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
