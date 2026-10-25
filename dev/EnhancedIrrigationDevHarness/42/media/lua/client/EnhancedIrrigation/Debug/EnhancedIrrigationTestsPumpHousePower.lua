require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibPumps"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/Power"
require "EnhancedIrrigation/Pumps/PumpClient"
require "EnhancedIrrigation/SquareSounds"
require "EnhancedIrrigation/UI/PumpMenu"

-- Houses are placed, plumbed and run for set hours by their own pass from server handlers, so the
-- clock doesn't decide the sums.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Pumps, PumpJobs = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs

local APPLIANCE, UTILITY = Pumps.APPLIANCE_PUMP, Pumps.UTILITY_PUMP
-- How near a generator's fuel comes to the bill: Java keeps it as a float.
local FUEL_TOLERANCE = 0.0005

local fitted, update, readUntil = T.pumpHouseFitted, T.updatePumpHouse, T.readPumpUntil
local lifts = T.pumpLifts

-- The generator fuel `part` burns in `hours`.
local function burns(part, hours)
    return Pumps.PARTS[part].fuel * SandboxVars.GeneratorFuelConsumption * hours
end

-- Houses -------------------------------------------------------------------------------------------------

-- Whether `square` has a neighbour, north, south, east or west, in a room: what lets the grid power
-- an appliance outdoors (ItemContainer.isSquarePowered).
local function besideRoom(square)
    for _, step in ipairs({ { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } }) do
        local neighbour = getSquare(square:getX() + step[1], square:getY() + step[2], square:getZ())
        if neighbour and neighbour:getRoom() then
            return true
        end
    end
    return false
end

-- A handle of a square beside `square`, on its floor, that is outdoors with nothing but its floor,
-- not taken by the test nor the character's own, taken when `take`; or nil.
local function bareBeside(self, square, take)
    for dx = -1, 1 do
        for dy = -1, 1 do
            local other = getSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            if other and other ~= square and not self.used[other] and other:isOutside() and other:isFree(false)
                    and other:getObjects():size() == 1 and other ~= T.player():getCurrentSquare() then
                if take then
                    self.used[other] = true
                end
                return T.where(other)
            end
        end
    end
    return nil
end

-- Power ---------------------------------------------------------------------------------------------------

-- On open ground with no room beside it, the grid on, a fitted house has no power: Turn On is greyed
-- out saying so, the server refuses it too, and switched on anyway an hour lifts nothing and it
-- isn't running. Catches grid power where vanilla gives an appliance none.
T.test("irrigation_pump_house_power_refuses_the_grid_in_the_open", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true,
            accept = function(squares) return not besideRoom(squares[1]) end })
        if not spots then return end
        self.house, self.tank = T.plumbedPump(self, spots, T.WOOD, fitted(APPLIANCE))
        T.useMenu(self, self.house, "on", T.job("pump", PumpJobs.TURN_ON), false)
        T.read(self, "jobs.perform", T.at(self.house, { feature = "pump", job = PumpJobs.TURN_ON }), "forced")
        update(self, self.house, "hour", { hoursAgo = 1, fields = { on = true }, tank = self.tank })
    end,
    validate = function(self)
        T.expectOptionRefused(self, "on", "IGUI_RadioRequiresPowerNearby")
        expect(self.reads.forced.done == false, "the server switched the unpowered house on")
        local after = self.reads.hour.after
        expectNear("the tank after an hour unpowered", after.tank.litres, 0, T.LITRES)
        expect(not after.summary.running, "the unpowered house runs")
    end,
})

-- Outdoors beside a house's wall, the grid on: Turn On from the menu runs it, this client hums with
-- it, and an hour lifts the Appliance Pump's rate of the well's water into the barrel, wearing the
-- part by an hour's wear; the menu says it runs. Turn Off stops it and the hum. Catches a house the
-- grid can't run beside a room, water at the wrong rate, wear that isn't by the hour, or a hum that
-- doesn't follow the switch. This client looks for running houses every frame while it lasts, not
-- every SquareSounds.CHECK_MS.
T.test("irrigation_pump_house_power_runs_on_the_grid_beside_a_room", {
    instant = true,
    run = function(self)
        local SquareSounds = EnhancedIrrigation.SquareSounds
        local checkMs = SquareSounds.CHECK_MS
        SquareSounds.CHECK_MS = 0
        T.defer(self, function() SquareSounds.CHECK_MS = checkMs end)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, accept = function(squares)
            return besideRoom(squares[1]) and bareBeside(self, squares[1]) ~= nil
        end })
        if not spots then return end
        -- The well beside the house; the barrel anywhere the pipe reaches.
        spots[2] = bareBeside(self, spots[1].square, true)
        spots[3] = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots[3] then return end
        spots[3] = spots[3][1]
        self.house, self.tank = T.plumbedPump(self, spots, T.METAL, fitted(APPLIANCE))
        T.useMenu(self, self.house, "on", T.job("pump", PumpJobs.TURN_ON), true)
        readUntil(self, self.house, "on", function(state) return state.record.running == true end)
        T.waitForPumpSummary(self, self.house, function(summary) return summary.running end, "this client's summary of the running house")
        T.waitFor(self, function()
            return EnhancedIrrigation.PumpClient.isHumming(self.house.x, self.house.y, self.house.z)
        end, "this client's hum of the running house")
        update(self, self.house, "hour", { hoursAgo = 1, tank = self.tank })
        T.readMenu(self, function() return T.copyOf(self.house) end, "running")
        T.useMenu(self, self.house, "off", T.job("pump", PumpJobs.TURN_OFF), true)
        readUntil(self, self.house, "off", function(state) return not state.record.on end)
        T.waitForPumpSummary(self, self.house, function(summary) return not summary.running end, "this client's summary of the stopped house")
        T.waitFor(self, function()
            return not EnhancedIrrigation.PumpClient.isHumming(self.house.x, self.house.y, self.house.z)
        end, "this client's hum to stop")
    end,
    validate = function(self)
        T.expectOffered(self, "on")
        local hour = self.reads.hour
        -- From the state before, in the same call: a ten-minute pass may have run the house since
        -- Turn On.
        expectNear("the barrel after an hour", hour.after.tank.litres - hour.before.tank.litres, lifts(APPLIANCE, 1), T.LITRES)
        expect(not hour.after.tank.tainted, "the well's water came out tainted")
        expectNear("the part after an hour", hour.before.record.partCondition - hour.after.record.partCondition,
            Pumps.PARTS[APPLIANCE].wearPerHour, 0.001)
        T.expectWord(self, "running", getText("IGUI_EnhancedIrrigation_Running"))
        T.expectOffered(self, "off")
        expect(not self.reads.off.record.on, "Turn Off left the house switched on")
    end,
})

-- Hours the generator test runs: long enough that its bill stands well clear of the float's slack.
local GENERATOR_HOURS = 2

-- The grid off, a generator a few tiles off running: Turn On is offered and runs a Utility Pump,
-- and two hours burn its draw at the sandbox's rate from the generator, whose reach pays for it, the
-- full barrel stopping the water but not the pump, which wears as it does lifting. Catches a
-- generator that runs a house for nothing, or a full tank that stops the bill or wears the part as
-- if its source were dry.
T.test("irrigation_pump_house_power_runs_on_a_generator_and_burns_its_fuel", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.generator = spots[4]
        T.server(self, "pumpHouse.generator", T.at(self.generator, { fuel = 5 }))
        self.house, self.tank = T.plumbedPump(self, spots, T.WOOD, fitted(UTILITY))
        T.waitFor(self, function() return EnhancedIrrigation.Power.powered(T.copyOf(self.house)) end,
            "this client's power from the generator")
        T.useMenu(self, self.house, "on", T.job("pump", PumpJobs.TURN_ON), true)
        readUntil(self, self.house, "on", function(state) return state.record.running == true end)
        update(self, self.house, "hours", { hoursAgo = GENERATOR_HOURS, tank = self.tank, generator = self.generator })
    end,
    validate = function(self)
        T.expectOffered(self, "on")
        local hours = self.reads.hours
        expectNear("the generator's fuel after the hours", hours.after.generator.fuel,
            hours.before.generator.fuel - burns(UTILITY, GENERATOR_HOURS), FUEL_TOLERANCE)
        local payer = hours.after.record.payer
        expect(payer and payer.x == self.generator.x and payer.y == self.generator.y, "the house's payer is "
            .. (payer and payer.x .. "," .. payer.y or "nothing"))
        expectNear("the barrel after the hours", hours.after.tank.litres, T.BARREL_LITRES, T.LITRES)
        expect(hours.after.summary.running, "the house stopped at the full barrel")
        expectNear("the part after the hours", hours.before.record.partCondition - hours.after.record.partCondition,
            Pumps.PARTS[UTILITY].wearPerHour * GENERATOR_HOURS, 0.001)
    end,
})

-- The fuel the debt test's payer had when the house last saw it: more than an hour's bill.
local PAYER_FUEL = 5

-- The grid off, a running Utility Pump's house powered by a generator in reach, its payer the
-- generator it last saw, on a square that isn't loaded, as one in a chunk the character left: an
-- hour bills that payer, the house owing it the hour's fuel, and the generator in reach burns none.
-- Switched off, it pays the debt once its payer is loaded again. Catches hours run on an away
-- payer's power for nothing or billed to another generator, or a debt that waits until the house
-- runs again. The payer stands a storey up, where a square exists only once something stands there.
T.test("irrigation_pump_house_power_pays_its_debt_switched_off", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true, accept = function(squares)
            return getSquare(squares[1]:getX(), squares[1]:getY(), squares[1]:getZ() + 1) == nil
        end })
        if not spots then return end
        self.generator = spots[2]
        self.payer = { x = spots[1].x, y = spots[1].y, z = spots[1].z + 1 }
        T.server(self, "pumpHouse.generator", T.at(self.generator, { fuel = 5 }))
        self.house = T.placePump(self, spots[1], T.WOOD, fitted(UTILITY))
        T.waitFor(self, function() return EnhancedIrrigation.Power.powered(T.copyOf(self.house)) end,
            "this client's power from the generator")
        update(self, self.house, "away", { hoursAgo = 1, generator = self.generator,
            fields = { on = true, payer = T.at(self.payer), payerFuel = PAYER_FUEL } })
        T.read(self, "jobs.perform", T.at(self.house, { feature = "pump", job = PumpJobs.TURN_OFF }), "off")
        readUntil(self, self.house, "owing", function(state) return not state.record.on end)
        T.read(self, "pumpHouse.generator", T.at(self.payer, { fuel = PAYER_FUEL }), "payer")
        update(self, self.house, "paid", { generator = self.payer })
    end,
    validate = function(self)
        local away = self.reads.away
        expectNear("the fuel the house owes its away payer", (away.after.record.owedFuel or 0)
            - (away.before.record.owedFuel or 0), burns(UTILITY, 1), FUEL_TOLERANCE)
        expectNear("the fuel of the generator in reach", away.after.generator.fuel, away.before.generator.fuel, FUEL_TOLERANCE)
        local owing = self.reads.owing.record
        expect(self.reads.off.done and not owing.on, "Turn Off left the house switched on")
        -- From the payer's fuel as set down: the house's next pass, its own or the test's, pays.
        local paid = self.reads.paid.after
        expectNear("the payer's fuel once the debt is paid", paid.generator.fuel,
            self.reads.payer.fuel - (owing.owedFuel or 0), FUEL_TOLERANCE)
        expect(paid.record.owedFuel == nil, "the house still owes " .. tostring(paid.record.owedFuel))
    end,
})

-- Hours the spent generator's fuel runs the Appliance Pump.
local FUEL_HOURS = 1.5

-- A generator with an hour and a half of the Appliance Pump's draw in it runs the house three hours
-- behind for that long and no more: the barrel gets that time's water, the generator is empty and
-- off, and the menu says the house has no power. Catches a pass that runs past the fuel, or a
-- generator left running empty.
T.test("irrigation_pump_house_power_stops_when_its_generator_is_spent", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.generator = spots[4]
        T.server(self, "pumpHouse.generator", T.at(self.generator, { fuel = burns(APPLIANCE, FUEL_HOURS) }))
        self.house, self.tank = T.plumbedPump(self, spots, T.WOOD, fitted(APPLIANCE, { on = true }))
        update(self, self.house, "spent", { hoursAgo = 2 * FUEL_HOURS, tank = self.tank, generator = self.generator })
        T.waitForPumpSummary(self, self.house, function(summary) return not summary.running end, "this client's summary of the stopped house")
        T.readMenu(self, function() return T.copyOf(self.house) end, "spent")
    end,
    validate = function(self)
        local before, after = self.reads.spent.before, self.reads.spent.after
        -- The fuel read in the same call: the generator burns its own at each hour's turn.
        expectNear("the barrel after the fuel ran out", after.tank.litres - before.tank.litres,
            lifts(APPLIANCE, before.generator.fuel / burns(APPLIANCE, 1)), T.LITRES)
        expect(after.generator.fuel == 0 and not after.generator.running, "the generator is left at "
            .. after.generator.fuel .. (after.generator.running and ", running" or ", off"))
        T.expectWord(self, "spent", getText("IGUI_EnhancedIrrigation_NoPower"))
    end,
})

-- A storey up over open ground, beside a well on that floor, a generator below in reach: an hour
-- switched on lifts the Appliance Pump's rate into a barrel on the ground. Above the ground a square
-- exists only where something stands, so the squares around the house are missing though their
-- chunk is loaded. Catches a raised house that waits for them and never runs.
T.test("irrigation_pump_house_power_runs_a_storey_up", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 3, 0 } }, { bare = true,
            accept = function(squares)
                return getSquare(squares[1]:getX(), squares[1]:getY(), squares[1]:getZ() + 1) == nil
            end })
        if not spots then return end
        self.generator = spots[4]
        T.server(self, "pumpHouse.generator", T.at(self.generator, { fuel = 5 }))
        local above = { x = spots[1].x, y = spots[1].y, z = spots[1].z + 1 }
        self.house, self.tank = T.plumbedPump(self, { above, spots[2], spots[3] }, T.WOOD,
            fitted(APPLIANCE, { on = true }), { source = "wellAbove" })
        update(self, self.house, "hour", { hoursAgo = 1, tank = self.tank })
    end,
    validate = function(self)
        local hour = self.reads.hour
        expectNear("the barrel after an hour a storey up", hour.after.tank.litres - hour.before.tank.litres,
            lifts(APPLIANCE, 1), T.LITRES)
    end,
})

-- Time away -----------------------------------------------------------------------------------------------

-- Hours before the shutoff the gap runs the house: less than the barrel holds.
local BEFORE_SHUTOFF = 1
-- TimeSinceApo's choice of a world joined a month into the apocalypse (its first is none), so the
-- grid's days, which count from the apocalypse, aren't the world's own.
local A_MONTH_IN = 2

-- Indoors, running on the grid at its last pass; then the grid shuts off, and a pass that finds
-- the house a while past the shutoff runs it for the part of the gap before it only. Catches a gap
-- run on a grid that is gone, one the shutoff throws away whole, or a shutoff at another hour than
-- vanilla's, such as one that leaves out the months before the world began.
T.test("irrigation_pump_house_power_grid_runs_a_gap_until_the_shutoff", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        T.setSandbox(self, "TimeSinceApo", A_MONTH_IN)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house, self.tank = T.plumbedPump(self, spots, T.METAL, fitted(APPLIANCE, { on = true }))
        update(self, self.house, "lit", {})
        T.read(self, "pumpHouse.shutoff", {}, "shutoff")
        T.step(function()
            local shutoff = self.reads.shutoff
            self.gap = shutoff.now - shutoff.shutoff + BEFORE_SHUTOFF
            update(self, self.house, "gap", { hoursAgo = self.gap, tank = self.tank })
        end)
    end,
    validate = function(self)
        expect(self.reads.lit.after.record.grid, "the grid didn't power the house at its last pass")
        local shutoff, gap = self.reads.shutoff, self.reads.gap
        expect(not shutoff.grid, "the grid is still on after its shutoff")
        local from = gap.now - self.gap
        -- Within a minute's water: the clock a multiplayer server reports between two answers
        -- drifts by seconds against the hour the shutoff was set to.
        expectNear("the barrel after the gap", gap.after.tank.litres - gap.before.tank.litres,
            lifts(APPLIANCE, shutoff.shutoff - from), lifts(APPLIANCE, 1 / 60))
    end,
})

-- Renewable Energy ------------------------------------------------------------------------------------

-- What a Utility Pump's house tells a Renewable Energy bank it draws (PumpHouse.bankDraw, which
-- the bank's scan asks when that mod is loaded), with no power, as a bank that cut it for an
-- overload leaves it: its part's draw under the house's own load label while it is switched on or
-- its timer is open and nothing else pays; nothing while a vanilla generator pays for it, so the
-- two never both bill one run, nor while it is off with its timer shut, nor once its part is burnt
-- out, its timer still open. Catches a house a bank powers for free, one billed twice or for a part
-- that can't run, or one an overloaded bank loses sight of and powers again.
T.test("irrigation_pump_house_power_tells_a_bank_what_it_draws", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.house = T.placePump(self, spots[1], T.WOOD, fitted(UTILITY))
        local timer = EnhancedIrrigation.Valves.TIMER
        T.read(self, "pumpHouse.bankDraw", T.at(self.house, { cases = {
            { on = true },
            { timer = { item = timer, openNow = true } },
            { on = true, payer = T.at(spots[1]) },
            { timer = { item = timer, start = 0, minutes = 0 } },
            { timer = { item = timer, openNow = true }, partCondition = 0 },
        } }), "draws")
    end,
    validate = function(self)
        local draws = self.reads.draws.draws
        for i, what in ipairs({ "the switched-on house", "the house in its timer's window" }) do
            expect(draws[i].kind == "IGUI_EnhancedIrrigation_PumpHouseLoad", what .. " reports the load " .. tostring(draws[i].kind))
            expectNear(what .. "'s draw", draws[i].fuel or 0, Pumps.PARTS[UTILITY].fuel, 0.0001)
        end
        expect(draws[3].kind == nil, "a house a generator pays for also bills the bank")
        expect(draws[4].kind == nil, "a house off with its timer unset bills the bank")
        expect(draws[5].kind == nil, "a burnt-out house in its timer's window bills the bank")
    end,
})
