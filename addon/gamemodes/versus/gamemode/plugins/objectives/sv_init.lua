local PLUGIN = PLUGIN

util.AddNetworkString("versus.objective.setObjective")
util.AddNetworkString("versus.objective.clearObjective")
util.AddNetworkString("versus.objective.addSubObjective")
util.AddNetworkString("versus.objective.removeSubObjective")
util.AddNetworkString("versus.objective.updateSubObjective")

-- Get all extraction points in the map
function PLUGIN.getExtractionPoints()
  return ents.FindByClass("versus_objective_interaction")
end

-- Get all extraction conditions in the map
function PLUGIN.getExtractionConditions()
  return ents.FindByClass("versus_objective_interaction")
end

--[[
  Objective Management
--]]

-- Set the main objective for a player
function PLUGIN.setObjective(player, title, description, distance)
  if not IsValid(player) then return false end

  player._objectiveTitle = title
  player._objectiveDescription = description or ""
  player._objectiveDistance = distance

  net.Start("versus.objective.setObjective")
  net.WriteString(title or "")
  net.WriteString(description or "")
  if distance then
    net.WriteBool(true)
    net.WriteFloat(distance)
  else
    net.WriteBool(false)
  end
  net.Send(player)

  return true
end

-- Clear the main objective for a player
function PLUGIN.clearObjective(player)
  if not IsValid(player) then return end

  player._objectiveTitle = nil
  player._objectiveDescription = nil
  player._objectiveDistance = nil
  player._subObjectives = {}

  net.Start("versus.objective.clearObjective")
  net.Send(player)
end

-- Add a sub-objective for a player
function PLUGIN.addSubObjective(player, id, text, completed, distance)
  if not IsValid(player) then return false end

  player._subObjectives = player._subObjectives or {}
  player._subObjectives[id] = {
    text = text,
    completed = completed or false,
    distance = distance
  }

  net.Start("versus.objective.addSubObjective")
  net.WriteString(id)
  net.WriteString(text)
  net.WriteBool(completed or false)
  if distance then
    net.WriteBool(true)
    net.WriteFloat(distance)
  else
    net.WriteBool(false)
  end
  net.Send(player)

  return true
end

-- Remove a sub-objective for a player
function PLUGIN.removeSubObjective(player, id)
  if not IsValid(player) then return end

  player._subObjectives = player._subObjectives or {}
  player._subObjectives[id] = nil

  net.Start("versus.objective.removeSubObjective")
  net.WriteString(id)
  net.Send(player)
end

-- Update a sub-objective for a player
function PLUGIN.updateSubObjective(player, id, text, completed, distance)
  if not IsValid(player) then return false end

  player._subObjectives = player._subObjectives or {}
  if not player._subObjectives[id] then return false end

  if text then
    player._subObjectives[id].text = text
  end
  if completed ~= nil then
    player._subObjectives[id].completed = completed
  end
  if distance ~= nil then
    player._subObjectives[id].distance = distance
  end

  net.Start("versus.objective.updateSubObjective")
  net.WriteString(id)
  if text then
    net.WriteBool(true)
    net.WriteString(text)
  else
    net.WriteBool(false)
  end
  net.WriteBool(completed or false)
  if distance then
    net.WriteBool(true)
    net.WriteFloat(distance)
  else
    net.WriteBool(false)
  end
  net.Send(player)

  return true
end

--[[
  Console Commands
--]]

-- Console command to set objective
concommand.Add("versus_set_objective", function(ply, cmd, args)
  if not IsValid(ply) or not ply:IsAdmin() then return end

  if #args < 2 then
    ply:ChatPrint("Usage: versus_set_objective <player_name> <title> [description]")
    return
  end

  local targetName = args[1]
  local target = nil

  for _, player in ipairs(player.GetAll()) do
    if string.find(string.lower(player:Name()), string.lower(targetName)) then
      target = player
      break
    end
  end

  if not IsValid(target) then
    ply:ChatPrint("Player not found: " .. targetName)
    return
  end

  local title = args[2]
  local description = table.concat(args, " ", 3)

  PLUGIN.setObjective(target, title, description)
  ply:ChatPrint("Set objective for " .. target:Name())
end)

-- Console command to clear objective
concommand.Add("versus_clear_objective", function(ply, cmd, args)
  if not IsValid(ply) or not ply:IsAdmin() then return end

  if #args < 1 then
    ply:ChatPrint("Usage: versus_clear_objective <player_name>")
    return
  end

  local targetName = args[1]
  local target = nil

  for _, player in ipairs(player.GetAll()) do
    if string.find(string.lower(player:Name()), string.lower(targetName)) then
      target = player
      break
    end
  end

  if not IsValid(target) then
    ply:ChatPrint("Player not found: " .. targetName)
    return
  end

  PLUGIN.clearObjective(target)
  ply:ChatPrint("Cleared objective for " .. target:Name())
end)

-- Console command to add sub-objective
concommand.Add("versus_add_subobjective", function(ply, cmd, args)
  if not IsValid(ply) or not ply:IsAdmin() then return end

  if #args < 3 then
    ply:ChatPrint("Usage: versus_add_subobjective <player_name> <id> <text>")
    return
  end

  local targetName = args[1]
  local target = nil

  for _, player in ipairs(player.GetAll()) do
    if string.find(string.lower(player:Name()), string.lower(targetName)) then
      target = player
      break
    end
  end

  if not IsValid(target) then
    ply:ChatPrint("Player not found: " .. targetName)
    return
  end

  local id = args[2]
  local text = table.concat(args, " ", 3)

  PLUGIN.addSubObjective(target, id, text)
  ply:ChatPrint("Added sub-objective '" .. id .. "' for " .. target:Name())
end)

-- Console command to update sub-objective
concommand.Add("versus_update_subobjective", function(ply, cmd, args)
  if not IsValid(ply) or not ply:IsAdmin() then return end

  if #args < 4 then
    ply:ChatPrint("Usage: versus_update_subobjective <player_name> <id> <completed> <text>")
    return
  end

  local targetName = args[1]
  local target = nil

  for _, player in ipairs(player.GetAll()) do
    if string.find(string.lower(player:Name()), string.lower(targetName)) then
      target = player
      break
    end
  end

  if not IsValid(target) then
    ply:ChatPrint("Player not found: " .. targetName)
    return
  end

  local id = args[2]
  local completed = tobool(args[3])
  local text = table.concat(args, " ", 4)

  PLUGIN.updateSubObjective(target, id, text, completed)
  ply:ChatPrint("Updated sub-objective '" .. id .. "' for " .. target:Name())
end)
