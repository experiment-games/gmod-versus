local PLUGIN = PLUGIN

--- Returns the player's current radiation level.
--- @param player Player
--- @return number Radiation level between 0 and PLUGIN.maxLevel
function PLUGIN.getRadiationLevel(player)
  return player:getCharacter("radiation_level", 0)
end

--- Sets the player's radiation level and syncs it to their client.
--- @param player Player
--- @param level number New radiation level (clamped to 0–maxLevel)
function PLUGIN.setRadiationLevel(player, level)
  level = math.Clamp(math.Round(level), 0, PLUGIN.maxLevel)

  player:setCharacter("radiation_level", level)
  versus.player.setLocalPlayerVariable(player, NWTYPE_FLOAT, "_versusRadiationLevel", level)
end

--[[
  Database persistence
--]]

function PLUGIN.hook:VersusPlayerBuildExtraColumns(columnDefinitions)
  table.insert(columnDefinitions, "`radiation_level` tinyint(3) UNSIGNED NOT NULL DEFAULT 0")
end

function PLUGIN.hook:VersusPlayerBuildSelectColumns(columns)
  table.insert(columns, "`radiation_level`")
end

function PLUGIN.hook:PlayerPreDataLoad(player)
  player:setCharacter("radiation_level", 0)
end

function PLUGIN.hook:PlayerDataLoading(player, result)
  if not result then return end

  local level = math.Clamp(tonumber(result.radiation_level) or 0, 0, PLUGIN.maxLevel)
  player:setCharacter("radiation_level", level, true)

  versus.player.setLocalPlayerVariable(player, NWTYPE_FLOAT, "_versusRadiationLevel", level)
end

--[[
  Accumulation and decontamination
--]]

-- Use per-player timestamps stored directly on the player object so they are
-- automatically garbage-collected when the player disconnects.
function PLUGIN.hook:Think()
  local now = CurTime()
  local isRadiated = PLUGIN.mapIsRadiated()

  for _, player in player.Iterator() do
    if not player._VersusInitialized then continue end

    if isRadiated then
      -- Accumulate radiation only for living players.
      if not player:Alive() then continue end

      local nextAccumulation = player._versusRadiationNextAccumulation

      if nextAccumulation == nil then
        -- First think for this player — start the timer from now.
        player._versusRadiationNextAccumulation = now + PLUGIN.accumulationRate
        continue
      end

      if now >= nextAccumulation then
        player._versusRadiationNextAccumulation = now + PLUGIN.accumulationRate

        local level = PLUGIN.getRadiationLevel(player)

        if level < PLUGIN.maxLevel then
          PLUGIN.setRadiationLevel(player, level + 1)
        end
      end
    else
      -- Passively decontaminate while on a non-radiated server.
      local nextDecontamination = player._versusRadiationNextDecontamination

      if nextDecontamination == nil then
        -- First think for this player — start the timer from now.
        player._versusRadiationNextDecontamination = now + PLUGIN.decontaminationRate
        continue
      end

      if now >= nextDecontamination then
        player._versusRadiationNextDecontamination = now + PLUGIN.decontaminationRate

        local level = PLUGIN.getRadiationLevel(player)

        if level > 0 then
          PLUGIN.setRadiationLevel(player, level - 1)
        end
      end
    end
  end
end

--[[
  Contract locking
--]]

--- Hook called before a contract is accepted. Return false to block it.
function PLUGIN.hook:PlayerCanAcceptContract(player, preparedContract)
  if not PLUGIN.mapIsRadiated() then return end

  local level = PLUGIN.getRadiationLevel(player)

  if level >= PLUGIN.contractThreshold then
    return false, "Too irradiated to take contracts."
  end
end

--[[
  Debug commands
--]]

concommand.Add("versus_set_radiation", function(player, cmd, args)
  if not player:IsAdmin() then return end

  local target = player
  local level = tonumber(args[1])

  if not level then
    versus.message.notify(player, "Usage: versus_set_radiation <level> [player]", NOTIFY_GENERIC)
    return
  end

  if args[2] then
    target = versus.player.get(args[2])

    if not IsValid(target) then
      versus.message.notify(player, "Player not found: " .. args[2], NOTIFY_ERROR)
      return
    end
  end

  PLUGIN.setRadiationLevel(target, level)
  versus.message.notify(player, string.format("Set %s radiation to %d.", target:Nick(), level), NOTIFY_GENERIC)
end)
