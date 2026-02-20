---@class VersusNetworkMessageReader
local networkMessageMeta = {}
networkMessageMeta.__index = networkMessageMeta

function networkMessageMeta:init(chunks)
  self.identifier = chunks[1].messageIdentifier

  self.chunks = chunks
  self.currentChunkIndex = 1
  self.currentChunkPointer = 1 -- Bit index we're reading in this chunk

  return self
end

function networkMessageMeta:IsValid()
  return true
end

-- TODO: Optimize this mess instead of keeping all these bits in memory in a table
function networkMessageMeta:readFromChunk(readBitSize, asNumber)
  local chunk = self.chunks[self.currentChunkIndex]
  local chunkDataLength = #chunk.data
  local data = asNumber and 0 or {}
  local bytePart = 0

  for bitsRead = 1, readBitSize do
    if (self.currentChunkPointer > chunkDataLength) then
      self.currentChunkIndex = self.currentChunkIndex + 1
      self.currentChunkPointer = 1
      chunk = self.chunks[self.currentChunkIndex]
      chunkDataLength = #chunk.data

      if (chunk == nil) then
        error("Attempted to read past the end of the message!")
      end
    end

    if (asNumber) then
      data = bit.bor(data, bit.lshift(chunk.data[self.currentChunkPointer], bytePart))
      bytePart = bytePart + 1
    else
      table.insert(data, chunk.data[self.currentChunkPointer])
    end

    self.currentChunkPointer = self.currentChunkPointer + 1
  end

  return data
end

function networkMessageMeta:readBit()
  local bitSize = 1
  return self:readFromChunk(bitSize, true)
end

function networkMessageMeta:readBool()
  return self:readBit() == 1
end

function networkMessageMeta:readInt(bitSize)
  return self:readFromChunk(bitSize, true)
end

function networkMessageMeta:readUInt(bitSize)
  return self:readFromChunk(bitSize, true)
end

local function bitTableToBytes(bitTable)
  local bytes = { string.char(0) }
  local bytePart = 0

  for i = 1, #bitTable do
    if (bytePart == 8) then
      table.insert(bytes, string.char(0))
      bytePart = 0
    end

    bytes[#bytes] = string.char(
      bit.bor(string.byte(bytes[#bytes]),
        bit.lshift(bitTable[i], bytePart)))
    bytePart = bytePart + 1
  end

  return bytes
end

function networkMessageMeta:readDataAsByteTable(dataLength)
  local bitSize = dataLength * 8 -- from bytes (string characters) to bits (8 bits per byte)
  local data = self:readFromChunk(bitSize)
  return bitTableToBytes(data)
end

function networkMessageMeta:readData(bitSize)
  local data = self:readDataAsByteTable(bitSize)
  return table.concat(data)
end

-- TODO: This 32-bit uint makes the max string size 4,294,967,295 characters/bytes long
function networkMessageMeta:readString()
  local length = self:readUInt(32)
  local data = self:readDataAsByteTable(length)
  return table.concat(data)
end

-- TODO: Optimize this to not first have to convert from json
function networkMessageMeta:readTable()
  local json = self:readString()
  return util.JSONToTable(json)
end

function networkMessageMeta:readFloat()
  local data = self:readData(4) -- Read 4 bytes (32 bits)

  -- Parse IEEE 754 single-precision float
  local b1, b2, b3, b4 = string.byte(data, 1, 4)

  -- Combine into 32-bit value (little-endian)
  local bits = b4 * 16777216 + b3 * 65536 + b2 * 256 + b1

  -- Extract components
  local sign = (bits >= 2147483648) and -1 or 1
  local exponent = math.floor((bits % 2147483648) / 8388608)
  local mantissa = bits % 8388608

  -- Handle special cases
  if exponent == 0 then
    if mantissa == 0 then
      return sign * 0
    else
      return sign * math.ldexp(mantissa / 8388608, -126)
    end
  elseif exponent == 255 then
    return (mantissa == 0) and (sign * math.huge) or (0 / 0)
  end

  return sign * math.ldexp(1 + mantissa / 8388608, exponent - 127)
end

function networkMessageMeta:readVector()
  local x = self:readFloat()
  local y = self:readFloat()
  local z = self:readFloat()

  return Vector(x, y, z)
end

function networkMessageMeta:readPlayer()
  local entIndex = self:readUInt(MAX_PLAYER_BITS)
  return Entity(entIndex)
end

function networkMessageMeta:readEntity()
  local entIndex = self:readUInt(MAX_EDICT_BITS)

  if (not entIndex) then
    return nil
  end

  return Entity(entIndex)
end

-- TODO: readAngle, readType, readNormal, readMatrix, etc

debug.getregistry()["VersusNetworkMessageReader"] = networkMessageMeta
