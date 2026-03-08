local UNIT = UNIT
UNIT.libraryKey = "database"

UNIT.countConVar = CreateConVar("versus_database_query_count", "0", FCVAR_ARCHIVE,
  "If enabled, will count and print the number of database queries being made to the server console for debugging purposes.")

versus.includePrefixed("sv_hooks.lua")

xpcall(function()
  require("mysqloo")
end, function(err)
  if (not success) then
    ErrorNoHalt(
      "\n==================================================" ..
      "\n[Versus] MySQLOO is not installed correctly!" ..
      "\n\tFailed with error: " .. err ..
      "\n\tDownload and install MySQLOO from: https://github.com/FredyH/MySQLOO\n" ..
      "\n==================================================\n")

    error("Could not recover from error state. Expect more errors to follow!")
  end
end)

UNIT.connections = UNIT.connections or {}
UNIT.queryCount = UNIT.queryCount or {}
UNIT.startTime = UNIT.startTime or 0

--- TODO: This is only for debugging, using it to track how many statements
--- are made to the database
local function countStatement(statement)
  if (not UNIT.countConVar:GetBool()) then
    return
  end

  local statementType = string.Explode(" ", statement:Trim())[1]

  UNIT.queryCount[statementType] = (UNIT.queryCount[statementType] or 0) + 1

  print(
    "\n==================================================",
    "\n[DEBUG] Counting statements",
    "\n\t- Have counted for: " .. tostring(os.time() - UNIT.startTime) .. " seconds. Since timestamp: ", UNIT.startTime,
    "\n\t- Type of statement: " .. statementType:gsub("%s+", " "),
    "\n\t- Num statements of that type: #" .. tostring(UNIT.queryCount[statementType]),
    "\n\t- Full statement: " .. statement:gsub("%s+", " "),
    "\n=================================================="
  )
end

-- Returns the connection
function UNIT.getConnection(id)
  return UNIT.connections[id or UNIT.default or 1]
end

-- Create a connection with the database
function UNIT.initialize(host, username, password, database, port)
  port = port or 3306
  -- TODO: note , 5, 5 arguments that were used with tmysql (I believe to configure always returning lastid on insert and timeout?)

  UNIT.startTime = os.time()

  local connection = mysqloo.connect(host, username, password, database, 3306)
  local connectionID = table.insert(UNIT.connections, connection)

  function connection:onConnected()
    ServerLog("Database has connected!\n")

    UNIT.createTables(connectionID, function()
      print("[Versus] Successfully created/verified database tables!")

      hook.Run("DatabaseConnected", connection)
    end, function(err)
      ErrorNoHaltWithStack("An error occured while creating/verifying database tables: " .. err)
    end)
  end

  function connection:onConnectionFailed(err)
    ErrorNoHaltWithStack(
      "\n==================================================" ..
      "\n[Versus] Connection to database failed with error: " .. tostring(err) .. "\n" ..
      "\n\tDouble-check that: " ..
      "\n\t\t- The database has been started." ..
      "\n\t\t- You have entered the correct details in gamemode/core/sv_configuration.lua." ..
      "\n==================================================\n")
  end

  connection:connect()

  return connectionID
end

-- Create the players table in the database if it doesn't exist
function UNIT.createTables(connectionID, callback, errorCallback)
  local queries = {}

  -- Core tables that do not refer to each other
  hook.Run("VersusBuildCreateTablesQueriesCore", queries)

  -- Tables that depend on core tables (e.g. with foreign keys referencing core tables)
  hook.Run("VersusBuildCreateTablesQueries", queries)

  UNIT.transactedQueries(queries, callback, errorCallback, connectionID)
end

function UNIT.getDate(seconds)
  return os.date(versus.config["MySQL Date Format"], seconds)
end

-- Get a type from a given value
function UNIT.getTypeFromValue(value)
  local rawType = TypeID(value)

  -- These are the only types that can be put in the database
  if (rawType ~= TYPE_STRING
        and rawType ~= TYPE_NUMBER
        and rawType ~= TYPE_BOOL
        and rawType ~= TYPE_NIL) then
    return nil
  end

  return rawType
end

-- Query a database
function UNIT.query(statement, callback, errorCallback, connectionID)
  local connection = UNIT.getConnection(connectionID)
  local query = connection:query(statement)

  countStatement(statement)

  function query:onSuccess(data)
    if (callback) then
      callback(data)
    end
  end

  function query:onError(err)
    ErrorNoHaltWithStack("An error occured while executing the query: " .. err)

    if (errorCallback) then
      errorCallback(err)
    end
  end

  query:start()
end

-- Query a database using a prepared statement
function UNIT.queryPrepared(statement, values, callback, errorCallback, returnLastInsert, connectionID)
  local connection = UNIT.getConnection(connectionID)
  local query = connection:prepare(statement)

  countStatement(statement)

  function query:onSuccess(data)
    if (callback) then
      callback(data, returnLastInsert and query:lastInsert() or nil, query:affectedRows())
    end
  end

  function query:onError(err)
    ErrorNoHaltWithStack("An error occured while executing the query: " .. err)

    if (errorCallback) then
      errorCallback(err)
    end
  end

  for i = 1, #values do
    local valueData = values[i]

    if (valueData.databaseType == TYPE_STRING) then
      query:setString(i, valueData.value)
    elseif (valueData.databaseType == TYPE_NUMBER) then
      query:setNumber(i, valueData.value)
    elseif (valueData.databaseType == TYPE_BOOL) then
      query:setBoolean(i, valueData.value)
    elseif (valueData.databaseType == TYPE_NIL) then
      query:setNull(i)
    else
      ErrorNoHaltWithStack("Invalid type for value on prepared statement (" ..
        statement .. ") " .. tostring(i) .. "! Dumping info to console")
      PrintTable(valueData)
      PrintTable(values)
    end
  end

  query:start()
end

-- Execute multiple statements in a transaction
function UNIT.transactedQueries(statements, callback, errorCallback, connectionID)
  local connection = UNIT.getConnection(connectionID)
  local transaction = connection:createTransaction()

  for _, statement in pairs(statements) do
    local query = connection:query(statement)
    transaction:addQuery(query)

    countStatement(statement)
  end

  function transaction:onSuccess()
    -- local allQueries = transaction:getQueries()
    -- local query1Duplicate = allQueries[1]
    if (callback) then
      callback()
    end
  end

  function transaction:onError(err)
    ErrorNoHaltWithStack("An error occured while executing the query: " .. err)

    if (errorCallback) then
      errorCallback(err)
    end
  end

  transaction:start()
end
