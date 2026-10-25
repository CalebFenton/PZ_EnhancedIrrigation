if isClient() then return end

local Loot = require "cf_commonlib/Loot"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/Valves"

-- Where the mod's found items turn up in the game's loot lists, each a find rather than a given.

EnhancedIrrigation = EnhancedIrrigation or {}
local Distributions = {}
EnhancedIrrigation.Distributions = Distributions

local Pumps, Sprinklers, Valves = EnhancedIrrigation.Pumps, EnhancedIrrigation.Sprinklers, EnhancedIrrigation.Valves

Distributions.PAMPHLET = "EnhancedIrrigation.CisternsForKentucky"

-- Each found item: its full type, its lists as { ProceduralDistributions list, weight } before the
-- option, and the sandbox option that scales their weights.
Distributions.LOOT = {
    -- A weight w spawns with ceil(w x 100 x the literature loot rarity) in 10,000 per roll, and
    -- each of these lists rolls four times (ItemPickerJava.getActualSpawnChance). Vanilla's farming
    -- magazines, the nearest thing, sit at 1 to 2 in the lists that carry them. Farmhouse kitchens
    -- and living rooms are the town's ordinary rooms, with no list of their own, so a farm is
    -- reached through its storage, barn and shed.
    {
        item = Distributions.PAMPHLET, option = "PamphletLoot",
        lists = {
            -- Farms: the crates of farm storage, barns and sheds (and of general stores and
            -- warehouses), where the seed sacks and farming magazines are kept.
            { "CrateFarming", 1 },
            -- The tool cabinets of farm storage and the barns' tool crates: tacked up by the tools.
            { "ToolCabinetFarming", 0.5 },
            { "BarnTools", 0.5 },
            -- A homesteader's box, in closets and garage storage.
            { "Homesteading", 1 },
            -- Garden and farm-supply stores: the extension office left its leaflets by the seed
            -- racks.
            { "GardenStoreMisc", 2 },
            { "GardenStoreTools", 0.5 },
            -- The farm aisles of hardware stores and the Gigamart.
            { "ToolStoreFarming", 1 },
            { "GigamartFarming", 0.5 },
            -- Libraries: the gardening shelf, the reference shelf with the government paper, and
            -- the magazine rack.
            { "LibraryOutdoors", 1 },
            { "LibraryGeneralReference", 0.5 },
            { "LibraryMagazines", 1 },
            -- Post offices: extension leaflets went out by mail, among the brochures.
            { "PostOfficeMagazines", 1 },
        },
    },
    -- The Utility Pump, at the Blower Fan's weight in a hardware store's tools, the nearest vanilla
    -- part, and half that where tools are kept at home; worn ones in old tool crates (an isWorn
    -- list, which wears what shows its condition).
    {
        item = Pumps.UTILITY_PUMP, option = "PartsLoot",
        lists = {
            -- Hardware stores and the Gigamart: sump and utility pumps sat by the drills and
            -- wrenches.
            { "ToolStoreTools", 1 },
            { "GigamartTools", 1 },
            -- Garages and sheds, and the tool crates of garages and basements.
            { "GarageTools", 0.5 },
            { "CrateTools", 0.5 },
            -- Old tool crates, in sheds and basements: a pump that has seen use.
            { "CrateToolsOld", 1 },
        },
    },
    -- The Lawn Sprinkler, by vanilla's Empty Gardening Spray Can, the nearest garden kit: a fifth
    -- to a tenth of its weight in garden stores, less where garden kit is kept at home, and worn
    -- ones in old tool crates. It is a garden part, so the parts option scales it too.
    {
        item = Sprinklers.ITEM, option = "PartsLoot",
        lists = {
            -- Garden stores: by the hoses and sprayers.
            { "GardenStoreTools", 2 },
            { "GardenStoreMisc", 1 },
            -- Garages and sheds, and the farm and garden crates of sheds, barns and garages.
            { "GarageTools", 0.5 },
            { "CrateFarming", 0.5 },
            { "CrateGardening", 1 },
            -- Old tool crates, in sheds and basements: a sprinkler that has seen use.
            { "CrateToolsOld", 0.5 },
        },
    },
    -- The Sprinkler Timer, a garden store's plug-in timer, as often as a Lawn Sprinkler there and
    -- half that by a hardware store's garden tools. A garden part, so the parts option scales it.
    {
        item = Valves.SPRINKLER_TIMER, option = "PartsLoot",
        lists = {
            { "GardenStoreTools", 2 },
            { "GardenStoreMisc", 1 },
            { "ToolStoreFarming", 1 },
            { "GigamartFarming", 0.5 },
        },
    },
    -- The Water Valve, rare in plumbing supplies: a washer's inlet valve is a spare few kept. Most
    -- come out of washers and dishwashers (Salvage Pump).
    { item = Valves.WATER_VALVE, option = "PartsLoot", lists = { { "PlumbingSupplies", 0.5 } } },
}

--- Puts each item of LOOT into each of its lists at its weight times its option (Loot.place). The
--- save's options are read only once loaded, so Loot runs this then (Loot.register).
function Distributions.apply()
    for _, loot in ipairs(Distributions.LOOT) do
        local entries = {}
        for _, entry in ipairs(loot.lists) do
            table.insert(entries, { entry[2], "proc:" .. entry[1] })
        end
        Loot.place("EnhancedIrrigation", loot.item, entries, SandboxVars.EnhancedIrrigation[loot.option])
    end
end

Loot.register(Distributions.apply)

return Distributions
