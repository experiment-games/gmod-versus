local PLUGIN = PLUGIN

function PLUGIN.hook:PlayerInitialSpawn(player)
  timer.Simple(1, function()
    if IsValid(player) then
      versus.message.notify(
        player,
        "Welcome! Join our Discord for support, news, and more! https://discord.gg/U4x4HgpNhy",
        NOTIFY_CHAT_LIGHTBULB
      )
    end
  end)
end
