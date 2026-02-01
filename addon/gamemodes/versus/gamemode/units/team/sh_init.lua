local UNIT = UNIT

UNIT.libraryKey = "team"

UNIT.index = UNIT.index or 1
UNIT.stored = UNIT.stored or {}

-- Add a new team.
function UNIT.add(data)
  local data = table.Merge({
    index = UNIT.index
  }, data)

  -- Make the limit maximum players if there is none set.
  data.limit = data.limit or game.MaxPlayers()
  data.access = data.access or "b"
  data.description = data.description or "N/A."
  data.models = data.models or versus.player.getDefaultModelList()

  if (not istable(data.models)) then
    data.models = { data.models }
  end

  -- (this is called on the server and the client).
  team.SetUp(UNIT.index, data.name, data.color)

  UNIT.stored[data.name] = data

  if (UNIT.index == data.index) then
    UNIT.index = UNIT.index + 1
  end

  return data.index
end

-- Get a team from a name of index.
function UNIT.get(name)
  local foundTeam

  -- Check if we have a number (it's probably an index).
  if (tonumber(name)) then
    for _, team in pairs(UNIT.stored) do
      if (team.index == tonumber(name)) then
        foundTeam = team
        break
      end
    end
  else
    for _, team in pairs(UNIT.stored) do
      if (string.find(string.lower(team.name), string.lower(name), nil, false)) then
        if (foundTeam) then
          if (string.len(team.name) < string.len(foundTeam.name)) then
            foundTeam = team
          end
        else
          foundTeam = team
        end
      end
    end
  end

  return foundTeam
end

-- Check if the team has the required access.
function UNIT.hasFlags(name, access)
  local query = UNIT.query(name, "access")

  -- Check to see if the team has access.
  if (query) then
    if (string.len(access) == 1) then
      return string.find(query, access, nil, false)
    else
      for i = 1, string.len(access) do
        local flag = string.sub(access, i, i)

        -- Check to see if the team does not has this flag.
        if (not UNIT.hasFlags(name, flag)) then
          return false
        end

        return true
      end
    end
  else
    return false
  end
end

-- Query a variable from a team.
function UNIT.query(name, key, default)
  local team = UNIT.get(name)

  -- Check to see if it's a valid team.
  if (team) then
    return team[key] or default
  else
    return default
  end
end

if (SERVER) then
  function UNIT.blocklist(player, name, boolean)
    local team = UNIT.get(name)

    -- Check to see if the team exists.
    if (team) then
      if (boolean) then
        player:getCharacter("blocklist")[team.name] = true
      else
        player:getCharacter("blocklist")[team.name] = nil
      end
    end
  end

  -- Make a player a member of a team.
  function UNIT.make(player, name)
    local team = UNIT.get(name)

    if (team) then
      if (not player:getCharacter("blocklist")[team.name]) then
        player._NextChangeTeam[player:Team()] = CurTime() + 300

        player:SetTeam(team.index)

        player._ChangeTeam = true
        player:KillSilent()

        return true
      else
        return false, "You have been blocklisted from " .. team.name .. "!"
      end
    else
      return false, "This is not a valid team!"
    end
  end
end
