local PLUGIN = PLUGIN

util.AddNetworkString("versus.news.admin.save")
util.AddNetworkString("versus.news.admin.saveResult")
util.AddNetworkString("versus.news.admin.delete")
util.AddNetworkString("versus.news.admin.deleteResult")

local DATA_DIR  = "versus/news"
local DATA_FILE = DATA_DIR .. "/articles.json"

file.CreateDir(DATA_DIR)

--- Load articles from disk. Returns an empty table if no data exists yet.
local function loadArticles()
  if not file.Exists(DATA_FILE, "DATA") then
    return {}
  end

  local raw = file.Read(DATA_FILE, "DATA")
  if not raw then return {} end

  local articles = util.JSONToTable(raw)
  return istable(articles) and articles or {}
end

--- Persist articles to disk.
--- @param articles table
local function saveArticles(articles)
  file.Write(DATA_FILE, util.TableToJSON(articles, false))
end

PLUGIN.articles = PLUGIN.articles or loadArticles()

--- Build the merged article list with a hook where dynamic articles can be injected.
local function buildArticleList()
  local articles = {}

  for _, article in ipairs(PLUGIN.articles) do
    table.insert(articles, article)
  end

  hook.Run("ModifyVersusNewsArticles", articles)

  return articles
end

--- Send the full article list to a single player via unbounded message.
--- @param player Player
local function sendArticles(player)
  if not IsValid(player) then return end

  local json    = util.TableToJSON(buildArticleList(), false)
  local message = versus.network.startUnboundedMessage("versus.news.articles")
  message:writeString(json)
  message:send(player)
end

--- Broadcast the article list to every connected player.
local function broadcastArticles()
  for _, player in ipairs(player.GetAll()) do
    sendArticles(player)
  end
end

-- Send articles when a player has fully initialised on the server.
function PLUGIN.hook:PlayerInitialized(player)
  sendArticles(player)
end

--[[
  Admin net messages
--]]

-- Save (add or update) an article. The article JSON is sent as a string.
net.Receive("versus.news.admin.save", function(len, player)
  if not player:IsAdmin() then return end

  local json = net.ReadString()

  if #json > PLUGIN.MAX_PAYLOAD_SIZE then
    net.Start("versus.news.admin.saveResult")
    net.WriteBool(false)
    net.WriteString("Payload exceeds the maximum allowed size.")
    net.Send(player)
    return
  end

  local article = util.JSONToTable(json)

  if not istable(article) then
    net.Start("versus.news.admin.saveResult")
    net.WriteBool(false)
    net.WriteString("Malformed article data.")
    net.Send(player)
    return
  end

  -- Validate required fields
  local articleID    = isstring(article.id) and article.id or ""
  local articleTitle = isstring(article.title) and article.title or ""

  if not articleID:match("^[%w%-%_%.]+$") then
    net.Start("versus.news.admin.saveResult")
    net.WriteBool(false)
    net.WriteString("Article ID must be non-empty and use only alphanumerics, hyphens, underscores, or dots.")
    net.Send(player)
    return
  end

  if #articleTitle < 1 then
    net.Start("versus.news.admin.saveResult")
    net.WriteBool(false)
    net.WriteString("Article must have a non-empty title.")
    net.Send(player)
    return
  end

  local articleContent     = isstring(article.content) and article.content or ""
  local articleHeaderImage = isstring(article.headerImage) and article.headerImage or nil

  -- Sanitise: strip to only the known-safe fields
  local cleaned            = {
    id          = articleID:sub(1, 100),
    type        = (article.type == "event") and "event" or "update",
    title       = articleTitle:sub(1, PLUGIN.MAX_TITLE_LENGTH),
    date        = isnumber(article.date) and math.floor(article.date) or os.time(),
    headerImage = (articleHeaderImage ~= nil and #articleHeaderImage > 0)
        and articleHeaderImage:sub(1, 512) or nil,
    content     = articleContent:sub(1, PLUGIN.MAX_CONTENT_LENGTH),
  }

  -- Upsert: update existing article, or insert at the front (newest first)
  local found              = false

  for i, a in ipairs(PLUGIN.articles) do
    if a.id == cleaned.id then
      PLUGIN.articles[i] = cleaned
      found = true
      break
    end
  end

  if not found then
    if #PLUGIN.articles >= PLUGIN.MAX_ARTICLES then
      net.Start("versus.news.admin.saveResult")
      net.WriteBool(false)
      net.WriteString("Maximum number of articles (" .. PLUGIN.MAX_ARTICLES .. ") reached.")
      net.Send(player)
      return
    end

    table.insert(PLUGIN.articles, 1, cleaned)
  end

  saveArticles(PLUGIN.articles)
  broadcastArticles()

  net.Start("versus.news.admin.saveResult")
  net.WriteBool(true)
  net.WriteString("Article saved successfully.")
  net.Send(player)
end)

-- Delete an article by ID.
net.Receive("versus.news.admin.delete", function(len, player)
  if not player:IsAdmin() then return end

  local id = net.ReadString()

  -- Sanitise: only allow safe characters in the ID
  id = id:match("^[%w%-%_%.]+$")

  if not id then
    net.Start("versus.news.admin.deleteResult")
    net.WriteBool(false)
    net.WriteString("Invalid article ID.")
    net.Send(player)
    return
  end

  local removed = false

  for i, a in ipairs(PLUGIN.articles) do
    if a.id == id then
      table.remove(PLUGIN.articles, i)
      removed = true
      break
    end
  end

  if not removed then
    net.Start("versus.news.admin.deleteResult")
    net.WriteBool(false)
    net.WriteString("Article not found.")
    net.Send(player)
    return
  end

  saveArticles(PLUGIN.articles)
  broadcastArticles()

  net.Start("versus.news.admin.deleteResult")
  net.WriteBool(true)
  net.WriteString("Article deleted.")
  net.Send(player)
end)
