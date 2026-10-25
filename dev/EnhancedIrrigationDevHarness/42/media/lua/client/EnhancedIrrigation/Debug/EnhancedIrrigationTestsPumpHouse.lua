require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
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
local expect, expectNear = T.expect, T.expectNear
local Sprites, Pumps, PumpJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs
local Lines, LineJobs = EnhancedIrrigation.Lines, EnhancedIrrigation.LineJobs
local Parts = EnhancedIrrigation.Parts

local WOOD, METAL = "EnhancedIrrigation_PumpHouseWood", "EnhancedIrrigation_PumpHouseMetal"
local APPLIANCE, UTILITY = Pumps.APPLIANCE_PUMP, Pumps.UTILITY_PUMP
-- A raised barrel's water: vanilla's round rain barrel's.
local BARREL_LITRES = 600

local fitted, at, update, readUntil = T.pumpHouseFitted, T.pumpHouseAt, T.updatePumpHouse, T.readPumpHouseUntil
local lifts = T.pumpLifts

-- Houses -------------------------------------------------------------------------------------------------

local function partWord(part, condition)
    return getText("IGUI_EnhancedIrrigation_PartCondition", getItemNameFromFullType(part), condition)
end

-- Building ------------------------------------------------------------------------------------------------

-- The build menu builds each Pump House from its recipe on a bare square, empty, with its record at
-- once: this client's menu says no pump is fitted and greys Turn On out saying so. Catches a recipe
-- the build menu can't build, a house without its record, or one that runs with nothing in it.
for _, case in ipairs({ { entity = WOOD, name = "wood" }, { entity = METAL, name = "metal" } }) do
    T.test("irrigation_pump_house_" .. case.name .. "_built_from_build_menu", {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.house = T.buildFromMenu(self, "Base." .. case.entity, spots[1], T.PUMP_SPRITES[case.entity])
            if not self.house then return end
            readUntil(self, self.house, "built", function(state) return state.record ~= nil end)
            T.waitForPumpSummary(self, self.house, function() return true end, "this client's summary of the built house")
            T.readMenu(self, self.house, "built")
            T.useMenu(self, self.house, "on", T.job("pump", PumpJobs.TURN_ON), false)
        end,
        validate = function(self)
            local record = self.reads.built.record
            if not expect(record, "the built house has no record") then return end
            expect(record.unit == case.entity and record.part == nil, "the built house is " .. tostring(record.unit)
                .. " with " .. tostring(record.part) .. " in it")
            T.expectWord(self, "built", getText("IGUI_EnhancedIrrigation_NoPumpFitted"))
            T.expectRefused(self, "on", "Tooltip_EnhancedIrrigation_NoPumpFitted")
        end,
    })
end

-- Parts ---------------------------------------------------------------------------------------------------

-- A worn condition and a lower ceiling, as a repaired part carries.
local WORN, CEILING = 73, 90

-- Fit Pump from the house's menu, with a worn Appliance Pump carrying a lower ceiling and a
-- screwdriver, puts it in as it is: the menu names it at its condition. Take Out Pump gives back the
-- same part, as worn, with its ceiling, on both sides. Catches a part fitted new, or handed back new
-- or with its ceiling lost.
T.test("irrigation_pump_house_fit_and_take_out_keep_its_condition", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.house = T.placePump(self, spots[1], WOOD)
        T.give(self, "parts", { { type = "Base.Screwdriver" },
            { type = APPLIANCE, condition = WORN, modData = { [Parts.CEILING_KEY] = CEILING } } })
        T.useMenu(self, self.house, "fit", function(context)
            return T.jobOption(context, "pump", PumpJobs.FIT_PUMP, self.items.parts[2])
        end, true)
        readUntil(self, self.house, "fitted", function(state) return state.record.part ~= nil end)
        T.waitForPumpSummary(self, self.house, function(summary) return summary.part ~= nil end, "this client's summary of the part")
        T.readMenu(self, self.house, "fitted")
        T.useMenu(self, self.house, "take out", T.job("pump", PumpJobs.TAKE_OUT_PUMP), true)
        readUntil(self, self.house, "taken", function(state) return state.record.part == nil end)
        T.read(self, "items.carried", { type = APPLIANCE }, "carried")
        T.waitFor(self, function()
            self.back = T.player():getInventory():getFirstTypeRecurse(APPLIANCE)
            return self.back ~= nil
        end, "this client's copy of the part taken out")
    end,
    validate = function(self)
        T.expectOffered(self, "fit")
        local record = self.reads.fitted.record
        expect(record.part == APPLIANCE and record.partCondition == WORN and record.partCeiling == CEILING,
            "the fitted part is " .. tostring(record.part) .. " at " .. tostring(record.partCondition) .. " of "
            .. tostring(record.partCeiling))
        T.expectWord(self, "fitted", partWord(APPLIANCE, WORN))
        T.expectOffered(self, "take out")
        expect(self.reads.taken.record.part == nil, "Take Out Pump left " .. tostring(self.reads.taken.record.part)
            .. " in the house")
        local items = self.reads.carried.items
        expect(#items == 1 and items[1].condition == WORN and items[1].ceiling == CEILING, "the server's part came back as "
            .. (items[1] and (items[1].condition .. " of " .. items[1].ceiling) or "nothing"))
        expect(self.back and self.back:getCondition() == WORN and Parts.ceilingOf(self.back) == CEILING,
            "this client's part came back at " .. tostring(self.back and self.back:getCondition()))
    end,
})

-- What a part's wear leaves past its last whole point: more than half, so rounding to the nearest
-- point would hand it back a point up.
local FRACTION = 0.7

-- Take Out Pump of a part worn to a fraction of a point gives it back at the whole points below,
-- on both sides, and Fit Pump puts it back in at the fraction it had: taking a part out and in
-- again never gains it condition. Catches a part handed back rounded up or to the nearest point, a
-- free hour's wear on every Take Out.
T.test("irrigation_pump_house_take_out_keeps_a_fraction_of_wear", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.house = T.placePump(self, spots[1], WOOD, fitted(APPLIANCE, nil, { condition = WORN, fraction = FRACTION }))
        T.give(self, "tools", { { type = "Base.Screwdriver" } })
        T.useMenu(self, self.house, "take out", T.job("pump", PumpJobs.TAKE_OUT_PUMP), true)
        readUntil(self, self.house, "taken", function(state) return state.record.part == nil end)
        T.read(self, "items.carried", { type = APPLIANCE }, "carried")
        T.waitFor(self, function()
            self.back = T.player():getInventory():getFirstTypeRecurse(APPLIANCE)
            return self.back ~= nil
        end, "this client's copy of the part taken out")
        T.step(function() self.backCondition = self.back:getCondition() end)
        T.useMenu(self, self.house, "fit", function(context)
            return T.jobOption(context, "pump", PumpJobs.FIT_PUMP, self.back)
        end, true)
        readUntil(self, self.house, "refitted", function(state) return state.record.part ~= nil end)
    end,
    validate = function(self)
        T.expectOffered(self, "take out")
        local items = self.reads.carried.items
        expect(#items == 1 and items[1].condition == WORN, "the server's part came back at "
            .. (items[1] and items[1].condition or "nothing"))
        expect(self.backCondition == WORN, "this client's part came back at " .. tostring(self.backCondition))
        T.expectOffered(self, "fit")
        expectNear("the part fitted again", self.reads.refitted.record.partCondition, WORN + FRACTION, 0.0001)
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
        self.house = T.placePump(self, spots[1], WOOD, fitted(APPLIANCE, { on = true }))
        T.placeTank(self, spots[2], "ground", 0)
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        T.linkPump(self, self.house, self.tank)
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
        self.house = T.placePump(self, spots[1], WOOD, fitted(APPLIANCE, { on = true },
            { condition = LAST_CONDITION, ceiling = CEILING }))
        update(self, self.house, "burnt", { hoursAgo = 1 })
        T.waitForPumpSummary(self, self.house, function(summary) return summary.burntOut end, "this client's summary of the burnt-out part")
        T.readMenu(self, self.house, "burnt")
        T.useMenu(self, self.house, "on", T.job("pump", PumpJobs.TURN_ON), false)
        T.setPerk(self, Perks.Electricity, 2)
        T.give(self, "kit", { { type = "Base.Screwdriver" }, { type = "Base.ElectronicsScrap" }, { type = "Base.TirePiece" } })
        T.useMenu(self, self.house, "repair", T.job("pump", PumpJobs.REPAIR_PUMP), true)
        readUntil(self, self.house, "repaired", function(state) return state.record.partCondition > 0 end)
        T.waitForPumpSummary(self, self.house, function(summary) return not summary.burntOut end, "this client's summary of the repair")
        T.readMenu(self, self.house, "repaired")
        T.useMenu(self, self.house, "again", T.job("pump", PumpJobs.REPAIR_PUMP), false)
        T.count(self, "used", { "Base.ElectronicsScrap", "Base.TirePiece", "Base.Screwdriver" })
    end,
    validate = function(self)
        local burnt = self.reads.burnt.after
        expect(burnt.record.partCondition == 0 and burnt.summary.burntOut, "the part is left at "
            .. burnt.record.partCondition)
        expect(not burnt.record.on and not burnt.summary.running, "the burnt-out house is still switched on")
        T.expectWord(self, "burnt", getText("IGUI_EnhancedIrrigation_PartBurntOut", getItemNameFromFullType(APPLIANCE)))
        T.expectRefused(self, "on", "Tooltip_EnhancedIrrigation_PumpBurntOut")
        T.expectOffered(self, "repair")
        local restored = CEILING - Pumps.REPAIR_LOSS
        local repaired = self.reads.repaired.record
        expect(repaired.partCondition == restored and repaired.partCeiling == restored, "the repair left the part at "
            .. repaired.partCondition .. " of " .. repaired.partCeiling)
        T.expectWord(self, "repaired", partWord(APPLIANCE, restored))
        T.expectRefused(self, "again", "Tooltip_EnhancedIrrigation_PumpSound")
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
        self.house = T.placePump(self, spots[1], WOOD, fitted(APPLIANCE))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded", BARREL_LITRES - ROOM)
        T.linkPump(self, self.house, self.tank)
        update(self, self.house, "burnt", { hoursAgo = 1, tank = self.tank,
            fields = { on = true, partCondition = Pumps.PARTS[APPLIANCE].wearPerHour / 4 } })
    end,
    validate = function(self)
        local after = self.reads.burnt.after
        expectNear("the barrel when the part burnt out", after.tank.litres, BARREL_LITRES, T.LITRES)
        expect(after.record.partCondition == 0, "the part is left at " .. after.record.partCondition)
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
        self.house = T.placePump(self, spots[1], METAL, fitted(APPLIANCE))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        T.linkPump(self, self.house, self.tank)
        T.give(self, "tools", { { type = "Base.Screwdriver" }, { type = Valves.TIMER } })
        T.useMenu(self, self.house, "fit", T.job("pump", PumpJobs.FIT_TIMER), true)
        readUntil(self, self.house, "fitted", function(state) return state.record.timer ~= nil end)
        T.waitFor(self, function() return T.hasOverlay(T.overlaysOf(T.copyOf(self.house)), Sprites.HOUSE_TIMER) end,
            "this client's copy of the house showing its timer")
        self.start = (math.floor(getGameTime():getTimeOfDay()) - 2) % 24
        T.useMenu(self, self.house, "set", function(context)
            return T.findOption(context, context, function(option) return option.onSelect == PumpMenu.openTimer end)
        end, true)
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
        T.waitForPumpSummary(self, self.house, function(summary) return summary.timer and summary.timer.minutes == 30 end,
            "this client's summary of the set timer")
        T.readMenu(self, self.house, "set")
        T.useMenu(self, self.house, "take off", T.job("pump", PumpJobs.TAKE_OFF_TIMER), true)
        readUntil(self, self.house, "off", function(state) return state.record.timer == nil end)
        T.read(self, "items.carried", { type = Valves.TIMER }, "carried")
    end,
    validate = function(self)
        local Valves = EnhancedIrrigation.Valves
        T.expectOffered(self, "fit")
        expect(self.reads.fitted.record.timer.item == Valves.TIMER, "the fitted timer is " .. tostring(self.reads.fitted.record.timer.item))
        T.expectOffered(self, "set")
        expect(self.reads.set.record.timer.start == self.start, "the timer starts at " .. tostring(self.reads.set.record.timer.start))
        local hours = self.reads.hours
        expectNear("the barrel after its window", hours.after.tank.litres - hours.before.tank.litres, lifts(APPLIANCE, 0.5), T.LITRES)
        expectNear("the part after its window", hours.before.record.partCondition - hours.after.record.partCondition,
            Pumps.PARTS[APPLIANCE].wearPerHour * 0.5, 0.001)
        expect(not hours.after.record.running, "the house runs outside its timer's window")
        T.expectWord(self, "set", Valves.describe({ item = Valves.TIMER, start = self.start, minutes = 30 }))
        T.expectOffered(self, "take off")
        expect(self.reads.off.record.timer == nil, "Take Off Timer left the timer in the house")
        expect(#self.reads.carried.items == 1, "Take Off Timer gave back " .. #self.reads.carried.items .. " timers")
    end,
})

-- Lines ------------------------------------------------------------------------------------------------

-- Where the line tests set a house, the barrel it draws from beside it, and two line tiles below.
local LINE_SPOTS = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }
-- Litres in that barrel.
local SOURCE_LITRES = 100
local HALF_HOUR = 0.5

-- Queues a Pump House `entity` fitted with a new `part` at spots[1], a lidded barrel of
-- SOURCE_LITRES beside it at spots[2] for its water, and its outlet plumbed to the first of two holed
-- line tiles on spots[3] and spots[4], with dry crops on them. Returns the house, the barrel and the
-- tiles.
local function houseLine(self, spots, entity, part)
    local tiles = { spots[3], spots[4] }
    for _, tile in ipairs(tiles) do
        tile.fields = { holed = true }
    end
    T.placeLine(self, tiles, "iron")
    T.plant(self, tiles[1], 0)
    T.plant(self, tiles[2], 0)
    local house = T.placePump(self, spots[1], entity, fitted(part))
    local barrel = T.placeTank(self, spots[2], "lidded", SOURCE_LITRES)
    T.linkPump(self, house, tiles[1])
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
        self.house, self.barrel, self.tiles = houseLine(self, spots, METAL, UTILITY)
        T.read(self, "tanks.perform", T.at(self.house, { feature = "pump", job = PumpJobs.TURN_ON }), "turned on")
        readUntil(self, self.house, "on", function(state) return state.record.running == true end)
        T.waitForLines(self, self.tiles, "this client's copy of the running line", function(summary) return summary.running end)
        T.useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain running", false)
        -- The crops dried in the same call, so the ten-minute passes since Turn On leave them room.
        update(self, self.house, "half", { hoursAgo = HALF_HOUR, squares = self.tiles, water = 0, tank = self.barrel })
        T.read(self, "tanks.perform", T.at(self.house, { feature = "pump", job = PumpJobs.TURN_OFF }), "off")
        T.waitForLines(self, self.tiles, "this client's copy of the stopped line", function(summary)
            return not summary.running
        end)
        T.useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain stopped", false)
    end,
    validate = function(self)
        expect(self.reads["turned on"].done and self.reads.on.record.running, "Turn On didn't run the house")
        T.expectRefused(self, "drain running", "Tooltip_EnhancedIrrigation_LineRunning")
        local half = self.reads.half
        local each = Lines.HOLE_RATE * Pumps.PARTS[UTILITY].push * HALF_HOUR
        for i = 1, 2 do
            expectNear("crop " .. i .. "'s water", half.after.squares[i].water - half.before.squares[i].water,
                each * Lines.POINTS_PER_LITRE, 0.05)
        end
        expectNear("the barrel's water drawn", half.before.tank.litres - half.after.tank.litres, 2 * each, T.LITRES)
        expectNear("the part's wear", half.before.record.partCondition - half.after.record.partCondition,
            Pumps.PARTS[UTILITY].wearPerHour * HALF_HOUR, 0.001)
        expect(self.reads.off.done, "Turn Off wasn't done")
        T.expectOffered(self, "drain stopped")
    end,
})

-- Hours the houses are away while their chunk is unloaded.
local AWAY_HOURS = 1

-- Two running houses' records wait while their chunk is away, one plumbed to a barrel, one to a
-- line of two holed tiles: the pass leaves each as it was, however long ago it last ran. Loaded
-- again, each runs the whole gap on the grid it still has: the barrel gets the gap's water, and the
-- line's holes push theirs out at the part's push for all of it. Catches a record that lifts into a
-- tank or line it can't see, or forgets the time it was away. The houses are switched on only once
-- away, so no ten-minute pass before the reload runs what the gap doesn't count. The line's house
-- stands clear of the other's well and barrel, which it would draw from instead of its own.
T.test("irrigation_pump_house_catches_up_after_its_chunk_reloads", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves",
    instant = true,
    timeoutSeconds = T.RELOAD_SECONDS,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        local lineSpots = T.layout(self, LINE_SPOTS, { bare = true, indoors = true, joined = true,
            accept = function(squares)
                for _, spot in ipairs(spots) do
                    if math.abs(spot.x - squares[1]:getX()) <= 1 and math.abs(spot.y - squares[1]:getY()) <= 1 then
                        return false
                    end
                end
                return true
            end })
        if not lineSpots then return end
        self.house = T.placePump(self, spots[1], WOOD, fitted(APPLIANCE))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        T.linkPump(self, self.house, self.tank)
        self.lineHouse, self.barrel, self.tiles = houseLine(self, lineSpots, WOOD, APPLIANCE)
        T.server(self, "pumpHouse.update", at(self.house))
        T.server(self, "pumpHouse.update", at(self.lineHouse))
        T.reload(self, T.at(self.house), function()
            update(self, self.house, "away", { hoursAgo = AWAY_HOURS, fields = { on = true } })
            update(self, self.lineHouse, "line away", { hoursAgo = AWAY_HOURS, fields = { on = true } })
        end)
        T.waitFor(self, function()
            for _, handle in ipairs({ self.lineHouse, self.barrel, self.tiles[1], self.tiles[2] }) do
                if not getSquare(handle.x, handle.y, handle.z) then
                    return false
                end
            end
            return true
        end, "this client to load the line's house again", T.LOAD_MS)
        update(self, self.house, "back", { tank = self.tank })
        update(self, self.lineHouse, "line back", { squares = self.tiles, tank = self.barrel })
    end,
    validate = function(self)
        T.expectReloaded(self, "house")
        local away, back = self.reads.away, self.reads.back
        expect(away.after.record.lastHour == away.before.record.lastHour, "the barrel's house ran while away")
        -- From the clock wound back while away to the pass after the reload, whichever pass ran it.
        expectNear("the barrel, back", back.after.tank.litres, lifts(APPLIANCE, back.now - (away.now - AWAY_HOURS)), T.LITRES)
        local lineAway, lineBack = self.reads["line away"], self.reads["line back"]
        expect(lineAway.after.record.lastHour == lineAway.before.record.lastHour, "the line's house ran while away")
        local perHour = 2 * Lines.HOLE_RATE * Pumps.PARTS[APPLIANCE].push
        expectNear("the line's barrel drawn, back", SOURCE_LITRES - lineBack.after.tank.litres,
            perHour * (lineBack.now - (lineAway.now - AWAY_HOURS)), T.LITRES)
        for i = 1, 2 do
            expect((lineBack.after.squares[i].water or 0) > 0, "crop " .. i .. " got no water from the gap")
        end
    end,
})

-- Make Utility Pump ---------------------------------------------------------------------------------------

-- Make Utility Pump from a Blower Fan, at a table, with the skills, the knowledge and exactly a
-- craft's inputs, makes a Utility Pump at the made ceiling, taking the fan, the sheet metal and the
-- hose, two uses of the torch and one of the rods. Catches a recipe the game won't craft, a made
-- pump as good as a found one, or welding that takes whole items. Its surface is a work table by
-- the character, which the scenario sets down and T.placeWorkTable sets down again if it is gone.
T.test("irrigation_pump_house_make_utility_pump", {
    instant = true,
    run = function(self)
        if not T.craft(self, "EnhancedIrrigation_MakeUtilityPump", "Base.BlowerFan",
            { UTILITY, "Base.BlowerFan", "Base.SmallSheetMetal", "Base.RubberHose" }, { workTable = true }) then
            return
        end
        T.read(self, "items.carried", { type = UTILITY }, "made")
        T.read(self, "items.carried", { type = "Base.BlowTorch" }, "torch")
        T.read(self, "items.carried", { type = "Base.WeldingRods" }, "rods")
    end,
    validate = function(self)
        local craft = self.counts.craft or {}
        expect(craft[UTILITY] == 1, "the craft made " .. tostring(craft[UTILITY]) .. " Utility Pumps")
        for _, fullType in ipairs({ "Base.BlowerFan", "Base.SmallSheetMetal", "Base.RubberHose" }) do
            expect(craft[fullType] == 0, "the craft left " .. tostring(craft[fullType]) .. " " .. fullType)
        end
        local made = self.reads.made.items[1]
        expect(made and made.condition == Pumps.MADE_CEILING and made.ceiling == Pumps.MADE_CEILING,
            "the made pump is at " .. tostring(made and made.condition) .. " of " .. tostring(made and made.ceiling))
        local torch, rods = self.reads.torch.items[1], self.reads.rods.items[1]
        local torchFull = math.floor(1 / getScriptManager():getItem("Base.BlowTorch"):getUseDelta() + 0.5)
        local rodsFull = math.floor(1 / getScriptManager():getItem("Base.WeldingRods"):getUseDelta() + 0.5)
        expect(torch and torch.uses == torchFull - 2, "the torch has " .. tostring(torch and torch.uses) .. " uses left")
        expect(rods and rods.uses == rodsFull - 1, "the rods have " .. tostring(rods and rods.uses) .. " uses left")
    end,
})
