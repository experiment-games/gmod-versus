local PLUGIN = PLUGIN
local ITEM = ITEM

ITEM.category = "Holidays"
ITEM.name = "Easter Egg"
ITEM.size = 0
ITEM.cost = 10000
ITEM.model = "models/props_phx/misc/egg.mdl"
ITEM.description =
"A colorful egg hidden during the Easter holiday. Collect them all to receive a special reward!"
ITEM.noRarity = true

local colors

-- When this item is first created, set a random bright color for it to add some variety.
function ITEM:onCreated()
  self.modelColor = colors[math.random(1, #colors)]
end

function ITEM:onDrop(player, position) end

colors = {
  -- Pinks & Reds
  Color(255, 105, 180), -- HotPink
  Color(255, 20, 147),  -- DeepPink
  Color(255, 182, 193), -- LightPink
  Color(220, 20, 60),   -- Crimson
  Color(255, 127, 80),  -- Coral
  Color(250, 128, 114), -- Salmon
  Color(252, 85, 93),   -- Watermelon
  Color(247, 121, 152), -- RoseQuartz

  -- Purples & Violets
  Color(230, 190, 255), -- Lavender
  Color(238, 130, 238), -- Violet
  Color(160, 32, 240),  -- Purple
  Color(218, 112, 214), -- Orchid
  Color(221, 160, 221), -- Plum
  Color(153, 102, 204), -- Amethyst
  Color(200, 162, 200), -- Lilac
  Color(179, 68, 208),  -- MauvePurple

  -- Blues
  Color(135, 206, 235), -- SkyBlue
  Color(100, 149, 237), -- CornflowerBlue
  Color(65, 105, 225),  -- RoyalBlue
  Color(102, 130, 223), -- PeriwinkleBlue
  Color(137, 207, 240), -- BabyBlue
  Color(0, 199, 200),   -- TurquoiseBlue
  Color(30, 144, 255),  -- DodgerBlue
  Color(0, 123, 167),   -- Cerulean

  -- Greens
  Color(152, 255, 152), -- MintGreen
  Color(0, 255, 127),   -- SpringGreen
  Color(50, 205, 50),   -- LimeGreen
  Color(147, 197, 114), -- Pistachio
  Color(0, 168, 107),   -- Jade
  Color(127, 255, 0),   -- Chartreuse
  Color(46, 139, 87),   -- SeaGreen
  Color(164, 198, 57),  -- PeaGreen

  -- Yellows & Golds
  Color(255, 247, 0),  -- Lemon
  Color(252, 220, 0),  -- ButtercupYellow
  Color(255, 215, 0),  -- Dandelion
  Color(251, 236, 93), -- Maize
  Color(255, 239, 0),  -- Canary
  Color(218, 165, 32), -- Goldenrod
  Color(255, 191, 0),  -- Amber
  Color(255, 200, 0),  -- SunflowerYellow

  -- Oranges
  Color(242, 133, 0),   -- Tangerine
  Color(255, 218, 185), -- Peach
  Color(251, 206, 177), -- Apricot
  Color(234, 123, 0),   -- Marigold
  Color(255, 117, 24),  -- PumpkinOrange
  Color(255, 130, 67),  -- Mango
  Color(255, 151, 71),  -- Papaya
  Color(204, 85, 0),    -- BurntOrange

  -- Teals & Cyans
  Color(0, 255, 255),   -- Aqua
  Color(0, 128, 128),   -- Teal
  Color(0, 188, 212),   -- Cyan
  Color(127, 255, 212), -- AquaMarine
  Color(64, 224, 208),  -- TurquoiseTeal
  Color(102, 205, 170), -- MediumAquamarine
  Color(32, 178, 170),  -- LightSeaGreen
  Color(95, 158, 160),  -- CadetBlue

  -- Pastels
  Color(255, 209, 220), -- PastelPink
  Color(174, 210, 245), -- PastelBlue
  Color(185, 246, 202), -- PastelGreen
  Color(255, 253, 181), -- PastelYellow
  Color(216, 191, 255), -- PastelPurple
  Color(255, 218, 193), -- PastelOrange
  Color(178, 243, 238), -- PastelTeal
  Color(230, 220, 255), -- PastelLavender

  -- Neons
  Color(255, 16, 240), -- NeonPink
  Color(57, 255, 20),  -- NeonGreen
  Color(255, 255, 0),  -- NeonYellow
  Color(255, 95, 0),   -- NeonOrange
  Color(4, 217, 255),  -- NeonBlue
  Color(188, 19, 254), -- NeonPurple
  Color(255, 7, 58),   -- NeonRed
  Color(0, 255, 239),  -- NeonCyan
}
