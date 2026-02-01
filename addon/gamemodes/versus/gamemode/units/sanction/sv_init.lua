local UNIT = UNIT

local function processExpiredSanction(player, sanction, playerSanction)
  if (sanction:expire(player, playerSanction) == false) then
    return
  end

  if (playerSanction.id) then
    local statement = string.format([[
      UPDATE `%s`
      SET `expired_at` = NOW()
      WHERE `id` = %u
    ]], versus.config["MySQL Player Sanctions Table"], playerSanction.id)

    versus.database.query(statement)
  end
end

local function processUnappliedSanction(player, sanction, playerSanction)
  local appliedBy

  if (playerSanction.created_by) then
    local applier = versus.player.getByVersusID(playerSanction.created_by)

    appliedBy = IsValid(applier) and applier or nil
  end

  if (sanction:apply(player, playerSanction) == false) then
    return
  end

  playerSanction.is_applied = true

  if (playerSanction.id) then
    local statement = string.format([[
      UPDATE `%s`
      SET `is_applied` = TRUE
      WHERE `id` = %u
    ]], versus.config["MySQL Player Sanctions Table"], playerSanction.id)

    versus.database.query(statement)
  end
end

function UNIT.processSanction(sanction, playerSanction)
  local player = versus.player.getByVersusID(playerSanction.player_id)

  if (not playerSanction.expired_at) then
    hook.Run("PlayerSanctionProcessing", player, sanction, playerSanction)
  end

  if (not IsValid(player)) then
    return
  end

  UNIT.processPlayerSanction(player, sanction, playerSanction)
end

function UNIT.processPlayerSanction(player, sanction, playerSanction)
  if (playerSanction.expires_at < os.time() and not playerSanction.expired_at) then
    processExpiredSanction(player, sanction, playerSanction)
  end

  if (not tobool(playerSanction.is_applied)) then
    processUnappliedSanction(player, sanction, playerSanction)
  end
end

function UNIT.process(player, where)
  if (IsValid(player)) then
    if (where) then
      where = where .. " AND "
    else
      where = ""
    end

    where = where .. "`player_id` = " .. player:getVersusID()
  end

  UNIT.fetch(function(rawSanctions)
    for _, playerSanction in pairs(rawSanctions) do
      local sanction = UNIT.get(playerSanction.sanction_key)

      UNIT.processSanction(sanction, playerSanction)
    end
  end, where)
end

function UNIT.processNotExpired(player)
  UNIT.process(player, "`expired_at` IS NULL")
end

function UNIT.fetch(callback, where)
  where = where and ("WHERE " .. where) or ""

  local statement = string.format([[
		SELECT
      `id`,
      `sanction_key`,
      `player_id`,
      `reason`,
      `data`,
      `created_by`,
      UNIX_TIMESTAMP(`created_at`) as `created_at`,
      `is_applied`,
      UNIX_TIMESTAMP(`expires_at`) as `expires_at`,
      UNIX_TIMESTAMP(`expired_at`) as `expired_at`
    FROM `%s` %s
	]], versus.config["MySQL Player Sanctions Table"], where)

  versus.database.query(statement, function(sanctions)
    if (callback) then
      callback(sanctions)
    end
  end)
end

function UNIT.addSanction(player, sanction, duration, reason, createdBy, data)
  local playerSanction = {
    sanction_key = sanction.key,
    player_id = player:getVersusID(),
    reason = reason,
    data = data,
    created_by = IsValid(createdBy) and createdBy:getVersusID() or nil,
    expires_at = os.time() + duration,
  }
  local sanctionsTable = versus.config["MySQL Player Sanctions Table"]
  local statement = string.format([[
		INSERT INTO `%s` (`sanction_key`, `player_id`, `reason`, `data`, `created_by`, `is_applied`, `expires_at`)
		VALUES (?, ?, ?, ?, ?, TRUE, ?);
	]], sanctionsTable)

  local values = {
    versus.player.getValueTypeDefinition(playerSanction.sanction_key),
    versus.player.getValueTypeDefinition(playerSanction.player_id),
    versus.player.getValueTypeDefinition(playerSanction.reason),
    versus.player.getValueTypeDefinition(playerSanction.data),
    versus.player.getValueTypeDefinition(playerSanction.created_by),
    versus.player.getValueTypeDefinition(playerSanction.expires_at, true),
  }

  UNIT.processPlayerSanction(player, sanction, playerSanction)

  versus.database.queryPrepared(statement, values, function(_, sanctionID)
    if (IsValid(player)) then
      player.sanctions[playerSanction.sanction_key].id = sanctionID
    end
  end, nil, true)
end

function UNIT.expireSanction(player, sanction)
  local playerSanction = player.sanctions[sanction.key]

  if (not playerSanction) then
    return false
  end

  processExpiredSanction(player, sanction, playerSanction)
end
