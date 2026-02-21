local PLUGIN = PLUGIN
local ENT = ENT

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "Teargas impact position"
ENT.Author = ""
ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.TearGasDuration = 25

if (CLIENT) then
  ENT.TearGasFadeTime = 2
  ENT.TearGasFadeInTime = 1
  ENT.TearGasIntensity = 0
  ENT.TearGasStartDistance = 512
  ENT.TearGasMaxIntensityDistance = 256
  -- How often (in seconds) a new smoke puff is emitted
  ENT.TearGasParticleRate = 0.12

  function ENT:Initialize()
    self.InitTime = self:GetCreationTime()
    self.TearGasMaxIntensityDuration = self.TearGasDuration - self.TearGasFadeTime
    self.TearGasEndTime = self.InitTime + self.TearGasDuration
    self.TearGasFadeInDuration = self.InitTime + self.TearGasFadeInTime
    self.PartialIntensityDistance = self.TearGasStartDistance - self.TearGasMaxIntensityDistance
    self.NextParticleTime = 0
    self.Emitter = ParticleEmitter(self:GetPos(), false)
  end

  function ENT:Draw()
  end

  function ENT:OnRemove()
    self:StopParticles()

    if self.Emitter and self.Emitter:IsValid() then
      self.Emitter:Finish()
    end
  end

  function ENT:Think()
    local CT = CurTime()
    local pos = self:GetPos()

    local overallIntensity = 0

    -- if the lifetime of the grenade is nearing its end, fade it out based on time left
    if CT > self.InitTime + self.TearGasMaxIntensityDuration then
      local timeRel = self.TearGasEndTime - CT

      overallIntensity = math.Clamp(timeRel / self.TearGasFadeTime, 0, 1)
    else
      -- if it's fresh and is only fading in, scale the intensity based on time left until full intensity
      if CT < self.TearGasFadeInDuration then
        local timeRel = math.Clamp(1 - (self.TearGasFadeInDuration - CT) / self.TearGasFadeInTime, 0, 1)

        overallIntensity = timeRel
      else
        -- overall, give it full intensity
        overallIntensity = 1
      end
    end

    -- Emit transparent, yellowish teargas smoke particles.
    -- These are much more see-through than a regular smoke grenade so the effect
    -- reads as a thin chemical gas rather than an opaque smoke screen.
    if CT >= self.NextParticleTime and overallIntensity > 0 and self.Emitter and self.Emitter:IsValid() then
      self.NextParticleTime = CT + self.TearGasParticleRate

      local particle = self.Emitter:Add(
        "particle/smokesprites_000" .. math.random(1, 9),
        pos + VectorRand() * 20
      )

      if particle then
        particle:SetVelocity(Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(8, 20)))
        particle:SetDieTime(math.Rand(3, 5))
        -- Keep alpha low so the gas is translucent (teargas, not thick smoke)
        particle:SetStartAlpha(math.floor(40 * overallIntensity))
        particle:SetEndAlpha(0)
        particle:SetStartSize(math.Rand(30, 50))
        particle:SetEndSize(math.Rand(80, 120))
        particle:SetRollDelta(math.Rand(-0.08, 0.08))
        -- Yellowish-green tint typical of tear gas
        particle:SetColor(210, 210, 130)
        particle:SetLighting(false)
        particle:SetGravity(Vector(0, 0, 4))
      end
    end

    if overallIntensity == 0 then
      return
    end

    -- get the distance from the impact position to the player
    local distToPlayer = EyePos():Distance(pos)

    if distToPlayer > self.TearGasStartDistance then
      return
    end

    -- time to figure out position-based intensity

    if distToPlayer > self.TearGasMaxIntensityDistance then
      -- if we're within the smoke's partial intensity distance, scale it based on the distance
      local distanceRel = 1 -
          math.Clamp((distToPlayer - self.TearGasMaxIntensityDistance) / self.PartialIntensityDistance, 0, 1)

      overallIntensity = overallIntensity * distanceRel

      -- and if we aren't just don't change the intensity (since we're at max intensity)
    end

    local lp = LocalPlayer()

    if not lp._VersusTeargasIntensity or overallIntensity > lp._VersusTeargasIntensity then
      lp._VersusTeargasIntensity = overallIntensity
    end
  end

  return
end

function ENT:Initialize()
  self:SetModel("models/Items/AR2_Grenade.mdl")
  self:PhysicsInit(SOLID_NONE)
  self:SetMoveType(MOVETYPE_NONE)
  self:SetSolid(SOLID_NONE)
  self:SetCollisionGroup(COLLISION_GROUP_NONE)

  timer.Simple(self.TearGasDuration, function()
    SafeRemoveEntity(self)
  end)
end

function ENT:CreateParticles()
  self:EmitSound("weapons/smokegrenade/sg_explode.wav", 100, 100)
end

function ENT:Use(activator, caller)
  return false
end

function ENT:OnRemove()
  self:StopParticles()
  return false
end
