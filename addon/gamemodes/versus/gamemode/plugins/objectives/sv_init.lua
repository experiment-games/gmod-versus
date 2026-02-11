local PLUGIN = PLUGIN

util.AddNetworkString("versus.objectives.setObjective")
util.AddNetworkString("versus.objectives.clearObjective")
util.AddNetworkString("versus.objectives.addSubObjective")
util.AddNetworkString("versus.objectives.removeSubObjective")
util.AddNetworkString("versus.objectives.updateSubObjective")
util.AddNetworkString("versus.objectives.setTimer")
util.AddNetworkString("versus.objectives.setTimerPaused")
util.AddNetworkString("versus.objectives.clearTimer")
util.AddNetworkString("versus.objectives.addRadiusRender")
util.AddNetworkString("versus.objectives.removeRadiusRender")
util.AddNetworkString("versus.objectives.clearRadiusRenders")

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
  player._objectiveTitle = title
  player._objectiveDescription = description or ""
  player._objectiveDistance = distance

  net.Start("versus.objectives.setObjective")
  net.WriteString(title or "")
  net.WriteString(description or "")
  if distance then
    net.WriteBool(true)
    net.WriteFloat(distance)
  else
    net.WriteBool(false)
  end
  net.Send(player)
end

-- Clear the main objective for a player
function PLUGIN.clearObjective(player)
  player._objectiveTitle = nil
  player._objectiveDescription = nil
  player._objectiveDistance = nil
  player._subObjectives = {}

  net.Start("versus.objectives.clearObjective")
  net.Send(player)
end

-- Add a sub-objective for a player
function PLUGIN.addSubObjective(player, id, text, completed, distance)
  player._subObjectives = player._subObjectives or {}
  player._subObjectives[id] = {
    text = text,
    completed = completed or false,
    distance = distance
  }

  net.Start("versus.objectives.addSubObjective")
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
end

-- Remove a sub-objective for a player
function PLUGIN.removeSubObjective(player, id)
  if not IsValid(player) then return end

  player._subObjectives = player._subObjectives or {}
  player._subObjectives[id] = nil

  net.Start("versus.objectives.removeSubObjective")
  net.WriteString(id)
  net.Send(player)
end

-- Update a sub-objective for a player
function PLUGIN.updateSubObjective(player, id, text, completed, distance)
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

  net.Start("versus.objectives.updateSubObjective")
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
end

--- Sets a timer on the player's HUD with the given time, countdown mode, and text
--- @param player Player # The player to set the timer for
--- @param time number # The time in seconds for the timer
--- @param countDown boolean # Whether the timer should count down (true) or up (false)
--- @param text string # The text to display next to the timer
function PLUGIN.setObjectiveTimer(player, time, countDown, text)
  net.Start("versus.objectives.setTimer")
  net.WriteFloat(time)
  net.WriteBool(countDown)
  net.WriteString(text or "")
  net.Send(player)
end

--- Pauses or resumes the objective timer for a player
--- @param player Player # The player to pause or resume the timer for
--- @param paused boolean # Whether to pause (true) or resume (false) the timer
function PLUGIN.setObjectiveTimerPaused(player, paused)
  net.Start("versus.objectives.setTimerPaused")
  net.WriteBool(paused)
  net.Send(player)
end

--- Clears the objective timer for a player
--- @param player Player # The player to clear the timer for
function PLUGIN.clearObjectiveTimer(player)
  net.Start("versus.objectives.clearTimer")
  net.Send(player)
end

--- Adds a radius render for a player at the given position and distance
--- @param player Player # The player to add the radius render for
--- @param id string # A unique identifier for the radius render
--- @param position Vector # The center position of the radius render
--- @param maxDistance number # The maximum distance of the radius render
function PLUGIN.addObjectiveRadiusRender(player, id, position, maxDistance)
  net.Start("versus.objectives.addRadiusRender")
  net.WriteString(id)
  net.WriteVector(position)
  net.WriteFloat(maxDistance)
  net.Send(player)
end

--- Removes a radius render for a player by its identifier
--- @param player Player # The player to remove the radius render for
--- @param id string # The unique identifier of the radius render to remove
function PLUGIN.removeObjectiveRadiusRender(player, id)
  net.Start("versus.objectives.removeRadiusRender")
  net.WriteString(id)
  net.Send(player)
end

--- Clears all radius renders for a player
--- @param player Player # The player to clear the radius renders for
function PLUGIN.clearObjectiveRadiusRenders(player)
  net.Start("versus.objectives.clearRadiusRenders")
  net.Send(player)
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
