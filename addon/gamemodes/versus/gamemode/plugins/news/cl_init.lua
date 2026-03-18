local PLUGIN       = PLUGIN

PLUGIN.articles    = PLUGIN.articles or {}
PLUGIN.newsPanel   = PLUGIN.newsPanel or nil
PLUGIN.editorPanel = PLUGIN.editorPanel or nil

--- Open the news screen panel. If one is already open, refresh it with the current articles.
function PLUGIN.openNewsScreen()
  if #PLUGIN.articles == 0 then return end

  if IsValid(PLUGIN.newsPanel) then
    PLUGIN.newsPanel:SetArticles(PLUGIN.articles)
    return
  end

  PLUGIN.newsPanel = vgui.Create("versus_NewsScreen")
  PLUGIN.newsPanel:SetArticles(PLUGIN.articles)
end

--- Open the news article editor. Optionally pre-loads an existing article for editing.
--- @param article table|nil  Existing article data, or nil to create a new one.
function PLUGIN.openNewsEditor(article)
  if not LocalPlayer():IsAdmin() then return end

  if IsValid(PLUGIN.editorPanel) then
    if article then
      PLUGIN.editorPanel:LoadArticle(article)
    end
    return
  end

  PLUGIN.editorPanel = vgui.Create("versus_NewsEditor")

  if article then
    PLUGIN.editorPanel:LoadArticle(article)
  end
end

--[[
  Net messages
--]]

-- Receive the full article list from the server (possibly a large unbounded message).
versus.network.receiveUnbounded("versus.news.articles", function(message)
  local json      = message:readString()
  local articles  = util.JSONToTable(json)
  PLUGIN.articles = istable(articles) and articles or {}

  -- Refresh the panel if it is already open.
  if IsValid(PLUGIN.newsPanel) then
    PLUGIN.newsPanel:SetArticles(PLUGIN.articles)
  else
    PLUGIN.openNewsScreen()
  end
end)

net.Receive("versus.news.admin.saveResult", function()
  local ok  = net.ReadBool()
  local msg = net.ReadString()

  versus.message.notify(
    msg or (ok and "Article saved." or "Failed to save article."),
    ok and NOTIFY_CHAT_LIGHTBULB or NOTIFY_ERROR
  )
end)

net.Receive("versus.news.admin.deleteResult", function()
  local ok  = net.ReadBool()
  local msg = net.ReadString()

  versus.message.notify(
    msg or (ok and "Article deleted." or "Failed to delete article."),
    ok and NOTIFY_CHAT_LIGHTBULB or NOTIFY_ERROR
  )
end)

--[[
  Console commands
--]]

concommand.Add("versus_news", function()
  PLUGIN.openNewsScreen()
end)

-- versus_news_new  – open a blank editor to create a new article.
concommand.Add("versus_news_new", function()
  if not LocalPlayer():IsAdmin() then
    versus.message.notify("You don't have permission to access this panel.")
    return
  end

  PLUGIN.openNewsEditor()
end)

-- versus_news_edit <id>  – open the editor pre-filled with the article matching <id>.
concommand.Add("versus_news_edit", function(_, _, args)
  if not LocalPlayer():IsAdmin() then
    versus.message.notify("You don't have permission to access this panel.")
    return
  end

  local id = args[1]

  if not isstring(id) or id == "" then
    versus.message.notify("Usage: versus_news_edit <article id>")
    return
  end

  local found = nil

  for _, article in ipairs(PLUGIN.articles) do
    if article.id == id then
      found = article
      break
    end
  end

  if not found then
    versus.message.notify("No article found with id: " .. tostring(id))
    return
  end

  PLUGIN.openNewsEditor(found)
end)
