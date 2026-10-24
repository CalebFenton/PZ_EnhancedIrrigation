-- Development only; dev/run-debug-client.sh --art runs it instead of the tests. It checks the art
-- from art/models in the world: it lays every pipe material dry and wet, a tap, crops over pipes, a
-- line along a wall, and the Tank Stand bare and with each raised barrel beside vanilla's rain
-- barrel, then the Barrel and Brick Filters, on one open lot, and saves each shot to
-- <cachedir>/Screenshots as <name>.png.
-- Single player only: it lays the lines through the authority's LineSystem.

require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Utilities"
local Stage = require "EnhancedIrrigationDevStage"
local Capture = require "PZHarness/Capture"

local Art = {}

local Sprites = EnhancedIrrigation.Sprites
local MARK = "EIArt"

local WALL_NORTH = "walls_exterior_house_01_1"
local WALL_WEST = "walls_exterior_house_01_0"
local VANILLA_BARREL = "carpentry_02_122"

-- The lot, in squares east and south of its north-west corner. Each material takes a band: a block
-- dry (corners, tees and the cross) with a tail east of its middle row (a straight and an end),
-- then the same wet, with a column between left free for the character. The stands stand in a row
-- below the bands, beside vanilla's rain barrel, and east of them a line runs round the inside of
-- a wall corner.
local AREA = { w = 10, h = 20 }
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
local STANDS = { Sprites.STAND, Sprites.RAISED_BARREL, Sprites.RAISED_BARREL_CLOSED, Sprites.RAISED_TARP_BARREL,
    Sprites.RAISED_TARP_BARREL_CLOSED, VANILLA_BARREL, Sprites.BARREL_FILTER, Sprites.BRICK_FILTER }
local WALLS = {
    { x = 7, y = 16, sprite = WALL_NORTH }, { x = 8, y = 16, sprite = WALL_NORTH }, { x = 9, y = 16, sprite = WALL_NORTH },
    { x = 7, y = 16, sprite = WALL_WEST }, { x = 7, y = 17, sprite = WALL_WEST },
}
local WALL_LINE = { material = "iron", tiles = { { x = 7, y = 16 }, { x = 8, y = 16 }, { x = 9, y = 16 }, { x = 7, y = 17 } } }

-- Where the character stands for each shot, and how far it zooms out from the closest zoom. A
-- material's spot is in the free column below its band, where it hides none of the pipes.
local SHOTS = {}
for i, material in ipairs(Sprites.PIPE_MATERIALS) do
    table.insert(SHOTS, { name = "art_pipes_" .. material, x = 5, y = i * 4, zoomSteps = 0 })
end
for _, shot in ipairs({
    { name = "art_pipes", x = 5, y = 8, zoomSteps = 2 },
    { name = "art_lot", x = 5, y = 11, zoomSteps = 3 },
    -- Beside the filters, east of vanilla's barrel, then behind the row, then in front of it,
    -- diagonally in front of the bare stand, whose legs must draw behind the character.
    { name = "art_stands", x = 8, y = 18, zoomSteps = 0 },
    { name = "art_stands_mid", x = 8, y = 18, zoomSteps = 1 },
    { name = "art_stands_behind", x = 2, y = 17, zoomSteps = 0 },
    { name = "art_stands_front", x = 1, y = 19, zoomSteps = 0 },
    { name = "art_wall", x = 8, y = 19, zoomSteps = 0 },
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
    Stage.removeTrees(lot.x, lot.y, lot.z)
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
    for x = -1, AREA.w do
        for y = -1, AREA.h do
            local square = lotSquare(lot, x, y)
            if square then
                square:RecalcAllWithNeighbours(true)
            end
        end
    end
end

-- The steps that walk the character to a shot's spot, let it see around, zoom and save.
local function addShot(steps, player, lot, shot)
    Stage.addLookAround(steps, player, lotSquare(lot, shot.x, shot.y))
    table.insert(steps, function()
        Stage.zoomOut(shot.zoomSteps)
        return Capture.zoomSettled()
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
        run:fail("no open lot within " .. Stage.SEARCH_RADIUS .. " squares")
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
