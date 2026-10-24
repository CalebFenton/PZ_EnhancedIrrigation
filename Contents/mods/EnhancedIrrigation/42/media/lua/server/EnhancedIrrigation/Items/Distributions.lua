if isClient() then return end

require "Items/Distributions"
require "Items/ProceduralDistributions"

-- Where the mod's found items turn up: Cisterns for Kentucky wherever a 1993 extension leaflet on
-- farm water would have been left, the Utility Pump wherever tools and garage kit are, and the Lawn
-- Sprinkler wherever garden kit is, each a find rather than a given. apply() puts them into the
-- game's loot lists in OnInitGlobalModData, each scaled by its sandbox option.

EnhancedIrrigation = EnhancedIrrigation or {}
local Distributions = {}
EnhancedIrrigation.Distributions = Distributions

local procLists = ProceduralDistributions.list

Distributions.PAMPHLET = "EnhancedIrrigation.CisternsForKentucky"
Distributions.UTILITY_PUMP = "EnhancedIrrigation.UtilityPump"
Distributions.LAWN_SPRINKLER = "EnhancedIrrigation.LawnSprinkler"
Distributions.SPRINKLER_TIMER = "EnhancedIrrigation.SprinklerTimer"
Distributions.WATER_VALVE = "EnhancedIrrigation.WaterValve"

-- { ProceduralDistributions list, weight } before the option. A weight w spawns with
-- ceil(w x 100 x the literature loot rarity) in 10,000 per roll, and each of these lists rolls
-- four times (ItemPickerJava.getActualSpawnChance). Vanilla's farming magazines, the nearest
-- thing, sit at 1 to 2 in the lists that carry them. Farmhouse kitchens and living rooms are the
-- town's ordinary rooms, with no list of their own, so a farm is reached through its storage,
-- barn and shed.
Distributions.PAMPHLET_LISTS = {
    -- Farms: the crates of farm storage, barns and sheds (and of general stores and warehouses),
    -- where the seed sacks and farming magazines are kept.
    { "CrateFarming", 1 },
    -- The tool cabinets of farm storage and the barns' tool crates: tacked up by the tools.
    { "ToolCabinetFarming", 0.5 },
    { "BarnTools", 0.5 },
    -- A homesteader's box, in closets and garage storage.
    { "Homesteading", 1 },
    -- Garden and farm-supply stores: the extension office left its leaflets by the seed racks.
    { "GardenStoreMisc", 2 },
    { "GardenStoreTools", 0.5 },
    -- The farm aisles of hardware stores and the Gigamart.
    { "ToolStoreFarming", 1 },
    { "GigamartFarming", 0.5 },
    -- Libraries: the gardening shelf, the reference shelf with the government paper, and the
    -- magazine rack.
    { "LibraryOutdoors", 1 },
    { "LibraryGeneralReference", 0.5 },
    { "LibraryMagazines", 1 },
    -- Post offices: extension leaflets went out by mail, among the brochures.
    { "PostOfficeMagazines", 1 },
}

-- The same for the Utility Pump, at the Blower Fan's weight in a hardware store's tools, the
-- nearest vanilla part, and half that where tools are kept at home; worn ones in old tool crates
-- (an isWorn list, which wears what shows its condition).
Distributions.UTILITY_PUMP_LISTS = {
    -- Hardware stores and the Gigamart: sump and utility pumps sat by the drills and wrenches.
    { "ToolStoreTools", 1 },
    { "GigamartTools", 1 },
    -- Garages and sheds, and the tool crates of garages and basements.
    { "GarageTools", 0.5 },
    { "CrateTools", 0.5 },
    -- Old tool crates, in sheds and basements: a pump that has seen use.
    { "CrateToolsOld", 1 },
}

-- The same for the Lawn Sprinkler, by vanilla's Empty Gardening Spray Can, the nearest garden kit:
-- a fifth to a tenth of its weight in garden stores, less where garden kit is kept at home, and worn
-- ones in old tool crates. It is a garden part, so the parts option scales it too.
Distributions.LAWN_SPRINKLER_LISTS = {
    -- Garden stores: by the hoses and sprayers.
    { "GardenStoreTools", 2 },
    { "GardenStoreMisc", 1 },
    -- Garages and sheds, and the farm and garden crates of sheds, barns and garages.
    { "GarageTools", 0.5 },
    { "CrateFarming", 0.5 },
    { "CrateGardening", 1 },
    -- Old tool crates, in sheds and basements: a sprinkler that has seen use.
    { "CrateToolsOld", 0.5 },
}

-- The same for the Sprinkler Timer, a garden store's plug-in timer, as often as a Lawn Sprinkler
-- there and half that by a hardware store's garden tools. A garden part, so the parts option
-- scales it.
Distributions.SPRINKLER_TIMER_LISTS = {
    { "GardenStoreTools", 2 },
    { "GardenStoreMisc", 1 },
    { "ToolStoreFarming", 1 },
    { "GigamartFarming", 0.5 },
}

-- The same for the Water Valve, rare in plumbing supplies: a washer's inlet valve is a spare few
-- kept. Most come out of washers and dishwashers (Salvage Pump).
Distributions.WATER_VALVE_LISTS = {
    { "PlumbingSupplies", 0.5 },
}

-- Each found item: its full type, its lists and the sandbox option that scales their weights.
Distributions.LOOT = {
    { item = Distributions.PAMPHLET, lists = Distributions.PAMPHLET_LISTS, option = "PamphletLoot" },
    { item = Distributions.UTILITY_PUMP, lists = Distributions.UTILITY_PUMP_LISTS, option = "PartsLoot" },
    { item = Distributions.LAWN_SPRINKLER, lists = Distributions.LAWN_SPRINKLER_LISTS, option = "PartsLoot" },
    { item = Distributions.SPRINKLER_TIMER, lists = Distributions.SPRINKLER_TIMER_LISTS, option = "PartsLoot" },
    { item = Distributions.WATER_VALVE, lists = Distributions.WATER_VALVE_LISTS, option = "PartsLoot" },
}

-- Items lists are flat name, weight pairs.
local function removeItem(items, fullType)
    for i = #items - 1, 1, -2 do
        if items[i] == fullType then
            table.remove(items, i + 1)
            table.remove(items, i)
        end
    end
end

--- Puts each item of LOOT into each of its lists at its weight times its option, replacing what an
--- earlier call put there. At 0 it leaves the item out altogether, since a zero weight could still
--- spawn through the zombie density bonus. ItemPickerJava reads the Lua tables only when it parses
--- them, so ItemPickerJava.Parse() has to run afterwards.
function Distributions.apply()
    for _, loot in ipairs(Distributions.LOOT) do
        local multiplier = SandboxVars.EnhancedIrrigation[loot.option]
        for _, entry in ipairs(loot.lists) do
            local list = procLists[entry[1]]
            if list and list.items then
                removeItem(list.items, loot.item)
                if multiplier > 0 then
                    table.insert(list.items, loot.item)
                    table.insert(list.items, entry[2] * multiplier)
                end
            else
                print("EnhancedIrrigation: no loot list " .. entry[1] .. " for " .. loot.item .. ", skipped")
            end
        end
    end
end

-- The save's sandbox options aren't loaded yet when this file runs, nor during the distribution
-- merge events: IsoWorld.init fires those, then loads the options, then parses the tables, and
-- only then fires OnInitGlobalModData.
Events.OnInitGlobalModData.Add(function()
    Distributions.apply()
    ItemPickerJava.Parse()
end)

return Distributions
