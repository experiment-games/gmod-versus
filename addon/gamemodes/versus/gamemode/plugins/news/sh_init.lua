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
