local PLUGIN = PLUGIN
local HTTP

-- Required, because otherwise messages won't go through Cloudflare's network, which is used by Discord.
if (pcall(require, "chttp") and CHTTP ~= nil) then
  HTTP = CHTTP
else
  ErrorNoHalt(
  "[Discord] CHTTP module not found, Discord notifications will not be sent. Please install the CHTTP module from https://github.com/timschumi/gmod-chttp\n")
end

PLUGIN.notificationTypes = PLUGIN.notificationTypes or {}

--- @alias DiscordEmbed {title: string, description: string, color: number}

--- Registers a Discord notification type, that a webhook can be called with.
--- @param name string The name of the notification type, used to call the webhook with.
--- @param callback fun(data: table): DiscordEmbed[] A function that takes a data table and returns a table of embed objects to send to Discord. Each embed object should have a title, description, and color field.
function PLUGIN.registerNotificationType(name, callback)
  PLUGIN.notificationTypes[name] = callback
end

--- Sends a notification to the configured Discord webhook.
--- @param notificationType string The type of notification to send, which determines the title, message, and color of the notification.
--- @param data table A table of data to pass to the notification type's callback function, which will be used to generate the title, message, and color of the notification.
function PLUGIN.sendDiscordNotification(notificationType, data)
  local webhookURL = versus.config["Discord Webhook"]

  if (not webhookURL) then
    return
  end

  -- CHTTP isn't available, so we can't send a notification.
  if (not HTTP) then
    return
  end

  local callback = PLUGIN.notificationTypes[notificationType]

  if (not callback) then
    return
  end

  local payload = {
    embeds = callback(data)
  }

  local hasMadeRequest = HTTP({
    url = webhookURL,
    method = "POST",
    body = util.TableToJSON(payload),
    type = "application/json",

    success = function(code, responseBody)
      if (code ~= 204) then
        ErrorNoHalt(string.format("[Discord] Webhook returned HTTP %d: %s\n", code, responseBody))
        return
      end
    end,

    failed = function(reason)
      ErrorNoHalt(string.format("[Discord] HTTP request failed: %s\n", reason))
    end,
  })

  if not hasMadeRequest then
    ErrorNoHalt("[Discord] Failed to make HTTP request\n")
  end
end

--[[
  Types
--]]

PLUGIN.registerNotificationType("player_joined", function(data)
  return {
    {
      title = data.playerName,
      description = string.format("Just joined '%s'", GetHostName()),
      color = 2326507, -- Blue
      author = {
        name = "PLAYER CONNECTED",
      },
      footer = {
        text = "at " .. os.date("%Y-%m-%d %H:%M:%S", os.time())
      }
    }
  }
end)

PLUGIN.registerNotificationType("player_left", function(data)
  return {
    {
      title = data.playerName,
      description = string.format("Just left '%s'", GetHostName()),
      color = 15409955, -- Red
      author = {
        name = "PLAYER DISCONNECTED",
      },
      footer = {
        text = "at " .. os.date("%Y-%m-%d %H:%M:%S", os.time())
      }
    }
  }
end)

--[[
  Hooks
--]]

function PLUGIN.hook:PlayerInitialSpawn(player)
  local webhookURL = versus.config["Discord Webhook"]
  local inviteLink = versus.config["Discord Invite Link"]

  timer.Simple(1, function()
    if not IsValid(player) then
      return
    end

    if inviteLink then
      versus.message.notify(
        player,
        "Welcome! Join our Discord for support, news, and more! " .. inviteLink,
        NOTIFY_CHAT_LIGHTBULB
      )
    end

    if (not webhookURL) then
      return
    end

    self.sendDiscordNotification(
      "player_joined",
      {
        playerName = player:Nick(),
      }
    )
  end)
end

function PLUGIN.hook:PlayerDisconnected(player)
  local webhookURL = versus.config["Discord Webhook"]

  if (not webhookURL) then
    return
  end

  self.sendDiscordNotification(
    "player_left",
    {
      playerName = player:Nick(),
    }
  )
end
