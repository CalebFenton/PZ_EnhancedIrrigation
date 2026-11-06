require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibLines"
require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibPumps"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/Power"
require "EnhancedIrrigation/Parts"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Pumps/PumpClient"
require "EnhancedIrrigation/SquareSounds"
require "EnhancedIrrigation/UI/PumpMenu"
require "EnhancedIrrigation/UI/LineMenu"

-- Houses are placed, plumbed and run for set hours by their own pass from server handlers, so the
-- clock doesn't decide the sums.

local T = EnhancedIrrigationTest
local expect, expectNear, expectEqual = T.expect, T.expectNear, T.expectEqual
local Sprites, Pumps, PumpJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs
local Lines, LineJobs = EnhancedIrrigation.Lines, EnhancedIrrigation.LineJobs
local Parts = EnhancedIrrigation.Parts

local APPLIANCE, UTILITY = Pumps.APPLIANCE_PUMP, Pumps.UTILITY_PUMP

local fitted, update, readUntil = T.pumpHouseFitted, T.updatePumpHouse, T.readPumpUntil
local lifts = T.pumpLifts

-- Houses -------------------------------------------------------------------------------------------------

local function partWord(part, condition)
    return getText("IGUI_EnhancedIrrigation_PartCondition", getItemNameFromFullType(part), condition)
end

-- Building ------------------------------------------------------------------------------------------------

-- The build menu builds each Pump House from its recipe on a bare square, empty, with its record at
-- once: this client's menu says no pump is fitted and greys Turn On out saying so. Catches a recipe
-- the build menu can't build, a house without its record, or one that runs with nothing in it.
for _, case in ipairs({ { entity = T.WOOD, name = "wood" }, { entity = T.METAL, name = "metal" } }) do
    T.test("irrigation_pump_house_" .. case.name .. "_built_from_build_menu", {
        instant = true,
        run = function(self)
            self.house = T.buildTile(self, "Base." .. case.entity, T.PUMP_SPRITES[case.entity], nil, "pump")
            if not self.house then return end
            readUntil(self, self.house, "built", function(state) return state.record ~= nil end)
            T.waitForSummary(self, self.house, function() return true end, "this client's summary of the built house")
            T.readMenu(self, function() return T.copyOf(self.house) end, "built")
            T.useMenu(self, self.house, "on", T.findJob("pump", PumpJobs.TURN_ON), false)
        end,
        validate = function(self)
            local record = self.reads.built.record
            if not expect(record, "the built house has no record") then return end
            expectEqual("the built house", record.unit, case.entity)
            expectEqual("the built house's part", record.part, nil)
            T.expectWord(self, "built", getText("IGUI_EnhancedIrrigation_NoPumpFitted"))
            T.expectOptionRefused(self, "on", "Tooltip_EnhancedIrrigation_NoPumpFitted")
        end,
    })
end

-- Parts ---------------------------------------------------------------------------------------------------

-- A worn condition and a lower ceiling, as a repaired part carries.
local WORN, CEILING = 73, 90
-- What a part's wear leaves past its last whole point: more than half, so rounding to the nearest
-- point would hand it back a point up.
local FRACTION = 0.7

-- The house's menu shows the worn Appliance Pump at the condition Take Out gives it. Take Out Pump
-- from that menu, with a screwdriver, gives back the part at the whole points below its wear, with
-- its lower ceiling, on both sides; Fit Pump puts that item back in at the fraction of a point it
-- had and the same ceiling. Taking a part out and in again never gains it condition. Catches a menu
-- that rounds the part up from what comes out, a part handed back new, rounded up or to the nearest
-- point, or with its ceiling lost, or a part fitted new.
T.test("irrigation_pump_house_take_out_and_fit_keep_the_parts_wear", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.house = T.placePump(self, spots[1], T.WOOD,
            fitted(APPLIANCE, nil, { condition = WORN, ceiling = CEILING, fraction = FRACTION }))
        T.give(self, "tools", { { type = "Base.Screwdriver" } })
        T.waitForSummary(self, self.house, function(summary) return summary.part ~= nil end,
            "this client's summary of the fitted house")
        T.goNextTo(self, spots[1].square)
        T.readMenu(self, function() return T.copyOf(self.house) end, "fitted")
        T.useMenu(self, self.house, "take out", T.findJob("pump", PumpJobs.TAKE_OUT_PUMP), true)
        readUntil(self, self.house, "taken", function(state) return state.record.part == nil end)
        T.readCarried(self, { APPLIANCE })
        T.waitFor(self, function()
            self.back = T.carried(APPLIANCE)
            return self.back ~= nil
        end, "this client's copy of the part taken out")
        T.step(function() self.backCondition, self.backCeiling = self.back:getCondition(), Parts.ceilingOf(self.back) end)
        T.useMenu(self, self.house, "fit", function(context)
            return T.jobOption(context, "pump", PumpJobs.FIT_PUMP, self.back)
        end, true)
        readUntil(self, self.house, "refitted", function(state) return state.record.part ~= nil end)
    end,
    validate = function(self)
        T.expectWord(self, "fitted", partWord(APPLIANCE, WORN))
        T.expectOffered(self, "take out")
        expectEqual("the part Take Out Pump left in the house", self.reads.taken.record.part, nil)
        local items = T.carriedItems(self, APPLIANCE)
        expectEqual("the parts the server's character carries", #items, 1)
        expectEqual("the server's part's condition", items[1] and items[1].condition, WORN)
        expectEqual("the server's part's ceiling", T.ceilingOf(items[1]), CEILING)
        expectEqual("this client's part's condition", self.backCondition, WORN)
        expectEqual("this client's part's ceiling", self.backCeiling, CEILING)
        T.expectOffered(self, "fit")
        local refitted = self.reads.refitted.record
        expectEqual("the part fitted again", refitted.part, APPLIANCE)
        expectNear("the part's condition fitted again", refitted.partCondition, WORN + FRACTION, 0.0001)
        expectEqual("the part's ceiling fitted again", refitted.partCeiling, CEILING)
    end,
})

-- Wear -------------------------------------------------------------------------------------------------

-- Indoors on the grid, beside a dry barrel, its outlet plumbed to another: two hours wear the
-- Appliance Pump faster than running wet, and lift nothing. Catches a dry pump that wears as if it
-- lifted water, or one that wears dry only with nowhere to pump to.
T.test("irrigation_pump_house_dry_source_wears_it_fast", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house, self.tank = T.plumbedPump(self, spots, T.WOOD, fitted(APPLIANCE, { on = true }),
            { source = "ground", sourceLitres = 0 })
        update(self, self.house, "dry", { hoursAgo = 2, tank = self.tank })
    end,
    validate = function(self)
        local dry = self.reads.dry
        -- From the state before, in the same call: a ten-minute pass may have run the house since it
        -- was placed.
        expectNear("the part after two dry hours", dry.before.record.partCondition - dry.after.record.partCondition,
            2 * Pumps.PARTS[APPLIANCE].wearPerHour * Pumps.DRY_WEAR, 0.001)
        expectNear("the outlet's barrel after two dry hours", dry.after.tank.litres, 0, T.LITRES)
    end,
})

-- Condition the nearly burnt-out part has left: half an hour run dry.
local LAST_CONDITION = 5

-- A part already repaired once, with its last few points run dry, burns out within the hour: the
-- house switches itself off, the menu says the part is burnt out and greys Turn On out. Repair Pump
-- with Electricity 2, a screwdriver, Scrap Electronics and a Tire Piece restores it to its ceiling
-- lowered by a repair's loss, taking the scrap and the piece; the menu says so, and a second repair
-- is refused as the part is sounder than one would leave it. Catches a burnt-out pump that runs, a
-- repair to new or from a new part's ceiling, or one that takes nothing.
T.test("irrigation_pump_house_burns_out_and_is_repaired", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house = T.placePump(self, spots[1], T.WOOD, fitted(APPLIANCE, { on = true },
            { condition = LAST_CONDITION, ceiling = CEILING }))
        update(self, self.house, "burnt", { hoursAgo = 1 })
        T.waitForSummary(self, self.house, function(summary) return summary.burntOut end, "this client's summary of the burnt-out part")
        T.readMenu(self, function() return T.copyOf(self.house) end, "burnt")
        T.useMenu(self, self.house, "on", T.findJob("pump", PumpJobs.TURN_ON), false)
        T.setPerk(self, Perks.Electricity, 2)
        T.give(self, "kit", { { type = "Base.Screwdriver" }, { type = "Base.ElectronicsScrap" }, { type = "Base.TirePiece" } })
        T.useMenu(self, self.house, "repair", T.findJob("pump", PumpJobs.REPAIR_PUMP), true)
        readUntil(self, self.house, "repaired", function(state) return state.record.partCondition > 0 end)
        T.waitForSummary(self, self.house, function(summary) return not summary.burntOut end, "this client's summary of the repair")
        T.readMenu(self, function() return T.copyOf(self.house) end, "repaired")
        T.useMenu(self, self.house, "again", T.findJob("pump", PumpJobs.REPAIR_PUMP), false)
        T.count(self, "used", { "Base.ElectronicsScrap", "Base.TirePiece", "Base.Screwdriver" })
    end,
    validate = function(self)
        local burnt = self.reads.burnt.after
        expect(burnt.record.partCondition == 0 and burnt.summary.burntOut, "the part is left at "
            .. burnt.record.partCondition)
        expect(not burnt.record.on and not burnt.summary.running, "the burnt-out house is still switched on")
        T.expectWord(self, "burnt", getText("IGUI_EnhancedIrrigation_PartBurntOut", getItemNameFromFullType(APPLIANCE)))
        T.expectOptionRefused(self, "on", "Tooltip_EnhancedIrrigation_PumpBurntOut")
        T.expectOffered(self, "repair")
        local restored = CEILING - Pumps.REPAIR_LOSS
        local repaired = self.reads.repaired.record
        expect(repaired.partCondition == restored and repaired.partCeiling == restored, "the repair left the part at "
            .. repaired.partCondition .. " of " .. repaired.partCeiling)
        T.expectWord(self, "repaired", partWord(APPLIANCE, restored))
        T.expectOptionRefused(self, "again", "Tooltip_EnhancedIrrigation_PumpSound")
        local used = self.counts.used
        expect(used["Base.ElectronicsScrap"] == 0 and used["Base.TirePiece"] == 0, "the repair left its scrap or tire piece")
        expect(used["Base.Screwdriver"] == 1, "the repair took the screwdriver")
    end,
})

-- Room the nearly full barrel has left: a couple of minutes of an Appliance Pump's water.
local ROOM = 10

-- A part with a quarter-hour's wear left, run an hour on the grid into a barrel with a couple of
-- minutes' room, fills the barrel before it burns out. Catches burn-out that cuts the water by the
-- share of the hour the part lasted, though the barrel filled long before.
T.test("irrigation_pump_house_fills_its_tank_before_burning_out", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house, self.tank = T.plumbedPump(self, spots, T.WOOD, fitted(APPLIANCE), { litres = T.BARREL_LITRES - ROOM })
        update(self, self.house, "burnt", { hoursAgo = 1, tank = self.tank,
            fields = { on = true, partCondition = Pumps.PARTS[APPLIANCE].wearPerHour / 4 } })
    end,
    validate = function(self)
        local after = self.reads.burnt.after
        expectNear("the barrel when the part burnt out", after.tank.litres, T.BARREL_LITRES, T.LITRES)
        expectEqual("the burnt-out part's condition", after.record.partCondition, 0)
    end,
})

-- How long the Utility Pump runs into the raised barrel: a share of the barrel, so it can't fill.
local QUARTER_HOUR = 0.25

-- A Pump House on a generator plumbed to a raised barrel on the storey above, two storeys up, as a
-- Utility Pump lifts and an Appliance Pump doesn't: with the Appliance Pump fitted an hour lifts
-- nothing into it; with the Utility Pump in its place a quarter-hour lifts that part's rate. The
-- outlet is plumbed by the server, as one plumbed while a Utility Pump was in. Catches a house that
-- lifts past its part's reach, as by the house's or the last part's, or one that never lifts that
-- high.
T.test("irrigation_pump_house_lifts_only_as_high_as_its_part", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        T.server(self, "pumpHouse.generator", T.at(spots[4], { fuel = 5 }))
        self.house, self.tank = T.plumbedPump(self, spots, T.WOOD, fitted(APPLIANCE, { on = true }),
            { tank = "raisedAbove" })
        update(self, self.house, "appliance", { hoursAgo = 1, tank = self.tank })
        -- The Appliance Pump's condition carries over, far more than the quarter-hour wears.
        update(self, self.house, "utility", { hoursAgo = QUARTER_HOUR, tank = self.tank, fields = { part = UTILITY } })
    end,
    validate = function(self)
        local appliance, utility = self.reads.appliance, self.reads.utility
        expectNear("the barrel two storeys up after an hour of the Appliance Pump",
            appliance.after.tank.litres - appliance.before.tank.litres, 0, T.LITRES)
        expectNear("the barrel two storeys up after a quarter-hour of the Utility Pump",
            utility.after.tank.litres - utility.before.tank.litres, lifts(UTILITY, QUARTER_HOUR), T.LITRES)
    end,
})

-- Timer ---------------------------------------------------------------------------------------------------

-- Indoors on the grid, switched off: Fit Timer from the menu fits the Timer Valve carried, which
-- shows by the house's plug; Set Timer from its panel opens it two hours before the hour now for
-- 30 minutes; three hours gone by, the house lifted half an hour of the Appliance Pump's water into
-- the barrel and wore its part by half an hour, and isn't running now; the menu names the timer;
-- Take Off Timer gives it back. Catches a timer that never runs the house, runs it outside its
-- window or all the time, or is lost taking it off.
T.test("irrigation_pump_house_timer_runs_it_in_its_window", {
    instant = true,
    run = function(self)
        local Valves, PumpMenu, ValveUI = EnhancedIrrigation.Valves, EnhancedIrrigation.PumpMenu, EnhancedIrrigation.ValveUI
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house, self.tank = T.plumbedPump(self, spots, T.METAL, fitted(APPLIANCE))
        T.give(self, "tools", { { type = "Base.Screwdriver" }, { type = Valves.TIMER } })
        T.useMenu(self, self.house, "fit", T.findJob("pump", PumpJobs.FIT_TIMER), true)
        readUntil(self, self.house, "fitted", function(state) return state.record.timer ~= nil end)
        T.waitFor(self, function() return T.hasOverlay(T.overlaysOf(T.copyOf(self.house)), Sprites.HOUSE_TIMER) end,
            "this client's copy of the house showing its timer")
        self.start = (math.floor(getGameTime():getTimeOfDay()) - 2) % 24
        T.useMenu(self, self.house, "set", T.running(PumpMenu.openTimer), true)
        T.waitFor(self, function() return ValveUI.instances[T.player():getPlayerNum()] ~= nil end, "the timer's panel")
        T.step(function()
            local panel = ValveUI.instances[T.player():getPlayerNum()]
            for _ = 1, (self.start - panel.hour) % 24 do
                panel:onClick(panel.hourUp)
            end
            panel.knob:setKnobPosition(30)
            panel:onClick(panel.ok)
        end)
        readUntil(self, self.house, "set", function(state) return state.record.timer.minutes == 30 end)
        update(self, self.house, "hours", { hoursAgo = 3, tank = self.tank })
        T.waitForSummary(self, self.house, function(summary) return summary.timer and summary.timer.minutes == 30 end,
            "this client's summary of the set timer")
        T.readMenu(self, function() return T.copyOf(self.house) end, "set")
        T.useMenu(self, self.house, "take off", T.findJob("pump", PumpJobs.TAKE_OFF_TIMER), true)
        readUntil(self, self.house, "off", function(state) return state.record.timer == nil end)
        T.readCarried(self, { Valves.TIMER })
    end,
    validate = function(self)
        local Valves = EnhancedIrrigation.Valves
        T.expectOffered(self, "fit")
        expectEqual("the fitted timer", self.reads.fitted.record.timer.item, Valves.TIMER)
        T.expectOffered(self, "set")
        expectEqual("the timer's start", self.reads.set.record.timer.start, self.start)
        local hours = self.reads.hours
        expectNear("the barrel after its window", hours.after.tank.litres - hours.before.tank.litres, lifts(APPLIANCE, 0.5), T.LITRES)
        expectNear("the part after its window", hours.before.record.partCondition - hours.after.record.partCondition,
            Pumps.PARTS[APPLIANCE].wearPerHour * 0.5, 0.001)
        expect(not hours.after.record.running, "the house runs outside its timer's window")
        T.expectWord(self, "set", Valves.describe({ item = Valves.TIMER, start = self.start, minutes = 30 }))
        T.expectOffered(self, "take off")
        expect(self.reads.off.record.timer == nil, "Take Off Timer left the timer in the house")
        expectEqual("timers Take Off Timer gave back", #T.carriedItems(self, Valves.TIMER), 1)
    end,
})

-- Lines ------------------------------------------------------------------------------------------------

-- Where the line tests set a house, the barrel it draws from beside it, and two line tiles below.
local LINE_SPOTS = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }
-- Litres in that barrel.
local SOURCE_LITRES = 100

-- Queues a Pump House `entity` fitted with a new `part` at spots[1], a lidded barrel of
-- SOURCE_LITRES beside it at spots[2] for its water, and its outlet plumbed to the first of two holed
-- line tiles on spots[3] and spots[4], with dry crops on them (T.pumpedLine). Returns the house, the
-- barrel and the tiles.
local function houseLine(self, spots, entity, part)
    local tiles = { spots[3], spots[4] }
    local house, barrel = T.pumpedLine(self, tiles, spots, entity, fitted(part),
        { source = "lidded", sourceLitres = SOURCE_LITRES })
    return house, barrel, tiles
end

-- A Pump House with a Utility Pump on the grid, its outlet on a line of two holed tiles: switched
-- on, every client's copy of the line runs and its Drain Line is greyed out saying so; half an hour
-- pushes each hole's water out at the part's push, drawing only what the holes took from its barrel
-- and wearing the part by the hour; switched off, the line stops and drains. The switch is the
-- authority's own job, whose menu the tests above play. Catches a pumped line run at a tank's head,
-- a pump that draws its whole rate into a line, or a line drained under its pump.
T.test("irrigation_pump_house_drives_its_line_while_on", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, LINE_SPOTS, { bare = true, indoors = true, joined = true })
        if not spots then return end
        self.house, self.barrel, self.tiles = houseLine(self, spots, T.METAL, UTILITY)
        T.job(self, "pump", PumpJobs.TURN_ON, self.house, nil, "turned on")
        readUntil(self, self.house, "on", function(state) return state.record.running == true end)
        T.waitForLines(self, self.tiles, "this client's copy of the running line", function(summary) return summary.running end)
        T.useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain running", false)
        -- The crops dried in the same call, so the ten-minute passes since Turn On leave them room.
        update(self, self.house, "half", { hoursAgo = T.HALF_HOUR, squares = self.tiles, water = 0, tank = self.barrel })
        T.job(self, "pump", PumpJobs.TURN_OFF, self.house, nil, "off")
        T.waitForLines(self, self.tiles, "this client's copy of the stopped line", function(summary)
            return not summary.running
        end)
        T.useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain stopped", false)
    end,
    validate = function(self)
        expect(self.reads["turned on"].ok and self.reads.on.record.running, "Turn On didn't run the house")
        T.expectOptionRefused(self, "drain running", "Tooltip_EnhancedIrrigation_LineRunning")
        local half = self.reads.half
        local each = Lines.HOLE_RATE * Pumps.PARTS[UTILITY].push * T.HALF_HOUR
        for i = 1, 2 do
            expectNear("crop " .. i .. "'s water", half.after.squares[i].water - half.before.squares[i].water,
                each * Lines.POINTS_PER_LITRE, 0.05)
        end
        expectNear("the barrel's water drawn", half.before.tank.litres - half.after.tank.litres, 2 * each, T.LITRES)
        expectNear("the part's wear", half.before.record.partCondition - half.after.record.partCondition,
            Pumps.PARTS[UTILITY].wearPerHour * T.HALF_HOUR, 0.001)
        expect(self.reads.off.ok, "Turn Off wasn't done")
        T.expectOffered(self, "drain stopped")
    end,
})

-- A full sealed tile cracks during catch-up, before this pump budgets its water and dry wear.
-- The new crack and the drilled hole exhaust a finite source halfway through the pass. Catches a
-- pump that budgets the line as it stood before the crack, or wears dry time as wet.
T.test("irrigation_pump_house_budgets_after_line_freeze", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, LINE_SPOTS, { bare = true, indoors = true, joined = true })
        if not spots then return end
        self.tiles = { spots[3], spots[4] }
        self.tiles[1].fields = { full = true }
        self.litres = (Lines.HOLE_RATE + Lines.CRACK_RATE) * Pumps.PARTS[UTILITY].push * T.HALF_HOUR / 2
        self.house, self.barrel = T.pumpedLine(self, self.tiles, spots, T.METAL, fitted(UTILITY),
            { source = "lidded", sourceLitres = self.litres })
        T.batch(function()
            T.server(self, "lines.temperature", { celsius = EnhancedIrrigation.Frost.HARD_FREEZE_CELSIUS - 1 })
            -- Every roll a sure split. The full tile's is the pass's only one, as the drilled tile
            -- catches up empty before the pump's water comes; what the passes after draw comes after
            -- these reads.
            T.forceRoll(self, 0)
            local args = T.pumpAt(self.house, { hoursAgo = T.HALF_HOUR, fields = { on = true },
                squares = self.tiles, water = 0, tank = self.barrel })
            args.lineHoursAgo = 1
            T.read(self, "pumps.update", args, "frozen")
            T.readLines(self, self.tiles, "line")
        end)
    end,
    validate = function(self)
        local frozen = self.reads.frozen
        expect(self.reads.line.tiles[1].record.cracked, "the full tile did not crack during the pump's catch-up")
        expectNear("water drawn after the crack opened", frozen.before.tank.litres - frozen.after.tank.litres,
            self.litres, T.LITRES)
        expectNear("water reaching the drilled tile", frozen.after.squares[2].water - frozen.before.squares[2].water,
            self.litres * Lines.HOLE_RATE / (Lines.HOLE_RATE + Lines.CRACK_RATE) * Lines.POINTS_PER_LITRE, 0.05)
        expectNear("wear from equal wet and dry running", frozen.before.record.partCondition - frozen.after.record.partCondition,
            Pumps.PARTS[UTILITY].wearPerHour * T.HALF_HOUR / 2 * (1 + Pumps.DRY_WEAR), 0.001)
    end,
})

-- A running Pump House driving a line, smashed with a sledgehammer through vanilla's Destroy cursor
-- and action, takes its record with it and stops the line on both sides: this client's Drain Line
-- is offered and the server drains it. Catches a line left running by a pump that is gone, which
-- nothing could then stop or drain.
T.test("irrigation_pump_house_smashed_stops_its_line", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, LINE_SPOTS, { bare = true, indoors = true, joined = true })
        if not spots then return end
        local _
        self.house, _, self.tiles = houseLine(self, spots, T.METAL, UTILITY)
        T.job(self, "pump", PumpJobs.TURN_ON, self.house, nil, "on")
        -- Run long enough to fill the line, so Drain Line has water to take.
        update(self, self.house, "ran", { hoursAgo = T.HALF_HOUR })
        T.waitForLines(self, self.tiles, "this client's copy of the running line", function(summary) return summary.running end)
        T.smash(self, self.house, Pumps.isPump, "Pump House")
        T.readPump(self, self.house, "smashed")
        T.waitForLines(self, self.tiles, "this client's copy of the stopped line", function(summary)
            return not summary.running
        end)
        T.useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain", false)
        T.job(self, "line", LineJobs.DRAIN, self.tiles[2], nil, "drained")
    end,
    validate = function(self)
        T.expectOk(self.reads.on, "Turn On")
        local smashed = self.reads.smashed
        expect(not smashed.found and smashed.record == nil, "the smashed house or its record is still there")
        T.expectOffered(self, "drain")
        T.expectOk(self.reads.drained, "the server's Drain Line once the house was smashed")
    end,
})

-- Hours the house is away while its chunk is unloaded.
local AWAY_HOURS = 1

-- A running house's record waits while its chunk is away: the pass leaves it as it was, however
-- long ago it last ran. Loaded again, it runs the whole gap on the grid it still has, and the barrel
-- its outlet fills gets the gap's water. Catches a record that lifts into a tank it can't see, or
-- forgets the time it was away. The house is switched on only once away, so no ten-minute pass
-- before the reload runs what the gap doesn't count. A house feeding a line waits on the same
-- check of its outlet's square (PumpObject's endsLoaded), and the tests above run a line's gap.
T.test("irrigation_pump_house_catches_up_after_its_chunk_reloads", {
    spOnly = T.CHUNK_RELOAD_SP_ONLY,
    instant = true,
    timeoutSeconds = T.CHUNK_RELOAD_SECONDS,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house, self.tank = T.plumbedPump(self, spots, T.WOOD, fitted(APPLIANCE))
        T.server(self, "pumps.update", T.at(self.house))
        T.reloadChunk(self, T.at(self.house), function()
            update(self, self.house, "away", { hoursAgo = AWAY_HOURS, fields = { on = true } })
        end)
        -- The house waits until every square around it is loaded, which may be another chunk's.
        T.waitFor(self, function()
            for _, spot in ipairs(spots) do
                if not getSquare(spot.x, spot.y, spot.z) then
                    return false
                end
            end
            return true
        end, "this client to load the house's well and barrel again", T.CHUNK_MS)
        update(self, self.house, "back", { tank = self.tank })
    end,
    validate = function(self)
        local away, back = self.reads.away, self.reads.back
        expect(away.after.record.lastHour == away.before.record.lastHour, "the house ran while away")
        -- From the clock wound back while away to the pass after the reload, whichever pass ran it.
        expectNear("the barrel, back", back.after.tank.litres, lifts(APPLIANCE, back.now - (away.now - AWAY_HOURS)), T.LITRES)
    end,
})

-- Make Utility Pump ---------------------------------------------------------------------------------------

-- Make Utility Pump from a Blower Fan makes a Utility Pump at the made ceiling, short of a found
-- one's. Catches a recipe the game won't craft, or a made pump as good as a found one.
T.craftTest("irrigation_pump_house_make_utility_pump", {
    recipe = "EnhancedIrrigation_MakeUtilityPump",
    from = "Base.BlowerFan",
    counts = { [UTILITY] = 1 },
    after = function(self) T.readCarried(self, { UTILITY }) end,
    validate = function(self)
        local made = T.carriedFirst(self, UTILITY)
        expectEqual("the made pump's condition", made and made.condition, Pumps.MADE_CEILING)
        expectEqual("the made pump's ceiling", T.ceilingOf(made), Pumps.MADE_CEILING)
    end,
})
