local UNIT = UNIT

-- Tuned to ~2x our typical query radius
local CELL_SIZE = 512 -- 256

-- Cantor-style hash into a string key
local function cellKey(cx, cy, cz)
  return string.format("%d,%d,%d", cx, cy, cz)
end

local function worldToCell(x, y, z)
  return math.floor(x / CELL_SIZE),
      math.floor(y / CELL_SIZE),
      math.floor(z / CELL_SIZE)
end

--- Returns the squared distance from point `p` to the segment `(a, b)`.
--- @param px number
--- @param py number
--- @param pz number
--- @param ax number
--- @param ay number
--- @param az number
--- @param bx number
--- @param by number
--- @param bz number
--- @return number
local function pointToSegmentDistSq(px, py, pz, ax, ay, az, bx, by, bz)
  local dx, dy, dz = bx - ax, by - ay, bz - az
  local lenSq = dx * dx + dy * dy + dz * dz

  local t
  if lenSq == 0 then
    -- Degenerate segment, treat as point
    t = 0
  else
    t = ((px - ax) * dx + (py - ay) * dy + (pz - az) * dz) / lenSq
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
  end

  local cx = ax + t * dx - px
  local cy = ay + t * dy - py
  local cz = az + t * dz - pz
  return cx * cx + cy * cy + cz * cz
end

--- @class ParsedNodeGraph
--- @field header NodeGraphHeader
--- @field numNodes number
--- @field nodes table Array of NodeGraphNode, indexed by node ID (1-based)
--- @field numLinks number
--- @field links table Array of NodeGraphLink
--- @field lookup table Array of node IDs indexed by their file offset, used for quick lookup
local nodeGraphMeta = {}
nodeGraphMeta.__index = nodeGraphMeta

--- Pre-builds the spatial grid. Called immediately after parsing.
function nodeGraphMeta:BuildSpatialIndex()
  local grid = {}

  for id, node in ipairs(self.nodes) do
    local cx, cy, cz = worldToCell(node.pos.x, node.pos.y, node.pos.z)
    local key = cellKey(cx, cy, cz)

    if not grid[key] then
      grid[key] = {}
    end

    table.insert(grid[key], id)
  end

  self._grid = grid
end

--- Returns all node IDs within `radius` units of `pos`.
--- @param pos Vector
--- @param radius number
--- @return number[] # Array of node IDs
function nodeGraphMeta:GetNodesInRange(pos, radius)
  local grid = self._grid
  assert(grid, "Call BuildSpatialIndex() first")

  local results = {}
  local radiusSq = radius * radius

  -- Expand AABB to cell coords
  local cMinX, cMinY, cMinZ = worldToCell(pos.x - radius, pos.y - radius, pos.z - radius)
  local cMaxX, cMaxY, cMaxZ = worldToCell(pos.x + radius, pos.y + radius, pos.z + radius)

  for cx = cMinX, cMaxX do
    for cy = cMinY, cMaxY do
      for cz = cMinZ, cMaxZ do
        local cell = grid[cellKey(cx, cy, cz)]

        if not cell then
          continue
        end

        for _, id in ipairs(cell) do
          local node = self.nodes[id]
          local dx = node.pos.x - pos.x
          local dy = node.pos.y - pos.y
          local dz = node.pos.z - pos.z

          if dx * dx + dy * dy + dz * dz > radiusSq then
            continue
          end

          table.insert(results, id)
        end
      end
    end
  end

  return results
end

--- Returns all node IDs within a capsule between `startPos` and `endPos` with the given `width`.
--- @param startPos Vector
--- @param endPos Vector
--- @param width number Full width of the path (radius = width/2)
--- @return number[] # Array of node IDs
function nodeGraphMeta:GetNodesInPath(startPos, endPos, width)
  local grid = self._grid
  assert(grid, "Call BuildSpatialIndex() first")

  local radius = width * 0.5
  local radiusSq = radius * radius

  local ax, ay, az = startPos.x, startPos.y, startPos.z
  local bx, by, bz = endPos.x, endPos.y, endPos.z

  -- AABB of the capsule
  local minX = math.min(ax, bx) - radius
  local minY = math.min(ay, by) - radius
  local minZ = math.min(az, bz) - radius
  local maxX = math.max(ax, bx) + radius
  local maxY = math.max(ay, by) + radius
  local maxZ = math.max(az, bz) + radius

  local cMinX, cMinY, cMinZ = worldToCell(minX, minY, minZ)
  local cMaxX, cMaxY, cMaxZ = worldToCell(maxX, maxY, maxZ)

  local results = {}

  for cx = cMinX, cMaxX do
    for cy = cMinY, cMaxY do
      for cz = cMinZ, cMaxZ do
        local cell = grid[cellKey(cx, cy, cz)]
        if cell then
          for _, id in ipairs(cell) do
            local node = self.nodes[id]
            local distSq = pointToSegmentDistSq(
              node.pos.x, node.pos.y, node.pos.z,
              ax, ay, az,
              bx, by, bz
            )
            if distSq <= radiusSq then
              table.insert(results, id)
            end
          end
        end
      end
    end
  end

  return results
end

--- Gets a node by its ID (index in the nodes array)
--- @param id number Node ID (1-based index)
--- @return NodeGraphNode? # The node with the given ID, or nil if not found
function nodeGraphMeta:GetNodeByID(id)
  return self.nodes[id]
end

--- Gets all nodes, optionally filtered by type
--- @param typeName string? If provided, only nodes of this type will be returned
--- @return NodeGraphNode[] # Array of nodes matching the criteria
function nodeGraphMeta:GetNodes(typeName)
  if not typeName then
    return self.nodes
  end

  local filtered = {}
  for _, node in ipairs(self.nodes) do
    if node.nodeTypeName == typeName then
      table.insert(filtered, node)
    end
  end

  return filtered
end

debug.getregistry()["ParsedNodeGraph"] = nodeGraphMeta
