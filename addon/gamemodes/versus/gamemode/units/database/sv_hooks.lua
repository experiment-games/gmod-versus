local UNIT = UNIT

-- Called when the server initializes.
function UNIT.hook:Initialize()
  local host = versus.config["MySQL Host"]
  local username = versus.config["MySQL Username"]
  local password = versus.config["MySQL Password"]
  local database = versus.config["MySQL Database"]

  -- Initialize a connection to the MySQL database.
  UNIT.default = UNIT.initialize(host, username, password, database, 3306)
end
