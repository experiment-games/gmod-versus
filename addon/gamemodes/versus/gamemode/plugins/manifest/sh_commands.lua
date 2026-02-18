local PLUGIN = PLUGIN

do
  local COMMAND = versus.command.define("generatemanifest")
  COMMAND.description = "Generate the server manifest and map entity files."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  function COMMAND:onRun(player)
    local manifest = PLUGIN:generateManifestFromEntities()

    if (not manifest) then
      versus.message.notify(player, "Failed to generate manifest.", NOTIFY_ERROR)
      return
    end

    -- Save map-specific entities to maps/{mapname}.json
    local mapEntities = { entities = manifest.entities }
    local mapEntitiesData = util.TableToJSON(mapEntities, true)
    local mapPath = "versus/maps/" .. manifest.map .. ".json"
    file.Write(mapPath, mapEntitiesData)

    versus.message.notify(player, "Server manifest and map entities generated successfully.", NOTIFY_GENERIC)
    versus.message.notify(player, "Saved to: versus/server_manifest.json and " .. mapPath, NOTIFY_GENERIC)
  end
end
