local UNIT = UNIT

function UNIT.run(command, ...)
  local arguments = ""

  for _, data in pairs({ ... }) do
    -- Surround the argument in "quotes"
    arguments = arguments .. (arguments:len() > 0 and " " or "") .. string.format("$q%s$q", data)
  end

  -- Legacy. We comment this, since the silent throttling of console command can result in unresponsive UIs.
  -- RunConsoleCommand("say", string.format("%s%s %s", versus.config["Command Prefix"], command, arguments))

  net.Start("versus.unit.command.execute")
  net.WriteString(command)
  net.WriteString(arguments)
  net.SendToServer()
end
