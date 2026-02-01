local UNIT = UNIT
UNIT.libraryKey = "command"
UNIT.stored = UNIT.stored or {}

versus.includePrefixed("sh_hooks.lua")
versus.includePrefixed("sv_hooks.lua")

function UNIT.find(query)
  local matches = {}

  for commandText, commandData in pairs(UNIT.stored) do
    if (string.find(commandText, query, 1, true)) then
      table.insert(matches, commandData)
    end
  end

  table.SortByMember(matches, "command", true)

  return matches
end

function UNIT.define(commandText)
  local command = UNIT.stored[commandText:lower()]

  if (command == nil) then
    command = setmetatable({}, FindMetaTable("VersusCommand")):init(commandText)
  else
    command:reset()
  end

  UNIT.stored[commandText:lower()] = command

  return command
end

-- By Lexi @ https://github.com/Lexicality/applejack/blob/c3a2f3ffb846165289300b4033343dac1881e699/gamemode/libraries/sv_commands.lua#L151
function UNIT.parseCommand(text)
  local args = {}
  local varg = 0
  local j = 1
  local leng = text:len()
  local lastc = ""
  local quoting = false
  local c = 1
  local i = 1
  local ctext = ""
  -- MsgN("Incoming Text:")
  -- MsgN(text)
  while (i <= leng) do
    ctext = text:sub(i, i)
    -- MsgC(Color(200,200,200), i, '/', leng)
    -- MsgC(Color(255,255,255), " '", ctext, "' ")
    if (i == leng) then
      -- MsgC(cg, "End of the message!")
      if (ctext == "\"") then
        i = i - 1
      end
      args[c] = text:sub(j, i)
      break
    elseif (quoting) then
      -- MsgC(cy, '-')
      -- yn(ctext == ' ') yn(lastc == '"')
      if (ctext == " " and lastc == "\"") then
        quoting = false
        args[c] = text:sub(j, i - 2)
        -- MsgC(cg," New arg: '", args[c], "' ")
        c = c + 1
        j = i + 1
      end
    elseif (ctext == "\"" and (i == 1 or lastc == " ")) then
      -- MsgC(cg, '+')
      quoting = true
      j = i + 1
    else
      if (ctext == " ") then
        args[c] = text:sub(j, i - 1)
        -- MsgC(cg," New arg: '", args[c], "' ")
        -- This is the first argument, and thus is the command.
        if (c == 1) then
          -- MsgC(cy, "CMD! ")
          local cmd = UNIT.stored[args[c]:lower()]
          -- Make sure it exists so we don't do evreything for nothing
          if (not cmd) then
            -- MsgC(cr, "Unknown command :(")
            -- Skip everything else, so the command handler can yell at them.
            break
          end
          --  Apply vargocity
          if (cmd.VarArg) then
            varg = cmd.VarArg + 1
          end
        end
        c = c + 1
        j = i + 1
      end
    end
    -- MsgN()
    lastc = ctext
    i = i + 1
    if (c == varg) then
      args[c] = text:sub(i)
      -- MsgN("vararg! Dumping the rest of the message as: '", args[#args], "'")
      break
    end
  end
  -- MsgN()
  -- MsgN("Args be like")
  -- PrintTable(args)
  return args
end
