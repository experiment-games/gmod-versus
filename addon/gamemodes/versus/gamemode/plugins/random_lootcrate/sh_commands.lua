local PLUGIN = PLUGIN

do
  local COMMAND = versus.command.define("spawnrandomcrate")
  COMMAND.description = "Spawn a loot crate with random items."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  function COMMAND:onRun(player)
    local trace = player:GetEyeTrace()
    local position = trace.HitPos
    position.z = position.z + 16

    local itemPool = {}

    for itemID, item in pairs(versus.item.all()) do
      if (item.isBaseItem or item.hidden) then
        continue
      end

      table.insert(itemPool, {
        itemID = itemID,
        size = 1,
        weight = item.lootWeight or 0.2,
      })
    end

    -- Spawn the crate
    local entity = PLUGIN.spawnLootCrate(player, itemPool, position)

    if (IsValid(entity)) then
      versus.message.notify(
        player,
        "Spawned a random loot crate.",
        NOTIFY_CHAT_LIGHTBULB
      )
    else
      versus.message.notify(
        player,
        "Failed to spawn loot crate!",
        NOTIFY_ERROR
      )
    end
  end
end
