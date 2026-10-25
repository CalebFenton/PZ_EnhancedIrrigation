-- Development only; dev/run-debug-client.sh --art runs it instead of the tests. It checks the art
-- from art/models in the world: it stages the mod's tiles beside vanilla's on one open lot and
-- saves each shot to <cachedir>/Screenshots as <name>.png.
-- Single player only: it lays the lines through the authority's LineSystem.

require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Utilities"
local Stage = require "EnhancedIrrigationDevStage"
local Harness = require "PZHarness/Stage"
local Capture = require "PZHarness/Capture"

local Art = {}

local Sprites = EnhancedIrrigation.Sprites
local MARK = "EIArt"

local WALL_NORTH = "walls_exterior_house_01_1"
local WALL_WEST = "walls_exterior_house_01_0"
local VANILLA_BARREL = "carpentry_02_122"
local VANILLA_BARREL_FIRE = "crafted_01_26"
local VANILLA_WELL = "camping_01_16"

-- The lot, in squares east and south of its north-west corner. A column between each material's
-- dry and wet blocks is left free for the character, and the boilers stand far enough south to
-- stay out of the stands' shots.
local AREA = { w = 10, h = 29 }
-- Ground cover this far round the lot goes too, so none of it stands in front of the shots.
local MARGIN = 3
local BLOCK = { dry = 0, wet = 6 }
local WET_FIELDS = { soak = 20 }
local TAPS = { { x = 3, y = 1 }, { x = 9, y = 5 } }
-- Crops on wet line tiles, as grown as each stage says, fully watered.
local CROPS = {
    { x = 6, y = 0, seed = "Tomato", stage = 6 },
    { x = 7, y = 1, seed = "Carrots", stage = 5 },
    { x = 8, y = 10, seed = "Broccoli", stage = 4 },
}
local CROP_WATER = 100
local STAND_ROW = 18
local STANDS = { Sprites.TANK_STAND, Sprites.RAISED_BARREL, Sprites.RAISED_BARREL_CLOSED, Sprites.RAISED_BARREL_TARP,
    Sprites.RAISED_BARREL_TARP_CLOSED, VANILLA_BARREL, Sprites.BARREL_FILTER, Sprites.BRICK_FILTER, Sprites.FILTER_CROCK }
local WALLS = {
    { x = 7, y = 16, sprite = WALL_NORTH }, { x = 8, y = 16, sprite = WALL_NORTH }, { x = 9, y = 16, sprite = WALL_NORTH },
    { x = 7, y = 16, sprite = WALL_WEST }, { x = 7, y = 17, sprite = WALL_WEST },
}
local WALL_LINE = { material = "iron", tiles = { { x = 7, y = 16 }, { x = 8, y = 16 }, { x = 9, y = 16 }, { x = 7, y = 17 } } }
-- Each boiler unlit at the row's end and lit beside vanilla's barrel fire in the middle, whose
-- flames the game draws on the boilers too: they must read as the fire under the drum.
local BOILER_ROW = 22
local BOILERS = {
    { x = 2, sprite = Sprites.BOILER_STONE }, { x = 3, sprite = Sprites.BOILER_STONE, lit = true },
    { x = 4, sprite = VANILLA_BARREL_FIRE, lit = true },
    { x = 5, sprite = Sprites.BOILER_WELDED, lit = true }, { x = 6, sprite = Sprites.BOILER_WELDED },
}
-- Fuel enough that the fire burns at its full light radius through every shot: the clock's jump to
-- the night shot burns the hours it skips (IsoFireplace.update counts world hours).
local BOILER_FUEL = 48 * 60
local MIDNIGHT = 0
-- How dark the climate must have gone before a night shot: the light follows the clock on the
-- climate's next ticks, not at once.
local NIGHT_STRENGTH = 0.9
-- The pumps as plain tiles, as the shots need only their sprites, between the well and the barrel
-- they would draw from, for scale.
local PUMP_ROW = 26
local PUMPS = {
    { x = 1, sprite = VANILLA_WELL }, { x = 2, sprite = Sprites.WOODEN_HAND_PUMP }, { x = 3, sprite = Sprites.IRON_HAND_PUMP },
    { x = 4, sprite = VANILLA_BARREL }, { x = 5, sprite = Sprites.PUMP_HOUSE_WOOD }, { x = 6, sprite = Sprites.PUMP_HOUSE_METAL },
}
-- A line of three tiles each, a sprinkler on the middle one: the thinnest pipe and the widest, whose
-- fittings the sprinkler's collar must stand over.
local SPRINKLER_ROW = 28
local SPRINKLER_LINES = { { material = "plastic", x = 2 }, { material = "clay", x = 6 } }

-- Where the character stands for each shot, and how far it zooms out from the closest zoom. A
-- material's spot is in the free column below its band, where it hides none of the pipes.
local SHOTS = {}
for i, material in ipairs(Sprites.PIPE_MATERIALS) do
    table.insert(SHOTS, { name = "art_pipes_" .. material, x = 5, y = i * 4, zoomSteps = 0 })
end
for _, shot in ipairs({
    { name = "art_pipes", x = 5, y = 8, zoomSteps = 2 },
    { name = "art_lot", x = 5, y = 11, zoomSteps = 3 },
    -- Beside the crock at the row's east end, east of vanilla's barrel; on the crock's square, which
    -- a character walks over, so the crock must draw where it is in front of the character's feet;
    -- behind the row, then in front of it, diagonally in front of the bare stand, whose legs must
    -- draw behind the character.
    { name = "art_stands", x = 9, y = 18, zoomSteps = 0 },
    { name = "art_stands_mid", x = 9, y = 18, zoomSteps = 1 },
    { name = "art_stands_crock", x = 8, y = 18, zoomSteps = 0 },
    { name = "art_stands_behind", x = 2, y = 17, zoomSteps = 0 },
    { name = "art_stands_front", x = 1, y = 19, zoomSteps = 0 },
    { name = "art_wall", x = 8, y = 19, zoomSteps = 0 },
    -- East of the pumps' row, then diagonally behind the iron pump, which must hide the character's
    -- legs, then between the sprinklers' lines. Before the boilers' shots, whose last is at night.
    { name = "art_pumps", x = 8, y = PUMP_ROW, zoomSteps = 0 },
    { name = "art_pumps_behind", x = 2, y = PUMP_ROW - 1, zoomSteps = 0 },
    { name = "art_sprinklers", x = 5, y = SPRINKLER_ROW, zoomSteps = 0 },
    -- East of the boilers' row at noon, then diagonally behind the lit stone boiler, which must
    -- hide the character's legs, then east of the row again at night, by the fires' light.
    { name = "art_boilers", x = 7, y = BOILER_ROW, zoomSteps = 0 },
    { name = "art_boilers_behind", x = 2, y = BOILER_ROW - 1, zoomSteps = 0 },
    { name = "art_boilers_night", x = 7, y = BOILER_ROW, zoomSteps = 0, night = true },
}) do
    table.insert(SHOTS, shot)
end

-- The north-west corner of the closest lot that takes the whole stage, on soil or grass if one is
-- in reach.
local function findLot(player)
    for _, natural in ipairs({ true, false }) do
        local lot = Stage.findLot(player, AREA.w, AREA.h, natural)
        if lot then
            lot.natural = natural
            return lot
        end
    end
end

local lotSquare = Stage.lotSquare

local function layBlock(lot, material, left, top, fields)
    local LineSystem = EnhancedIrrigation.LineSystem
    for x = left, left + 2 do
        for y = top, top + 2 do
            LineSystem.place(lotSquare(lot, x, y), material, fields)
        end
    end
    LineSystem.place(lotSquare(lot, left + 3, top + 1), material, fields)
end

-- Builds the whole stage. Returns what was missing, or nil.
local function buildStage(lot)
    local LineSystem = EnhancedIrrigation.LineSystem
    if not LineSystem or not SFarmingSystem then
        return "the authority's systems (LineSystem, SFarmingSystem); --art runs in single player only"
    end
    Harness.removeTrees(lot.x, lot.y, lot.z)
    Stage.clearLot(lot, AREA.w, AREA.h, MARGIN)
    for _, wall in ipairs(WALLS) do
        PZHarness.Fixtures.newTile(lotSquare(lot, wall.x, wall.y), wall.sprite)
    end
    for i, material in ipairs(Sprites.PIPE_MATERIALS) do
        local top = (i - 1) * 4
        layBlock(lot, material, BLOCK.dry, top)
        layBlock(lot, material, BLOCK.wet, top, WET_FIELDS)
    end
    for _, at in ipairs(WALL_LINE.tiles) do
        LineSystem.place(lotSquare(lot, at.x, at.y), WALL_LINE.material)
    end
    for _, at in ipairs(TAPS) do
        local record = EnhancedIrrigation.Lines.recordAt(lot.x + at.x, lot.y + at.y, lot.z)
        record.tap = true
        record:afterChange()
    end
    for _, line in ipairs(SPRINKLER_LINES) do
        for x = line.x, line.x + 2 do
            LineSystem.place(lotSquare(lot, x, SPRINKLER_ROW), line.material)
        end
        -- Through the record, as Set Sprinkler sets it, which draws it as the tap is drawn.
        local record = EnhancedIrrigation.Lines.recordAt(lot.x + line.x + 1, lot.y + SPRINKLER_ROW, lot.z)
        record.sprinkler = { condition = 100, ceiling = 100 }
        record:afterChange()
    end
    for _, crop in ipairs(CROPS) do
        local missing = Stage.plant(lotSquare(lot, crop.x, crop.y), crop.seed, crop.stage, CROP_WATER)
        if missing then
            return missing
        end
    end
    for x, sprite in ipairs(STANDS) do
        local built, missing = Stage.build(lotSquare(lot, x - 1, STAND_ROW), sprite)
        if not built then
            return missing
        end
    end
    -- As a built boiler is once its OnCreate has run, and as vanilla places its barrel fire: a
    -- fireplace, whose lit flames the shots are for.
    for _, boiler in ipairs(BOILERS) do
        local fireplace = IsoFireplace.new(getCell(), lotSquare(lot, boiler.x, BOILER_ROW), getSprite(boiler.sprite))
        lotSquare(lot, boiler.x, BOILER_ROW):AddTileObject(fireplace)
        if boiler.lit then
            fireplace:setFuelAmount(BOILER_FUEL)
            fireplace:setLit(true)
        end
    end
    for _, pump in ipairs(PUMPS) do
        PZHarness.Fixtures.newTile(lotSquare(lot, pump.x, PUMP_ROW), pump.sprite)
    end
    for x = -1, AREA.w do
        for y = -1, AREA.h do
            local square = lotSquare(lot, x, y)
            if square then
                square:RecalcAllWithNeighbours(true)
            end
        end
    end
end

-- The steps that turn the clock to midnight for a night shot, walk the character to the shot's
-- spot, let it see around, zoom and save.
local function addShot(steps, player, lot, shot)
    if shot.night then
        table.insert(steps, function()
            getGameTime():setTimeOfDay(MIDNIGHT)
            return function()
                return getClimateManager():getNightStrength() >= NIGHT_STRENGTH
            end
        end)
    end
    Harness.addLookAround(steps, player, lotSquare(lot, shot.x, shot.y))
    table.insert(steps, function()
        return Harness.zoomOut(shot.zoomSteps)
    end)
    table.insert(steps, function()
        return Capture.DRAW_FRAMES
    end)
    table.insert(steps, function()
        Capture.screenshot(MARK, shot.name)
    end)
end

function Art.capture(onDone)
    local run = Capture.new(MARK)
    local player = getPlayer()
    local lot = findLot(player)
    if not lot then
        run:fail("no open lot within " .. Harness.SEARCH_RADIUS .. " squares")
        return
    end
    print(string.format("%s stage at %d,%d natural=%s", MARK, lot.x, lot.y, tostring(lot.natural)))
    -- Hides the HUD, the debug console and the character window, which the shots don't need.
    ISUIHandler.setVisibleAllUI(false)
    table.insert(run.steps, function()
        getGameTime():setTimeOfDay(12)
        local missing = buildStage(lot)
        if missing then
            run:fail(missing)
        end
    end)
    for _, shot in ipairs(SHOTS) do
        addShot(run.steps, player, lot, shot)
    end
    run:run(nil, onDone)
end

return Art
