local PLUGIN = PLUGIN

--- Opens the bounty board panel.  If it is already open, closes it instead.
function PLUGIN.openBountyBoard()
  if IsValid(PLUGIN.boardPanel) then
    PLUGIN.boardPanel:Close()
    return
  end

  PLUGIN.boardPanel = vgui.Create("versus_BountyBoard")

  -- Request fresh data from the server when the panel opens
  net.Start("versus.bounty_board.open")
  net.SendToServer()
end

--[[
  Net Messages
--]]

-- Server sends the full bounty list (active bounties + player progress)
net.Receive("versus.bounty_board.data", function()
  local count   = net.ReadUInt(PLUGIN.BIT_BOUNTY_DB_ID)
  local now     = net.ReadUInt(32)
  local entries = {}

  for i = 1, count do
    local entry = {}
    entry.id           = net.ReadUInt(PLUGIN.BIT_BOUNTY_DB_ID)
    entry.key          = net.ReadString()
    entry.expires_at   = net.ReadUInt(32)
    entry.name         = net.ReadString()
    entry.description  = net.ReadString()
    entry.targetCount  = net.ReadUInt(PLUGIN.BIT_PROGRESS)
    entry.reward       = net.ReadUInt(PLUGIN.BIT_REWARD)
    entry.progress     = net.ReadUInt(PLUGIN.BIT_PROGRESS)
    entry.completed_at = net.ReadUInt(32)
    entry.turned_in    = net.ReadBool()
    entry.picked_up    = net.ReadBool()
    table.insert(entries, entry)
  end

  if IsValid(PLUGIN.boardPanel) then
    PLUGIN.boardPanel:OnBountyData(entries, now)
  end
end)

-- Server triggers panel open (from the board entity's Use callback)
net.Receive("versus.bounty_board.open", function()
  PLUGIN.openBountyBoard()
end)
