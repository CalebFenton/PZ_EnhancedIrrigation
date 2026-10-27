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

-- Each found item: its full type, its entries as { weight, "proc:<ProceduralDistributions list>" }
-- before the option, and the sandbox option that scales their weights.
Distributions.LOOT = {
    -- A weight w spawns with ceil(w x 100 x the literature loot rarity) in 10,000 per roll, and
    -- each of these lists rolls four times (ItemPickerJava.getActualSpawnChance). Vanilla's farming
    -- magazines, the nearest thing, sit at 1 to 2 in the lists that carry them. Farmhouse kitchens
    -- and living rooms are the town's ordinary rooms, with no list of their own, so a farm is
    -- reached through its storage, barn and shed.
    {
        fullType = Distributions.PAMPHLET, option = "PamphletLoot",
        entries = {
            -- Farms: the crates of farm storage, barns and sheds (and of general stores and
            -- warehouses), where the seed sacks and farming magazines are kept.
            { 1, "proc:CrateFarming" },
            -- The tool cabinets of farm storage and the barns' tool crates: tacked up by the tools.
            { 0.5, "proc:ToolCabinetFarming" },
            { 0.5, "proc:BarnTools" },
            -- A homesteader's box, in closets and garage storage.
            { 1, "proc:Homesteading" },
            -- Garden and farm-supply stores: the extension office left its leaflets by the seed
            -- racks.
            { 2, "proc:GardenStoreMisc" },
            { 0.5, "proc:GardenStoreTools" },
            -- The farm aisles of hardware stores and the Gigamart.
            { 1, "proc:ToolStoreFarming" },
            { 0.5, "proc:GigamartFarming" },
            -- Libraries: the gardening shelf, the reference shelf with the government paper, and
            -- the magazine rack.
            { 1, "proc:LibraryOutdoors" },
            { 0.5, "proc:LibraryGeneralReference" },
            { 1, "proc:LibraryMagazines" },
            -- Post offices: extension leaflets went out by mail, among the brochures.
            { 1, "proc:PostOfficeMagazines" },
        },
    },
    -- The Utility Pump, at the Blower Fan's weight in a hardware store's tools, the nearest vanilla
    -- part, and half that where tools are kept at home; worn ones in old tool crates (an isWorn
    -- list, which wears what shows its condition).
    {
        fullType = Pumps.UTILITY_PUMP, option = "PartsLoot",
        entries = {
            -- Hardware stores and the Gigamart: sump and utility pumps sat by the drills and
            -- wrenches.
            { 1, "proc:ToolStoreTools" },
            { 1, "proc:GigamartTools" },
            -- Garages and sheds, and the tool crates of garages and basements.
            { 0.5, "proc:GarageTools" },
            { 0.5, "proc:CrateTools" },
            -- Old tool crates, in sheds and basements: a pump that has seen use.
            { 1, "proc:CrateToolsOld" },
        },
    },
    -- The Lawn Sprinkler, by vanilla's Empty Gardening Spray Can, the nearest garden kit: a fifth
    -- to a tenth of its weight in garden stores, less where garden kit is kept at home, and worn
    -- ones in old tool crates. It is a garden part, so the parts option scales it too.
    {
        fullType = Sprinklers.ITEM, option = "PartsLoot",
        entries = {
            -- Garden stores: by the hoses and sprayers.
            { 2, "proc:GardenStoreTools" },
            { 1, "proc:GardenStoreMisc" },
            -- Garages and sheds, and the farm and garden crates of sheds, barns and garages.
            { 0.5, "proc:GarageTools" },
            { 0.5, "proc:CrateFarming" },
            { 1, "proc:CrateGardening" },
            -- Old tool crates, in sheds and basements: a sprinkler that has seen use.
            { 0.5, "proc:CrateToolsOld" },
        },
    },
    -- The Sprinkler Timer, a garden store's plug-in timer, as often as a Lawn Sprinkler there and
    -- half that by a hardware store's garden tools. A garden part, so the parts option scales it.
    {
        fullType = Valves.SPRINKLER_TIMER, option = "PartsLoot",
        entries = {
            { 2, "proc:GardenStoreTools" },
            { 1, "proc:GardenStoreMisc" },
            { 1, "proc:ToolStoreFarming" },
            { 0.5, "proc:GigamartFarming" },
        },
    },
    -- The Water Valve, rare in plumbing supplies: a washer's inlet valve is a spare few kept. Most
    -- come out of washers and dishwashers (Salvage Pump).
    { fullType = Valves.WATER_VALVE, option = "PartsLoot", entries = { { 0.5, "proc:PlumbingSupplies" } } },
}

--- Puts each item of LOOT into each of its lists at its weight times its option again now, as a
--- load does once the save's options are loaded (Loot.register).
Distributions.apply = Loot.register("EnhancedIrrigation", Distributions.LOOT, function(loot)
    return SandboxVars.EnhancedIrrigation[loot.option]
end)

return Distributions
