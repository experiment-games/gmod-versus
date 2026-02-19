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
  "models/props_interiors/FurnitureChair001a.mdl",
  2
)

PLUGIN.registerCatalogItem(
  "table_wooden",
  "Wooden Table",
  "Tables",
  "models/props_interiors/FurnitureTable001a.mdl",
  4
)

PLUGIN.registerCatalogItem(
  "couch",
  "Couch",
  "Seating",
  "models/props_interiors/FurnitureCouch001a.mdl",
  5
)

PLUGIN.registerCatalogItem(
  "bookcase",
  "Bookcase",
  "Storage",
  "models/props_interiors/FurnitureBookcase002a.mdl",
  6
)

PLUGIN.registerCatalogItem(
  "dresser",
  "Dresser",
  "Storage",
  "models/props_interiors/FurnitureDresser001a.mdl",
  5
)

PLUGIN.registerCatalogItem(
  "tv",
  "Television",
  "Electronics",
  "models/props_interiors/tv_monitor.mdl",
  8
)

PLUGIN.registerCatalogItem(
  "lamp_floor",
  "Floor Lamp",
  "Lighting",
  "models/props_interiors/lamp_floor.mdl",
  3
)

PLUGIN.registerCatalogItem(
  "filing_cabinet",
  "Filing Cabinet",
  "Storage",
  "models/props_office/filing_cabinet01.mdl",
  4
)
