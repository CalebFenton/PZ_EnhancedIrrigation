-- Development only. The setup of the Enhanced Irrigation QA debug scenario, for playing through
-- the mod by hand: a character nothing can see or hurt, who carries anything and has every skill
-- and recipe the mod reads, and on an open lot between a farmhouse and its field, from north to
-- south, beds of crops beside tanks to lay lines from, tanks to set up and plumb, and a row to each
-- group of items the jobs take.
-- Single player only: it sows through the authority's SFarmingSystem.
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Stands/Stands"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Valves"
local Stage = require "EnhancedIrrigationDevStage"
local Build = require "EnhancedIrrigation/Debug/EnhancedIrrigationDebugBuild"
local Harness = require "PZHarness/Stage"
require "PZHarness/StageLots"
local HarnessQA = require "PZHarness/QA"

local QA = {}

local Sprites = EnhancedIrrigation.Sprites

-- Where the scenario starts, and where the lot is looked for from: the open grass between a
-- farmhouse west of Muldraugh and the rows of its field to the west.
QA.START = { x = 10458, y = 10062, z = 0 }

local MARK = "EIQA"
-- The lot, in squares east and south of its north-west corner, and the margin round it also
-- cleared of trees and ground cover.
local AREA = { w = 12, h = 20 }
local MARGIN = 1
-- Where the character is put: between the first two beds, beside their tanks.
local ARRIVE = { x = 2, y = 2 }

-- Vanilla's open round rain barrel, the one a Tank Stand takes, as it stands on the ground.
local BARREL_SPEC = EnhancedIrrigation.Stands.BARRELS[1]
local BARREL = BARREL_SPEC.barrel
-- The deck the upper tank stands on, built as a player builds one: vanilla's Log Stairs up the
-- lot's west column, climbing north to the landing they lay a storey up, and wooden floor joined to
-- the landing, the deck two squares by two with the bed's tank square among them. Each is the tile
-- of its build-menu entity and the cursor's rotation (ISBuildIsoEntity.nSprite: 1 is west), the
-- stairs given by their top step.
local STAIRS = { sprite = "crafted_02_98", nSprite = 1, x = 0, y = 5 }
local DECK_FLOOR = { sprite = "carpentry_02_58", nSprite = 1 }
-- In build order, each beside one built: the landing is at the stairs' x, a square north of them.
local DECK = { { x = 1, y = 4 }, { x = 0, y = 3 }, { x = 1, y = 3 } }

-- Water points of a crop gone dry.
local DRY = 15
-- A crop stage still growing, short of harvest.
local GROWING = 4
-- The column of the beds' tanks, whose crops run east of them.
local TANK_X = 1
-- Each bed: a row of crops east of a tank full of water at its west end, on which a line laid
-- from beside the tank waters them. `up` floors above the ground, on the deck; `dry`, how many of
-- the crops, from the west, have gone dry, the rest just watered. The raised barrel and the deck's
-- give a line on the ground a storey of head; the ground barrel gives none.
local BEDS = {
    { y = 1, tank = Sprites.RAISED_BARREL, seed = "Tomato", dry = 10 },
    { y = 3, tank = BARREL, up = 1, seed = "Carrots", dry = 0 },
    { y = 5, tank = BARREL, seed = "Cabbages", dry = 5 },
}
local BED_CROPS = 10

-- The tanks to set up and plumb: an empty Tank Stand and an empty barrel to set on it, and two
-- barrels within plumbing reach of each other, one full and one empty.
local TANK_ROW = 8
local TANKS = {
    { x = 1, sprite = Sprites.TANK_STAND },
    { x = 3, sprite = BARREL },
    { x = 6, sprite = BARREL, full = true },
    { x = 9, sprite = BARREL },
}

-- The items, a row to each group from FIRST_ITEM_ROW, with an empty row between, a square to each
-- item type. Pipe and joints for a line of LINE_TILES of each kind, and SPARE_LENGTHS more for its
-- tap and the longest Plumb to Tank.
local FIRST_ITEM_ROW = 11
local LINE_TILES = 24
local SPARE_LENGTHS = 5
local LENGTHS = LINE_TILES + SPARE_LENGTHS
local Pipes, LineJobs, Valves = EnhancedIrrigation.Pipes, EnhancedIrrigation.LineJobs, EnhancedIrrigation.Valves
-- Each pipe material, and the items a length of it takes.
local PIPES = {}
for _, material in ipairs(EnhancedIrrigation.Sprites.PIPE_MATERIALS) do
    local spec = Pipes.MATERIALS[material]
    table.insert(PIPES, { spec.item, spec.perLength })
end
-- What joins plastic, and what joins clay; enough of each one alone for every length.
local JOINTS = { "Base.Glue", "Base.Epoxy", "Base.DuctTape", "Base.BucketConcreteFull", "Base.BucketClayCement" }
-- The pipe wrench and everything each hole tool takes, what it uses up enough for every tile's
-- hole, and the saw the Tank Stand keeps besides the hammer among them.
local TOOLS = { { Pipes.WRENCH.item, 1 } }
for _, tool in ipairs(LineJobs.HOLE_TOOLS) do
    for _, material in ipairs(tool.materials) do
        table.insert(TOOLS, { material.item, material.need and material.need * LINE_TILES or 1 })
    end
end
table.insert(TOOLS, { "Base.Saw", 1 })
local READING = { { "EnhancedIrrigation.CisternsForKentucky", 1 }, { "Base.WateredCan", 1, FluidType.Water } }
-- One of each valve, to fit to the lines' taps.
local VALVES = { { Valves.WIND_UP, 1 }, { Valves.TIMER, 1 }, { Valves.SPRINKLER_TIMER, 1 } }

-- What the build-menu recipes use up (PZHarness.QA.materials); their tools are among TOOLS.
local function standMaterials()
    local materials = {}
    for _, need in ipairs(HarnessQA.materials(PZHarness.Test.buildRecipeNames())) do
        if need.used > 0 then
            table.insert(materials, { need.type, need.used, need.fluid })
        end
    end
    return materials
end

-- How many of the drainable `fullType` hold `uses` uses.
local function itemsFor(fullType, uses)
    local item = instanceItem(fullType)
    return item and math.ceil(uses / item:getCurrentUses()) or 0
end

-- The item groups, in order, each a list of { type, count, fluid }.
local function itemGroups()
    local pipes, joints = {}, {}
    for _, pipe in ipairs(PIPES) do
        table.insert(pipes, { pipe[1], pipe[2] * LENGTHS })
    end
    for _, joint in ipairs(JOINTS) do
        table.insert(joints, { joint, itemsFor(joint, LENGTHS) })
    end
    return { pipes, joints, TOOLS, standMaterials(), READING, VALVES }
end

-- Lays each group on its own row of the lot, a square to each item type, scattered over it so
-- they show.
local function layItems(lot, groups, summary)
    for row, group in ipairs(groups) do
        local y = FIRST_ITEM_ROW + (row - 1) * 2
        for column, entry in ipairs(group) do
            local fullType, count, fluid = entry[1], entry[2], entry[3]
            local square = column <= AREA.w and Harness.lotSquare(lot, column - 1, y)
            if not HarnessQA.isKnown(fullType) then
                table.insert(summary.unknown, fullType)
            elseif not square then
                table.insert(summary.unplaced, fullType)
            else
                for _ = 1, count do
                    square:AddWorldInventoryItem(HarnessQA.newItem(fullType, fluid), ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0)
                    summary.items = summary.items + 1
                end
                summary.types = summary.types + 1
            end
        end
    end
end

-- The vanilla build-menu entity of `tile` ({ sprite, nSprite }) built at the lot's x, y, `up`
-- floors above it, by `player` as the build menu builds it (PZHarness.QA.buildAsPlayer). Returns
-- what is missing, or nil.
local function buildOnLot(player, lot, tile, x, y, up)
    return HarnessQA.buildAsPlayer(player, tile.sprite, tile.nSprite, lot.x + x, lot.y + y, lot.z + (up or 0))
end

-- The stairs and the deck at their top. Returns what is missing, or nil.
local function buildDeck(player, lot)
    local missing = buildOnLot(player, lot, STAIRS, STAIRS.x, STAIRS.y)
    for _, at in ipairs(DECK) do
        missing = missing or buildOnLot(player, lot, DECK_FLOOR, at.x, at.y, 1)
    end
    return missing
end

-- The tile `sprite` built at the lot's x, y, `up` floors above it, `full` of water if asked.
-- Returns what is missing, or nil.
local function placeTank(lot, x, y, sprite, up, full)
    local square = Harness.lotSquare(lot, x, y, up)
    if not square then
        return "a square for " .. sprite .. " at " .. (lot.x + x) .. "," .. (lot.y + y) .. "," .. (lot.z + (up or 0))
    end
    local built, missing = Build.tile(square, sprite, full and Build.FULL)
    if not built then
        return missing
    end
    square:RecalcAllWithNeighbours(true)
end

-- Builds the deck, the beds and the tank row. Returns what is missing, or nil.
local function placeBeds(player, lot)
    local missing = buildDeck(player, lot)
    if missing then
        return missing
    end
    for _, bed in ipairs(BEDS) do
        missing = placeTank(lot, TANK_X, bed.y, bed.tank, bed.up, true)
        if missing then
            return missing
        end
        for i = 1, BED_CROPS do
            local water = i <= bed.dry and DRY or Stage.WATERED
            missing = Stage.plant(Harness.lotSquare(lot, TANK_X + i, bed.y), bed.seed, GROWING, water)
            if missing then
                return missing
            end
        end
    end
    for _, tank in ipairs(TANKS) do
        local missing = placeTank(lot, tank.x, TANK_ROW, tank.sprite, nil, tank.full)
        if missing then
            return missing
        end
    end
end

-- The QA character (PZHarness.QA.setUpCharacter), carrying an empty barrel as vanilla's pickup
-- gives it, the server module loaded by the first tick in single player.
local function setUpBarrelCarrier(player)
    HarnessQA.setUpCharacter(player)
    player:getInventory():AddItem(EnhancedIrrigation.StandSystem.barrelItem(BARREL_SPEC,
        player:getCurrentSquare()))
end

--- Sets the scenario up around `player`, and prints what it laid out, and anything it couldn't,
--- under MARK.
function QA.setup(player)
    getGameTime():setTimeOfDay(10)
    setUpBarrelCarrier(player)
    local lot = Harness.findLot(player, AREA.w, AREA.h, { floor = Harness.NATURAL_FLOOR, trees = true })
    if not lot then
        print(MARK .. " no open lot of soil or grass " .. AREA.w .. "x" .. AREA.h .. " within "
            .. Harness.SEARCH_RADIUS .. " squares")
        return
    end
    local summary = { types = 0, items = 0, unknown = {}, unplaced = {} }
    Harness.clearLot(lot, MARGIN)
    summary.missing = placeBeds(player, lot)
    layItems(lot, itemGroups(), summary)
    PZHarness.Fixtures.teleportToMiddle(player, lot.x + ARRIVE.x, lot.y + ARRIVE.y, lot.z)
    HarnessQA.printSummary(MARK, string.format("laid out %d beds, %d tanks and %d items of %d types on the lot at %d,%d",
        #BEDS, #TANKS, summary.items, summary.types, lot.x, lot.y), summary, { "missing", "unknown", "unplaced" })
end

return QA
