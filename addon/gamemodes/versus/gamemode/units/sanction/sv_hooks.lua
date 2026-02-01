local UNIT = UNIT

-- When a player joins load their sanctions
function UNIT.hook:PlayerInitialized(player)
  UNIT.process(player)
end

-- Called before a players' data is loaded, when default values are to be
-- set
function UNIT.hook:PlayerPreDataLoad(player)
  player.sanctions = {}
end

function UNIT.hook:Tick()
  local curTime = CurTime()

  if (self._LastUpdate and curTime - self._LastUpdate < UNIT.updateEvery) then
    return
  end

  self._LastUpdate = curTime

  UNIT.processNotExpired()
end

function UNIT.hook:VersusBuildCreateTablesQueries(queries)
  table.insert(queries, [[
		CREATE TABLE IF NOT EXISTS `]] .. versus.config["MySQL Player Sanctions Table"] .. [[` (
			`id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			`sanction_key` varchar(255) NOT NULL,
			`player_id` int(11) UNSIGNED NOT NULL,
      `reason` varchar(512) NOT NULL,
      `data` longtext NOT NULL,
			`created_by` int(11) UNSIGNED NULL DEFAULT NULL,
			`created_at` TIMESTAMP NOT NULL DEFAULT NOW(),
			`is_applied` BOOLEAN NOT NULL DEFAULT FALSE,
			`expires_at` TIMESTAMP NOT NULL DEFAULT NOW(),
			`expired_at` TIMESTAMP NULL DEFAULT NULL,
			INDEX (`player_id`),
			FOREIGN KEY (`player_id`)
			REFERENCES `players` (`id`)
			ON DELETE CASCADE
			ON UPDATE CASCADE
		);
	]])
end
