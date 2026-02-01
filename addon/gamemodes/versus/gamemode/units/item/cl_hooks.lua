local UNIT = UNIT

-- Called when the target ID should be drawn.
function UNIT.hook:HUDDrawTargetID()
  if (not LocalPlayer():Alive() or LocalPlayer():GetNWBool("versus_KnockedOut")) then
    return
  end

  local trace = LocalPlayer():GetEyeTrace()

  if (not IsValid(trace.Entity)) then
    return
  end

  local class = trace.Entity:GetClass()

  if (class ~= "versus_item" and class ~= "versus_shipment") then
    return
  end

  local fadeDistance = versus.config["Talk Radius"]
  local alpha = math.Clamp(255 - ((255 / fadeDistance) * (LocalPlayer():GetPos():Distance(trace.Entity:GetPos()))), 0,
    255)

  local x, y = GAMEMODE:GetScreenCenterBounce()

  if (class == "versus_item") then
    y = GAMEMODE:DrawInformation(trace.Entity:GetNWString("versus_Name"), "ChatFont", x, y, color_orange, alpha)
  else
    y = GAMEMODE:DrawInformation("Shipment", "ChatFont", x, y, color_orange, alpha)
    y = GAMEMODE:DrawInformation(trace.Entity:GetNWString("versus_Name"), "ChatFont", x, y, color_white, alpha)
  end

  y = GAMEMODE:DrawInformation("Size: " .. trace.Entity:GetNWInt("versus_Size"), "ChatFont", x, y, color_white, alpha)

  hook.Run("PostDrawItemHUDDrawTargetID", trace.Entity, x, y, alpha)
end
