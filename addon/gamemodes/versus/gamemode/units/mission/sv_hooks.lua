local UNIT = UNIT

-- Called before a players' data is loaded, when default values are to be
-- set
function UNIT.hook:PlayerPreDataLoad(player)
  player.missions = {}
end

-- Called when a players' data is loading and needs to be converted or
-- requires further loading
function UNIT.hook:PlayerDataLoading(player, rawPlayerData)
  if (not rawPlayerData) then
    -- New player doesn't have missions yet so that's done right away
    player._MissionsLoaded = true
    return
  end

  UNIT.loadPlayerProgress(player, function(missions)
    player._MissionsLoaded = true

    if (player:IsSuperAdmin()) then
      UNIT.networkAllMissions(player)
    end
  end)
end

-- When auto refresh occurs update the super admins with the mission data
function UNIT.hook:OnReloaded()
  for _, player in pairs(player.GetAll()) do
    if (player._MissionsLoaded) then
      if (player:IsSuperAdmin()) then
        UNIT.networkAllMissions(player)
      end
    end
  end
end

-- Called to get a list of functions that should return true when this unit
-- is done doing it's loading for the player. The player won't spawn until
-- all blockingCallbacks return true
function UNIT.hook:PlayerInitializing(player, blockingCallbacks)
  if (player:IsBot()) then
    return
  end

  table.insert(blockingCallbacks, function(player)
    return player._MissionsLoaded == true
  end)
end

-- Called every 0.1 second for each player
function UNIT.hook:PlayerTenthSecond(player)
  if (player._Initialized) then
    UNIT.checkPlayerArriveWaypoint(player)
  end
end

function UNIT.hook:VersusBuildCreateTablesQueries(queries)
  table.insert(queries, [[
		CREATE TABLE IF NOT EXISTS `]] .. versus.config["MySQL Player Missions Table"] .. [[` (
			`id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
			`mission_id` varchar(255) NOT NULL,
			`player_id` int(11) UNSIGNED NOT NULL,
			`stage` int(11) UNSIGNED DEFAULT NULL,
			`data` longtext NOT NULL,
			`messages` longtext NOT NULL,
			`started_at` TIMESTAMP NOT NULL,
			`completed_at` TIMESTAMP NULL DEFAULT NULL,
			INDEX (`player_id`),
			FOREIGN KEY (`player_id`)
			REFERENCES `players` (`id`)
			ON DELETE CASCADE
			ON UPDATE CASCADE
		);
	]])
end
