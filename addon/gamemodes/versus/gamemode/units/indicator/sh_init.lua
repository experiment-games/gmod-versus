local UNIT = UNIT

UNIT.libraryKey = "indicator"

versus.includePrefixed("cl_init.lua")

if (SERVER) then
  util.AddNetworkString("versus.indicator.create")
  util.AddNetworkString("versus.indicator.remove")

  function UNIT.create(player, id, indicator)
    net.Start("versus.indicator.create")
    net.WriteString(id)
    net.WriteTable(indicator)
    net.Send(player)

    player._VersusIndicators = player._VersusIndicators or {}
    player._VersusIndicators[id] = indicator
  end

  function UNIT.remove(player, id)
    net.Start("versus.indicator.remove")
    net.WriteString(id)
    net.Send(player)

    if (player._VersusIndicators) then
      player._VersusIndicators[id] = nil
    end
  end

  function UNIT.removeAll(player)
    if (player._VersusIndicators) then
      for id, _ in pairs(player._VersusIndicators) do
        UNIT.remove(player, id)
      end

      player._VersusIndicators = {}
    end
  end

  -- Ensure entities tracked by NPC indicators stay in the player's PVS
  function UNIT.hook:SetupPlayerVisibility(player)
    if not player._VersusIndicators then return end

    for _, indicator in pairs(player._VersusIndicators) do
      local entIndex = indicator.entIndex

      if entIndex then
        local ent = Entity(entIndex)

        if IsValid(ent) then
          AddOriginToPVS(ent:GetPos())
        end
      end
    end
  end
end
