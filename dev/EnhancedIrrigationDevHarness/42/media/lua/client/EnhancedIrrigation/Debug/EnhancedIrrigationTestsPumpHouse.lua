require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISToggleClothingWasher"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/PumpJobs"
require "EnhancedIrrigation/ApplianceJobs"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/Pumps/PumpClient"
require "EnhancedIrrigation/UI/PumpMenu"
require "EnhancedIrrigation/UI/ApplianceMenu"
require "EnhancedIrrigation/UI/LineMenu"

-- The Pump Houses and their parts (Pumps.lua, PumpJobs.lua, Pumps/PumpHouse.lua, PumpObject.lua,
-- PumpSystem.lua, PumpClient.lua, PumpMenu.lua, their entities in Entities.txt), Salvage Pump
-- (Appliances.lua, ApplianceJobs.lua, ApplianceSystem.lua, ApplianceMenu.lua) and Make Utility Pump
-- (Recipes.txt): building the houses from the build menu, fitting and taking out a part, the
-- switch, running on the grid beside a room and on a generator that pays for it in fuel, a dry
-- source and burning out, Repair Pump, the time a house was away and the grid's shutoff, a
-- garden line a house drives, a washer's pump salvaged, and a Utility Pump made. Houses are placed
-- and plumbed by EnhancedIrrigationTestServerPumps.lua's handlers, and run for set hours by its own
-- pass from EnhancedIrrigationTestServerPumpHouse.lua's and EnhancedIrrigationTestServerSprinklers.lua's,
-- so the clock doesn't decide the sums.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Pumps, PumpJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs
local ApplianceJobs, Lines, LineJobs = EnhancedIrrigation.ApplianceJobs, EnhancedIrrigation.Lines, EnhancedIrrigation.LineJobs

local LITRES = 0.05
local WOOD, METAL = "EnhancedIrrigation_PumpHouseWood", "EnhancedIrrigation_PumpHouseMetal"
local SPRITES = { [WOOD] = Sprites.PUMP_HOUSE_WOOD, [METAL] = Sprites.PUMP_HOUSE_METAL }
local APPLIANCE, UTILITY = Pumps.APPLIANCE_PUMP, Pumps.UTILITY_PUMP
-- A raised barrel's water: vanilla's round rain barrel's.
local BARREL_LITRES = 600
-- A washing machine, as vanilla's tile makes one (IsoClothingWasher), and a washer-dryer
-- (IsoCombinationWasherDryer).
local WASHER, COMBO = "appliances_laundry_01_4", "appliances_laundry_01_0"
-- How near a generator's fuel comes to the bill: Java keeps it as a float.
local FUEL = 0.0005

-- Houses -------------------------------------------------------------------------------------------------

local function copyOf(house)
    return T.objectWithSprite(getSquare(house.x, house.y, house.z), house.sprite)
end

local function summaryOf(house)
    local copy = copyOf(house)
    return copy and Pumps.summaryOf(copy)
end

-- The record's fields of a new part fitted: `part` (a full type) at full condition.
local function fitted(part, fields)
    local all = { part = part, partCondition = Pumps.PART_CONDITION, partCeiling = Pumps.PART_CONDITION }
    for key, value in pairs(fields or {}) do
        all[key] = value
    end
    return all
end

--- Queues placing the Pump House `entity` at `handle` with `fields` on its record, and a wait for
--- this client's copy and its summary. Returns its handle.
local function placeHouse(self, handle, entity, fields)
    local house = { x = handle.x, y = handle.y, z = handle.z, sprite = SPRITES[entity], square = handle.square }
    T.server(self, "pumps.place", T.at(house, { sprite = house.sprite, fields = fields }))
    T.waitFor(self, function() return summaryOf(house) ~= nil end, "this client's copy of the " .. entity)
    return house
end

-- Queues plumbing the house's outlet to `tank` on the server and a wait for this client to know.
local function link(self, house, tank)
    T.server(self, "pumps.link", T.at(house, { tank = T.at(tank) }))
    T.waitFor(self, function() return Pumps.outletOf(T.at(house)) ~= nil end, "this client's copy of the outlet")
end

-- The args of a server handler at the house, with the tank and generator to read.
local function at(house, extra)
    return T.at(house, {
        tank = extra and extra.tank and T.at(extra.tank) or nil,
        generator = extra and extra.generator and T.at(extra.generator) or nil,
        hoursAgo = extra and extra.hoursAgo,
        fields = extra and extra.fields,
    })
end

-- Queues the house's ten-minute pass on the server, `extra.hoursAgo` hours after its last, with
-- `extra.fields` set first, into self.reads[label] ({ now, before, after }).
local function update(self, house, label, extra)
    T.read(self, "pumpHouse.update", at(house, extra), label)
end

local function readUntil(self, house, label, done, extra)
    T.readUntil(self, "pumpHouse.state", at(house, extra), label, done)
end

local function waitForSummary(self, house, holds, what)
    T.waitFor(self, function()
        local summary = summaryOf(house)
        return summary ~= nil and holds(summary)
    end, what)
end

local function job(id, with)
    return function(context) return T.jobOption(context, "pump", id, with) end
end

local function useMenu(self, house, label, find, choose)
    T.goNextTo(self, house.square)
    T.useOption(self, function() return copyOf(house) end, label, find, choose)
end

-- Queues the names of every option in the world menu of `getObject()` into self.names[label].
local function readMenu(self, getObject, label)
    self.names = self.names or {}
    T.step(function()
        local object = getObject()
        local context = T.need(self, object and T.worldMenu(object), "a world menu for " .. label)
        if not context then return end
        local names = {}
        T.findOption(context, context, function(option)
            table.insert(names, option.name)
            return false
        end)
        self.names[label] = names
        context:hideAndChildren()
    end)
end

-- Expects a line of the menu self.names[label] read to list `word` whole among the words of the
-- status line.
local function expectWord(self, label, word)
    local found = false
    for _, name in ipairs(self.names and self.names[label] or {}) do
        for part in (name .. ", "):gmatch("(.-), ") do
            found = found or part == word
        end
    end
    expect(found, label .. ": the menu's status doesn't list " .. word)
end

local function partWord(part, condition)
    return getText("IGUI_EnhancedIrrigation_PartCondition", getItemNameFromFullType(part), condition)
end

-- The litres `part` lifts in `hours`.
local function lifts(part, hours)
    return Pumps.PARTS[part].rate * 60 * hours
end

-- The generator fuel `part` burns in `hours`.
local function burns(part, hours)
    return Pumps.PARTS[part].draw * SandboxVars.GeneratorFuelConsumption * hours
end

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
            self.house = T.buildFromMenu(self, "Base." .. case.entity, spots[1], SPRITES[case.entity])
            if not self.house then return end
            readUntil(self, self.house, "built", function(state) return state.record ~= nil end)
            T.count(self, "left", { "Base.ElectricWire", "Base.RubberHose" })
            waitForSummary(self, self.house, function() return true end, "this client's summary of the built house")
            readMenu(self, function() return copyOf(self.house) end, "built")
            useMenu(self, self.house, "on", job(PumpJobs.TURN_ON), false)
        end,
        validate = function(self)
            expect(self.canBuild and self.validSquare, "the build menu can't build the house from its materials on a bare square")
            local record = self.reads.built.record
            if not expect(record, "the built house has no record") then return end
            expect(record.unit == case.entity and record.part == nil, "the built house is " .. tostring(record.unit)
                .. " with " .. tostring(record.part) .. " in it")
            local left = self.counts.left
            expect(left["Base.ElectricWire"] == 0 and left["Base.RubberHose"] == 0, "building left wire or hose")
            expectWord(self, "built", getText("IGUI_EnhancedIrrigation_NoPumpFitted"))
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
        self.house = placeHouse(self, spots[1], WOOD)
        T.give(self, "parts", { { type = "Base.Screwdriver" },
            { type = APPLIANCE, condition = WORN, modData = { [Pumps.CEILING_KEY] = CEILING } } })
        useMenu(self, self.house, "fit", function(context)
            return T.jobOption(context, "pump", PumpJobs.FIT_PUMP, self.items.parts[2])
        end, true)
        readUntil(self, self.house, "fitted", function(state) return state.record.part ~= nil end)
        waitForSummary(self, self.house, function(summary) return summary.part ~= nil end, "this client's summary of the part")
        readMenu(self, function() return copyOf(self.house) end, "fitted")
        useMenu(self, self.house, "take out", job(PumpJobs.TAKE_OUT_PUMP), true)
        readUntil(self, self.house, "taken", function(state) return state.record.part == nil end)
        T.read(self, "pumpHouse.carried", { type = APPLIANCE }, "carried")
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
        expectWord(self, "fitted", partWord(APPLIANCE, WORN))
        T.expectOffered(self, "take out")
        local items = self.reads.carried.items
        expect(#items == 1 and items[1].condition == WORN and items[1].ceiling == CEILING, "the server's part came back as "
            .. (items[1] and (items[1].condition .. " of " .. items[1].ceiling) or "nothing"))
        expect(self.back and self.back:getCondition() == WORN and Pumps.ceilingOf(self.back) == CEILING,
            "this client's part came back at " .. tostring(self.back and self.back:getCondition()))
    end,
})

-- What a part's wear leaves past its last whole point.
local FRACTION = 0.2

-- Take Out Pump of a part worn to a fraction of a point gives it back at the whole points below,
-- on both sides, and Fit Pump puts it back in at the fraction it had: taking a part out and in
-- again never gains it condition. Catches a part handed back rounded up, a free hour's wear on
-- every Take Out.
T.test("irrigation_pump_house_take_out_keeps_a_fraction_of_wear", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.house = placeHouse(self, spots[1], WOOD, fitted(APPLIANCE, { partCondition = WORN + FRACTION }))
        T.give(self, "tools", { { type = "Base.Screwdriver" } })
        useMenu(self, self.house, "take out", job(PumpJobs.TAKE_OUT_PUMP), true)
        readUntil(self, self.house, "taken", function(state) return state.record.part == nil end)
        T.read(self, "pumpHouse.carried", { type = APPLIANCE }, "carried")
        T.waitFor(self, function()
            self.back = T.player():getInventory():getFirstTypeRecurse(APPLIANCE)
            return self.back ~= nil
        end, "this client's copy of the part taken out")
        T.step(function() self.backCondition = self.back:getCondition() end)
        useMenu(self, self.house, "fit", function(context)
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

-- Power ---------------------------------------------------------------------------------------------------

-- On open ground with no room beside it, the grid on, a fitted house has no power: Turn On is greyed
-- out saying so, the server refuses it too, and switched on anyway an hour lifts nothing and it
-- isn't running. Catches grid power where vanilla gives an appliance none.
T.test("irrigation_pump_house_refuses_the_grid_in_the_open", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true,
            accept = function(squares) return not besideRoom(squares[1]) end })
        if not spots then return end
        self.house = placeHouse(self, spots[1], WOOD, fitted(APPLIANCE))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.house, self.tank)
        useMenu(self, self.house, "on", job(PumpJobs.TURN_ON), false)
        T.read(self, "tanks.perform", T.at(self.house, { feature = "pump", job = PumpJobs.TURN_ON }), "forced")
        update(self, self.house, "hour", { hoursAgo = 1, fields = { on = true }, tank = self.tank })
    end,
    validate = function(self)
        T.expectRefused(self, "on", "IGUI_RadioRequiresPowerNearby")
        expect(self.reads.forced.done == false, "the server switched the unpowered house on")
        local after = self.reads.hour.after
        expectNear("the tank after an hour unpowered", after.tank.litres, 0, LITRES)
        expect(not after.summary.running, "the unpowered house runs")
    end,
})

-- Outdoors beside a house's wall, the grid on: Turn On from the menu runs it, this client hums with
-- it, and an hour lifts the Appliance Pump's rate of the well's water into the barrel, wearing the
-- part by an hour's wear; the menu says it runs. Turn Off stops it and the hum. Catches a house the
-- grid can't run beside a room, water at the wrong rate, wear that isn't by the hour, or a hum that
-- doesn't follow the switch. This client looks for running houses every frame while it lasts,
-- rather than every PumpClient.CHECK_MS.
T.test("irrigation_pump_house_runs_on_the_grid_beside_a_room", {
    instant = true,
    run = function(self)
        local PumpClient = EnhancedIrrigation.PumpClient
        local checkMs = PumpClient.CHECK_MS
        PumpClient.CHECK_MS = 0
        T.defer(self, function() PumpClient.CHECK_MS = checkMs end)
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
        self.house = placeHouse(self, spots[1], METAL, fitted(APPLIANCE))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.house, self.tank)
        useMenu(self, self.house, "on", job(PumpJobs.TURN_ON), true)
        readUntil(self, self.house, "on", function(state) return state.record.running == true end)
        waitForSummary(self, self.house, function(summary) return summary.running end, "this client's summary of the running house")
        T.waitFor(self, function()
            return EnhancedIrrigation.PumpClient.isHumming(self.house.x, self.house.y, self.house.z)
        end, "this client's hum of the running house")
        update(self, self.house, "hour", { hoursAgo = 1, tank = self.tank })
        readMenu(self, function() return copyOf(self.house) end, "running")
        useMenu(self, self.house, "off", job(PumpJobs.TURN_OFF), true)
        readUntil(self, self.house, "off", function(state) return not state.record.on end)
        waitForSummary(self, self.house, function(summary) return not summary.running end, "this client's summary of the stopped house")
        T.waitFor(self, function()
            return not EnhancedIrrigation.PumpClient.isHumming(self.house.x, self.house.y, self.house.z)
        end, "this client's hum to stop")
    end,
    validate = function(self)
        T.expectOffered(self, "on")
        local hour = self.reads.hour
        -- From the state before, in the same call: a ten-minute pass may have run the house since
        -- Turn On.
        expectNear("the barrel after an hour", hour.after.tank.litres - hour.before.tank.litres, lifts(APPLIANCE, 1), LITRES)
        expect(not hour.after.tank.tainted, "the well's water came out tainted")
        expectNear("the part after an hour", hour.before.record.partCondition - hour.after.record.partCondition,
            Pumps.PARTS[APPLIANCE].wearPerHour, 0.001)
        expectWord(self, "running", getText("IGUI_EnhancedIrrigation_Running"))
        T.expectOffered(self, "off")
    end,
})

-- Hours the generator test runs: long enough that its bill stands well clear of the float's slack.
local GENERATOR_HOURS = 2
-- Fuel the generator test's house owes from a time its generator wasn't loaded.
local OWED = 0.5

-- The grid off, a generator a few tiles off running: Turn On is offered and runs a Utility Pump,
-- and two hours burn its draw at the sandbox's rate from the generator, whose reach pays for it, the
-- full barrel stopping the water but not the pump. Fuel the house owes is taken once its generator
-- is loaded. Catches a generator that runs a house for nothing, a full tank that stops the bill, or
-- a debt never paid.
T.test("irrigation_pump_house_runs_on_a_generator_and_burns_its_fuel", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.generator = spots[4]
        T.read(self, "pumpHouse.generator", T.at(self.generator, { fuel = 5 }), "generator")
        self.house = placeHouse(self, spots[1], WOOD, fitted(UTILITY))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.house, self.tank)
        T.waitFor(self, function() return Pumps.powered(copyOf(self.house)) end, "this client's power from the generator")
        useMenu(self, self.house, "on", job(PumpJobs.TURN_ON), true)
        readUntil(self, self.house, "on", function(state) return state.record.running == true end)
        update(self, self.house, "hours", { hoursAgo = GENERATOR_HOURS, tank = self.tank, generator = self.generator })
        update(self, self.house, "owed", { fields = { owedFuel = OWED }, generator = self.generator })
    end,
    validate = function(self)
        T.expectOffered(self, "on")
        local hours = self.reads.hours
        expectNear("the generator's fuel after the hours", hours.after.generator.fuel,
            hours.before.generator.fuel - burns(UTILITY, GENERATOR_HOURS), FUEL)
        local payer = hours.after.record.payer
        expect(payer and payer.x == self.generator.x and payer.y == self.generator.y, "the house's payer is "
            .. (payer and payer.x .. "," .. payer.y or "nothing"))
        expectNear("the barrel after the hours", hours.after.tank.litres, BARREL_LITRES, LITRES)
        expect(hours.after.summary.running, "the house stopped at the full barrel")
        local owed = self.reads.owed
        expectNear("the generator's fuel once the debt is paid", owed.after.generator.fuel,
            owed.before.generator.fuel - OWED, FUEL)
        expect(owed.after.record.owedFuel == nil, "the house still owes " .. tostring(owed.after.record.owedFuel))
    end,
})

-- A house switched off, still owing fuel from a time its generator wasn't loaded, pays it at its
-- next pass with the generator loaded. Catches a debt that waits until the house runs off the grid
-- again.
T.test("irrigation_pump_house_pays_its_debt_switched_off", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.generator = spots[2]
        T.read(self, "pumpHouse.generator", T.at(self.generator, { fuel = 5 }), "generator")
        self.house = placeHouse(self, spots[1], WOOD, fitted(UTILITY))
        update(self, self.house, "owed", { fields = { payer = T.at(self.generator), owedFuel = OWED },
            generator = self.generator })
    end,
    validate = function(self)
        local owed = self.reads.owed
        expect(not owed.after.record.on, "the house switched itself on")
        expectNear("the generator's fuel once the debt is paid", owed.after.generator.fuel,
            owed.before.generator.fuel - OWED, FUEL)
        expect(owed.after.record.owedFuel == nil, "the house still owes " .. tostring(owed.after.record.owedFuel))
    end,
})

-- Hours the spent generator's fuel runs the Appliance Pump.
local FUEL_HOURS = 1.5

-- A generator with an hour and a half of the Appliance Pump's draw in it runs the house three hours
-- behind for that long and no more: the barrel gets that time's water, the generator is empty and
-- off, and the menu says the house has no power. Catches a pass that runs past the fuel, or a
-- generator left running empty.
T.test("irrigation_pump_house_stops_when_its_generator_is_spent", {
    instant = true,
    run = function(self)
        T.setGrid(self, false)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.generator = spots[4]
        T.read(self, "pumpHouse.generator", T.at(self.generator, { fuel = burns(APPLIANCE, FUEL_HOURS) }), "generator")
        self.house = placeHouse(self, spots[1], WOOD, fitted(APPLIANCE, { on = true }))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.house, self.tank)
        update(self, self.house, "spent", { hoursAgo = 2 * FUEL_HOURS, tank = self.tank, generator = self.generator })
        waitForSummary(self, self.house, function(summary) return not summary.running end, "this client's summary of the stopped house")
        readMenu(self, function() return copyOf(self.house) end, "spent")
    end,
    validate = function(self)
        local before, after = self.reads.spent.before, self.reads.spent.after
        -- The fuel read in the same call: the generator burns its own at each hour's turn.
        expectNear("the barrel after the fuel ran out", after.tank.litres - before.tank.litres,
            lifts(APPLIANCE, before.generator.fuel / burns(APPLIANCE, 1)), LITRES)
        expect(after.generator.fuel == 0 and not after.generator.running, "the generator is left at "
            .. after.generator.fuel .. (after.generator.running and ", running" or ", off"))
        expectWord(self, "spent", getText("IGUI_EnhancedIrrigation_NoPower"))
    end,
})

-- Wear -------------------------------------------------------------------------------------------------

-- Indoors on the grid, beside a dry barrel: two hours wear the Appliance Pump ten times as fast as
-- running wet. Catches a dry pump that wears as if it lifted water.
T.test("irrigation_pump_house_dry_source_wears_it_fast", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house = placeHouse(self, spots[1], WOOD, fitted(APPLIANCE, { on = true }))
        T.placeTank(self, spots[2], "ground", 0)
        update(self, self.house, "dry", { hoursAgo = 2 })
    end,
    validate = function(self)
        local dry = self.reads.dry
        -- From the state before, in the same call: a ten-minute pass may have run the house since it
        -- was placed.
        expectNear("the part after two dry hours", dry.before.record.partCondition - dry.after.record.partCondition,
            2 * Pumps.PARTS[APPLIANCE].wearPerHour * Pumps.DRY_WEAR, 0.001)
    end,
})

-- Condition the nearly burnt-out part has left: half an hour run dry.
local LAST_CONDITION = 5

-- A part with its last few points run dry burns out within the hour: the house switches itself off,
-- the menu says the part is burnt out and greys Turn On out. Repair Pump with Electricity 2, a
-- screwdriver, Scrap Electronics and a Tire Piece restores it to a ceiling lowered by a repair's
-- loss, taking the scrap and the piece; the menu says so, and a second repair is refused as the
-- part is sounder than one would leave it. Catches a burnt-out pump that runs, a repair to new, or
-- one that takes nothing.
T.test("irrigation_pump_house_burns_out_and_is_repaired", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house = placeHouse(self, spots[1], WOOD, fitted(APPLIANCE, { on = true, partCondition = LAST_CONDITION }))
        update(self, self.house, "burnt", { hoursAgo = 1 })
        waitForSummary(self, self.house, function(summary) return summary.burntOut end, "this client's summary of the burnt-out part")
        readMenu(self, function() return copyOf(self.house) end, "burnt")
        useMenu(self, self.house, "on", job(PumpJobs.TURN_ON), false)
        T.setPerk(self, Perks.Electricity, 2)
        T.give(self, "kit", { { type = "Base.Screwdriver" }, { type = "Base.ElectronicsScrap" }, { type = "Base.TirePiece" } })
        useMenu(self, self.house, "repair", job(PumpJobs.REPAIR_PUMP), true)
        readUntil(self, self.house, "repaired", function(state) return state.record.partCondition > 0 end)
        waitForSummary(self, self.house, function(summary) return not summary.burntOut end, "this client's summary of the repair")
        readMenu(self, function() return copyOf(self.house) end, "repaired")
        useMenu(self, self.house, "again", job(PumpJobs.REPAIR_PUMP), false)
        T.count(self, "used", { "Base.ElectronicsScrap", "Base.TirePiece", "Base.Screwdriver" })
    end,
    validate = function(self)
        local burnt = self.reads.burnt.after
        expect(burnt.record.partCondition == 0 and burnt.summary.burntOut, "the part is left at "
            .. burnt.record.partCondition)
        expect(not burnt.record.on and not burnt.summary.running, "the burnt-out house is still switched on")
        expectWord(self, "burnt", getText("IGUI_EnhancedIrrigation_PartBurntOut", getItemNameFromFullType(APPLIANCE)))
        T.expectRefused(self, "on", "Tooltip_EnhancedIrrigation_PumpBurntOut")
        T.expectOffered(self, "repair")
        local restored = Pumps.PART_CONDITION - Pumps.REPAIR_LOSS
        local repaired = self.reads.repaired.record
        expect(repaired.partCondition == restored and repaired.partCeiling == restored, "the repair left the part at "
            .. repaired.partCondition .. " of " .. repaired.partCeiling)
        expectWord(self, "repaired", partWord(APPLIANCE, restored))
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
        self.house = placeHouse(self, spots[1], WOOD, fitted(APPLIANCE))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded", BARREL_LITRES - ROOM)
        link(self, self.house, self.tank)
        update(self, self.house, "burnt", { hoursAgo = 1, tank = self.tank,
            fields = { on = true, partCondition = Pumps.PARTS[APPLIANCE].wearPerHour / 4 } })
    end,
    validate = function(self)
        local after = self.reads.burnt.after
        expectNear("the barrel when the part burnt out", after.tank.litres, BARREL_LITRES, LITRES)
        expect(after.record.partCondition == 0, "the part is left at " .. after.record.partCondition)
    end,
})

-- Time away -----------------------------------------------------------------------------------------------

-- Hours before the shutoff the gap runs the house: less than the barrel holds.
local BEFORE_SHUTOFF = 1

-- Indoors, running on the grid at its last pass; then the grid shuts off, and a pass that finds
-- the house a while past the shutoff runs it for the part of the gap before it only. Catches a gap
-- run on a grid that is gone, or one the shutoff throws away whole.
T.test("irrigation_pump_house_grid_runs_a_gap_until_the_shutoff", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house = placeHouse(self, spots[1], METAL, fitted(APPLIANCE, { on = true }))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.house, self.tank)
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
        expectNear("the barrel after the gap", gap.after.tank.litres, lifts(APPLIANCE, shutoff.shutoff - from),
            lifts(APPLIANCE, 1 / 60))
    end,
})

-- Hours the house is away while its chunk is unloaded.
local AWAY_HOURS = 1

-- A running house's record waits while its chunk is away: the pass leaves its barrel as it was,
-- however long ago it last ran. Loaded again, it runs the whole gap on the grid it still has.
-- Catches a record that lifts into a tank it can't see, or forgets the time it was away. The house
-- is switched on only once away, so no ten-minute pass before the reload lifts water the gap
-- doesn't count.
T.test("irrigation_pump_house_catches_up_after_its_chunk_reloads", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves",
    instant = true,
    timeoutSeconds = T.RELOAD_SECONDS,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 0, 1 } }, { bare = true, indoors = true })
        if not spots then return end
        self.house = placeHouse(self, spots[1], WOOD, fitted(APPLIANCE))
        T.placeTank(self, spots[2], "well")
        self.tank = T.placeTank(self, spots[3], "raisedLidded")
        link(self, self.house, self.tank)
        update(self, self.house, "lit", {})
        T.reload(self, T.at(self.house), function()
            update(self, self.house, "away", { hoursAgo = AWAY_HOURS, fields = { on = true } })
        end)
        update(self, self.house, "back", { tank = self.tank })
    end,
    validate = function(self)
        expect((self.chunkLoads or 0) > 0, "the house's chunk came back without LoadChunk, from a cache")
        local away, back = self.reads.away, self.reads.back
        expect(away.after.record.lastHour == away.before.record.lastHour, "the house's record ran while away")
        -- From the clock wound back while away to the pass after the reload, whichever pass ran it.
        expectNear("the barrel, back", back.after.tank.litres, lifts(APPLIANCE, back.now - (away.now - AWAY_HOURS)), LITRES)
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
    local house = placeHouse(self, spots[1], entity, fitted(part))
    local barrel = T.placeTank(self, spots[2], "lidded", SOURCE_LITRES)
    link(self, house, tiles[1])
    return house, barrel, tiles
end

local function useLineJob(self, tile, job, label, choose)
    T.useOption(self, function() return T.lineObject(tile) end, label, function(context)
        return T.jobOption(context, "line", job)
    end, choose)
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
        useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain running", false)
        -- The crops dried in the same call, so the ten-minute passes since Turn On leave them room.
        T.read(self, "sprinklers.house", T.at(self.house, { hoursAgo = HALF_HOUR, squares = T.tiles(self.tiles),
            water = 0, tank = T.at(self.barrel) }), "half")
        T.read(self, "tanks.perform", T.at(self.house, { feature = "pump", job = PumpJobs.TURN_OFF }), "off")
        T.waitForLines(self, self.tiles, "this client's copy of the stopped line", function(summary)
            return not summary.running
        end)
        useLineJob(self, self.tiles[2], LineJobs.DRAIN, "drain stopped", false)
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
        expectNear("the barrel's water drawn", half.before.tank.litres - half.after.tank.litres, 2 * each, LITRES)
        expectNear("the part's wear", half.before.pump.partCondition - half.after.pump.partCondition,
            Pumps.PARTS[UTILITY].wearPerHour * HALF_HOUR, 0.001)
        expect(self.reads.off.done, "Turn Off wasn't done")
        T.expectOffered(self, "drain stopped")
    end,
})

-- A running house's line waits with the house while its chunk is away, and once loaded again the
-- house runs the whole gap on the grid it still has, pushing each hole's water out at its part's
-- push for all of it. Catches a pumped line that loses the time it was away, or runs unseen. As the
-- catch-up test above, the house is switched on only once away.
T.test("irrigation_pump_house_catches_up_its_line_after_a_reload", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves",
    instant = true,
    timeoutSeconds = T.RELOAD_SECONDS,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, LINE_SPOTS, { bare = true, indoors = true, joined = true })
        if not spots then return end
        self.house, self.barrel, self.tiles = houseLine(self, spots, WOOD, APPLIANCE)
        update(self, self.house, "lit", {})
        T.reload(self, T.at(self.house), function()
            T.read(self, "sprinklers.house", T.at(self.house, { hoursAgo = AWAY_HOURS, fields = { on = true } }), "away")
        end)
        T.read(self, "sprinklers.house", T.at(self.house, { squares = T.tiles(self.tiles), tank = T.at(self.barrel) }),
            "back")
    end,
    validate = function(self)
        expect((self.chunkLoads or 0) > 0, "the house's chunk came back without LoadChunk, from a cache")
        local away, back = self.reads.away, self.reads.back
        expect(away.after.pump.lastHour == away.before.pump.lastHour, "the house's record ran while away")
        -- From the clock wound back while away to the pass after the reload, whichever pass ran it.
        local perHour = 2 * Lines.HOLE_RATE * Pumps.PARTS[APPLIANCE].push
        expectNear("the barrel's water drawn, back", SOURCE_LITRES - back.after.tank.litres,
            perHour * (back.now - (away.now - AWAY_HOURS)), LITRES)
        for i = 1, 2 do
            expect((back.after.squares[i].water or 0) > 0, "crop " .. i .. " got no water from the gap")
        end
    end,
})

-- Salvage Pump -----------------------------------------------------------------------------------------

-- The appliance drawn as `sprite` at `appliance` as the server has it, into self.reads[label].
local function readWasher(self, appliance, label, done, sprite)
    T.readUntil(self, "appliances.state", T.at(appliance, { sprite = sprite or WASHER }), label, done)
end

-- Queues vanilla's Turn On or Off of the washer drawn as `sprite` at `appliance`, run on the
-- authority as its action's complete() does, whatever the client checked, into self.reads[label];
-- a washer-dryer set to `mode` first.
local function toggle(self, appliance, label, sprite, mode)
    T.read(self, "appliances.toggle", T.at(appliance, { sprite = sprite or WASHER, mode = mode }), label)
end

-- A washing machine indoors on the grid with water in it runs once switched on. Salvage Pump from
-- its menu, with Electricity 2, the knowledge, a screwdriver and pliers, gives an Appliance Pump at
-- a used part's condition and stops the washer; its Turn On is then greyed out saying the pump is
-- gone, the server won't switch it on, and a second Salvage Pump is refused. Catches a washer that
-- runs with no pump, a pump salvaged twice, or one that comes out new.
T.test("irrigation_pumps_salvage_washer_gives_a_part_and_stops_it", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.washer = { x = spots[1].x, y = spots[1].y, z = spots[1].z, square = spots[1].square }
        T.server(self, "fixtures.place", T.at(self.washer, { sprite = WASHER, washer = true, buffer = { litres = 20 } }))
        T.waitFor(self, function() return T.objectWithSprite(self.washer.square, WASHER) ~= nil end,
            "this client's copy of the washer")
        T.goNextTo(self, self.washer.square)
        toggle(self, self.washer, "running")
        T.knowRecipes(self, { ApplianceJobs.RECIPE }, true)
        T.setPerk(self, Perks.Electricity, 2)
        T.give(self, "tools", { { type = "Base.Screwdriver" }, { type = "Base.Pliers" } })
        local function washer() return T.objectWithSprite(getSquare(self.washer.x, self.washer.y, self.washer.z), WASHER) end
        T.useOption(self, washer, "salvage", function(context)
            return T.jobOption(context, "appliance", ApplianceJobs.SALVAGE_PUMP)
        end, true)
        readWasher(self, self.washer, "salvaged", function(state) return state.stripped end)
        T.read(self, "pumpHouse.carried", { type = APPLIANCE }, "part")
        T.waitFor(self, function()
            local copy = washer()
            return copy ~= nil and EnhancedIrrigation.Appliances.isStripped(copy)
        end, "this client's copy of the stripped washer")
        T.useOption(self, washer, "on", function(context)
            return T.findNamed(context, context, getText("ContextMenu_Turn_On"))
        end, false)
        toggle(self, self.washer, "forced")
        T.useOption(self, washer, "again", function(context)
            return T.jobOption(context, "appliance", ApplianceJobs.SALVAGE_PUMP)
        end, false)
    end,
    validate = function(self)
        expect(self.reads.running.activated, "the washer never ran")
        T.expectOffered(self, "salvage")
        expect(not self.reads.salvaged.activated, "the stripped washer still runs")
        local items = self.reads.part.items
        local least, most = ApplianceJobs.SALVAGED_CONDITION[1], ApplianceJobs.SALVAGED_CONDITION[2]
        expect(#items == 1 and items[1].condition >= least and items[1].condition <= most,
            "Salvage Pump gave " .. #items .. " pumps" .. (items[1] and " at " .. items[1].condition or ""))
        T.expectRefused(self, "on", "Tooltip_EnhancedIrrigation_PumpSalvaged")
        expect(not self.reads.forced.activated, "the server switched the stripped washer on")
        T.expectRefused(self, "again", "Tooltip_EnhancedIrrigation_PumpSalvaged")
    end,
})

-- A washer-dryer indoors on the grid, set to dry and switched on, stops on this client too once
-- its pump is salvaged: in dryer mode vanilla carries its switch as the dryer's change, which the
-- washer's leaves alone. Catches a stripped washer-dryer the server stopped but every client still
-- runs.
T.test("irrigation_pumps_salvage_drying_combo_stops_it", {
    instant = true,
    run = function(self)
        T.setGrid(self, true)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.combo = { x = spots[1].x, y = spots[1].y, z = spots[1].z, square = spots[1].square }
        local function combo() return T.objectWithSprite(getSquare(self.combo.x, self.combo.y, self.combo.z), COMBO) end
        T.server(self, "fixtures.place", T.at(self.combo, { sprite = COMBO, combo = true }))
        T.waitFor(self, function() return combo() ~= nil end, "this client's copy of the washer-dryer")
        T.goNextTo(self, self.combo.square)
        toggle(self, self.combo, "drying", COMBO, "dryer")
        T.waitFor(self, function()
            local copy = combo()
            return copy ~= nil and copy:isModeDryer() and copy:isActivated()
        end, "this client's copy of the washer-dryer drying")
        T.knowRecipes(self, { ApplianceJobs.RECIPE }, true)
        T.setPerk(self, Perks.Electricity, 2)
        T.give(self, "tools", { { type = "Base.Screwdriver" }, { type = "Base.Pliers" } })
        T.useOption(self, combo, "salvage", function(context)
            return T.jobOption(context, "appliance", ApplianceJobs.SALVAGE_PUMP)
        end, true)
        readWasher(self, self.combo, "salvaged", function(state) return state.stripped end, COMBO)
        T.waitFor(self, function()
            local copy = combo()
            return copy ~= nil and EnhancedIrrigation.Appliances.isStripped(copy)
        end, "this client's copy of the stripped washer-dryer")
        -- The change follows the mark, which the server sent first.
        T.waitFor(self, function()
            local copy = combo()
            return copy ~= nil and not copy:isActivated()
        end, "this client's copy of the stripped washer-dryer to stop")
    end,
    validate = function(self)
        local drying = self.reads.drying
        expect(drying.activated and drying.dryer, "the washer-dryer never dried")
        T.expectOffered(self, "salvage")
        expect(not self.reads.salvaged.activated, "the server's stripped washer-dryer still runs")
    end,
})

-- Make Utility Pump ---------------------------------------------------------------------------------------

-- Make Utility Pump from a Blower Fan, at a table, with the skills, the knowledge and exactly a
-- craft's inputs, makes a Utility Pump at the made ceiling, taking the fan, the sheet metal and the
-- hose, two uses of the torch and one of the rods. Catches a recipe the game won't craft, a made
-- pump as good as a found one, or welding that takes whole items. T.craftTest would teach every
-- recipe of the mod, so the test teaches this one alone; its surface is the work table the
-- scenario sets beside the start (T.placeWorkTable only checks it is there).
T.test("irrigation_pump_house_make_utility_pump", {
    instant = true,
    run = function(self)
        local name = "EnhancedIrrigation_MakeUtilityPump"
        local recipe = T.need(self, getScriptManager():getCraftRecipe(name), "the recipe " .. name)
        if not recipe then return end
        T.knowRecipes(self, { name }, true)
        T.placeWorkTable(T.player())
        for i = 0, recipe:getRequiredSkillCount() - 1 do
            local skill = recipe:getRequiredSkill(i)
            T.setPerk(self, skill:getPerk(), skill:getLevel())
        end
        local inputs, unmatched = T.recipeInputs(recipe)
        if not T.need(self, #unmatched == 0, "an item for " .. table.concat(unmatched, "; ")) then return end
        T.give(self, "inputs", inputs)
        T.step(function()
            local fan = T.need(self, T.player():getInventory():getFirstTypeRecurse("Base.BlowerFan"), "a Blower Fan")
            if not fan then return end
            T.startCraft(self, recipe, fan)
            T.count(self, "craft", { UTILITY, "Base.BlowerFan", "Base.SmallSheetMetal", "Base.RubberHose" }, { dropped = true })
        end)
        T.read(self, "pumpHouse.carried", { type = UTILITY }, "made")
        T.read(self, "pumpHouse.carried", { type = "Base.BlowTorch" }, "torch")
        T.read(self, "pumpHouse.carried", { type = "Base.WeldingRods" }, "rods")
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
