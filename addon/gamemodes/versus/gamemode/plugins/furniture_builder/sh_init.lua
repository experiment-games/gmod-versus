local PLUGIN = PLUGIN

PLUGIN.libraryKey = "furnitureBuilder"

PLUGIN.catalogItems = PLUGIN.catalogItems or {}

--- Register a prop that can be built in the furniture catalog.
--- @param id string Unique identifier for this catalog entry
--- @param name string Display name shown in the catalog
--- @param category string Category used for filtering
--- @param model string Model path of the prop to spawn
--- @param materialCost number How many Raw Furniture Materials are consumed to build it
function PLUGIN.registerCatalogItem(id, name, category, model, materialCost)
  PLUGIN.catalogItems[id] = {
    id = id,
    name = name,
    category = category,
    model = model,
    materialCost = materialCost,
  }
end

-- Register default furniture catalog items
PLUGIN.registerCatalogItem(
  "chair_wooden",
  "Wooden Chair",
  "Seating",
  "models/props_c17/furniturechair001a.mdl",
  2
)

PLUGIN.registerCatalogItem(
  "table_wooden",
  "Wooden Table",
  "Tables",
  "models/props_c17/FurnitureTable001a.mdl",
  4
)

PLUGIN.registerCatalogItem(
  "couch",
  "Couch",
  "Seating",
  "models/props_c17/FurnitureCouch001a.mdl",
  5
)

PLUGIN.registerCatalogItem(
  "bookcase",
  "Bookcase",
  "Storage",
  "models/props/cs_office/bookshelf1.mdl",
  6
)

PLUGIN.registerCatalogItem(
  "dresser",
  "Dresser",
  "Storage",
  "models/props_c17/furnituredresser001a.mdl",
  5
)

PLUGIN.registerCatalogItem(
  "tv",
  "Television",
  "Electronics",
  "models/props/de_inferno/tv_monitor01.mdl",
  8
)

PLUGIN.registerCatalogItem(
  "lamp_floor",
  "Floor Lamp",
  "Lighting",
  "models/props_interiors/furniture_lamp01a.mdl",
  3
)

PLUGIN.registerCatalogItem(
  "filing_cabinet",
  "Filing Cabinet",
  "Storage",
  "models/props_wasteland/controlroom_filecabinet002a.mdl",
  4
)
