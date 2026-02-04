local PLUGIN = PLUGIN

-- Initialize player regeneration data
function PLUGIN:initializePlayerRegen(player)
  player._healthRegenData = {
    lastDamageTime = 0,
    lastRegenTime = 0,
    isRegenerating = false,
    lastSoundTime = 0
  }
end

-- Get player's max regenerable health
function PLUGIN:getMaxRegenHealth(player)
  local maxHealth = player:GetMaxHealth()
  return math.floor(maxHealth * self.maxRegenPercent)
end

-- Check if player can regenerate
function PLUGIN:canPlayerRegenerate(player)
  if not IsValid(player) or not player:Alive() then
    return false
  end

  local health = player:Health()
  local maxHealth = player:GetMaxHealth()
  local maxRegenHealth = self:getMaxRegenHealth(player)

  -- Already at or above max regen health
  if health >= maxRegenHealth then
    return false
  end

  -- Check if enough time has passed since last damage
  local regenData = player._healthRegenData
  if not regenData then
    self:initializePlayerRegen(player)
    regenData = player._healthRegenData
  end

  if CurTime() - regenData.lastDamageTime < self.regenDelay then
    return false
  end

  return true
end

-- Process health regeneration
function PLUGIN:processHealthRegen(player)
  if not self:canPlayerRegenerate(player) then
    if player._healthRegenData and player._healthRegenData.isRegenerating then
      player._healthRegenData.isRegenerating = false
    end
    return
  end

  local regenData = player._healthRegenData
  local currentTime = CurTime()

  -- Calculate time since last regen tick
  local timeSinceLastRegen = currentTime - regenData.lastRegenTime

  if timeSinceLastRegen >= 1 then
    local health = player:Health()
    local maxRegenHealth = self:getMaxRegenHealth(player)
    local newHealth = math.min(health + self.regenRate, maxRegenHealth)

    player:SetHealth(newHealth)
    regenData.lastRegenTime = currentTime
    regenData.isRegenerating = true

    -- Play regeneration sound
    if self.regenSound and (currentTime - regenData.lastSoundTime) >= self.regenSoundInterval then
      player:EmitSound(self.regenSound, 50, 100, 0.3)
      regenData.lastSoundTime = currentTime
    end

    -- Network regeneration state to client
    net.Start("versus.healthregen.regenerating")
    net.WriteBool(true)
    net.Send(player)
  end
end

function PLUGIN.hook:EntityTakeDamage(target, dmgInfo)
  if not IsValid(target) or not target:IsPlayer() then return end

  -- Initialize if needed
  if not target._healthRegenData then
    PLUGIN:initializePlayerRegen(target)
  end

  -- Record damage time
  target._healthRegenData.lastDamageTime = CurTime()
  target._healthRegenData.isRegenerating = false

  -- Network to client that regen stopped
  net.Start("versus.healthregen.regenerating")
  net.WriteBool(false)
  net.Send(target)
end

function PLUGIN.hook:PlayerSpawn(player)
  PLUGIN:initializePlayerRegen(player)
end

function PLUGIN.hook:PlayerLoadedCharacter(player, character)
  PLUGIN:initializePlayerRegen(player)
end

-- Think hook to process regeneration
function PLUGIN.hook:Think()
  for _, player in ipairs(player.GetAll()) do
    if IsValid(player) then
      PLUGIN:processHealthRegen(player)
    end
  end
end

-- Console command to configure regeneration (admin only)
concommand.Add("versus_healthregen_config", function(ply, cmd, args)
  if IsValid(ply) and not ply:IsAdmin() then
    ply:ChatPrint("You must be an admin to use this command!")
    return
  end

  if #args < 2 then
    local msg = [[
Health Regeneration Configuration:
  versus_healthregen_config delay <seconds> - Time before regen starts
  versus_healthregen_config rate <hp/sec> - Health per second
  versus_healthregen_config maxpercent <0-1> - Max regen percentage
  versus_healthregen_config minhp <amount> - Minimum HP to regen
  versus_healthregen_config combat <0/1> - Stop regen in combat

Current settings:
  Delay: ]] .. PLUGIN.regenDelay .. [[s
  Rate: ]] .. PLUGIN.regenRate .. [[ HP/s
  Max Percent: ]] .. (PLUGIN.maxRegenPercent * 100) .. [[%]]

    if IsValid(ply) then
      ply:ChatPrint(msg)
    else
      print(msg)
    end
    return
  end

  local setting = string.lower(args[1])
  local value = tonumber(args[2])

  if not value then
    if IsValid(ply) then
      ply:ChatPrint("Invalid value: " .. args[2])
    else
      print("Invalid value: " .. args[2])
    end
    return
  end

  local changed = false
  local message = ""

  if setting == "delay" then
    PLUGIN.regenDelay = math.max(0, value)
    message = "Regeneration delay set to " .. PLUGIN.regenDelay .. " seconds"
    changed = true
  elseif setting == "rate" then
    PLUGIN.regenRate = math.max(0, value)
    message = "Regeneration rate set to " .. PLUGIN.regenRate .. " HP/s"
    changed = true
  elseif setting == "maxpercent" then
    PLUGIN.maxRegenPercent = math.Clamp(value, 0, 1)
    message = "Max regeneration percent set to " .. (PLUGIN.maxRegenPercent * 100) .. "%"
    changed = true
  else
    message = "Unknown setting: " .. setting
  end

  if IsValid(ply) then
    ply:ChatPrint(message)
  else
    print(message)
  end

  if changed then
    PrintMessage(HUD_PRINTTALK, "[Health Regen] " .. message)
  end
end)

-- Network strings
util.AddNetworkString("versus.healthregen.regenerating")
