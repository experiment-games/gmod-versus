local UNIT = UNIT

--- @class NodeGraphHeader
--- @field ainetVer number Version of the AI Net format, e.g. 0x00000002 for Source 2007
--- @field mapVer number Version of the map the graph was generated from, usage depends on the map compiler

--- @class NodeGraphNode
--- @field pos Vector position of the node in the world
--- @field yaw number Yaw angle in degrees (0-360)
--- @field offsets table Array of 10 floats, used for reachability calculations
--- @field nodeType number Enum value indicating the type of node (e.g. ground, air)
--- @field nodeTypeName string Human-readable name of the node type
--- @field nodeInfo number Additional info about the node, usage depends on node type
--- @field zone number Zone ID for the node, used in some pathfinding algorithms

--- @class NodeGraphLink
--- @field srcId number ID of the source node (1-based index into nodes array)
--- @field destId number ID of the destination node (1-based index into nodes array)
--- @field moves table Array of 10 bytes, used for reachability calculations for different hull

UNIT.libraryKey = "nodeGraph"
UNIT.name = "NodeGraph Parser"
UNIT.description =
"Parser for Source engine nodegraph files (.ain). Provides a Lua representation of the graph with nodes, links, and spatial indexing for efficient queries."

local NUM_HULLS = 10
local NODE_TYPES = {
  [2] = "NODE_TYPE_GROUND",
  [3] = "NODE_TYPE_AIR",
  [4] = "NODE_TYPE_CLIMB",
  [5] = "NODE_TYPE_WATER",
}

UNIT.nodeTypes = {
  NODE_TYPE_GROUND = "NODE_TYPE_GROUND",
  NODE_TYPE_AIR    = "NODE_TYPE_AIR",
  NODE_TYPE_CLIMB  = "NODE_TYPE_CLIMB",
  NODE_TYPE_WATER  = "NODE_TYPE_WATER",
}

--- @param fileHandle File Opened file
--- @return NodeGraphHeader
local function parseHeader(fileHandle)
  return {
    ainetVer = fileHandle:ReadLong(),
    mapVer   = fileHandle:ReadLong(),
  }
end

--- @param fileHandle File Opened file
--- @return NodeGraphNode
local function parseNode(fileHandle)
  local node = {}

  node.pos = Vector(
    fileHandle:ReadFloat(),
    fileHandle:ReadFloat(),
    fileHandle:ReadFloat()
  )

  node.yaw = fileHandle:ReadFloat()

  node.offsets = {}
  for i = 1, NUM_HULLS do
    node.offsets[i] = fileHandle:ReadFloat()
  end

  node.nodeType     = fileHandle:ReadByte()
  node.nodeTypeName = NODE_TYPES[node.nodeType] or "NODE_TYPE_UNKNOWN"
  node.nodeInfo     = fileHandle:ReadUShort()
  node.zone         = fileHandle:ReadShort()

  return node
end

--- @param fileHandle File Opened file
--- @return NodeGraphLink
local function parseLink(fileHandle)
  local link  = {}

  link.srcId  = fileHandle:ReadShort()
  link.destId = fileHandle:ReadShort()

  link.moves  = {}
  for i = 1, NUM_HULLS do
    link.moves[i] = fileHandle:ReadByte()
  end

  return link
end

local function parseLookupTable(fileHandle, numNodes)
  local lookup = {}

  for i = 1, numNodes do
    lookup[i] = fileHandle:ReadLong()
  end

  return lookup
end

--- Loads and parses a nodegraph file from the game filesystem. Will build
--- a spatial index for efficient range queries after parsing.
--- @param mapName string Map name without extension, e.g. "rp_apocalypse"
--- @return table?, string? # Parsed graph table, or nil + error message
function UNIT.parseFile(mapName)
  local path = "maps/graphs/" .. mapName .. ".ain"
  local fileHandle = file.Open(path, "rb", "GAME")

  if not fileHandle then
    return nil, "could not open file: " .. path
  end

  local ok, result = pcall(function()
    local header   = parseHeader(fileHandle)
    local numNodes = fileHandle:ReadLong()

    local nodes    = {}
    for i = 1, numNodes do
      nodes[i] = parseNode(fileHandle)
    end

    local numLinks = fileHandle:ReadLong()

    local links = {}
    for i = 1, numLinks do
      links[i] = parseLink(fileHandle)
    end

    local lookup = parseLookupTable(fileHandle, numNodes)

    return {
      header   = header,
      numNodes = numNodes,
      nodes    = nodes,
      numLinks = numLinks,
      links    = links,
      lookup   = lookup,
    }
  end)

  fileHandle:Close()

  if not ok then
    return nil, "parse error: " .. tostring(result)
  end

  local graph = setmetatable(result, FindMetaTable("ParsedNodeGraph"))
  graph:BuildSpatialIndex()

  return graph, nil
end

--- Gets the parsed node graph for the current map, if it was successfully loaded. Will return nil if there was an error loading or parsing the graph.
--- @return table? # Parsed graph table, or nil if not loaded
function UNIT.getForCurrentMap()
  return UNIT.currentMapNodeGraph
end

--[[
  Hooks
--]]

-- When the gamemode initializes, we parse the nodegraph for the current map and store it in
-- the UNIT table for easy access by other plugins.
function UNIT.hook:Initialize()
  -- TODO: Will this fail the first time we load the map and there is no graph file yet? Should we add some retry logic or a console command to manually load the graph after it's generated?
  local mapName = string.lower(game.GetMap())
  local nodeGraph, err = self.parseFile(mapName)

  if (not nodeGraph) then
    ErrorNoHalt("Failed to load nodegraph for map " .. mapName .. ": " .. err .. " (expect further errors!)\n")
  end

  self.currentMapNodeGraph = nodeGraph
end

--[[
  Console Commands (for testing)
--]]

-- Draws the nodes near where the player is looking.
concommand.Add("versus_debug_draw_nodes", function(player, cmd, args)
  if (not player:IsAdmin()) then
    return
  end

  local graph = UNIT.getForCurrentMap()

  if not graph then
    print("Nodegraph not loaded for current map.")
    return
  end

  local range = tonumber(args[1]) or 512
  local pos = player:GetEyeTraceNoCursor().HitPos
  local nearbyNodes = graph:GetNodesInRange(pos, range)

  for _, nodeId in ipairs(nearbyNodes) do
    local node = graph.nodes[nodeId]
    debugoverlay.Sphere(node.pos, 16, 5, Color(255, 0, 0), true)
    debugoverlay.Text(node.pos + Vector(0, 0, 20), node.nodeTypeName, 5, true)
  end
end)

-- Draws the nodes in a path between where the player is and where they are looking.
concommand.Add("versus_debug_draw_path_nodes", function(player, cmd, args)
  if (not player:IsAdmin()) then
    return
  end

  local graph = UNIT.getForCurrentMap()

  if not graph then
    print("Nodegraph not loaded for current map.")
    return
  end

  local width = tonumber(args[1]) or 128
  local startPos = player:GetPos()
  local endPos = player:GetEyeTraceNoCursor().HitPos
  local pathNodes = graph:GetNodesInPath(startPos, endPos, width)

  for _, nodeId in ipairs(pathNodes) do
    local node = graph.nodes[nodeId]
    debugoverlay.Sphere(node.pos, 16, 5, Color(0, 255, 0), true)
    debugoverlay.Text(node.pos + Vector(0, 0, 20), node.nodeTypeName, 5, true)
  end
end)
