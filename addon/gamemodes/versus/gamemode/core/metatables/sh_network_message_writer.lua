local g_Player = player

---@class VersusNetworkMessageWriter
local networkMessageMeta = {}
networkMessageMeta.__index = networkMessageMeta

local debugPrint = function(...)
  --print(...)
end

local writeToChunk = function(chunk, dataBuilder, bitSize)
  table.insert(chunk.data, dataBuilder)

  chunk.bitsRemaining = chunk.bitsRemaining - bitSize
end

function networkMessageMeta:init(identifier)
  self.messageID = versus.network.CURRENT_MESSAGE_ID
  versus.network.CURRENT_MESSAGE_ID = versus.network.CURRENT_MESSAGE_ID + 1

  -- Start the first chunk and write this message's ID to it.
  self.chunks = {}
  local chunk = self:newChunk()
  local identifierBitSize = (identifier:len() * 8)
  identifierBitSize = identifierBitSize + 8 -- net.WriteString adds an extra byte

  writeToChunk(chunk, function()
    local chunkCount = #self.chunks
    debugPrint("Starting new message write!")
    debugPrint("\t > id: " .. identifier)
    debugPrint("\t > total chunks: " .. chunkCount)
    net.WriteString(identifier)
    net.WriteUInt(chunkCount, versus.network.BITSIZE_CHUNK_COUNT)
  end, versus.network.BITSIZE_CHUNK_COUNT + identifierBitSize)

  return self
end

function networkMessageMeta:IsValid()
  return true
end

function networkMessageMeta:newChunk()
  local chunk = {
    bitsRemaining = versus.network.MAX_CHUNK_SIZE,
    data = {}
  }

  local chunkID = table.insert(self.chunks, chunk)

  -- Insert this chunks id (to tie it to its sibling messages)
  writeToChunk(chunk, function()
    debugPrint("\tWriting new chunk!")
    debugPrint("\t\t > message id: " .. self.messageID)
    debugPrint("\t\t > chunk id: " .. chunkID)
    net.WriteUInt(self.messageID, versus.network.BITSIZE_MESSAGE_ID)
    net.WriteUInt(chunkID, versus.network.BITSIZE_CHUNK_ID)
  end, versus.network.BITSIZE_NEW_CHUNK_META)

  return chunk
end

function networkMessageMeta:getChunk(additionalBitSize)
  local lastChunk = self.chunks[#self.chunks]

  if (lastChunk.bitsRemaining - additionalBitSize < 0) then
    return self:newChunk()
  end

  return lastChunk
end

function networkMessageMeta:broadcast()
  self:send(g_Player.GetAll())
end

function networkMessageMeta:sendToServer()
  self:send(versus.network.TARGET_SERVER)
end

function networkMessageMeta:send(playerOrRecipientFilter)
  for _, chunk in pairs(self.chunks) do
    self:enqueueChunk(chunk, playerOrRecipientFilter)
  end
end

--- Adds a chunk to the network queue to be sent. This allows us to step through
--- the queue and prevent flooding the network with too many messages at once,
--- which would result in kicking the player with:
--- `BroadcastMessage: Reliable filter message overflow for client x`
--- @param chunk table The chunk to enqueue
function networkMessageMeta:enqueueChunk(chunk, playerOrRecipientFilter)
  if (playerOrRecipientFilter == versus.network.TARGET_SERVER) then
    versus.network.serverQueue = versus.network.serverQueue or versus.util.newQueue()

    versus.network.serverQueue:enqueue(chunk)
  else
    local function createPlayerMessageQueue(player)
      player._VersusNetworkQueue = player._VersusNetworkQueue or versus.util.newQueue()

      player._VersusNetworkQueue:enqueue(chunk)
    end

    if (type(playerOrRecipientFilter) == "CRecipientFilter") then
      playerOrRecipientFilter = playerOrRecipientFilter:GetPlayers()
    end

    if (istable(playerOrRecipientFilter)) then
      for _, player in ipairs(playerOrRecipientFilter) do
        createPlayerMessageQueue(player)
      end
    elseif (isentity(playerOrRecipientFilter) and playerOrRecipientFilter:IsPlayer()) then
      createPlayerMessageQueue(playerOrRecipientFilter)
    else
      error("Invalid playerOrRecipientFilter passed to VersusNetworkMessageWriter:send")
      return
    end
  end
end

function networkMessageMeta:writeBit(data)
  local bitSize = 1
  writeToChunk(self:getChunk(bitSize), function()
    debugPrint("\t\t\t Writing Bit: " .. tostring(data), " (bit size = " .. bitSize .. ")")
    net.WriteBit(data)
  end, bitSize)
end

networkMessageMeta.writeBool = networkMessageMeta.writeBit

function networkMessageMeta:writeInt(data, bitSize)
  writeToChunk(self:getChunk(bitSize), function()
    debugPrint("\t\t\t Writing Int: " .. data, " (bit size = " .. bitSize .. ")")
    net.WriteInt(data, bitSize)
  end, bitSize)
end

function networkMessageMeta:writeUInt(data, bitSize)
  writeToChunk(self:getChunk(bitSize), function()
    debugPrint("\t\t\t Writing UInt: " .. data, " (bit size = " .. bitSize .. ")")
    net.WriteUInt(data, bitSize)
  end, bitSize)
end

function networkMessageMeta:writeData(data, dataLength)
  local bitSize = dataLength * 8 -- from bytes (string characters) to bits (8 bits per byte)

  -- If the entire data can not fit in a single chunk, split it up
  if (bitSize + versus.network.BITSIZE_NEW_CHUNK_META > versus.network.MAX_CHUNK_SIZE) then
    -- Note: this will always skip the existing chunk, even if there's space in it. I guess that's desirable since we don't neccessarily know the length of the identifier string
    repeat
      local chunk = self:getChunk(versus.network.MAX_CHUNK_SIZE - versus.network.BITSIZE_NEW_CHUNK_META)
      local chunkData = string.sub(data, 1, versus.network.MAX_CHUNK_SIZE - versus.network.BITSIZE_NEW_CHUNK_META / 8)
      data = string.sub(data, (versus.network.MAX_CHUNK_SIZE - versus.network.BITSIZE_NEW_CHUNK_META / 8) + 1)

      writeToChunk(chunk, function()
        debugPrint("\t\t\t Writing Data over multiple chunks: " .. chunkData, " (bit size = " .. (#chunkData * 8) .. ")")
        net.WriteData(chunkData, #chunkData)
      end, #chunkData * 8)
    until (#data == 0)

    return
  end

  writeToChunk(self:getChunk(bitSize), function()
    debugPrint("\t\t\t Writing Data: " .. data, " (bit size = " .. bitSize .. ")")
    net.WriteData(data, dataLength)
  end, bitSize)
end

-- TODO: This 32-bit uint makes the max string size 4,294,967,295 characters/bytes long
function networkMessageMeta:writeString(data)
  self:writeUInt(data:len(), 32)
  self:writeData(data, data:len())
end

-- TODO: Optimize this to not first have to convert to json
function networkMessageMeta:writeTable(data)
  self:writeString(util.TableToJSON(data))
end

function networkMessageMeta:writeFloat(data)
  local bitSize = 32
  writeToChunk(self:getChunk(bitSize), function()
    debugPrint("\t\t\t Writing Float: " .. tostring(data), " (bit size = " .. bitSize .. ")")
    net.WriteFloat(data)
  end, bitSize)
end

function networkMessageMeta:writeVector(vector)
  self:writeFloat(vector.x)
  self:writeFloat(vector.y)
  self:writeFloat(vector.z)
end

function networkMessageMeta:writePlayer(player)
  self:writeUInt(IsValid(player) and player:IsPlayer() and player:EntIndex() or 0, MAX_PLAYER_BITS)
end

function networkMessageMeta:writeEntity(entity)
  self:writeUInt(IsValid(entity) and entity:EntIndex() or 0, MAX_EDICT_BITS)
end

-- TODO: writeAngle, writeType, writeNormal, writeMatrix, etc

debug.getregistry()["VersusNetworkMessageWriter"] = networkMessageMeta
