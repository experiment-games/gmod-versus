local PLUGIN = PLUGIN

--[[
  Database table creation
--]]

function PLUGIN.hook:VersusBuildCreateTablesQueriesCore(queries)
  -- Daily bounties table (shared across all players)
  table.insert(queries, [[
    CREATE TABLE IF NOT EXISTS `bounties` (
      `id`         int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      `bounty_key` varchar(255)     NOT NULL,
      `created_at` int(11) UNSIGNED NOT NULL DEFAULT 0,
      `expires_at` int(11) UNSIGNED NOT NULL DEFAULT 0,
      INDEX `idx_bounties_expires` (`expires_at`)
    );
  ]])
end

function PLUGIN.hook:VersusBuildCreateTablesQueries(queries)
  -- Per-player bounty progress table (references the bounties table)
  -- A row only exists once the player has picked up the bounty.
  table.insert(queries, [[
    CREATE TABLE IF NOT EXISTS `player_bounties` (
      `id`           int(11) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      `steam_id`     varchar(255)     NOT NULL,
      `bounty_id`    int(11) UNSIGNED NOT NULL,
      `progress`     int(11) UNSIGNED NOT NULL DEFAULT 0,
      `completed_at` int(11) UNSIGNED          DEFAULT NULL,
      `turned_in`    tinyint(1)       NOT NULL DEFAULT 0,
      UNIQUE KEY `uq_player_bounty` (`steam_id`, `bounty_id`),
      INDEX `idx_pb_steam_id` (`steam_id`),
      INDEX `idx_pb_bounty_id` (`bounty_id`)
    );
  ]])
end

--[[
  NPC kills → track kill_npc bounty progress
--]]

function PLUGIN.hook:OnNPCKilled(npc, attacker, inflictor)
  PLUGIN.onNPCKilled(npc, attacker)
end

--[[
  Encounter camp cleared → track clear_encounter bounty progress
--]]

function PLUGIN.hook:VersusEncounterCampCleared(campID, instance, attacker)
  PLUGIN.onEncounterCampCleared(campID, instance, attacker)
end

--[[
  Clean up in-memory data when a player disconnects
--]]

function PLUGIN.hook:PlayerDisconnected(player)
  if player:IsBot() then return end
  PLUGIN.playerBounties[player:SteamID()] = nil
end
