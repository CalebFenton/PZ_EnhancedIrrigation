-- Development only; dev/run-debug-client.sh --promo runs it instead of the tests. It stages the
-- mod in use on open lots near the scenario's start and saves the raw art that art/promo/compose.py
-- lays out: promo_<shot>.png screenshots, and EIPromo.json naming each screenshot's regions and the
-- item and recipe names in the game's language, which lib/capture.py turns into
-- art/promo/captures. PROMO=<group>,... shoots only those groups, building only the lots they need.
-- Single player only: it builds through the authority's systems.

require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/UI/LineMenu"
require "EnhancedIrrigation/UI/ValveUI"
local Stage = require "EnhancedIrrigationDevStage"
local Harness = require "PZHarness/Stage"
local Capture = require "PZHarness/Capture"

local Promo = {}

local EI = EnhancedIrrigation
local Sprites = EI.Sprites
local MARK = "EIPromo"

local NOON = 12
-- Late enough for the sky to have gone dark in any season, so that the boilers' fires read.
local NIGHT = 23
local VANILLA_WELL = "camping_01_16"
local GENERATOR = "Base.Generator"

-- Every item the mod defines, then the vanilla pipe it lays and the wrench that works it, in the
-- order the README shows them.
local ITEMS = {
    "EnhancedIrrigation.CisternsForKentucky", "EnhancedIrrigation.LawnSprinkler", "EnhancedIrrigation.WaterValve",
    "EnhancedIrrigation.WindUpValve", "EnhancedIrrigation.TimerValve", "EnhancedIrrigation.SprinklerTimer",
    "EnhancedIrrigation.FilterCrockUnfired", "EnhancedIrrigation.FilterCrock", "EnhancedIrrigation.AppliancePump",
    "EnhancedIrrigation.UtilityPump",
}
for _, material in ipairs(EI.Sprites.PIPE_MATERIALS) do
    table.insert(ITEMS, EI.Pipes.MATERIALS[material].item)
end
table.insert(ITEMS, EI.Pipes.WRENCH.item)
-- Inputs that take any item with a tag show this one.
local PREFER = { "Base.Hammer", "Base.Screwdriver", "Base.Saw", "Base.PipeWrench", "Base.Wrench", "Base.HandDrill",
    "Base.BlowTorch", "Base.WeldingMask", "Base.KitchenKnife", "Base.Bucket", "Base.Shovel2", "Base.MasonsTrowel",
    "Base.BucketConcreteFull", "Base.Matches", "Base.Charcoal" }
local FLUID_CONTAINERS = { Water = "Base.WaterBottle" }
local LITERATURE = { "EnhancedIrrigation.CisternsForKentucky" }

-- The lots, each its own patch of open soil or grass, in (east, south) squares from its north-west
-- corner, at least LOT_GAP apart so that no shot shows another's things. `player` is where the
-- character stands for the lot's shots, `scout` where it looks around first.
local LOT_GAP = 6
-- Ground cover this far round a lot goes too, so none of it stands in front of the shots.
local MARGIN = 2
-- How far round a lot the ground must be open, most first: buildings and fences at a lot's edge
-- stand in its shots, and the squares behind them, never seen, draw black.
local CLEARANCES = { 5, 3, 0 }

-- The garden in use: a raised barrel feeding a tap, an iron line from the tap along two beds of
-- crops, the holed tiles under the crops wet; a second raised barrel plumbed to the first, and a
-- barrel filter beside them. On the screen, a square further east is further right and one
-- further south further left, and both are nearer the camera, so the filter stands right of the
-- barrel, where neither hides the other.
local HOMESTEAD = {
    w = 11, h = 5,
    tank = { 1, 1, sprite = Sprites.RAISED_BARREL },
    second = { 1, 3, sprite = Sprites.RAISED_TARP_BARREL },
    filter = { 2, 0, sprite = Sprites.BARREL_FILTER },
    material = "iron",
    tap = { 2, 1 },
    -- The line from beside the tap: the bed rows' holed tiles, joined by the branch down the tap's
    -- column.
    branch = { { 2, 2 }, { 2, 3 } },
    beds = { { y = 1, from = 3, to = 10, seed = "Tomato" }, { y = 3, from = 3, to = 10, seed = "Cabbages" } },
    player = { 6, 2 },
    scout = { 8, 4 },
    -- The poster's few squares: both barrels, the filter, the tap and the first crops of each bed.
    poster = { { 1, 1 }, { 1, 3 }, { 2, 0 }, { 2, 1 }, { 3, 1 }, { 4, 1 }, { 5, 1 }, { 3, 3 }, { 4, 3 } },
    posterPlayer = { 4, 2 },
    -- The banner's: the barrels, the filter, the tap and the beds out to their third crops. The
    -- view centres on the character, so it stands left of them, below the barrels, for the crop
    -- to have them right of its middle without running off the screen.
    banner = { { 1, 1 }, { 1, 3 }, { 2, 0 }, { 2, 1 }, { 5, 1 }, { 5, 3 } },
    bannerPlayer = { 1, 5 },
}
-- The holed tiles' soak: wet, as after a morning's run, and short of waterlogged.
local HOMESTEAD_SOAK = 20
local HOMESTEAD_RUN_HOURS = 0.25
local CROP_STAGE = { Tomato = 5, Cabbages = 5, Carrots = 5, Broccoli = 4 }
local CROP_WATER = 100

-- The hand pumps either side of a well, and a Pump House beside it, its outlet plumbed to a raised
-- barrel, powered by a generator behind it. The character stands off to the left, in front of
-- none of them.
local PUMPS = {
    w = 7, h = 5,
    well = { 2, 2 },
    wooden = { 1, 2 },
    iron = { 3, 2 },
    house = { 3, 1 },
    generator = { 3, 0 },
    barrel = { 5, 1 },
    player = { 1, 4 },
    scout = { 5, 4 },
}

-- An iron hand pump at a well, its outlet plumbed to a plastic line along two beds, two
-- sprinklers on the line, the line's tiles in their reach wet.
local SPRINKLERS = {
    w = 12, h = 5,
    well = { 0, 1 },
    pump = { 0, 2 },
    material = "plastic",
    line = { y = 2, from = 1, to = 11 },
    sprinklers = { 3, 8 },
    beds = { { y = 1, seed = "Carrots" }, { y = 3, seed = "Broccoli" } },
    player = { 6, 4 },
    scout = { 9, 4 },
    pumpHours = 1,
}
local SPRINKLER_SOAK = 20

-- The treatment units in a row at night, each boiler lit between two filters, by whose fires the
-- row reads.
local FILTERS = {
    w = 7, h = 4,
    units = {
        { 1, 1, sprite = Sprites.BARREL_FILTER }, { 2, 1, sprite = Sprites.BOILER_STONE, lit = true },
        { 3, 1, sprite = Sprites.BRICK_FILTER }, { 4, 1, sprite = Sprites.BOILER_WELDED, lit = true },
        { 5, 1, sprite = Sprites.FILTER_CROCK },
    },
    player = { 1, 3 },
    scout = { 5, 3 },
}
-- Fuel enough that a fire burns at its full light radius through the shot, and water in each
-- drum, which a dry one burns through.
local BOILER_FUEL = 48 * 60
local BOILER_HEAD = 200
-- Raw water waiting in each filter, as one in use holds.
local FILTER_HEAD = { [Sprites.BARREL_FILTER] = 30, [Sprites.BRICK_FILTER] = 120, [Sprites.FILTER_CROCK] = 6 }

-- What the character carries for the tap's menu: the wrench and a valve of each kind, so that Fit
-- Valve lists them, and a drill and a sprinkler, so that the jobs it offers can all be done.
local MENU_ITEMS = { EI.Pipes.WRENCH.item, "Base.HandDrill", "EnhancedIrrigation.LawnSprinkler" }
for _, fullType in ipairs(EI.Valves.ORDER) do
    table.insert(MENU_ITEMS, fullType)
end
local MENU_AT = 100
-- The Timer Valve's setting the panel shows: early morning, before the heat.
local TIMER_START, TIMER_MINUTES = 6, 30

-- The run whose steps are being added; Promo.capture makes it.
local run
-- The lots found, by name.
local lots = {}

-- Positions --------------------------------------------------------------------------------------

local function at(lot, position)
    return Stage.lotSquare(lot, position[1], position[2])
end

-- The squares of `lot` at each list of positions given, in order.
local function squaresAt(lot, ...)
    local squares = {}
    for i = 1, select("#", ...) do
        for _, position in ipairs((select(i, ...))) do
            table.insert(squares, at(lot, position))
        end
    end
    return squares
end

-- Every square of `lot`, which its shots frame.
local function lotSquares(lot)
    local squares = {}
    for x = 0, lot.w - 1 do
        for y = 0, lot.h - 1 do
            table.insert(squares, Stage.lotSquare(lot, x, y))
        end
    end
    return squares
end

-- Building ---------------------------------------------------------------------------------------

-- Logs what the staging couldn't do; the shot goes on without it, and the eye catches the gap.
local function report(what)
    print(MARK .. " no " .. what)
end

-- The tile `sprite` built at `position` of `lot` as the build menu builds it, `full` of water if
-- asked.
local function build(lot, position, sprite, full)
    local object, missing = Stage.build(at(lot, position), sprite)
    if not object then
        report(missing)
        return nil
    end
    local fluid = full and object:getFluidContainer()
    if fluid then
        fluid:addFluid(FluidType.Water, fluid:getCapacity() - fluid:getAmount())
    end
    return object
end

local function placeTile(lot, position, sprite)
    return PZHarness.Fixtures.newTile(at(lot, position), sprite)
end

local function plant(lot, x, y, seed)
    local missing = Stage.plant(Stage.lotSquare(lot, x, y), seed, CROP_STAGE[seed], CROP_WATER)
    if missing then
        report(missing)
    end
end

local function squarePosition(square)
    return { x = square:getX(), y = square:getY(), z = square:getZ() }
end

-- Plumbs the tanks or pump outlet on squares `a` and `b` with iron pipe, as Plumb to Tank or Plumb
-- Outlet leaves them; `role` "pump" makes `a` the pump.
local function plumb(a, b, role)
    local from, to = squarePosition(a), squarePosition(b)
    EI.LinkSystem.instance:addLink(from, to, "iron", EI.Links.lengthsFor(EI.Links.distance(from, to)), nil, role)
end

-- A pump of the tile `sprite` at `position` of `lot`, its record made as its OnCreate makes it and
-- a seal fitted, so that it works.
local function placePump(lot, position, sprite)
    local pump = build(lot, position, sprite)
    if not pump then
        return nil
    end
    EI.PumpSystem.onCreate({ thumpable = pump })
    local record = EI.Pumps.recordOf(pump)
    if record then
        record:fitSeal("Base.LeatherStrips")
        record:sendSummary()
    else
        report("record for the pump " .. sprite)
    end
    return pump, record
end

local function recalc(lot)
    for x = -1, lot.w do
        for y = -1, lot.h do
            local square = Stage.lotSquare(lot, x, y)
            if square then
                square:RecalcAllWithNeighbours(true)
            end
        end
    end
end

local function clear(lot)
    Harness.removeTrees(lot.x, lot.y, lot.z)
    Stage.clearLot(lot, lot.w, lot.h, MARGIN)
end

local function buildHomestead()
    local lot, spec = lots.homestead, HOMESTEAD
    clear(lot)
    local tank = build(lot, spec.tank, spec.tank.sprite, true)
    local second = build(lot, spec.second, spec.second.sprite, true)
    if tank and second then
        plumb(tank:getSquare(), second:getSquare())
    end
    build(lot, spec.filter, spec.filter.sprite)
    local LineSystem = EI.LineSystem
    LineSystem.place(at(lot, spec.tap), spec.material, { tap = true })
    for _, position in ipairs(spec.branch) do
        LineSystem.place(at(lot, position), spec.material)
    end
    for _, bed in ipairs(spec.beds) do
        for x = bed.from, bed.to do
            LineSystem.place(Stage.lotSquare(lot, x, bed.y), spec.material, { holed = true, soak = HOMESTEAD_SOAK })
            plant(lot, x, bed.y, bed.seed)
        end
    end
    -- The tap run a while, as its job runs it, so that the line is full and its holes show wet.
    local tap = EI.Lines.lineAt(lot.x + spec.tap[1], lot.y + spec.tap[2], lot.z)
    local stopped = tap and EI.TapSystem.run(tap, HOMESTEAD_RUN_HOURS)
    if not tap or stopped then
        report("water from the homestead's tap: " .. tostring(stopped))
    end
    recalc(lot)
end

local function buildPumps()
    local lot, spec = lots.pumps, PUMPS
    clear(lot)
    placeTile(lot, spec.well, VANILLA_WELL)
    placePump(lot, spec.wooden, Sprites.WOODEN_HAND_PUMP)
    placePump(lot, spec.iron, Sprites.IRON_HAND_PUMP)
    local barrel = build(lot, spec.barrel, Sprites.RAISED_BARREL)
    local house, record = placePump(lot, spec.house, Sprites.PUMP_HOUSE_METAL)
    local generatorSquare = at(lot, spec.generator)
    local generator = IsoGenerator.new(instanceItem(GENERATOR), getCell(), generatorSquare)
    generator:setConnected(true)
    generator:setCondition(100)
    generator:setFuel(generator:getMaxFuel() * 0.7)
    generator:setActivated(true)
    if house and record and barrel then
        record:fitPart(instanceItem(EI.Pumps.UTILITY_PUMP))
        record.on = true
        plumb(house:getSquare(), barrel:getSquare(), "pump")
        record:afterChange()
    end
    recalc(lot)
end

local function buildSprinklers()
    local lot, spec = lots.sprinklers, SPRINKLERS
    clear(lot)
    placeTile(lot, spec.well, VANILLA_WELL)
    local pump = placePump(lot, spec.pump, Sprites.IRON_HAND_PUMP)
    local LineSystem = EI.LineSystem
    local isSprinkler = {}
    for _, x in ipairs(spec.sprinklers) do
        isSprinkler[x] = true
    end
    for x = spec.line.from, spec.line.to do
        LineSystem.place(Stage.lotSquare(lot, x, spec.line.y), spec.material, {
            soak = SPRINKLER_SOAK,
            sprinkler = isSprinkler[x] and { condition = 100, ceiling = 100 } or nil,
        })
    end
    for _, bed in ipairs(spec.beds) do
        for x = spec.line.from, spec.line.to do
            plant(lot, x, bed.y, bed.seed)
        end
    end
    if pump then
        plumb(pump:getSquare(), Stage.lotSquare(lot, spec.line.from, spec.line.y), "pump")
        local stopped = EI.PumpSystem.run(getPlayer(), pump, spec.pumpHours)
        if stopped then
            report("water from the sprinklers' pump: " .. tostring(stopped))
        end
    end
    recalc(lot)
end

-- As a built unit is once its OnCreate has run: a boiler a fireplace carrying its entity.
local function buildFilters()
    local lot = lots.filters
    clear(lot)
    for _, unit in ipairs(FILTERS.units) do
        local built = build(lot, unit, unit.sprite)
        local created = built and EI.TreatmentSystem.onCreate({ thumpable = built })
        local object = created and created.object or built
        local record = object and EI.Treatment.recordOf(object)
        if record then
            record.head = unit.lit and BOILER_HEAD or FILTER_HEAD[unit.sprite]
            if unit.lit then
                object:setFuelAmount(BOILER_FUEL)
                object:turnOn()
                record:update()
            end
            record:sendSummary()
        elseif built then
            report("record for the unit " .. unit.sprite)
        end
    end
    recalc(lot)
end

-- The lots each group needs, and what builds each lot, in the order they are looked for.
local LOTS = {
    { name = "homestead", spec = HOMESTEAD, build = buildHomestead },
    { name = "pumps", spec = PUMPS, build = buildPumps },
    { name = "sprinklers", spec = SPRINKLERS, build = buildSprinklers },
    { name = "filters", spec = FILTERS, build = buildFilters },
}

-- Shots ------------------------------------------------------------------------------------------

-- The squares the character has looked around from so far in the run. What it saw stays seen.
local lookedFrom = {}

-- Has the character look around from each of `squares` it hasn't yet, then from the last, where it
-- stays, and sets the zoom `stepsOut` steps out from the closest.
local function goTo(squares, stepsOut)
    for i, square in ipairs(squares) do
        if i == #squares or not lookedFrom[square] then
            Harness.addLookAround(run.steps, getPlayer(), square)
            lookedFrom[square] = true
        end
    end
    run:add(function()
        return Harness.zoomOut(stepsOut)
    end)
end

local function goToLot(name, stepsOut)
    local lot, spec = lots[name], nil
    for _, entry in ipairs(LOTS) do
        if entry.name == name then
            spec = entry.spec
        end
    end
    goTo({ at(lot, spec.scout), at(lot, spec.player) }, stepsOut)
end

local function addWorld()
    goToLot("homestead", 1)
    run:addOpaque("homestead", function()
        return { Harness.centred("homestead", lotSquares(lots.homestead)) }
    end)
    -- The banner, a step further out, has its title over the left half: the barrels, the tap and
    -- the near end of the beds stand against its right edge, the beds running on past it.
    goTo({ at(lots.homestead, HOMESTEAD.bannerPlayer) }, 2)
    run:addOpaque("banner", function()
        return { Harness.rightAligned("banner", squaresAt(lots.homestead, HOMESTEAD.banner)) }
    end)
end

local function addWater()
    goToLot("pumps", 0)
    run:addOpaque("pumps", function()
        return { Harness.centred("pumps", lotSquares(lots.pumps)) }
    end)
    goToLot("sprinklers", 1)
    run:addOpaque("sprinklers", function()
        return { Harness.centred("sprinklers", lotSquares(lots.sprinklers)) }
    end)
    Harness.addHour(run, NIGHT)
    goToLot("filters", 0)
    run:addOpaque("filters", function()
        return { Harness.centred("filters", lotSquares(lots.filters)) }
    end)
    Harness.addHour(run, NOON)
end

-- The homestead's tap tile.
local function homesteadTap()
    local lot = lots.homestead
    return EI.Lines.lineAt(lot.x + HOMESTEAD.tap[1], lot.y + HOMESTEAD.tap[2], lot.z)
end

-- The panel LineMenu opens for the valve on the tap tile `line` (LineMenu's valvePanel).
local function valvePanel(line)
    local state = EI.Lines.stateOf(line)
    local valve = state and state.valve
    if not valve then
        return nil
    end
    local windUp = EI.Valves.kindOf(valve.item) == "windup"
    return {
        title = getItemNameFromFullType(valve.item),
        object = line,
        feature = "line",
        job = windUp and EI.LineJobs.WIND_VALVE or EI.LineJobs.SET_VALVE_TIMER,
        okKey = windUp and "ContextMenu_EnhancedIrrigation_Wind" or "ContextMenu_EnhancedIrrigation_SetTimer",
        timer = not windUp,
        start = valve.start,
        minutes = windUp and EI.Valves.minutesLeft(valve) or valve.minutes,
    }
end

-- The tap's world menu with its Garden Line submenu and, while the character carries a valve of
-- each kind, the Fit Valve submenu open; then the Timer Valve's panel once one is fitted to it.
local function addMenu()
    local carried = {}
    local lot = lots.homestead
    goTo({ at(lot, HOMESTEAD.player) }, 1)
    run:add(function()
        local inventory = getPlayer():getInventory()
        for _, fullType in ipairs(MENU_ITEMS) do
            table.insert(carried, inventory:AddItem(fullType))
        end
    end)
    Harness.addMenuShot(run, "menu_tap", function()
        local tap = homesteadTap()
        if not tap then
            return nil, "the homestead's tap"
        end
        local context = ISWorldObjectContextMenu.createMenu(0, { tap }, MENU_AT, MENU_AT)
        -- Vanilla's options for the ground under the tap (gardening, sitting, walking) say nothing
        -- of the mod.
        local gardenLine = getText("ContextMenu_EnhancedIrrigation_GardenLine")
        local others = {}
        for _, option in ipairs(context.options) do
            if option.name ~= gardenLine then
                table.insert(others, option.name)
            end
        end
        for _, name in ipairs(others) do
            context:removeOptionByName(name)
        end
        local line = Harness.openSubMenu(context, gardenLine)
        if not line then
            return nil, "Garden Line submenu on the tap"
        end
        local menus = { context, line }
        local valves = Harness.openSubMenu(line, getText("ContextMenu_EnhancedIrrigation_FitValve"))
        if valves then
            table.insert(menus, valves)
        end
        return menus
    end)
    run:add(function()
        for _, item in ipairs(carried) do
            getPlayer():getInventory():Remove(item)
        end
        local record = EI.Lines.recordOf(homesteadTap())
        EI.ValveSystem.fit(record, instanceItem(EI.Valves.TIMER))
        EI.ValveSystem.setTimer(record, TIMER_START, TIMER_MINUTES)
        record:afterChange()
    end)
    Harness.addWindowShot(run, "timer", {
        near = function()
            return homesteadTap():getSquare()
        end,
        open = function()
            local tap = homesteadTap()
            return EI.ValveUI.open(getPlayer(), function() return valvePanel(tap) end)
        end,
        close = function(panel)
            panel:destroy()
        end,
    })
    -- The poster and a rerun of the world show the tap bare, as the menu found it.
    run:add(function()
        local record = EI.Lines.recordOf(homesteadTap())
        EI.ValveSystem.takeOff(record)
        record:afterChange()
    end)
end

-- The garden close in, at the closest zoom, so that it reads where Steam shows it smallest.
local function addPoster()
    local lot = lots.homestead
    goTo({ at(lot, HOMESTEAD.scout), at(lot, HOMESTEAD.posterPlayer) }, 0)
    run:addOpaque("poster", function()
        return { Harness.squareRegion("poster", squaresAt(lot, HOMESTEAD.poster, { HOMESTEAD.posterPlayer })) }
    end)
end

-- The groups of dev/harness.conf's MODE_GROUPS_promo, and the lots each needs.
local GROUPS = {
    icons = { lots = {} },
    world = { lots = { "homestead" }, add = addWorld },
    water = { lots = { "pumps", "sprinklers", "filters" }, add = addWater },
    menu = { lots = { "homestead" }, add = addMenu },
    poster = { lots = { "homestead" }, add = addPoster },
}

-- Finds the lots `chosen` groups need, each apart from those found before it, and adds the step
-- that builds them at noon. Returns nil, or what it couldn't find.
local function prepare(chosen)
    local LineSystem = EI.LineSystem
    if not LineSystem or not SFarmingSystem or not EI.PumpSystem then
        return "the authority's systems; --promo runs in single player only"
    end
    local needs = {}
    for _, name in ipairs(chosen) do
        for _, lot in ipairs(GROUPS[name].lots) do
            needs[lot] = true
        end
    end
    local found, origins, logged = {}, {}, {}
    for _, entry in ipairs(LOTS) do
        if needs[entry.name] then
            local lot, clearance
            for _, c in ipairs(CLEARANCES) do
                lot, clearance = Stage.findLot(getPlayer(), entry.spec.w, entry.spec.h, true, found, LOT_GAP, c), c
                if lot then
                    break
                end
            end
            if not lot then
                return "open soil or grass " .. entry.spec.w .. "x" .. entry.spec.h .. " for the " .. entry.name
                    .. " within " .. Harness.SEARCH_RADIUS .. " squares"
            end
            lots[entry.name] = lot
            table.insert(found, lot)
            table.insert(origins, Stage.lotSquare(lot, 0, 0))
            table.insert(logged, string.format("%s %d,%d clear %d", entry.name, lot.x, lot.y, clearance))
        end
    end
    if #logged > 0 then
        print(MARK .. " lots " .. table.concat(logged, "; "))
    end
    Harness.addWorldSettings(run, { hour = NOON, origins = origins })
    run:add(function()
        for _, entry in ipairs(LOTS) do
            if needs[entry.name] then
                entry.build()
            end
        end
        return Capture.DRAW_FRAMES
    end)
end

--- Shoots the groups named in `selection`, which run-client.sh gives every group of
--- MODE_GROUPS_promo when PROMO names none, and calls onDone.
function Promo.capture(selection, onDone)
    run = Capture.new(MARK)
    local catalog = Capture.newCatalog({ prefer = PREFER, fluidContainers = FLUID_CONTAINERS, literature = LITERATURE })
    -- The names come with every run, since they cost no shot.
    local data = {
        items = catalog:items(ITEMS),
        recipes = catalog:recipes(),
        strings = { modName = getText("Sandbox_EnhancedIrrigation") },
    }
    local adders = {}
    for name, group in pairs(GROUPS) do
        adders[name] = group.add
    end
    adders.icons = function()
        run:addIconSheet("icons", catalog:iconList())
    end
    Harness.runGroups(run, selection, adders, prepare, data, onDone)
end

return Promo
