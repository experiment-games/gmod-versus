local PLUGIN = PLUGIN

ENT.Type = "anim"
ENT.Base = "versus_lootcrate"
ENT.PrintName = "Random Loot Crate"
ENT.Author = ""
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true

--- Weighted item pool. Each entry: { itemID = "...", size = N, weight = N }
--- Higher weight = more common. Weights are relative within the pool.
ENT.ItemPool = {}

--- How many items to draw from the pool when the crate spawns.
ENT.RandomItemCount = 5

if (not SERVER) then
  return
end

--- Picks `count` items from `pool` using weighted random selection (with replacement).
local function pickRandomItems(pool, count)
  if (#pool == 0) then
    return {}
  end

  local totalWeight = 0

  for _, entry in ipairs(pool) do
    totalWeight = totalWeight + (entry.weight or 1)
  end

  local picked = {}

  for _ = 1, count do
    local roll       = math.random() * totalWeight
    local cumulative = 0

    for _, entry in ipairs(pool) do
      cumulative = cumulative + (entry.weight or 1)

      if (roll <= cumulative) then
        local item = versus.item.createInstance(entry.itemID)
        table.insert(picked, item)
        break
      end
    end
  end

  return picked
end

function ENT:Initialize()
  -- Populate _Items from the pool before the base class creates the inventory.
  if (#self.ItemPool > 0) then
    self._Items = pickRandomItems(self.ItemPool, self.RandomItemCount)
  end

  self.BaseClass.Initialize(self)
end

function ENT:SetItemPool(pool)
  self.ItemPool = pool or {}
end

function ENT:OpenCrate(activator)
  self._IsOpening = true

  -- Store activator so sv_init.lua's net.Receive can validate the response.
  local timerName = "versus_lootcrate_unlock_fallback_" .. self:EntIndex()
  self._pendingActivator = activator
  self._unlockTimerName = timerName

  -- Tell the client to play the unlock animation.
  -- The inventory is opened once the client confirms the animation finished
  -- (handled in sv_init.lua), or by the fallback timer below.
  net.Start("versus.lootcrate.beginUnlock")
  net.WriteEntity(self)
  net.Send(activator)

  -- Safety fallback: open the inventory after 4 s in case the client never responds.
  timer.Create(timerName, 4, 1, function()
    if (not IsValid(self) or not IsValid(activator)) then
      return
    end

    local openSeq = self:LookupSequence("open")
    self:ResetSequence(openSeq)
    self:SetPlaybackRate(1)
    self:EmitSound("items/ammocrate_open.wav", 75, 100, 0.8)

    self._pendingActivator = nil
    self._unlockTimerName  = nil
    self._IsOpening        = false

    versus.inventory.openOrCreateNamedInventory(activator, self:GetChestName(), self, nil)
  end)
end
