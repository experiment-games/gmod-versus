local PLUGIN                  = PLUGIN

PLUGIN.libraryKey             = "auction_house"

-- Number of auction entries shown per page
PLUGIN.PAGE_SIZE              = 10

-- How often (in seconds) the server checks for expired listings
PLUGIN.EXPIRY_CHECK_INTERVAL  = 60

-- Listing duration options. feeMultiplier is applied to the minimun bid to
-- compute the up-front listing fee (a money sink that increases with time).
PLUGIN.DURATIONS              = {
  { label = "24 HOURS", seconds = 86400,  feeMultiplier = 0.05 },
  { label = "48 HOURS", seconds = 172800, feeMultiplier = 0.08 },
  { label = "72 HOURS", seconds = 259200, feeMultiplier = 0.12 },
  { label = "1 WEEK",   seconds = 604800, feeMultiplier = 0.20 },
}

-- Minimum bid increment as a fraction of the current leading bid
PLUGIN.BID_INCREMENT_FRACTION = 0.05

-- Absolute floor for bid increments to avoid sub-1 bids
PLUGIN.BID_INCREMENT_MIN      = 1

-- Maximum concurrent active listings per player
PLUGIN.LISTING_LIMIT_BASE     = 3
PLUGIN.LISTING_LIMIT_PREMIUM  = 10
