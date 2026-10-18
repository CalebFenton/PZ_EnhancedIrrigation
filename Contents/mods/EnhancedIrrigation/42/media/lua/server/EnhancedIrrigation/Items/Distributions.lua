if isClient() then return end

require "Items/Distributions"
require "Items/ProceduralDistributions"

-- Where Cisterns for Kentucky turns up: wherever a 1993 extension leaflet on farm water would
-- have been left, a find rather than a given. apply() puts it into the game's loot lists in
-- OnInitGlobalModData, scaled by the PamphletLoot sandbox option.

EnhancedIrrigation = EnhancedIrrigation or {}
local Distributions = {}
EnhancedIrrigation.Distributions = Distributions

local procLists = ProceduralDistributions.list

Distributions.PAMPHLET = "EnhancedIrrigation.CisternsForKentucky"

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

-- Items lists are flat name, weight pairs.
local function removeItem(items, fullType)
    for i = #items - 1, 1, -2 do
        if items[i] == fullType then
            table.remove(items, i + 1)
            table.remove(items, i)
        end
    end
end

--- Puts the pamphlet into each of PAMPHLET_LISTS at its weight times the PamphletLoot option,
--- replacing what an earlier call put there. At 0 it leaves the pamphlet out altogether, since a
--- zero weight could still spawn through the zombie density bonus. ItemPickerJava reads the Lua
--- tables only when it parses them, so ItemPickerJava.Parse() has to run afterwards.
function Distributions.apply()
    local multiplier = SandboxVars.EnhancedIrrigation.PamphletLoot
    for _, entry in ipairs(Distributions.PAMPHLET_LISTS) do
        local list = procLists[entry[1]]
        if list and list.items then
            removeItem(list.items, Distributions.PAMPHLET)
            if multiplier > 0 then
                table.insert(list.items, Distributions.PAMPHLET)
                table.insert(list.items, entry[2] * multiplier)
            end
        else
            print("EnhancedIrrigation: no loot list " .. entry[1] .. " for " .. Distributions.PAMPHLET .. ", skipped")
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
