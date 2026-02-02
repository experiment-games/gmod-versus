local PLUGIN = PLUGIN

do
  local COMMAND = versus.command.define("generatemanifest")
  COMMAND.description = "Generate the server manifest file based on existing entities."
  COMMAND.category = "Super Admin Commands"
  COMMAND.requiredFlags = "s"

  COMMAND:addRequiredParameter(tostring, "Path", "The path to save the manifest file to.")

  function COMMAND:onRun(player, path)
    local manifest = PLUGIN:generateManifestFromEntities()

    if (not manifest) then
      versus.message.notify(player, "Failed to generate manifest.", NOTIFY_ERROR)
      return
    end

    -- Ensure it's in the versus folder
    if (not string.StartsWith(path, "versus/")) then
      path = "versus/" .. path
    end

    -- Ensure it has the .json extension
    if (not string.EndsWith(path, ".json")) then
      path = path .. ".json"
    end

    local manifestData = util.TableToJSON(manifest, true)
    file.Write(path, manifestData)

    print(manifestData)

    versus.message.notify(player, "Server manifest generated successfully and saved to " .. path .. ".", NOTIFY_GENERIC)
  end
end
