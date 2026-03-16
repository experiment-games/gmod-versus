local PLUGIN              = PLUGIN

PLUGIN.name               = "News Screen"
PLUGIN.description        = "Shows a popup news screen to players when they join, displaying news and event articles"
PLUGIN.libraryKey         = "news"

-- Maximum size for the full JSON payload sent over the network
PLUGIN.MAX_PAYLOAD_SIZE   = 128 * 1024 -- 128 KB

-- Maximum length for individual article fields
PLUGIN.MAX_TITLE_LENGTH   = 200
PLUGIN.MAX_CONTENT_LENGTH = 64 * 1024 -- 64 KB of HTML per article
PLUGIN.MAX_ARTICLES       = 50

-- Dynamic article providers registered by other plugins.
-- Each entry maps a unique provider ID -> callback: function() -> table|nil
-- Callbacks are called server-side when articles are sent to clients.
PLUGIN.dynamicProviders   = PLUGIN.dynamicProviders or {}

--- Register a dynamic article provider. The callback is invoked each time
--- articles are sent to a player and should return an article table when the
--- article is active, or nil when it is not.
--- Dynamic articles are prepended to the stored article list and take
--- precedence over any stored article with the same ID.
--- @param id       string    Unique provider ID (stable across hot-reloads)
--- @param callback function  function() -> table|nil
function PLUGIN.registerDynamic(id, callback)
  PLUGIN.dynamicProviders[id] = callback
end
