require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibLines"
require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibPumps"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/Parts"
require "EnhancedIrrigation/UI/PlantInfo"

-- Lines run for set hours on the server by what runs them there (pumps.run, lines.age and
-- lines.flow), so the clock doesn't decide the sums.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Lines, LineJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.LineJobs
local Pumps, Sprinklers, PlantInfo = EnhancedIrrigation.Pumps, EnhancedIrrigation.Sprinklers, EnhancedIrrigation.PlantInfo
local Parts = EnhancedIrrigation.Parts

-- A sprinkler as a new one goes on.
local NEW = { condition = 100, ceiling = 100 }
-- How many squares a sprinkler waters.
local SQUARES = (2 * Sprinklers.ALONG + 1) * (2 * Sprinklers.ACROSS + 1)
-- The plant info's soil word for waterlogged soil.
local WATERLOGGED = "IGUI_EnhancedIrrigation_Waterlogged"

-- Helpers -------------------------------------------------------------------------------------------

-- What the tests' iron hand pump is placed with: a leather seal.
local SEALED = { fields = { seal = T.LEATHER } }

-- Each square's change from `before` to `after` (the handlers' squares): water, soak and health.
local function changes(before, after)
    local list = {}
    for i, square in ipairs(after) do
        list[i] = { water = (square.water or 0) - (before[i].water or 0), soak = square.soak - before[i].soak,
            health = (square.health or 0) - (before[i].health or 0) }
    end
    return list
end

-- The plant points a sprinkler throws on each of its squares over `hours` from a pumped line that
-- gives it `litresPerHour`.
local function sprayed(litresPerHour, hours)
    return litresPerHour * hours * (1 - Sprinklers.LOST) * Lines.POINTS_PER_LITRE / SQUARES
end

-- Watering ------------------------------------------------------------------------------------------

-- The rectangle of a sprinkler on a line running north to south, with a crop on every square of it
-- and on the four squares just past its sides and ends: across, where an east-to-west rectangle
-- would reach, and along, a step past its ends.
local NORTH_SOUTH = {}
for dx = -Sprinklers.ACROSS, Sprinklers.ACROSS do
    for dy = -Sprinklers.ALONG, Sprinklers.ALONG do
        table.insert(NORTH_SOUTH, { dx, dy })
    end
end
local INSIDE = #NORTH_SOUTH
for _, offset in ipairs({ { -Sprinklers.ALONG, 0 }, { Sprinklers.ALONG, 0 }, { 0, -Sprinklers.ALONG - 1 },
    { 0, Sprinklers.ALONG + 1 } }) do
    table.insert(NORTH_SOUTH, offset)
end

-- The index in NORTH_SOUTH of the offset dx, dy.
local function indexOf(dx, dy)
    for i, offset in ipairs(NORTH_SOUTH) do
        if offset[1] == dx and offset[2] == dy then
            return i
        end
    end
    return nil
end

-- Hours the second run soaks the rectangle for: past full, so every square waterlogs, a dry crop
-- filling and then its soil soaking.
local SOAK_HOURS = 3
-- Hours the soaked rectangle is left after, while its roots rot.
local ROT_HOURS = 2

-- A sprinkler in the middle of a three-tile line running north to south, driven by an iron hand
-- pump, which lifts more than the sprinkler asks: a minute's work waters every crop of the
-- rectangle along the line the same, at the sprinkler's rate less what the air takes, and
-- none past it, and wears the seal by what the line took. Left on, it fills every crop and
-- waterlogs the soil, on the line's tiles and off them, which the plant info says of a crop off the
-- line; left a while, that crop's roots rot and its soil dries as a line tile's do. Catches a
-- sprinkler that waters off its rectangle or turned across the line, a pump that lifts more than
-- its line takes, soak lost off the line, or soil that never dries or rots.
T.test("irrigation_sprinklers_water_their_rectangle_and_waterlog_it", {
    instant = true,
    run = function(self)
        if not T.need(self, Pumps.ENTITIES[T.IRON].rate * 60 > Sprinklers.RATE,
            "an iron hand pump that lifts more than a sprinkler asks") then return end
        local squares = T.layout(self, NORTH_SOUTH, { joined = true })
        if not squares then return end
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 } }, { bare = true })
        if not spots then return end
        local north, middle, south = squares[indexOf(0, -1)], squares[indexOf(0, 0)], squares[indexOf(0, 1)]
        middle.fields = { sprinkler = NEW }
        T.placeLine(self, { north, middle, south }, "iron")
        self.pump = T.plumbedPump(self, spots, T.IRON, SEALED, { into = north })
        T.plant(self, squares, 0)
        T.runPump(self, self.pump, "minute", { T.MINUTE }, { squares = squares })
        T.runPump(self, self.pump, "soaked", { SOAK_HOURS }, { squares = squares })
        self.offLine, self.past = squares[indexOf(1, 0)], squares[indexOf(Sprinklers.ALONG, 0)]
        T.waitFor(self, function()
            local plant = CFarmingSystem.instance:getLuaObjectOnSquare(self.offLine.square)
            return plant ~= nil and PlantInfo.soilKeyOf(plant) == WATERLOGGED
        end, "this client's plant info naming the crop off the line waterlogged")
        T.step(function()
            local plant = CFarmingSystem.instance:getLuaObjectOnSquare(self.past.square)
            self.pastKey = plant and PlantInfo.soilKeyOf(plant)
        end)
        T.read(self, "lines.age", { tiles = { T.at(middle) }, hours = ROT_HOURS, squares = { T.at(self.offLine) } },
            "rotted")
    end,
    validate = function(self)
        local minute = self.reads.minute
        local each = sprayed(Sprinklers.RATE, T.MINUTE)
        for i, change in ipairs(changes(minute.before.squares, minute.steps[1].squares)) do
            local offset = NORTH_SOUTH[i][1] .. "," .. NORTH_SOUTH[i][2]
            expectNear("the crop at " .. offset .. " after a minute", change.water, i <= INSIDE and each or 0, T.POINTS)
        end
        expectNear("the seal's wear after a minute", minute.steps[1].record.sealWear - minute.before.record.sealWear,
            Sprinklers.RATE * T.MINUTE, T.LITRES)
        local soaked = self.reads.soaked
        for i, square in ipairs(soaked.steps[1].squares) do
            local offset = NORTH_SOUTH[i][1] .. "," .. NORTH_SOUTH[i][2]
            local inside = i <= INSIDE
            expectNear("the crop at " .. offset .. " left on", square.water, inside and Lines.PLANT_FULL or 0, T.POINTS)
            expectNear("the soak at " .. offset .. " left on", square.soak, inside and Lines.SOAK_MAX or 0, T.POINTS)
        end
        expect(self.pastKey == nil, "the plant info names the soil past the rectangle " .. tostring(self.pastKey))
        local rotted = self.reads.rotted
        local change = changes(rotted.squares.before, rotted.squares.after)[1]
        expectNear("the health of the waterlogged crop off the line", change.health, -Lines.ROOT_ROT_PER_HOUR * ROT_HOURS, T.POINTS)
        expectNear("the soak off the line after it was left", change.soak, -Lines.SOAK_DRY_OUT / 24 * ROT_HOURS, T.POINTS)
    end,
})

-- Two sprinklers on one line whose rectangles overlap keep one soak of a square off the line they
-- share: each soaks it as far as soil holds, and left waterlogged its crop's roots rot and its soil
-- dries as under a line tile, not twice as fast. Catches each sprinkler keeping a soak of its own.
T.test("irrigation_sprinklers_overlapping_keep_one_soak", {
    instant = true,
    run = function(self)
        -- A line west to east, a sprinkler on its second and fourth tiles; the crop beside the middle
        -- tile, in both rectangles.
        local squares = T.layout(self, { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 4, 0 }, { 2, 1 } }, { joined = true })
        if not squares then return end
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 } }, { bare = true })
        if not spots then return end
        local line, crop = { squares[1], squares[2], squares[3], squares[4], squares[5] }, squares[6]
        line[2].fields = { sprinkler = NEW }
        line[4].fields = { sprinkler = NEW }
        T.placeLine(self, line, "iron")
        self.pump = T.plumbedPump(self, spots, T.IRON, SEALED, { into = line[1] })
        -- Full already, so all each sprinkler throws on it soaks the soil.
        T.plant(self, { crop }, Lines.PLANT_FULL)
        T.runPump(self, self.pump, "soaked", { SOAK_HOURS })
        T.read(self, "lines.age", { tiles = { T.at(line[2]), T.at(line[4]) }, hours = ROT_HOURS,
            squares = { T.at(crop) } }, "rotted")
    end,
    validate = function(self)
        local rotted = self.reads.rotted
        expectNear("the shared square's soak", rotted.squares.before[1].soak, Lines.SOAK_MAX, T.POINTS)
        local change = changes(rotted.squares.before, rotted.squares.after)[1]
        expectNear("the health of the waterlogged crop both water", change.health, -Lines.ROOT_ROT_PER_HOUR * ROT_HOURS,
            T.POINTS)
        expectNear("the shared square's soak after it was left", change.soak, -Lines.SOAK_DRY_OUT / 24 * ROT_HOURS, T.POINTS)
    end,
})

-- A sprinkler on a line a raised barrel taps does nothing: an hour at the tap waters the crop on
-- the holed tap tile and draws its hole's water, and none of the crops around the sprinkler, which
-- a storey of head can't turn. Catches a sprinkler that runs on gravity.
T.test("irrigation_sprinklers_do_nothing_on_a_tapped_line", {
    instant = true,
    run = function(self)
        -- The line west to east, the sprinkler in the middle; crops on the tap tile and around it.
        local squares = T.layout(self, { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, -1 }, { 1, 1 }, { 3, 0 }, { -1, 0 } },
            { joined = true })
        if not squares then return end
        local tap, middle = squares[1], squares[2]
        T.placeTank(self, tap, "above", 100)
        tap.fields = T.tapped({ holed = true })
        middle.fields = { sprinkler = NEW }
        T.placeLine(self, { tap, middle, squares[3] }, "iron")
        local crops = { tap, squares[4], squares[5], squares[6], squares[7] }
        T.plant(self, crops, 0)
        T.read(self, "lines.flow", T.at(tap, { hours = 1, squares = T.tiles(crops) }), "hour")
    end,
    validate = function(self)
        local hour = self.reads.hour
        expect(hour.stopped == nil, "the tap stopped: " .. tostring(hour.stopped))
        local changed = changes(hour.squares.before, hour.squares.after)
        expectNear("the crop on the holed tap tile", changed[1].water, Lines.HOLE_RATE * Lines.POINTS_PER_LITRE, T.POINTS)
        for i = 2, #changed do
            expectNear("crop " .. i .. " by the sprinkler", changed[i].water, 0, T.POINTS)
            expectNear("the soak under crop " .. i .. " by the sprinkler", changed[i].soak, 0, T.POINTS)
        end
        expectNear("the barrel's water drawn", hour.drawn, Lines.HOLE_RATE, T.LITRES)
    end,
})

-- Setting and taking --------------------------------------------------------------------------------

-- A sprinkler made from pipe, worn: its condition and the ceiling its item carries.
local WORN = { condition = 70, ceiling = Sprinklers.MADE_CEILING }

-- Set Sprinkler is greyed out on the tap's tile and, carrying none, on the next; carrying a worn
-- one and a pipe wrench, it sets it there as it is, drawn over the pipe on both sides, and Fit Tap
-- is then refused there. Take Sprinkler gives it back as it went on, ceiling and all, and the tile
-- draws bare. Catches a sprinkler sharing the tap's tile, a sprinkler made new or lost, or one
-- left drawn.
T.test("irrigation_sprinklers_set_and_take_keep_condition", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 2)
        if not rows then return end
        local tap, tile = rows[1][1], rows[1][2]
        tap.fields = T.tapped()
        T.placeLine(self, { tap, tile }, "iron")
        T.give(self, "wrench", { { type = "Base.PipeWrench" } })
        T.goNextTo(self, tile.square)
        T.useLineJob(self, tap, LineJobs.SET_SPRINKLER, "on the tap", false)
        T.useLineJob(self, tile, LineJobs.SET_SPRINKLER, "carrying none", false)
        T.give(self, "sprinkler", { { type = Sprinklers.ITEM, condition = WORN.condition,
            modData = { [Parts.CEILING_KEY] = WORN.ceiling } } })
        T.useLineJob(self, tile, LineJobs.SET_SPRINKLER, "set", true)
        T.readUntil(self, "lines.read", { tiles = { T.at(tile) } }, "set", function(reply)
            return reply.tiles[1].record.sprinkler ~= nil
        end)
        T.waitFor(self, function() return T.hasOverlay(T.overlaysOf(T.lineObject(tile)), Sprites.SPRINKLER) end,
            "this client's copy of the sprinkler")
        T.useLineJob(self, tile, LineJobs.TAP, "tap on it", false)
        T.useLineJob(self, tile, LineJobs.TAKE_SPRINKLER, "take", true)
        T.readUntil(self, "lines.read", { tiles = { T.at(tile) } }, "taken", function(reply)
            return reply.tiles[1].record.sprinkler == nil
        end)
        T.waitFor(self, function() return not T.hasOverlay(T.overlaysOf(T.lineObject(tile)), Sprites.SPRINKLER) end,
            "this client's copy of the bare tile")
        T.readCarried(self, { Sprinklers.ITEM })
    end,
    validate = function(self)
        T.expectOptionRefused(self, "on the tap", "Tooltip_EnhancedIrrigation_TapAndSprinkler")
        T.expectOptionRefused(self, "carrying none", "Tooltip_EnhancedIrrigation_NoSprinkler")
        T.expectOffered(self, "set")
        local set = self.reads.set.tiles[1]
        local sprinkler = set.record.sprinkler
        expect(sprinkler and sprinkler.condition == WORN.condition and sprinkler.ceiling == WORN.ceiling,
            "the sprinkler went on at " .. tostring(sprinkler and sprinkler.condition) .. " of "
            .. tostring(sprinkler and sprinkler.ceiling))
        expect(T.hasOverlay(set.overlays, Sprites.SPRINKLER), "the server doesn't draw the sprinkler")
        T.expectOptionRefused(self, "tap on it", "Tooltip_EnhancedIrrigation_TapAndSprinkler")
        T.expectOffered(self, "take")
        local taken = self.reads.taken.tiles[1].record
        expect(taken.sprinkler == nil, "the tile's record still keeps the sprinkler it gave back")
        local items = T.carriedItems(self, Sprinklers.ITEM)
        local ceiling = T.ceilingOf(items[1])
        expect(#items == 1 and items[1].condition == WORN.condition and ceiling == WORN.ceiling,
            "Take Sprinkler gave " .. #items .. " sprinklers" .. (items[1] and " at " .. items[1].condition .. " of "
            .. ceiling or ""))
    end,
})

-- The plant info's soil word at `handle`'s crop as this client knows it, or nil.
local function soilKey(handle)
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(handle.square)
    return plant and PlantInfo.soilKeyOf(plant)
end

-- Soil a sprinkler waterlogged off the line rots the roots for as long as it stays so, so the plant
-- info keeps naming it waterlogged once a tile laid beside the sprinkler turns its rectangle away
-- from the crop, and once the sprinkler is taken. The crop the same distance the other way along
-- the line starts dry and takes all it is thrown, so its soil stays dry. Catches a soil word read
-- only from a sprinkler watering the square now, or read from the square mirrored across the
-- sprinkler.
T.test("irrigation_sprinklers_soil_word_outlasts_the_sprinkler", {
    instant = true,
    run = function(self)
        -- A line north to south, the sprinkler in the middle; the crop past the north tile, which
        -- only a rectangle along the line reaches, and its mirror past the south tile; and the
        -- square west of the middle, whose tile makes the middle a branch, whose rectangle runs
        -- east to west.
        local squares = T.layout(self, { { 0, -1 }, { 0, 0 }, { 0, 1 }, { 0, -Sprinklers.ALONG }, { -1, 0 },
            { 0, Sprinklers.ALONG } }, { joined = true })
        if not squares then return end
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 } }, { bare = true })
        if not spots then return end
        local north, middle, south, crop, west, mirror = squares[1], squares[2], squares[3], squares[4], squares[5],
            squares[6]
        middle.fields = { sprinkler = NEW }
        T.placeLine(self, { north, middle, south }, "iron")
        self.pump = T.plumbedPump(self, spots, T.IRON, SEALED, { into = north })
        -- The full crop's soil takes all it is thrown and the dry one none; points halfway between
        -- waterlogging the one and filling the other.
        T.plant(self, { crop }, Lines.PLANT_FULL)
        T.plant(self, { mirror }, 0)
        local hours = (Lines.WATERLOGGED + Lines.PLANT_FULL) / 2 / sprayed(Sprinklers.RATE, 1)
        T.runPump(self, self.pump, "soaked", { hours })
        T.waitFor(self, function() return soilKey(crop) == WATERLOGGED end,
            "this client's plant info naming the crop waterlogged")
        T.step(function() self.mirrored = soilKey(mirror) end)
        T.placeLine(self, { west }, "iron")
        T.step(function() self.turned = soilKey(crop) end)
        T.give(self, "wrench", { { type = "Base.PipeWrench" } })
        T.goNextTo(self, middle.square)
        T.useLineJob(self, middle, LineJobs.TAKE_SPRINKLER, "take", true)
        T.waitForLines(self, { middle }, "this client's copy of the tile without its sprinkler", function(summary)
            return not summary.sprinkler
        end)
        T.step(function() self.taken = soilKey(crop) end)
    end,
    validate = function(self)
        expect(self.mirrored == nil, "the soil word of the dry crop across the sprinkler: " .. tostring(self.mirrored))
        expect(self.turned == WATERLOGGED, "the soil word once the rectangle turned away: " .. tostring(self.turned))
        T.expectOffered(self, "take")
        expect(self.taken == WATERLOGGED, "the soil word once the sprinkler was taken: " .. tostring(self.taken))
    end,
})

-- Making --------------------------------------------------------------------------------------------

-- Make Pipe Sprinkler from an iron pipe, in hand, with the skill, the knowledge and exactly a
-- craft's inputs, makes one Lawn Sprinkler at the made ceiling (its OnCreate). Catches a recipe the
-- game won't craft, or a made sprinkler as good as a found one.
T.test("irrigation_sprinklers_make_pipe_sprinkler", {
    instant = true,
    run = function(self)
        if not T.craft(self, "EnhancedIrrigation_MakePipeSprinkler", "Base.MetalPipe", { Sprinklers.ITEM },
            { prefer = { "Base.Pliers" } }) then
            return
        end
        T.readCarried(self, { Sprinklers.ITEM }, nil, "made")
    end,
    validate = function(self)
        local craft = self.counts.craft or {}
        expect(craft[Sprinklers.ITEM] == 1, "the craft made " .. tostring(craft[Sprinklers.ITEM]) .. " sprinklers")
        local made = T.carriedFirst(self, Sprinklers.ITEM, "made")
        local ceiling = T.ceilingOf(made)
        expect(made and made.condition == Sprinklers.MADE_CEILING and ceiling == Sprinklers.MADE_CEILING,
            "the made sprinkler is at " .. tostring(made and made.condition) .. " of " .. tostring(ceiling))
    end,
})
