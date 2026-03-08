local PLUGIN = PLUGIN

function PLUGIN.hook:InitPostEntity()
  local desired = 10000
  local current = GetConVar("cl_detaildist"):GetInt()

  if (current < desired) then
    print(
      string.format(
        "[Versus] Increased cl_detaildist to %d (was %d) so grass doesn't pop in as noticably.",
        desired,
        current
      )
    )

    RunConsoleCommand("cl_detaildist", tostring(desired))
  end
end
