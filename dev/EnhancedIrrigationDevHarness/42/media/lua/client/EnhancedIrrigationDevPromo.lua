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
local Build = require "EnhancedIrrigation/Debug/EnhancedIrrigationDebugBuild"
local Harness = require "PZHarness/Stage"
require "PZHarness/StageLots"
local Capture = require "PZHarness/Capture"

local Promo = {}

local EI = EnhancedIrrigation
local Sprites = EI.Sprites

local NOON = 12
-- Late enough for the sky to have gone dark in any season, so that the boilers' fires read.
local NIGHT = 23
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
local FLUID_CONTAINERS = { Water = "Base.WaterBottle" }

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
    second = { 1, 3, sprite = Sprites.RAISED_BARREL_TARP },
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
-- Water in each drum, which a dry one burns through.
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
-- The lots found, by name: places (PZHarness/StageLots.lua) whose positions are (east, south)
-- squares from their north-west corner.
local lots = {}

-- Building ---------------------------------------------------------------------------------------

-- Logs what the staging couldn't do; the shot goes on without it, and the eye catches the gap.
local function report(what)
    print(run.mark .. " no " .. what)
end

-- The tile `sprite` built at `position` of `lot` as the build menu builds it, `full` of water if
-- asked.
local function build(lot, position, sprite, full)
    local object, missing = Build.tile(Harness.at(lot, position), sprite, full and Build.FULL)
    if not object then
        report(missing)
    end
    return object
end

local function plant(lot, x, y, seed)
    local missing = Stage.plant(Harness.lotSquare(lot, x, y), seed, CROP_STAGE[seed], Stage.WATERED)
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

local function buildHomestead(lot)
    local spec = lot.spec
    Harness.clearLotForShots(lot, MARGIN)
    local tank = build(lot, spec.tank, spec.tank.sprite, true)
    local second = build(lot, spec.second, spec.second.sprite, true)
    if tank and second then
        plumb(tank:getSquare(), second:getSquare())
    end
    build(lot, spec.filter, spec.filter.sprite)
    local LineSystem = EI.LineSystem
    LineSystem.place(Harness.at(lot, spec.tap), spec.material, { tap = true })
    for _, position in ipairs(spec.branch) do
        LineSystem.place(Harness.at(lot, position), spec.material)
    end
    for _, bed in ipairs(spec.beds) do
        for x = bed.from, bed.to do
            LineSystem.place(Harness.lotSquare(lot, x, bed.y), spec.material, { holed = true, soak = HOMESTEAD_SOAK })
            plant(lot, x, bed.y, bed.seed)
        end
    end
    -- The tap run a while, as its job runs it, so that the line is full and its holes show wet.
    local tap = EI.Lines.lineAt(lot.x + spec.tap[1], lot.y + spec.tap[2], lot.z)
    local stopped = tap and EI.TapSystem.run(tap, HOMESTEAD_RUN_HOURS)
    if not tap or stopped then
        report("water from the homestead's tap: " .. tostring(stopped))
    end
    Harness.recalcLot(lot)
end

local function buildPumps(lot)
    local spec = lot.spec
    Harness.clearLotForShots(lot, MARGIN)
    Harness.placeTile(Harness.at(lot, spec.well), Stage.VANILLA_WELL)
    placePump(lot, spec.wooden, Sprites.WOODEN_HAND_PUMP)
    placePump(lot, spec.iron, Sprites.IRON_HAND_PUMP)
    local barrel = build(lot, spec.barrel, Sprites.RAISED_BARREL)
    local house, record = placePump(lot, spec.house, Sprites.PUMP_HOUSE_METAL)
    local generatorSquare = Harness.at(lot, spec.generator)
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
    Harness.recalcLot(lot)
end

local function buildSprinklers(lot)
    local spec = lot.spec
    Harness.clearLotForShots(lot, MARGIN)
    Harness.placeTile(Harness.at(lot, spec.well), Stage.VANILLA_WELL)
    local pump = placePump(lot, spec.pump, Sprites.IRON_HAND_PUMP)
    local LineSystem = EI.LineSystem
    local isSprinkler = {}
    for _, x in ipairs(spec.sprinklers) do
        isSprinkler[x] = true
    end
    for x = spec.line.from, spec.line.to do
        LineSystem.place(Harness.lotSquare(lot, x, spec.line.y), spec.material, {
            soak = SPRINKLER_SOAK,
            sprinkler = isSprinkler[x] and Stage.newSprinkler() or nil,
        })
    end
    for _, bed in ipairs(spec.beds) do
        for x = spec.line.from, spec.line.to do
            plant(lot, x, bed.y, bed.seed)
        end
    end
    if pump then
        plumb(pump:getSquare(), Harness.lotSquare(lot, spec.line.from, spec.line.y), "pump")
        local stopped = EI.PumpSystem.run(getPlayer(), pump, spec.pumpHours)
        if stopped then
            report("water from the sprinklers' pump: " .. tostring(stopped))
        end
    end
    Harness.recalcLot(lot)
end

-- As a built unit is once its OnCreate has run: a boiler a fireplace carrying its entity.
local function buildFilters(lot)
    Harness.clearLotForShots(lot, MARGIN)
    for _, unit in ipairs(lot.spec.units) do
        local built = build(lot, unit, unit.sprite)
        local created = built and EI.TreatmentSystem.onCreate({ thumpable = built })
        local object = created and created.object or built
        local record = object and EI.Treatment.recordOf(object)
        if record then
            record.head = unit.lit and BOILER_HEAD or FILTER_HEAD[unit.sprite]
            if unit.lit then
                object:setFuelAmount(Stage.BOILER_FUEL)
                object:turnOn()
                record:update()
            end
            record:sendSummary()
        elseif built then
            report("record for the unit " .. unit.sprite)
        end
    end
    Harness.recalcLot(lot)
end

-- What builds each lot.
local BUILDS = { homestead = buildHomestead, pumps = buildPumps, sprinklers = buildSprinklers, filters = buildFilters }

-- A lot `spec` as a PZHarness.Stage.findPlaces spec: the closest open soil or grass, LOT_GAP from
-- the lots found before it, as clear around as it can be (CLEARANCES).
local function lotSpec(name, spec)
    return {
        name = name,
        label = name,
        missing = "open soil or grass " .. spec.w .. "x" .. spec.h .. " for the " .. name,
        find = function(player, found)
            for _, clearance in ipairs(CLEARANCES) do
                local lot = Harness.findLot(player, spec.w, spec.h,
                    { floor = Harness.NATURAL_FLOOR, trees = true, others = found, gap = LOT_GAP, clearance = clearance })
                if lot then
                    lot.spec, lot.clearance = spec, clearance
                    return lot
                end
            end
            return nil
        end,
        detail = function(lot)
            return " clear " .. lot.clearance
        end,
    }
end

-- The lots, in the order they are looked for.
local LOTS = { lotSpec("homestead", HOMESTEAD), lotSpec("pumps", PUMPS), lotSpec("sprinklers", SPRINKLERS),
    lotSpec("filters", FILTERS) }

-- Shots ------------------------------------------------------------------------------------------

local function goToLot(name, stepsOut)
    local lot = lots[name]
    Harness.addGoTo(run, getPlayer(), { Harness.at(lot, lot.spec.scout), Harness.at(lot, lot.spec.player) }, stepsOut)
end

local function addWorld()
    goToLot("homestead", 1)
    run:addOpaque("homestead", function()
        return { Harness.centred("homestead", Harness.lotSquares(lots.homestead)) }
    end)
    -- The banner, a step further out, has its title over the left half: the barrels, the tap and
    -- the near end of the beds stand against its right edge, the beds running on past it.
    Harness.addGoTo(run, getPlayer(), { Harness.at(lots.homestead, HOMESTEAD.bannerPlayer) }, 2)
    run:addOpaque("banner", function()
        return { Harness.rightAligned("banner", Harness.squaresAt(lots.homestead, HOMESTEAD.banner)) }
    end)
end

local function addWater()
    goToLot("pumps", 0)
    run:addOpaque("pumps", function()
        return { Harness.centred("pumps", Harness.lotSquares(lots.pumps)) }
    end)
    goToLot("sprinklers", 1)
    run:addOpaque("sprinklers", function()
        return { Harness.centred("sprinklers", Harness.lotSquares(lots.sprinklers)) }
    end)
    Harness.addHour(run, NIGHT)
    goToLot("filters", 0)
    run:addOpaque("filters", function()
        return { Harness.centred("filters", Harness.lotSquares(lots.filters)) }
    end)
    Harness.addHour(run, NOON)
end

-- The homestead's tap tile.
local function homesteadTap()
    local lot = lots.homestead
    return EI.Lines.lineAt(lot.x + HOMESTEAD.tap[1], lot.y + HOMESTEAD.tap[2], lot.z)
end

-- The tap's world menu with its Garden Line submenu and, while the character carries a valve of
-- each kind, the Fit Valve submenu open; then the Timer Valve's panel once one is fitted to it.
local function addMenu()
    local carried = {}
    local lot = lots.homestead
    Harness.addGoTo(run, getPlayer(), { Harness.at(lot, HOMESTEAD.player) }, 1)
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
        -- The panel LineMenu opens for the Timer Valve fitted above.
        open = function()
            local tap = homesteadTap()
            return EI.ValveUI.open(getPlayer(), function() return EI.LineMenu.valvePanel(tap) end)
        end,
        close = function(panel)
            panel:close()
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
    Harness.addGoTo(run, getPlayer(), { Harness.at(lot, HOMESTEAD.scout), Harness.at(lot, HOMESTEAD.posterPlayer) }, 0)
    run:addOpaque("poster", function()
        return { Harness.squareRegion("poster", Harness.squaresAt(lot, HOMESTEAD.poster, { HOMESTEAD.posterPlayer })) }
    end)
end

-- The groups of dev/harness.conf's MODE_GROUPS_promo but the harness's `icons`, and the lots each
-- needs.
local GROUPS = {
    world = { places = { "homestead" }, add = addWorld },
    water = { places = { "pumps", "sprinklers", "filters" }, add = addWater },
    menu = { places = { "homestead" }, add = addMenu },
    poster = { places = { "homestead" }, add = addPoster },
}

-- Adds the step that builds the lots found, `found` by name, at noon. Returns nil, or what it
-- needs and hasn't.
local function prepare(_, found, origins)
    if not EI.LineSystem or not SFarmingSystem or not EI.PumpSystem then
        return "the authority's systems; --promo runs in single player only"
    end
    lots = found
    Harness.addWorldSettings(run, { hour = NOON, origins = origins })
    run:add(function()
        for _, entry in ipairs(LOTS) do
            local lot = lots[entry.name]
            if lot then
                BUILDS[entry.name](lot)
            end
        end
        return Capture.DRAW_FRAMES
    end)
end

--- Shoots the groups named in `selection`, which run-client.sh gives every group of
--- MODE_GROUPS_promo when PROMO names none, and calls onDone.
function Promo.capture(selection, onDone)
    run = Capture.new()
    Harness.runGroups(run, selection, {
        groups = GROUPS,
        places = LOTS,
        catalog = Capture.newCatalog({ fluidContainers = FLUID_CONTAINERS }),
        items = ITEMS,
        data = { strings = { modName = getText("Sandbox_EnhancedIrrigation") } },
        prepare = prepare,
    }, onDone)
end

return Promo
