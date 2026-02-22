local PLUGIN = PLUGIN

do
  local COMMAND = versus.command.define("generatemanifest")
  COMMAND.description = "Generate the server manifest and map entity files."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addParameter(tostring, "convars",
    "Comma-separated list of convar names whose current values will be saved to the map manifest (e.g. versus_encounters_world_count,versus_lootcrate_world_count).",
    "")

  function COMMAND:onRun(player, convarList)
    local convars = nil

    if (convarList and convarList ~= "") then
      convars = {}

      for _, name in ipairs(string.Explode(",", convarList)) do
        name = string.Trim(name)

        if (name ~= "") then
          local cvar = GetConVar(name)

          if (cvar) then
            convars[name] = cvar:GetString()
          else
            versus.message.notify(player, "Unknown convar: " .. name, NOTIFY_ERROR)
          end
        end
      end
    end

    local manifest = PLUGIN:generateManifestFromEntities(convars)

    if (not manifest) then
      versus.message.notify(player, "Failed to generate manifest.", NOTIFY_ERROR)
      return
    end

    -- Save map-specific entities and convars to maps/{mapname}.json
    local mapData = { entities = manifest.entities }

    if (manifest.convars) then
      mapData.convars = manifest.convars
    end

    local mapDataJSON = util.TableToJSON(mapData, true)
    local mapPath = "versus/maps/" .. manifest.map .. ".json"
    file.Write(mapPath, mapDataJSON)

    versus.message.notify(player, "Server manifest and map entities generated successfully.", NOTIFY_GENERIC)
    versus.message.notify(player, "Saved to: versus/server_manifest.json and " .. mapPath, NOTIFY_GENERIC)
  end
end
