-- Development only. The setup of the Enhanced Irrigation QA debug scenario
-- (EnhancedIrrigationDebugScenario.lua), for playing through the mod by hand: a character nothing
-- can see or hurt, who carries anything, has every skill the mod reads and knows its recipes, and
-- carries an empty rain barrel, on an open lot between a farmhouse and its field. Laid out on the
-- lot from north to south, a group to a few rows: beds of growing crops, each beside a tank to
-- lay a line from (a barrel on a Tank Stand, a barrel on a deck a storey up, a barrel on the
-- ground); a row of tanks to set up and plumb (an empty stand, an empty barrel, two barrels to
-- plumb together); and on the ground, a row to each group of items: the pipe, the joints, the
-- tools, the Tank Stand's materials, and the pamphlet and a watering can.
-- Single player only: it sows through the authority's SFarmingSystem.
require "EnhancedIrrigation/Sprites"
local Stage = require "EnhancedIrrigationDevStage"

local QA = {}

local Sprites = EnhancedIrrigation.Sprites

-- Where the scenario starts, and where the lot is looked for from: the open grass between a
-- farmhouse west of Muldraugh and the rows of its field to the west.
QA.START = { x = 10458, y = 10062, z = 0 }

local MARK = "EIQA"
-- The lot, in squares east and south of its north-west corner, and the margin round it cleared of
-- ground cover too.
local AREA = { w = 11, h = 20 }
local MARGIN = 1
-- Where the character is put: between the first two beds, beside their tanks.
local ARRIVE = { x = 1, y = 2 }
-- Every perk the mod reads (the tests' `perks` setting) goes to this level.
local SKILL = 10

-- Vanilla's open round rain barrel, the one a Tank Stand takes, as it stands on the ground.
local BARREL = "carpentry_02_122"
-- The floor of the deck the upper tank stands on.
local DECK_FLOOR = "carpentry_02_58"

-- Water points of a crop just watered, and of one gone dry.
local WATERED, DRY = 100, 15
-- A crop stage still growing, short of harvest.
local GROWING = 4
-- Each bed: a row of crops east of a tank full of water at its west end, on which a line laid
-- from beside the tank waters them. `up` floors above the ground; `dry`, how many of the crops,
-- from the west, have gone dry, the rest just watered. The raised barrel and the deck's give a
-- line on the ground a storey of head; the ground barrel gives none.
local BEDS = {
    { y = 1, tank = Sprites.RAISED_BARREL, seed = "Tomato", dry = 10 },
    { y = 3, tank = BARREL, up = 1, seed = "Carrots", dry = 0 },
    { y = 5, tank = BARREL, seed = "Cabbages", dry = 5 },
}
local BED_CROPS = 10

-- The tanks to set up and plumb, in a row: an empty Tank Stand and an empty barrel to set on it,
-- and two barrels at one level close enough to plumb together, one full and one empty.
local TANK_ROW = 8
local TANKS = {
    { x = 0, sprite = Sprites.STAND },
    { x = 2, sprite = BARREL },
    { x = 5, sprite = BARREL, full = true },
    { x = 8, sprite = BARREL },
}

-- The items, a row to each group from FIRST_ITEM_ROW, with an empty row between, a square to each
-- item type. Pipe and joints for a line of LINE_TILES of each kind, and SPARE_LENGTHS more for its
-- tap and the longest Plumb to Tank.
local FIRST_ITEM_ROW = 11
local LINE_TILES = 24
local SPARE_LENGTHS = 5
local LENGTHS = LINE_TILES + SPARE_LENGTHS
-- Each kind of pipe, and the items a length of it takes (Pipes.KINDS).
local PIPES = { { "Base.Pipe", 1 }, { "Base.MetalPipe", 1 }, { "Base.LeadPipe", 1 }, { "Base.ClayPipeSegment", 2 } }
-- What joins plastic, and what joins clay; enough of each one alone for every length.
local JOINTS = { "Base.Glue", "Base.Epoxy", "Base.DuctTape", "Base.BucketConcreteFull", "Base.BucketClayCement" }
-- The pipe wrench and every tool that drills a hole (LineJobs.HOLE_TOOLS), with a nail for each
-- tile's hole by hammer, and the hammer and saw the Tank Stand keeps.
local TOOLS = {
    { "Base.PipeWrench", 1 }, { "Base.HandDrill", 1 }, { "Base.OldDrill", 1 }, { "Base.Awl", 1 },
    { "Base.StoneDrill", 1 }, { "Base.Hammer", 1 }, { "Base.Nails", LINE_TILES }, { "Base.Saw", 1 },
}
local READING = { { "EnhancedIrrigation.CisternsForKentucky", 1 }, { "Base.WateredCan", 1, FluidType.Water } }

-- The mod's build-menu recipes, which the craftRecipes T.learnRecipes teaches don't include.
local function buildRecipes()
    local recipes, prefix = {}, PZHarness.testSettings.recipePrefix
    local buildable = getScriptManager():getAllBuildableRecipes()
    for i = 0, buildable:size() - 1 do
        if PZHarness.startsWith(buildable:get(i):getName(), prefix) then
            table.insert(recipes, buildable:get(i))
        end
    end
    return recipes
end

local function recipeNames(recipes)
    local names = {}
    for _, recipe in ipairs(recipes) do
        table.insert(names, recipe:getName())
    end
    return names
end

-- What the build-menu recipes use up, the Tank Stand's logs, planks and nails: their tools are
-- among TOOLS.
local function standMaterials(recipes)
    local materials = {}
    for _, recipe in ipairs(recipes) do
        local inputs = recipe:getInputs()
        for i = 0, inputs:size() - 1 do
            local input = inputs:get(i)
            local item = input:getResourceType() == ResourceType.Item and not input:isKeep()
                and PZHarness.Test.inputItem(input)
            if item then
                table.insert(materials, { item:getFullName(), input:getIntAmount() })
            end
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
local function itemGroups(recipes)
    local pipes, joints = {}, {}
    for _, pipe in ipairs(PIPES) do
        table.insert(pipes, { pipe[1], pipe[2] * LENGTHS })
    end
    for _, joint in ipairs(JOINTS) do
        table.insert(joints, { joint, itemsFor(joint, LENGTHS) })
    end
    return { pipes, joints, TOOLS, standMaterials(recipes), READING }
end

local function isKnown(fullType)
    return getScriptManager():FindItem(fullType) ~= nil
end

-- A new item of `fullType`, its fluid container filled with `fluid` if given.
local function newItem(fullType, fluid)
    local item = instanceItem(fullType)
    local container = fluid and item:getFluidContainer()
    if container then
        container:Empty()
        container:addFluid(fluid, container:getCapacity())
    end
    return item
end

-- Lays each group on its own row of the lot, a square to each item type, scattered over it so
-- they show.
local function layItems(lot, groups, summary)
    for row, group in ipairs(groups) do
        local y = FIRST_ITEM_ROW + (row - 1) * 2
        for column, entry in ipairs(group) do
            local fullType, count, fluid = entry[1], entry[2], entry[3]
            local square = column <= AREA.w and Stage.lotSquare(lot, column - 1, y)
            if not isKnown(fullType) then
                table.insert(summary.unknown, fullType)
            elseif not square then
                table.insert(summary.unplaced, fullType)
            else
                for _ = 1, count do
                    square:AddWorldInventoryItem(newItem(fullType, fluid), ZombRandFloat(0.2, 0.8), ZombRandFloat(0.2, 0.8), 0)
                    summary.items = summary.items + 1
                end
                summary.types = summary.types + 1
            end
        end
    end
end

-- The tile `sprite` built at the lot's x, y, `up` floors above it on a deck laid for it, `full`
-- of water if asked. Returns what is missing, or nil.
local function placeTank(lot, x, y, sprite, up, full)
    local square = Stage.lotSquare(lot, x, y, up)
    if up and not square then
        square = getCell():createNewGridSquare(lot.x + x, lot.y + y, lot.z + up, true)
    end
    if not square then
        return "a square for " .. sprite .. " at " .. (lot.x + x) .. "," .. (lot.y + y)
    end
    if not square:getFloor() then
        square:addFloor(DECK_FLOOR)
    end
    local object, missing = Stage.build(square, sprite)
    if not object then
        return missing
    end
    local fluid = full and object:getFluidContainer()
    if fluid then
        fluid:addFluid(FluidType.Water, fluid:getCapacity() - fluid:getAmount())
    end
    square:RecalcAllWithNeighbours(true)
end

-- Builds the beds and the tank row. Returns what is missing, or nil.
local function placeBeds(lot)
    for _, bed in ipairs(BEDS) do
        local missing = placeTank(lot, 0, bed.y, bed.tank, bed.up, true)
        if missing then
            return missing
        end
        for i = 1, BED_CROPS do
            missing = Stage.plant(Stage.lotSquare(lot, i, bed.y), bed.seed, GROWING, i <= bed.dry and DRY or WATERED)
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

-- The rain barrel vanilla's pickup would give for an empty BARREL: the moveable named after its
-- tile (ISMoveableSpriteProps:instanceItem), carrying the components of a new barrel of that tile,
-- which pickup moves from the barrel onto the item (GameEntityFactory.TransferComponents).
local function carriedBarrel(square)
    local item = instanceItem("Moveables." .. BARREL)
    local fresh = IsoThumpable.new(getCell(), square, BARREL, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(fresh, EnhancedIrrigation.tileEntity(BARREL), true)
    GameEntityFactory.TransferComponents(fresh, item)
    return item
end

local function setUpCharacter(player, recipes)
    player:setGodMod(true)
    player:setInvisible(true)
    player:setUnlimitedCarry(true)
    player:setUnlimitedEndurance(true)
    local levels = {}
    for _, perk in ipairs(PZHarness.testSettings.perks) do
        levels[perk:getId()] = SKILL
    end
    PZHarness.Fixtures.setPerkLevels(player, levels)
    PZHarness.Test.learnRecipes(player)
    PZHarness.Fixtures.learnRecipes(player, recipeNames(recipes))
    player:getInventory():AddItem(carriedBarrel(player:getCurrentSquare()))
end

--- Sets the scenario up around `player`, and prints what it laid out, and anything it couldn't,
--- under MARK. Returns that summary.
function QA.setup(player)
    getGameTime():setTimeOfDay(10)
    local recipes = buildRecipes()
    setUpCharacter(player, recipes)
    local summary = { types = 0, items = 0, unknown = {}, unplaced = {} }
    local lot = Stage.findLot(player, AREA.w, AREA.h, true)
    if not lot then
        print(MARK .. " no open lot of soil or grass " .. AREA.w .. "x" .. AREA.h .. " within "
            .. Stage.SEARCH_RADIUS .. " squares")
        return summary
    end
    summary.lot = lot
    Stage.clearLot(lot, AREA.w, AREA.h, MARGIN)
    summary.missing = placeBeds(lot)
    layItems(lot, itemGroups(recipes), summary)
    PZHarness.Fixtures.teleportToMiddle(player, lot.x + ARRIVE.x, lot.y + ARRIVE.y, lot.z)
    print(string.format("%s laid out %d beds, %d tanks and %d items of %d types on the lot at %d,%d", MARK, #BEDS,
        #TANKS, summary.items, summary.types, lot.x, lot.y))
    if summary.missing then
        print(MARK .. " missing: " .. summary.missing)
    end
    for _, what in ipairs({ "unknown", "unplaced" }) do
        if #summary[what] > 0 then
            print(MARK .. " " .. what .. ": " .. table.concat(summary[what], "; "))
        end
    end
    return summary
end

--- QA.setup on the first tick: a scenario's onStart runs during the world's start (OnGameStart),
--- before the global object systems exist, which sowing and clearing ground cover reach.
function QA.setupSoon()
    local function onTick()
        Events.OnTick.Remove(onTick)
        QA.setup(getPlayer())
    end
    Events.OnTick.Add(onTick)
end

return QA
