versus.network = versus.network or {}
versus.network.callbacks = versus.network.callbacks or {}
versus.network.messageCache = versus.network.messageCache or {}
versus.network.messageCountCache = versus.network.messageCountCache or {}

-- Net message size limit in bits
versus.network.TARGET_SERVER = -1
versus.network.MAX_CHUNK_SIZE = 65533 * 8

-- Chunk send throttling
versus.network.MAX_CHUNKS_PER_TICK = 1
versus.network.MAX_CHUNKS_PER_INTERVAL = 1
versus.network.CHUNK_SEND_INTERVAL_SECONDS = 0.15

versus.network.BITSIZE_CHUNK_COUNT = 32
versus.network.BITSIZE_MESSAGE_ID = 32
versus.network.BITSIZE_CHUNK_ID = 32
versus.network.BITSIZE_NEW_CHUNK_META = versus.network.BITSIZE_MESSAGE_ID + versus.network.BITSIZE_CHUNK_ID

versus.network.CURRENT_MESSAGE_ID = versus.network.CURRENT_MESSAGE_ID or 1

--- Creates a new message writer for sending unbounded size messages.
--- ! WARNING: You should only use this for large data transfers that cannot be
--- ! accomplished with normal net messages, as this system is more complex and
--- ! has more overhead.
--- ! A good use case is for example: sending large inventory data or world data.
--- @param identifier string The identifier for this message type
--- @return VersusNetworkMessageWriter # The message writer
function versus.network.startUnboundedMessage(identifier)
  return setmetatable({}, FindMetaTable("VersusNetworkMessageWriter")):init(identifier)
end

if (SERVER) then
  util.AddNetworkString("versus.network.messagePart")
end

function versus.network.receiveUnbounded(identifier, callback)
  versus.network.callbacks[identifier] = callback
end

-- We will receive chunks in parts, so we need to cache them
net.Receive("versus.network.messagePart", function(len, player)
  local chunk = {}
  local bitsRead = 0

  local messageID = net.ReadUInt(versus.network.BITSIZE_MESSAGE_ID)
  bitsRead = bitsRead + versus.network.BITSIZE_MESSAGE_ID
  local chunkID = net.ReadUInt(versus.network.BITSIZE_CHUNK_ID)
  bitsRead = bitsRead + versus.network.BITSIZE_CHUNK_ID

  versus.network.messageCache[messageID] = versus.network.messageCache[messageID] or {}
  versus.network.messageCountCache[messageID] = versus.network.messageCountCache[messageID] or 0

  if (versus.network.messageCache[messageID][chunkID]) then
    ErrorNoHalt("versus.network: Received duplicate chunk " .. chunkID .. " for message " .. messageID .. "\n")
  end

  versus.network.messageCache[messageID][chunkID] = chunk

  local firstChunk

  if (chunkID == 1) then
    firstChunk = chunk
    chunk.messageIdentifier = net.ReadString()
    bitsRead = bitsRead + 8 +
        (chunk.messageIdentifier:len() * 8) -- WriteString includes and extra byte for strings (and a byte per char)
    chunk.messageChunkCount = net.ReadUInt(versus.network.BITSIZE_CHUNK_COUNT)
    bitsRead = bitsRead + versus.network.BITSIZE_CHUNK_COUNT
  else
    firstChunk = versus.network.messageCache[messageID][1]
  end

  local remainingBits = len - bitsRead

  chunk.data = {}

  for i = 1, remainingBits do
    table.insert(chunk.data, net.ReadBit())
  end

  versus.network.messageCountCache[messageID] = versus.network.messageCountCache[messageID] + 1

  if (firstChunk
        and versus.network.messageCountCache[messageID] == firstChunk.messageChunkCount) then
    local message = setmetatable({}, FindMetaTable("VersusNetworkMessageReader")):init(versus.network.messageCache
      [messageID])

    local handler = versus.network.callbacks[message.identifier]

    if (handler) then
      handler(message, player)
    else
      ErrorNoHalt("versus.network: No handler for message identifier " .. message.identifier .. "\n")
    end

    -- Clear the cache so we don't bloat memory
    versus.network.messageCache[messageID] = nil
    versus.network.messageCountCache[messageID] = nil
  end
end)

if (CLIENT) then
  local chunksThisInterval = 0
  local lastResetTime = CurTime()

  hook.Add("Tick", "versus.network.messagePartSender", function()
    local queue = versus.network.serverQueue
    if (not queue) then
      return
    end

    -- Reset interval counter
    local currentTime = CurTime()
    if (currentTime - lastResetTime >= versus.network.CHUNK_SEND_INTERVAL_SECONDS) then
      chunksThisInterval = 0
      lastResetTime = currentTime
    end

    -- Check interval limit
    if (chunksThisInterval >= versus.network.MAX_CHUNKS_PER_INTERVAL) then
      return
    end

    -- Process up to MAX_CHUNKS_PER_TICK chunks
    for i = 1, versus.network.MAX_CHUNKS_PER_TICK do
      local chunk = queue:dequeue()
      if (not chunk) then
        break
      end

      -- Send the chunk
      net.Start("versus.network.messagePart")
      for _, dataBuilder in pairs(chunk.data) do
        dataBuilder()
      end
      net.SendToServer()

      chunksThisInterval = chunksThisInterval + 1

      -- Check if we've hit the interval limit
      if (chunksThisInterval >= versus.network.MAX_CHUNKS_PER_INTERVAL) then
        break
      end
    end
  end)
else
  hook.Add("PlayerTick", "versus.network.messagePartSender", function(player)
    local queue = player._VersusNetworkQueue
    if (not queue) then
      return
    end

    -- Initialize per-player throttling state
    player.versusNetworkChunksThisInterval = player.versusNetworkChunksThisInterval or 0
    player.versusNetworkLastResetTime = player.versusNetworkLastResetTime or CurTime()

    -- Reset interval counter
    local currentTime = CurTime()
    if (currentTime - player.versusNetworkLastResetTime >= versus.network.CHUNK_SEND_INTERVAL_SECONDS) then
      player.versusNetworkChunksThisInterval = 0
      player.versusNetworkLastResetTime = currentTime
    end

    -- Check interval limit
    if (player.versusNetworkChunksThisInterval >= versus.network.MAX_CHUNKS_PER_INTERVAL) then
      return
    end

    -- Process up to MAX_CHUNKS_PER_TICK chunks
    for i = 1, versus.network.MAX_CHUNKS_PER_TICK do
      local chunk = queue:dequeue()
      if (not chunk) then
        break
      end

      local success = xpcall(function()
        net.Start("versus.network.messagePart")
        for _, dataBuilder in pairs(chunk.data) do
          dataBuilder()
        end
        net.Send(player)
      end, function(err)
        ErrorNoHaltWithStack("Error sending network chunk: " .. tostring(err) .. "\n")
        PrintTable(chunk)
      end)

      if (not success) then
        net.Abort()
      end

      player.versusNetworkChunksThisInterval = player.versusNetworkChunksThisInterval + 1

      -- Check if we've hit the interval limit
      if (player.versusNetworkChunksThisInterval >= versus.network.MAX_CHUNKS_PER_INTERVAL) then
        break
      end
    end
  end)
end
