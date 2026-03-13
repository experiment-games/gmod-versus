local UNIT = UNIT

UNIT.libraryKey = "mapOverview"

function UNIT.hook:VersusRegisterMapOverviews(registry, desiredMapFileName)
  registry["versus_c18_v1"] = {
    scale = 12,
    pos_x = -5314,
    pos_y = 6662
  }

  registry["versus_base_bunker"] = {
    scale = 2,
    pos_x = -1195,
    pos_y = 296
  }

  registry["rp_apocalypse"] = {
    scale = 28,
    pos_x = -12734,
    pos_y = 13640
  }
end
