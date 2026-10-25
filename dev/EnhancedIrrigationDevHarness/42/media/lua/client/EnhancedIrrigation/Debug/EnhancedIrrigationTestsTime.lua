require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibLines"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Frost"

-- What the hours do to a line record: the soil's soak drying, waterlogged roots rotting and frost
-- splitting full pipe, loaded or not. The hours are run on the server, each record as though they
-- had passed since its last pass, so the clock doesn't decide them.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Lines, Frost = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.Frost

-- How long the root rot test's soil stays waterlogged as it dries; the test ages it twice that.
local LOGGED_HOURS = 6

-- Soak dries faster outdoors than in, at each side's rate, and the tile's soil stops showing wet
-- once it has. Catches the rates swapped, or a dry tile still drawn wet.
T.test("irrigation_time_soak_dries", {
    run = function(self)
        local outdoor = T.row(self, 1)
        local indoor = T.row(self, 1, { indoors = true })
        if not (outdoor and indoor) then return end
        self.tiles = { outdoor[1][1], indoor[1][1] }
        self.start = Lines.SOAK_DRY_OUT
        for _, tile in ipairs(self.tiles) do
            tile.fields = { soak = self.start }
        end
        T.placeLine(self, self.tiles, "plastic")
        T.waitFor(self, function() return T.lineSprite(self.tiles[1]) == Sprites.pipe("plastic", true, 0) end,
            "this client's copy of the soaked tile, wet")
        T.batch(function()
            T.read(self, "lines.age", { tiles = T.tiles(self.tiles), hours = 12 }, "half")
            T.read(self, "lines.age", { tiles = T.tiles(self.tiles), hours = 12 }, "day")
        end)
        T.waitFor(self, function() return T.lineSprite(self.tiles[1]) == Sprites.pipe("plastic", false, 0) end,
            "this client's copy of the dried tile, dry")
    end,
    validate = function(self)
        local half, day = self.reads.half.tiles, self.reads.day.tiles
        local function after(days, rate)
            return math.max(0, self.start - days * rate)
        end
        expectNear("the outdoor soak after half a day", half[1].record.soak, after(0.5, Lines.SOAK_DRY_OUT), T.POINTS)
        expectNear("the indoor soak after half a day", half[2].record.soak, after(0.5, Lines.SOAK_DRY_IN), T.POINTS)
        expectNear("the outdoor soak after a day", day[1].record.soak, after(1, Lines.SOAK_DRY_OUT), T.POINTS)
        expectNear("the indoor soak after a day", day[2].record.soak, after(1, Lines.SOAK_DRY_IN), T.POINTS)
        expect(not day[1].record.wet, "the dry tile is still wet")
        expect(day[1].sprite == Sprites.pipe("plastic", false, 0), "the server still shows the dried tile wet")
    end,
})

-- A crop's roots rot for the hours its soil stays waterlogged as it dries through the threshold, not
-- the whole pass, costing it health at the rot's rate. Catches rot counted for the whole pass.
T.test("irrigation_time_waterlogged_roots_rot", {
    run = function(self)
        local rows = T.row(self, 1, { indoors = true })
        if not rows then return end
        local logged = rows[1][1]
        self.tiles = { logged }
        self.dryPerHour = Lines.SOAK_DRY_IN / 24
        logged.fields = { soak = Lines.WATERLOGGED + LOGGED_HOURS * self.dryPerHour }
        T.placeLine(self, self.tiles, "iron")
        T.plant(self, { logged }, Lines.PLANT_FULL / 2)
        T.read(self, "lines.age", { tiles = T.tiles(self.tiles), hours = 2 * LOGGED_HOURS }, "aged")
    end,
    validate = function(self)
        local before, after = self.reads.aged.before, self.reads.aged.tiles
        expectNear("the soak, dried past the threshold", after[1].record.soak,
            before[1].record.soak - 2 * LOGGED_HOURS * self.dryPerHour, T.POINTS)
        -- From where the soak stood when read, not where it was placed.
        local logged = math.max(0, (before[1].record.soak - Lines.WATERLOGGED) / self.dryPerHour)
        expectNear("the health the crop whose soil dried through the threshold lost",
            before[1].plant.health - after[1].plant.health, logged * Lines.ROOT_ROT_PER_HOUR, T.POINTS)
    end,
})

-- A hard freeze may split a full pipe and leaves an empty one whole; a frost short of a hard freeze
-- splits nothing. Each tile is aged on its own roll, pinned to a sure split, so only the cold and
-- the water decide. Catches the threshold back at freezing, or an empty pipe that splits.
T.test("irrigation_time_frost_cracks_full_lines", {
    run = function(self)
        local rows = T.row(self, 4)
        if not rows then return end
        local full, empty, mild, beside = rows[1][1], rows[1][2], rows[1][3], rows[1][4]
        self.full = full
        full.fields = { full = true }
        empty.fields = { full = false }
        -- Filled from its tap only once the air is above a hard freeze, so no hard freeze can reach
        -- it before.
        mild.fields = T.tapped({ full = false })
        -- Beside the line, not over it: a floor above would roof it.
        T.placeTank(self, beside, "raised", T.TANK_LITRES)
        T.placeLine(self, { full, empty, mild }, "clay")
        T.batch(function()
            T.server(self, "lines.temperature", { celsius = Frost.HARD_FREEZE_CELSIUS - 1 })
            T.server(self, "lines.pinRoll", {})
            T.read(self, "lines.age", { tiles = T.tiles({ full }), hours = 1 }, "frozen")
            T.server(self, "lines.pinRoll", {})
            T.read(self, "lines.age", { tiles = T.tiles({ empty }), hours = 1 }, "frozen empty")
            -- Below freezing, short of a hard freeze.
            T.server(self, "lines.temperature", { celsius = Frost.HARD_FREEZE_CELSIUS / 2 })
            T.flow(self, mild, 1, {}, "filled")
            T.server(self, "lines.pinRoll", {})
            T.read(self, "lines.age", { tiles = T.tiles({ mild }), hours = 1 }, "mild")
        end)
        T.waitForLines(self, { full }, "this client's summary of the split pipe", function(summary) return summary.cracked end)
    end,
    validate = function(self)
        local frozen, empty, mild = self.reads.frozen.tiles, self.reads["frozen empty"].tiles, self.reads.mild
        expect(frozen[1].record.cracked, "a full pipe came through a hard freeze whole")
        local summary = T.lineSummary(self.full)
        expect(summary and summary.cracked, "this client's summary of the split pipe isn't cracked")
        expect(not empty[1].record.full and not empty[1].record.cracked, "an empty pipe split in a hard freeze")
        expect(mild.before[1].record.full, "the tap's hour didn't fill the pipe before the frost")
        expect(not mild.tiles[1].record.cracked, "a full pipe split in a frost short of a hard freeze")
    end,
})

-- A line runs on while its chunk is unloaded: a soaked tile dries for the hours away, as outdoors,
-- and its full pipe splits in a hard freeze, which both sides show once the chunk loads again. The
-- tap tile is holed, so an hour's flow fills the line and soaks the soil under it; the hours away
-- are those that leave it just short of damp, so it loads dry. Catches a record that stops while
-- unloaded, or a tile that loads showing what it was before.
T.test("irrigation_time_lines_dry_and_freeze_while_unloaded", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves",
    timeoutSeconds = T.RELOAD_SECONDS,
    run = function(self)
        local rows = T.row(self, 2)
        if not rows then return end
        local tile, beside = rows[1][1], rows[1][2]
        self.tile = tile
        -- Beside the tile, not over it: a floor above would roof it.
        T.placeTank(self, beside, "raised", T.TANK_LITRES)
        tile.fields = T.tapped({ holed = true })
        T.placeLine(self, { tile }, "iron")
        T.flow(self, tile, 1, { tile }, "watered")
        T.waitFor(self, function() return T.lineSprite(tile) == Sprites.pipe("iron", true, 0) end,
            "this client's copy of the watered tile, wet")
        self.dryPerHour = Lines.SOAK_DRY_OUT / 24
        self.hours = (Lines.HOLE_RATE * Lines.POINTS_PER_LITRE - Lines.DAMP / 2) / self.dryPerHour
        T.reload(self, tile, function()
            T.batch(function()
                -- Aged by no hours first, which drops the hours since its last pass, so the soak
                -- dries for exactly the hours away.
                T.read(self, "lines.age", { tiles = T.tiles({ tile }), hours = 0 }, "left")
                T.server(self, "lines.temperature", { celsius = Frost.HARD_FREEZE_CELSIUS - 1 })
                T.server(self, "lines.pinRoll", {})
                T.read(self, "lines.age", { tiles = T.tiles({ tile }), hours = self.hours }, "away")
            end)
        end)
        T.waitForLines(self, { tile }, "this client's copy of the tile, loaded again")
        T.readLines(self, { tile }, "back")
    end,
    validate = function(self)
        local watered, left = self.reads.watered.tiles[1].record, self.reads.left.tiles[1]
        local away, back = self.reads.away.tiles[1], self.reads.back.tiles[1]
        T.expectReloaded(self, "tile")
        expect(watered.full and left.record.soak >= Lines.DAMP, "the hour's flow left the tile full "
            .. tostring(watered.full) .. ", soak " .. tostring(left.record.soak))
        expect(left.sprite == nil, "the server kept the tile's chunk loaded")
        expectNear("the soak after the hours away", away.record.soak,
            left.record.soak - self.hours * self.dryPerHour, T.POINTS)
        expect(away.record.cracked, "the full pipe came through the hard freeze whole")
        expect(back.record.cracked and not back.record.wet, "the server's record, loaded again: cracked "
            .. tostring(back.record.cracked) .. ", wet " .. tostring(back.record.wet))
        expect(back.sprite == Sprites.pipe("iron", false, 0), "the server shows the dried tile as " .. tostring(back.sprite))
        local summary = T.lineSummary(self.tile)
        expect(summary.cracked, "this client's summary of the tile isn't cracked")
        expect(summary.soil == nil, "this client still names the dried soil " .. tostring(summary.soil)
            .. " at the server's soak " .. tostring(back.record.soak))
        expect(T.lineSprite(self.tile) == Sprites.pipe("iron", false, 0),
            "this client shows the dried tile as " .. tostring(T.lineSprite(self.tile)))
    end,
})
