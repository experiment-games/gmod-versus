local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("indicators", function(player, bag, data)
  versus.indicator.removeAll(player)

  -- We wait a frame, as any tagged NPC's may not have spawned yet due to the table keys not having
  -- any precedence (meaning indicators may be looped before or after escortNPCs for example).
  versus.util.nextFrame(function()
    for _, indicatorData in ipairs(data) do
      local indicatorTable = {
        text = indicatorData.text,
        icon = indicatorData.icon,
        color = indicatorData.color,
        removeOnReach = indicatorData.removeOnReach,
      }

      -- NPC tag: track a living tagged NPC by entity index so the indicator follows it
      if indicatorData.npcTag then
        local taggedNPCs = bag.contract.taggedNPCs
        local npc = taggedNPCs and taggedNPCs[indicatorData.npcTag]

        if not IsValid(npc) then
          error("Failed to find tagged NPC for contract indicator with npcTag: " .. tostring(indicatorData.npcTag))
          continue
        end

        indicatorTable.entIndex = npc:EntIndex()
        indicatorTable.pos = npc:GetPos()
      else
        local locationReference = indicatorData.location
        local entity = PLUGIN.getEntityFromReference(player, locationReference)

        if not IsValid(entity) then
          error("Failed to find entity for contract phase indicators key with location reference: " ..
            util.TableToJSON(locationReference))
          continue
        end

        indicatorTable.pos = entity:GetPos()
      end

      versus.indicator.create(player, indicatorData.name, indicatorTable)
    end
  end, player)
end)
