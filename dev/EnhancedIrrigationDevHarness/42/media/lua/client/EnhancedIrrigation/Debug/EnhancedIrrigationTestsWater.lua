require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Tanks"

-- Water from Tank (Taps.lua, Lines/TapSystem.lua, Lines/Flow.lua and
-- TimedActions/EnhancedIrrigationWaterAction.lua): opening a tap from its menu, who may hold it,
-- which tank it draws on and what an hour's water gives the crops. The verb runs at a raised clock
-- speed; the flow's sums are run for set hours on the server (lines.flow), so the clock doesn't
-- decide them.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local expectOffered, expectRefused = T.expectOffered, T.expectRefused
local Sprites, Lines, Tanks = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.Tanks

local LITRES = 0.01
local POINTS = 0.05
-- A crop's water as read, give or take vanilla's own ten-minute drying (SFarmingSystem.checkWater)
-- landing between placing the crop and reading it.
local CROP_POINTS = 0.25
-- How long the tap may take to drain the test's tank at the raised speed, in real time.
local WATER_MS = 60000
-- The clock's speed while the tap runs, so the tank empties in seconds.
local WATER_SPEED = 100
-- How far from the tap, in squares, the character goes: well past EnhancedIrrigationAction.REACH.
local AWAY_SQUARES = 8
-- What the tank holds when the tap is let go of early: far more than a few runs draw.
local TANK_LITRES = 100
-- What a tank the tap runs dry holds: a few game minutes' flow out of a hole, which a thirsty crop
-- takes all of.
local SMALL_TANK_LITRES = 0.05
-- Who holds the tap in the one-person test, standing in for another player.
local OTHER = "EnhancedIrrigationTestOther"
-- How often, in real milliseconds, the multiplayer server runs an open tap in these tests: a
-- frame or two, where the mod's second would be most of a test's time.
local RUN_MS = 20

-- Makes the multiplayer server run taps opened from now every RUN_MS until the test ends.
local function quickRuns(self)
    T.server(self, "water.runEvery", { ms = RUN_MS })
end

-- Queues T.useOption on this client's copy of the tap tile at `handle` for Water from Tank.
local function useWater(self, handle, label, choose)
    T.useOption(self, function() return T.lineObject(handle) end, label, function(context)
        return T.findOption(context, context, function(option)
            return option.onSelect == EnhancedIrrigationWaterAction.queue
        end)
    end, choose)
end

-- Queues opening the tap at `handle` for a character whose client doesn't check that it stands
-- there: the action's isValid always passes, so only the authority's own check can stop it.
local function waterUnchecked(self, handle)
    T.step(function()
        local tap = T.lineObject(handle)
        if not T.need(self, tap, "this client's copy of the tap tile") then return end
        local action = EnhancedIrrigationWaterAction:new(T.player(), tap)
        action.isValid = function() return true end
        ISTimedActionQueue.add(action)
    end)
end

-- Queues sending the character to `there` once the water runs, which this client's copy of `tank`
-- shows, calling `noting()` first if given; self.walkedOff says whether it went.
local function walkOffOnceWaterRuns(self, tank, there, noting)
    T.step(function()
        T.onTick(self, function()
            local copy = not self.walkedOff and Tanks.tankAt(tank.x, tank.y, tank.z)
            if copy and Tanks.litres(copy) < TANK_LITRES - LITRES then
                if noting then noting() end
                self.walkedOff = true
                PZHarness.Fixtures.teleportToMiddle(T.player(), there.x, there.y, there.z)
            end
        end)
    end)
end

-- The tap ----------------------------------------------------------------------------------------

-- A tap on a barrel standing on the line's own floor has no head: Water from Tank says so. Catches
-- water run uphill.
T.test("irrigation_water_needs_pressure", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 2)
        if not rows then return end
        local tile, beside = rows[1][1], rows[1][2]
        T.placeTank(self, beside, "ground", TANK_LITRES)
        tile.fields = T.tapped()
        T.placeLine(self, { tile }, "iron")
        T.goNextTo(self, tile.square)
        useWater(self, tile, "water", false)
    end,
    validate = function(self)
        expectRefused(self, "water", "Tooltip_EnhancedIrrigation_NoPressure")
    end,
})

-- The tap held open at a barrel on a Tank Stand runs the line until the barrel is dry: the crop on
-- the holed tile gets all of it, and the soil shows it. Catches the real verb losing water between
-- tank and crop, or the tap not closing on an empty tank.
T.test("irrigation_water_from_a_raised_tank", {
    instant = true,
    timeoutSeconds = 90,
    run = function(self)
        local rows = T.row(self, 2, { indoors = true })
        if not rows then return end
        local tile, beside = rows[1][1], rows[1][2]
        self.tank = T.placeTank(self, beside, "raised", SMALL_TANK_LITRES)
        tile.fields = T.tapped({ holed = true })
        T.placeLine(self, { tile }, "plastic")
        T.plant(self, tile, 0)
        T.goNextTo(self, tile.square)
        T.setMultiplier(self, WATER_SPEED)
        quickRuns(self)
        useWater(self, tile, "water", true)
        -- The open tap holds the queue until it closes itself; a refused or stopped one would have
        -- emptied it, failing the test.
        T.readUntil(self, "tanks.read", T.at(self.tank), "tank", function(reply)
            return reply.found and reply.litres <= 0
        end, WATER_MS)
        T.readLines(self, { tile }, "watered")
        T.waitFor(self, function() return T.lineSprite(tile) == Sprites.pipe("plastic", true, 0) end,
            "this client's copy of the wet tile")
    end,
    validate = function(self)
        expectOffered(self, "water")
        expectNear("the raised tank's water", self.reads.tank.litres, 0, LITRES)
        local read = self.reads.watered.tiles[1]
        expectNear("the crop's water", read.plant.water, SMALL_TANK_LITRES * Lines.POINTS_PER_LITRE, CROP_POINTS)
        expect(read.record.full, "the line isn't full")
        expect(read.record.wet, "the hole's soil isn't wet")
    end,
})

-- The authority lets go of the tap once the character walks off it, though their client says they
-- are still there: the line stops, and the tank keeps the rest. Catches a tap left running.
T.test("irrigation_water_stops_when_the_character_walks_off", {
    instant = true,
    timeoutSeconds = 60,
    run = function(self)
        local rows = T.row(self, 1)
        local away = T.row(self, 1, { minDistance = AWAY_SQUARES })
        if not (rows and away) then return end
        local tile = rows[1][1]
        self.tank = T.placeTank(self, tile, "above", TANK_LITRES)
        tile.fields = T.tapped({ cracked = true })
        T.placeLine(self, { tile }, "plastic")
        T.goNextTo(self, tile.square)
        T.setMultiplier(self, WATER_SPEED)
        quickRuns(self)
        walkOffOnceWaterRuns(self, self.tank, away[1][1])
        -- An open tap the authority never closes holds the queue until the test runs out of time.
        waterUnchecked(self, tile)
        T.read(self, "tanks.read", T.at(self.tank), "tank")
    end,
    validate = function(self)
        expect(self.walkedOff, "the water never ran")
        expect(self.reads.tank.litres > TANK_LITRES / 2, "the line ran on after the character walked off: "
            .. self.reads.tank.litres .. " litres left")
    end,
})

-- The authority won't open a tap for a character who isn't at it, whatever their client says.
-- Catches reach checked only on the client.
T.test("irrigation_water_refused_out_of_reach", {
    instant = true,
    mpOnly = "single player has one copy of the character, whose start() refuses with isValid's own check",
    run = function(self)
        local rows = T.row(self, 1)
        local away = T.row(self, 1, { minDistance = AWAY_SQUARES })
        if not (rows and away) then return end
        local tile = rows[1][1]
        self.tank = T.placeTank(self, tile, "above", TANK_LITRES)
        tile.fields = T.tapped({ cracked = true })
        T.placeLine(self, { tile }, "plastic")
        T.goNextTo(self, away[1][1].square)
        waterUnchecked(self, tile)
        T.read(self, "tanks.read", T.at(self.tank), "tank")
        T.readLines(self, { tile }, "after")
    end,
    validate = function(self)
        expectNear("the tank's water", self.reads.tank.litres, TANK_LITRES, LITRES)
        local record = self.reads.after.tiles[1].record
        expect(record and not record.full, "the line filled from a tap nobody stood at")
    end,
})

-- The authority runs a tap for one Water from Tank at a time. While another player holds it, the
-- menu greys Water from Tank out saying so, and the authority won't open it for this character,
-- whose client doesn't check. Once that player's action falls silent, as a client's does that
-- disconnects mid-run, the tap frees itself and this character's water runs, holding it in turn,
-- until they walk off and let go. Catches two players doubling a tap's draw, or a tap left held
-- after its holder is gone.
T.test("irrigation_water_one_person_per_tap", {
    instant = true,
    mpOnly = "a player holding a tap from another client needs a multiplayer server",
    timeoutSeconds = 120,
    run = function(self)
        local rows = T.row(self, 1)
        local away = T.row(self, 1, { minDistance = AWAY_SQUARES })
        if not (rows and away) then return end
        local tile = rows[1][1]
        self.tank = T.placeTank(self, tile, "above", TANK_LITRES)
        tile.fields = T.tapped({ holed = true })
        T.placeLine(self, { tile }, "plastic")
        T.read(self, "lines.holdTap", T.at(tile, { as = OTHER }), "other")
        T.waitForLines(self, { tile }, "this client's summary of the tap another player holds",
            function(summary) return summary.heldBy == OTHER end)
        T.goNextTo(self, tile.square)
        useWater(self, tile, "while held", false)
        waterUnchecked(self, tile)
        T.read(self, "tanks.read", T.at(self.tank), "refused")
        -- The other player's action has been silent too long.
        T.server(self, "lines.lapseHold", T.at(tile))
        T.setMultiplier(self, WATER_SPEED)
        quickRuns(self)
        T.waitFor(self, function()
            local summary = T.lineSummary(tile)
            return summary ~= nil and summary.heldBy == nil
        end, "this client's summary of the tap, freed", WATER_MS)
        useWater(self, tile, "freed", false)
        walkOffOnceWaterRuns(self, self.tank, away[1][1], function()
            local summary = T.lineSummary(tile)
            self.heldByMe = summary ~= nil and summary.heldBy == T.player():getUsername()
        end)
        -- An open tap the authority never closes holds the queue until the test runs out of time.
        waterUnchecked(self, tile)
        T.readLines(self, { tile }, "let go")
    end,
    validate = function(self)
        expect(self.reads.other.held, "the other player couldn't hold the free tap")
        expectRefused(self, "while held", "Tooltip_EnhancedIrrigation_TapInUse")
        expectNear("the tank's water while another player held the tap", self.reads.refused.litres, TANK_LITRES,
            LITRES)
        expectOffered(self, "freed")
        expect(self.walkedOff, "no water ran for this character once the tap was free")
        expect(self.heldByMe, "the tap wasn't held for this character while its water ran")
        local record = self.reads["let go"].tiles[1].record
        expect(record and record.heldBy == nil, "the tap is still held by " .. tostring(record and record.heldBy)
            .. " after this character walked off")
    end,
})

-- Each time the water runs, the tap draws on the highest tank reaching it that holds water, the
-- fuller of two on one level: an empty barrel two storeys up and a full one on the ground give
-- none, and the fuller of two a storey up gives it all. Catches a tap tied to one tank, an empty
-- tank chosen, or a tank without the head drawn on.
T.test("irrigation_water_tap_draws_from_the_highest_tank_holding_water", {
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local west, tile, east = rows[1][1], rows[1][2], rows[1][3]
        tile.fields = T.tapped({ holed = true })
        T.placeLine(self, { tile }, "iron")
        -- Each holding more than an hour draws, the fuller twice the emptier.
        self.start = { empty = 0, fuller = 4 * Lines.HOLE_RATE, emptier = 2 * Lines.HOLE_RATE, ground = TANK_LITRES }
        self.tanks = {
            empty = T.placeTank(self, east, "raisedAbove", self.start.empty),
            fuller = T.placeTank(self, tile, "above", self.start.fuller),
            emptier = T.placeTank(self, west, "raised", self.start.emptier),
            ground = T.placeTank(self, east, "lidded", self.start.ground),
        }
        T.batch(function()
            T.flow(self, tile, 1, {}, "hour")
            for name, tank in pairs(self.tanks) do
                T.read(self, "tanks.read", T.at(tank), name)
            end
        end)
    end,
    validate = function(self)
        local hour = self.reads.hour
        if not expect(hour.drawn, "the line didn't run: " .. tostring(hour.stopped)) then return end
        -- The fuller tank stands a storey over the line: one storey of head.
        local want = { empty = 0, fuller = Lines.HOLE_RATE, emptier = 0, ground = 0 }
        for name, drawn in pairs(want) do
            expectNear("the " .. name .. " tank's water", self.reads[name].litres, self.start[name] - drawn, LITRES)
        end
    end,
})

-- Flow ---------------------------------------------------------------------------------------------

-- An hour through two holes under a storey of head: each draws Lines.HOLE_RATE from the tank; the
-- thirsty crop takes its share at vanilla's points a litre, and the full crop's share soaks into
-- the soil. Catches water lost or made between tank and outlets, or a full crop's water vanishing.
T.test("irrigation_water_points_per_litre", {
    run = function(self)
        local rows = T.row(self, 3, { indoors = true })
        if not rows then return end
        local tap, thirsty, full = rows[1][1], rows[1][2], rows[1][3]
        self.tank = T.placeTank(self, tap, "above", TANK_LITRES)
        tap.fields = T.tapped()
        thirsty.fields = { holed = true }
        full.fields = { holed = true }
        T.placeLine(self, { tap, thirsty, full }, "iron")
        T.plant(self, thirsty, 0)
        T.plant(self, full, Lines.PLANT_FULL)
        T.batch(function()
            T.flow(self, tap, 1, { thirsty, full }, "hour")
            T.read(self, "tanks.read", T.at(self.tank), "tank")
        end)
    end,
    validate = function(self)
        local hour = self.reads.hour
        if not expect(hour.drawn, "the line didn't run: " .. tostring(hour.stopped)) then return end
        local each = Lines.HOLE_RATE
        expectNear("litres drawn", hour.drawn, 2 * each, LITRES)
        expectNear("the tank's water", self.reads.tank.litres, TANK_LITRES - 2 * each, LITRES)
        local thirsty, full = hour.tiles[1], hour.tiles[2]
        expectNear("the thirsty crop's water", thirsty.plant.water, each * Lines.POINTS_PER_LITRE, CROP_POINTS)
        expectNear("the soak under the thirsty crop", thirsty.record.soak, 0, POINTS)
        expectNear("the full crop's water", full.plant.water, Lines.PLANT_FULL, CROP_POINTS)
        expectNear("the soak under the full crop", full.record.soak, each * Lines.POINTS_PER_LITRE, CROP_POINTS)
        expect(thirsty.record.full and full.record.full, "the line isn't full")
    end,
})

-- A tank two storeys over a line pushes each hole's water out the square root of two times as fast
-- as one a storey over it (Torricelli). Catches the head ignored, or taken linearly.
T.test("irrigation_water_higher_tank_waters_faster", {
    run = function(self)
        local tiles = T.layout(self, { { 0, 0 }, { 2, 0 } }, { indoors = true })
        if not tiles then return end
        self.low = T.placeTank(self, tiles[1], "above", TANK_LITRES)
        self.high = T.placeTank(self, tiles[2], "raisedAbove", TANK_LITRES)
        tiles[1].fields = T.tapped({ holed = true })
        tiles[2].fields = T.tapped({ holed = true })
        T.placeLine(self, tiles, "iron")
        T.batch(function()
            T.flow(self, tiles[1], 1, {}, "low hour")
            T.flow(self, tiles[2], 1, {}, "high hour")
            T.read(self, "tanks.read", T.at(self.low), "low tank")
            T.read(self, "tanks.read", T.at(self.high), "high tank")
        end)
    end,
    validate = function(self)
        local low = TANK_LITRES - self.reads["low tank"].litres
        local high = TANK_LITRES - self.reads["high tank"].litres
        expectNear("the litres a storey of head gives in an hour", low, Lines.HOLE_RATE, LITRES)
        expectNear("the litres two storeys of head give in an hour", high, Lines.HOLE_RATE * math.sqrt(2), LITRES)
    end,
})

-- A crack leaks while the tap runs, faster than a hole, into the ground beside the pipe: the tank
-- loses it and the tile shows wet, but its crop gets none and its soil doesn't soak; the holed tile
-- beside it waters its crop as ever. Catches a crack that waters, or one that loses nothing.
T.test("irrigation_water_crack_leaks_to_waste", {
    run = function(self)
        local rows = T.row(self, 2, { indoors = true })
        if not rows then return end
        local cracked, holed = rows[1][1], rows[1][2]
        self.tank = T.placeTank(self, cracked, "above", TANK_LITRES)
        cracked.fields = T.tapped({ cracked = true })
        holed.fields = { holed = true }
        T.placeLine(self, { cracked, holed }, "plastic")
        T.plant(self, cracked, 0)
        T.plant(self, holed, 0)
        T.batch(function()
            T.flow(self, cracked, 1, { cracked, holed }, "hour")
            T.read(self, "tanks.read", T.at(self.tank), "tank")
        end)
        T.waitFor(self, function() return T.lineSprite(cracked) == Sprites.pipe("plastic", true, Sprites.EAST) end,
            "this client's copy of the cracked tile, wet")
    end,
    validate = function(self)
        local hour = self.reads.hour
        if not expect(hour.drawn, "the line didn't run: " .. tostring(hour.stopped)) then return end
        -- The tank stands a storey over the line: one storey of head.
        local drawn = Lines.CRACK_RATE + Lines.HOLE_RATE
        expectNear("litres drawn", hour.drawn, drawn, LITRES)
        expectNear("the tank's water", self.reads.tank.litres, TANK_LITRES - drawn, LITRES)
        local cracked, holed = hour.tiles[1], hour.tiles[2]
        expectNear("the crop on the crack's water", cracked.plant.water, 0, CROP_POINTS)
        expectNear("the soak under the crack", cracked.record.soak, 0, POINTS)
        expect(cracked.record.wet, "the cracked tile doesn't show wet")
        expectNear("the crop on the hole's water", holed.plant.water, Lines.HOLE_RATE * Lines.POINTS_PER_LITRE, CROP_POINTS)
    end,
})
