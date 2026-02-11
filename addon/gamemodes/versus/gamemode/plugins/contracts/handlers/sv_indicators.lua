local PLUGIN = PLUGIN

PLUGIN.registerContractPhaseKeyHandler("indicators", function(player, bag, data)
  versus.indicator.removeAll(player)

  for _, indicatorData in ipairs(data) do
    local locationReference = indicatorData.location
    local entity = PLUGIN.getEntityFromReference(player, locationReference)

    if not IsValid(entity) then
      error("Failed to find entity for contract phase indicators key with location reference: " ..
        util.TableToJSON(locationReference))
      continue
    end

    versus.indicator.create(player, indicatorData.name, {
      pos = entity:GetPos(),
      text = indicatorData.text,
      icon = indicatorData.icon,
      color = indicatorData.color,
      removeOnReach = indicatorData.removeOnReach,
    })
  end
end)
