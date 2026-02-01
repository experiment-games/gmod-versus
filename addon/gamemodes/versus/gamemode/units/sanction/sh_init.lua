local UNIT = UNIT

UNIT.libraryKey = "sanction"

-- TODO: Increase to something like 30/60 or even longer to reduce db calls
UNIT.updateEvery = 10 -- How often to get new sanctions from the database in seconds

UNIT.stored = UNIT.stored or {}

versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

function UNIT.get(sanctionKey)
  return UNIT.stored[sanctionKey:lower()]
end

function UNIT.all()
  return UNIT.stored
end

function UNIT.find(query)
  local matches = {}

  for sanctionText, sanctionData in pairs(UNIT.stored) do
    if (string.find(sanctionText, query, 1, true)) then
      table.insert(matches, sanctionData)
    end
  end

  table.SortByMember(matches, "key", true)

  return matches
end

function UNIT.define(sanctionKey)
  local sanction = UNIT.stored[sanctionKey:lower()]

  if (sanction == nil) then
    sanction = setmetatable({}, FindMetaTable("VersusSanction")):init(sanctionKey)
  else
    sanction:reset()
  end

  UNIT.stored[sanctionKey:lower()] = sanction

  return sanction
end
