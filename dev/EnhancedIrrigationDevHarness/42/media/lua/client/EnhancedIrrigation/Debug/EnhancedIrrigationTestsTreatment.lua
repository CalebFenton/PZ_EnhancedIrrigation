require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/Frost"
require "EnhancedIrrigation/UI/LinkMenu"
require "EnhancedIrrigation/UI/TreatmentMenu"
require "ISUI/ISBBQMenu"
require "Camping/ISCampingMenu"

-- The sand filters, the Filter Crock and the Boilers. Units are placed, read and run by the
-- server's treatment handlers; time runs there through the record's own advance for set hours, so
-- the clock doesn't decide what a test sees.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Links, LinkJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Treatment, TreatmentJobs, LinkMenu = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs,
    EnhancedIrrigation.LinkMenu

local BARREL, BRICK = "EnhancedIrrigation_BarrelFilter", "EnhancedIrrigation_BrickFilter"
local CROCK = "EnhancedIrrigation_FilterCrock"
local STONE, WELDED = "EnhancedIrrigation_BoilerStone", "EnhancedIrrigation_BoilerWelded"
local SPRITES = { [BARREL] = Sprites.BARREL_FILTER, [BRICK] = Sprites.BRICK_FILTER, [CROCK] = Sprites.FILTER_CROCK,
    [STONE] = Sprites.BOILER_STONE, [WELDED] = Sprites.BOILER_WELDED }

-- Units -----------------------------------------------------------------------------------------------

--- Queues placing the unit `entity` at `handle` (up `opts.up` storeys), with `opts.fields` on its
--- record, and a wait for this client's copy and its summary. Returns its handle, with `spec`.
local function placeUnit(self, handle, entity, opts)
    opts = opts or {}
    local up = opts.up or 0
    local unit = { x = handle.x, y = handle.y, z = handle.z + up, sprite = SPRITES[entity],
        spec = Treatment.UNITS[entity], square = up == 0 and handle.square or nil }
    T.server(self, "treatment.place", T.at(unit, { sprite = unit.sprite, fields = opts.fields }))
    T.waitFor(self, function()
        unit.square = getSquare(unit.x, unit.y, unit.z)
        local copy = T.copyOf(unit)
        return copy ~= nil and Treatment.summaryOf(copy) ~= nil
    end, "this client's copy of the " .. entity)
    return unit
end

local function readUntil(self, unit, label, done, tank)
    T.readUntil(self, "treatment.state", T.at(unit, { tank = tank and T.at(tank) }), label, done)
end

-- Queues `fields` set on the unit's record and a run of each of `hours`, with the tank's state if
-- given, into self.reads[label] ({ before, steps }).
local function run(self, unit, label, hours, fields, tank)
    T.read(self, "treatment.run", T.at(unit, { hours = hours, fields = fields, tank = tank and T.at(tank) }), label)
end

-- Queues a wait until this client's copy of the unit holds `litres` in its basin, if given, and its
-- summary satisfies `holds(summary)`, if given.
local function waitForCopy(self, unit, litres, holds, what)
    T.waitFor(self, function()
        local copy = T.copyOf(unit)
        local summary = copy and Treatment.summaryOf(copy)
        return summary ~= nil and (not litres or math.abs(copy:getFluidContainer():getAmount() - litres) < T.LITRES)
            and (not holds or holds(summary))
    end, what)
end

-- Queues a wait until this client's summary of the unit agrees on `key` with the server's in
-- self.reads[label] (a state, an update's `after` or a run's last step), so a menu read after it
-- shows what the server answered.
local function waitForServer(self, unit, label, key)
    T.waitFor(self, function()
        local read = self.reads and self.reads[label]
        local state = read and (read.after or read.steps and read.steps[#read.steps] or read)
        local summary = Treatment.summaryOf(T.copyOf(unit))
        return state ~= nil and state.summary ~= nil and summary ~= nil and summary[key] == state.summary[key]
    end, "this client's summary of " .. label)
end

-- Queues the boiler's fire set on the authority (treatment.fire: `fuel` minutes if given, lit or
-- not) and a wait for this client's copy to show it, as vanilla's own fire actions leave it.
local function setFire(self, unit, label, lit, fuel)
    T.read(self, "treatment.fire", T.at(unit, { lit = lit, fuel = fuel }), label)
    T.waitFor(self, function()
        local copy = T.copyOf(unit)
        return copy ~= nil and copy:isLit() == lit
    end, "this client's copy of the boiler " .. (lit and "lit" or "out"))
end

-- Fuel for the tests' fires, in minutes: longer than any test runs one.
local FUEL = 600

-- Queues `litres` of raw water, tainted if `tainted`, set in the unit's head and treated into its
-- basin by the hours its rate takes (self.reads.filled), a boiler lit for them and put out after,
-- then a wait for this client's copy of the basin. A sand filter's film is grown for clean water
-- and new for tainted, so its basin holds the water as it was.
local function fillBasin(self, unit, litres, tainted)
    local spec = unit.spec
    local fields, hours = { head = litres, headTainted = tainted == true }, litres / spec.rate
    if spec.kind == "sand" then
        fields.ripeHours = tainted and 0 or Treatment.RIPE_HOURS
    elseif spec.kind == "boiler" then
        -- A cold drum passes nothing until it is hot.
        hours = hours + Treatment.HOT_HOURS
        setFire(self, unit, "filled lit", true, FUEL)
    end
    run(self, unit, "filled", { hours }, fields)
    if spec.kind == "boiler" then
        setFire(self, unit, "filled out", false)
    end
    waitForCopy(self, unit, litres, nil, "this client's copy of the filled basin")
end

-- Expects (`want`, or not) a line of the menu T.readMenu read as `label` to contain `text`.
local function expectLine(self, label, text, want)
    local found = false
    for _, name in ipairs(self.names and self.names[label] or {}) do
        found = found or name:find(text, 1, true) ~= nil
    end
    expect(found == (want ~= false), label .. ": the menu " .. (found and "says " or "doesn't say ") .. text)
end

local function expectBasin(who, state, litres, tainted)
    if not expect(state and state.basin, who .. ": no unit") then return end
    expectNear(who .. ": the basin's water", state.basin.litres, litres, T.LITRES)
    if litres > 0 then
        expect(state.basin.tainted == tainted, who .. ": the basin's water is " .. (state.basin.tainted and "tainted" or "clean"))
    end
end

-- This client's copy's basin as the state expectBasin reads.
local function clientBasin(unit)
    local copy = T.copyOf(unit)
    local basin = copy and copy:getFluidContainer()
    return basin and { basin = { litres = basin:getAmount(), tainted = basin:isTainted() } } or nil
end

-- Building ----------------------------------------------------------------------------------------------

-- The build menu builds each filter from its recipe on a bare square, with its record at once:
-- this client's menu reads its state. Catches a recipe the build menu can't build, or a filter
-- without its record.
for _, entity in ipairs({ BARREL, BRICK }) do
    T.test("irrigation_treatment_" .. (entity == BARREL and "barrel" or "brick") .. "_filter_built_from_build_menu", {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.unit = T.buildFromMenu(self, "Base." .. entity, spots[1], SPRITES[entity])
            if not self.unit then return end
            self.unit.spec = Treatment.UNITS[entity]
            readUntil(self, self.unit, "built", function(state) return state.record ~= nil end)
            T.waitFor(self, function() return Treatment.summaryOf(T.copyOf(self.unit)) ~= nil end,
                "this client's summary of the built filter")
            T.readMenu(self, self.unit, "built")
        end,
        validate = function(self)
            local built = self.reads.built
            expect(built.entity == entity, "the build menu built " .. tostring(built.entity))
            expect(built.record and built.record.head == 0, "the built filter has no record, or water in its head")
            expect(built.basin and built.basin.litres == 0 and built.basin.locked, "the built filter's basin isn't empty and locked")
            expectLine(self, "built", getText("IGUI_EnhancedIrrigation_Ripening", Treatment.RIPE_HOURS))
        end,
    })
end

-- Pour In ------------------------------------------------------------------------------------------------

-- Pour In from a carried bucket of tainted water fills the head as far as it has room, the bucket
-- keeping the rest, and the new filter's next hour passes it tainted. A can of petrol is greyed
-- out, and so, with the head full, is the bucket. Catches water lost or created, the taint dropped,
-- or anything but water on the sand.
T.test("irrigation_treatment_pour_in_fills_the_head", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        local head = Treatment.UNITS[BARREL].head
        self.room = 5
        self.unit = placeUnit(self, spots[1], BARREL, { fields = { head = head - self.room } })
        T.give(self, "carried", { { type = "Base.Bucket" }, { type = "Base.PetrolCan" } })
        T.server(self, "treatment.fillCarried", { type = "Base.Bucket", fluid = "TaintedWater", litres = 10 })
        T.server(self, "treatment.fillCarried", { type = "Base.PetrolCan", fluid = "Petrol", litres = 5 })
        T.waitFor(self, function()
            local bucket, can = self.items.carried[1], self.items.carried[2]
            return bucket:getFluidContainer():getAmount() > 10 - T.LITRES and can:getFluidContainer():getAmount() > 5 - T.LITRES
        end, "this client's copies of the filled bucket and can")
        T.step(function() self.bucket, self.can = self.items.carried[1], self.items.carried[2] end)
        T.useMenu(self, self.unit, "petrol", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.can)
        end, false)
        T.useMenu(self, self.unit, "pour", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.bucket)
        end, true)
        readUntil(self, self.unit, "poured", function(state)
            return state.record and state.record.head + state.basin.litres > head - T.LITRES
        end)
        T.read(self, "treatment.carried", { type = "Base.Bucket" }, "bucket")
        T.waitFor(self, function()
            local summary = Treatment.summaryOf(T.copyOf(self.unit))
            return summary ~= nil and summary.head > head - 1
        end, "this client's summary of the full head")
        T.useMenu(self, self.unit, "full", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.bucket)
        end, false)
        run(self, self.unit, "hour", { 1 })
    end,
    validate = function(self)
        local head = Treatment.UNITS[BARREL].head
        T.expectRefused(self, "petrol", "Tooltip_EnhancedIrrigation_OnlyWater")
        T.expectOffered(self, "pour")
        local poured = self.reads.poured
        expectNear("the head and basin after pouring", poured.record.head + poured.basin.litres, head, T.LITRES)
        local hour = self.reads.hour
        expectBasin("the hour's water", hour.steps[1], hour.before.basin.litres + Treatment.UNITS[BARREL].rate, true)
        local bucket = self.reads.bucket
        expectNear("the bucket's water left", bucket.litres, 10 - self.room, T.LITRES)
        expect(bucket.tainted, "the bucket's water left is clean")
        T.expectRefused(self, "full", "Tooltip_EnhancedIrrigation_HeadFull")
    end,
})

-- Through the sand ----------------------------------------------------------------------------------------

-- An unripe Barrel Filter passes its head's water as it is, at its rate: tainted from a tainted
-- head, on both sides. Catches a new filter that cleans, or one that runs at the wrong rate.
T.test("irrigation_treatment_unripe_filter_passes_tainted_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL)
        self.hours = 2
        run(self, self.unit, "run", { self.hours }, { head = 20, headTainted = true, ripeHours = 0 })
        local litres = self.unit.spec.rate * self.hours
        waitForCopy(self, self.unit, litres, nil, "this client's copy of the filled basin")
    end,
    validate = function(self)
        local litres = self.unit.spec.rate * self.hours
        local before, after = self.reads.run.before, self.reads.run.steps[1]
        expectBasin("the server", after, before.basin.litres + litres, true)
        expectBasin("this client", clientBasin(self.unit), before.basin.litres + litres, true)
        expectNear("the head left", after.record.head, 20 - litres, T.LITRES)
    end,
})

-- A ripe Brick Filter passes clean water from a tainted head, at its rate, on both sides, and its
-- menu says it's ripe, greying out Clean Filter as it isn't clogged. Catches a ripe filter passing
-- taint, or Clean Filter offered for nothing.
T.test("irrigation_treatment_ripe_filter_passes_clean_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BRICK)
        self.hours = 2
        run(self, self.unit, "run", { self.hours }, { head = 50, headTainted = true, ripeHours = Treatment.RIPE_HOURS })
        local litres = self.unit.spec.rate * self.hours
        waitForCopy(self, self.unit, litres, nil, "this client's copy of the filled basin")
        T.readMenu(self, self.unit, "ripe")
        T.useMenu(self, self.unit, "clean", T.job("treatment", TreatmentJobs.CLEAN_FILTER), false)
    end,
    validate = function(self)
        local litres = self.unit.spec.rate * self.hours
        local after = self.reads.run.steps[1]
        expectBasin("the server", after, litres, false)
        expectBasin("this client", clientBasin(self.unit), litres, false)
        T.expectWord(self, "ripe", getText("IGUI_EnhancedIrrigation_Ripe"))
        T.expectRefused(self, "clean", "Tooltip_EnhancedIrrigation_NotClogged")
    end,
})

-- Enough hours with an empty head kill the film, which ripens from nothing again: a filter fed a
-- tainted head an hour short of them still passes it clean; one fed at them passes it tainted, and
-- before that its menu says it's ripening and how long it's been dry. Catches a film that never
-- dies, or dies early.
T.test("irrigation_treatment_two_dry_days_kill_the_layer", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.short = placeUnit(self, spots[1], BARREL)
        self.dead = placeUnit(self, spots[2], BARREL)
        run(self, self.short, "short", { Treatment.DRY_DEATH_HOURS - 1 }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
        run(self, self.short, "short fed", { 1 }, { head = 10, headTainted = true })
        run(self, self.dead, "dry", { Treatment.DRY_DEATH_HOURS }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
        waitForServer(self, self.dead, "dry", "ripeHours")
        T.readMenu(self, self.dead, "dead")
        run(self, self.dead, "fed", { 1 }, { head = 10, headTainted = true })
    end,
    validate = function(self)
        local rate = self.dead.spec.rate
        local short, fed = self.reads["short fed"], self.reads.fed
        expectBasin("fed an hour short of two dry days", short.steps[1], short.before.basin.litres + rate, false)
        expectLine(self, "dead", getText("IGUI_EnhancedIrrigation_Ripening", Treatment.RIPE_HOURS))
        expectLine(self, "dead", getText("IGUI_EnhancedIrrigation_DryFor", Treatment.DRY_DEATH_HOURS))
        expectBasin("fed after two dry days", fed.steps[1], fed.before.basin.litres + rate, true)
    end,
})

-- A hard freeze with water on the sand kills the film: frozen, it passes nothing that hour, its
-- menu says it ripens from the start, and thawed, its next hour passes a tainted head as it is. A
-- filter with an empty head keeps its film: its menu still says it's ripe. Catches frost ignored,
-- or a dry filter killed by it.
T.test("irrigation_treatment_hard_freeze_kills_the_layer", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.wet = placeUnit(self, spots[1], BARREL)
        self.dry = placeUnit(self, spots[2], BARREL)
        T.server(self, "lines.temperature", { celsius = EnhancedIrrigation.Frost.HARD_FREEZE_CELSIUS - 3 })
        run(self, self.wet, "wet", { 1 }, { head = 20, ripeHours = Treatment.RIPE_HOURS })
        run(self, self.dry, "dry", { 1 }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
        waitForServer(self, self.wet, "wet", "ripeHours")
        waitForServer(self, self.dry, "dry", "ripeHours")
        T.readMenu(self, self.wet, "wet")
        T.readMenu(self, self.dry, "dry")
        T.server(self, "lines.temperature", { celsius = EnhancedIrrigation.Frost.HARD_FREEZE_CELSIUS + 20 })
        run(self, self.wet, "thawed", { 1 }, { headTainted = true })
    end,
    validate = function(self)
        expectNear("the frozen filter's basin", self.reads.wet.steps[1].basin.litres, 0, T.LITRES)
        expectLine(self, "wet", getText("IGUI_EnhancedIrrigation_Ripening", Treatment.RIPE_HOURS))
        T.expectWord(self, "dry", getText("IGUI_EnhancedIrrigation_Ripe"))
        local thawed = self.reads.thawed
        expectBasin("the thawed filter's hour", thawed.steps[1], thawed.before.basin.litres + self.wet.spec.rate, true)
    end,
})

-- Clogging and cleaning ----------------------------------------------------------------------------

-- Past its litres a filter trickles, and its menu says it's clogged; Clean Filter, with a shovel,
-- restores the rate, and its menu says the film is ripening again: tainted water passes again.
-- Catches a clog that never comes, a cleaning that leaves it clogged, or one that leaves the film
-- ripe.
T.test("irrigation_treatment_clogged_filter_trickles_until_cleaned", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL)
        local spec = self.unit.spec
        run(self, self.unit, "clogged", { 1 }, { head = 20, headTainted = true, ripeHours = Treatment.RIPE_HOURS,
            passed = spec.clogLitres })
        waitForCopy(self, self.unit, nil, function(summary) return summary.clogged end,
            "this client's summary of the clogged filter")
        T.readMenu(self, self.unit, "clogged")
        T.give(self, "tools", { { type = "Base.Shovel" } })
        T.useMenu(self, self.unit, "clean", T.job("treatment", TreatmentJobs.CLEAN_FILTER), true)
        readUntil(self, self.unit, "cleaned", function(state) return not state.summary.clogged end)
        waitForServer(self, self.unit, "cleaned", "clogged")
        T.readMenu(self, self.unit, "cleaned")
        run(self, self.unit, "after", { 1 }, { head = 20, headTainted = true })
    end,
    validate = function(self)
        local spec = self.unit.spec
        local clogged = self.reads.clogged
        expectNear("a clogged filter's hour", clogged.steps[1].basin.litres - clogged.before.basin.litres,
            spec.rate * Treatment.CLOGGED_FACTOR, T.LITRES)
        expect(clogged.steps[1].basin.tainted == false, "a ripe clogged filter passed tainted water")
        expectLine(self, "clogged", getText("IGUI_EnhancedIrrigation_Clogged"))
        T.expectOffered(self, "clean")
        T.expectWord(self, "cleaned", getText("IGUI_EnhancedIrrigation_Clogged"), false)
        expectLine(self, "cleaned", getText("IGUI_EnhancedIrrigation_Ripening",
            Treatment.RIPE_HOURS - Treatment.CLEANED_RIPE_HOURS))
        local after = self.reads.after
        expectNear("a cleaned filter's hour", after.steps[1].basin.litres - after.before.basin.litres, spec.rate, T.LITRES)
        expect(after.steps[1].basin.tainted, "a filter ripening after a cleaning passed a tainted head clean")
    end,
})

-- Links -------------------------------------------------------------------------------------------------

-- Plumb Inlet from a filter's menu to a raw tank on its level lays the pipe chosen, and an hour on
-- the filter tops its head up from the tank, taint and all: the new filter passes that hour's water
-- tainted. Catches an inlet that draws nothing, overfills, or cleans on the way in.
T.test("irrigation_treatment_inlet_fills_the_head_from_a_tank", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL)
        self.tank = T.placeTank(self, spots[2], "lidded", 100, true)
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe" } })
        T.useMenu(self, self.unit, "inlet", T.job("link", LinkJobs.PLUMB_INLET, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.unit, "plumbed", function(state) return state.inlet end)
        run(self, self.unit, "hour", { 1 }, nil, self.tank)
        T.count(self, "left", { "Base.MetalPipe" })
    end,
    validate = function(self)
        T.expectOffered(self, "inlet")
        expect(self.reads.plumbed.inlet, "the server didn't plumb the inlet")
        expect(self.counts.left["Base.MetalPipe"] == 0, "plumbing the inlet left the iron pipe")
        local spec = self.unit.spec
        local before, after = self.reads.hour.before, self.reads.hour.steps[1]
        expectNear("the head after an hour", after.record.head, spec.head - spec.rate, T.LITRES)
        expectBasin("the hour's water", after, before.basin.litres + spec.rate, true)
        expectNear("the water drawn", after.tank.litres + after.record.head + after.basin.litres, 100, T.LITRES)
    end,
})

-- A tank on a lower floor can't run into a filter's head: the inlet's submenu greys it out saying
-- so, and the server refuses on its own. Catches water piped uphill.
T.test("irrigation_treatment_inlet_refuses_a_lower_tank", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL, { up = 1 })
        self.tank = T.placeTank(self, spots[2], "ground", 100)
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe" } })
        T.useOption(self, function() return T.copyOf(self.unit) end, "lower tank", function(context)
            local label = LinkMenu.tankLabel(T.at(self.unit), T.at(self.tank))
            return T.inSubmenu(context, "ContextMenu_EnhancedIrrigation_PlumbInlet", function(option)
                return option.name == label
            end)
        end, false)
        T.read(self, "tanks.perform", T.at(self.unit, { feature = "link", job = LinkJobs.PLUMB_INLET,
            with = Links.encode(T.at(self.tank), "iron") }), "forced")
    end,
    validate = function(self)
        T.expectRefused(self, "lower tank", "Tooltip_EnhancedIrrigation_InletTankTooLow")
        local forced = self.reads.forced
        expect(forced.done == false and forced.links == 0, "the server plumbed an inlet from a lower tank")
    end,
})

-- Plumb Outlet to a clean tank on the filter's level lays the pipe, and an hour on the filter
-- empties the basin into it; a raised barrel, a level up, is greyed out saying so. Catches an outlet
-- that leaves the basin full, or one that runs uphill.
T.test("irrigation_treatment_outlet_fills_a_tank_no_higher", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 }, { 0, 2 } }, { bare = true })
        if not spots then return end
        self.litres = 30
        self.unit = placeUnit(self, spots[1], BARREL)
        fillBasin(self, self.unit, self.litres)
        self.tank = T.placeTank(self, spots[2], "lidded")
        self.high = T.placeTank(self, spots[3], "raised")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe" } })
        T.useMenu(self, self.unit, "higher tank", function(context)
            local label = LinkMenu.tankLabel(T.at(self.unit), T.at(self.high))
            return T.inSubmenu(context, "ContextMenu_EnhancedIrrigation_PlumbOutlet", function(option)
                return option.name == label
            end)
        end, false)
        T.useOption(self, function() return T.copyOf(self.unit) end, "outlet",
            T.job("link", LinkJobs.PLUMB_OUTLET, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.unit, "plumbed", function(state) return state.outlet end)
        run(self, self.unit, "passed", { 1 }, nil, self.tank)
    end,
    validate = function(self)
        T.expectRefused(self, "higher tank", "Tooltip_EnhancedIrrigation_OutletTankTooHigh")
        T.expectOffered(self, "outlet")
        local passed = self.reads.passed.steps[1]
        expect(passed.outlet, "the server didn't plumb the outlet")
        expectNear("the basin after an hour", passed.basin.litres, 0, T.LITRES)
        expectNear("the clean tank after an hour", passed.tank.litres, self.litres, T.LITRES)
        expect(not passed.tank.tainted, "the clean tank's water is tainted")
    end,
})

-- A plumbed filter's inlet keeps its sand wet through the time it wasn't caught up, as it would have
-- loaded: its clock wound back past the hours its head takes to run through and the film to die
-- dry, it comes back ripe and wet, the raw tank down by what went into the head, the basin and the
-- outlet's tank, which holds it clean; its next hour passes clean water on into that tank. The
-- chunk stays loaded, as the catch-up is the record's own, so this runs in multiplayer too. Catches
-- a catch-up that runs the gap on the head alone.
T.test("irrigation_treatment_inlet_keeps_the_film_through_an_absence", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 }, { 0, 3 } }, { bare = true })
        if not spots then return end
        local spec = Treatment.UNITS[BARREL]
        self.unit = placeUnit(self, spots[1], BARREL, { fields = { head = spec.head, headTainted = true,
            ripeHours = Treatment.RIPE_HOURS } })
        self.raw = T.placeTank(self, spots[2], "lidded", 300, true)
        self.clean = T.placeTank(self, spots[3], "lidded")
        T.server(self, "links.make", T.at(self.unit, { to = T.at(self.raw), kind = "iron", lengths = 1, role = "inlet" }))
        T.server(self, "links.make", T.at(self.unit, { to = T.at(self.clean), kind = "iron", lengths = 1,
            role = "outlet" }))
        local gap = spec.head / spec.rate + Treatment.DRY_DEATH_HOURS + 6
        T.read(self, "treatment.update", T.at(self.unit, { hoursAgo = gap, tank = T.at(self.raw), into = T.at(self.clean) }),
            "back")
        waitForServer(self, self.unit, "back", "ripeHours")
        T.readMenu(self, self.unit, "back")
        run(self, self.unit, "next", { 1 }, nil, self.clean)
    end,
    validate = function(self)
        local spec = self.unit.spec
        local before, after = self.reads.back.before, self.reads.back.after
        T.expectWord(self, "back", getText("IGUI_EnhancedIrrigation_Ripe"))
        expect(after.record.head > 0, "the filter came back dry")
        expectNear("what the raw tank fed", before.tank.litres - after.tank.litres,
            after.basin.litres - before.basin.litres + after.record.head - before.record.head
            + after.into.litres - before.into.litres, T.LITRES)
        expect(not after.basin.tainted, "the filter caught up passed tainted water")
        expect(not after.into.tainted, "the outlet's tank holds tainted water")
        local hour = self.reads.next
        expectNear("the outlet's tank after the next hour", hour.steps[1].tank.litres - hour.before.tank.litres,
            hour.before.basin.litres + spec.rate - hour.steps[1].basin.litres, T.LITRES)
        expect(not hour.steps[1].tank.tainted, "the next hour's water reached the outlet's tank tainted")
    end,
})

-- A plumbed filter's outlet empties the basin through the time the filter wasn't caught up, as it
-- would have loaded: its clock wound back longer than its basin takes to fill, it comes back with
-- the basin empty and the outlet's tank holding all the gap passed, the inlet keeping the head
-- topped up. The chunk stays loaded, so this runs in multiplayer too. Catches a catch-up that fills
-- the basin and stops, leaving the outlet only what one pass carries on reload.
T.test("irrigation_treatment_outlet_drains_through_an_absence", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 }, { 0, 3 } }, { bare = true })
        if not spots then return end
        local spec = Treatment.UNITS[BARREL]
        self.unit = placeUnit(self, spots[1], BARREL, { fields = { head = spec.head, ripeHours = Treatment.RIPE_HOURS } })
        self.raw = T.placeTank(self, spots[2], "lidded", 100)
        self.clean = T.placeTank(self, spots[3], "lidded")
        T.server(self, "links.make", T.at(self.unit, { to = T.at(self.raw), kind = "iron", lengths = 1, role = "inlet" }))
        T.server(self, "links.make", T.at(self.unit, { to = T.at(self.clean), kind = "iron", lengths = 1,
            role = "outlet" }))
        self.gap = 24
        T.read(self, "treatment.update", T.at(self.unit, { hoursAgo = self.gap, tank = T.at(self.raw),
            into = T.at(self.clean) }), "back")
    end,
    validate = function(self)
        local before, after = self.reads.back.before, self.reads.back.after
        local passed = self.unit.spec.rate * self.gap
        expect(passed > before.basin.capacity, "the gap passes no more than the basin holds, so it can't tell")
        expectNear("the outlet's tank, back", after.into.litres, passed, T.LITRES)
        expectNear("the basin, back", after.basin.litres, 0, T.LITRES)
        expectNear("what the raw tank fed", before.tank.litres - after.tank.litres,
            passed + after.record.head - before.record.head, T.LITRES)
    end,
})

-- A plumbed filter whose inlet's or outlet's tank stands where no chunk is loaded waits for it:
-- however long ago it last ran, its pass leaves the head and basin as they were, since the tank
-- might have kept it wet or taken its water. With that pipe gone, its next pass treats the whole
-- gap at its rate, so the wait lost no time. The far end is far past any loaded chunk, as a tank
-- beyond the edge of the loaded area is when the filter's chunk loads first; so this runs in
-- multiplayer too. Catches a filter that runs the gap without its tank.
for _, role in ipairs({ "inlet", "outlet" }) do
    T.test("irrigation_treatment_waits_for_an_unloaded_" .. role .. "_tank", {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.gap, self.head = 5, 40
            self.unit = placeUnit(self, spots[1], BARREL, { fields = { head = self.head, ripeHours = Treatment.RIPE_HOURS } })
            local far = { x = self.unit.x + 3000, y = self.unit.y, z = self.unit.z }
            T.server(self, "links.make", T.at(self.unit, { to = far, kind = "iron", lengths = 1, role = role }))
            T.read(self, "treatment.update", T.at(self.unit, { hoursAgo = self.gap, tank = far }), "waiting")
            T.server(self, "treatment.unlink", far)
            T.read(self, "treatment.update", T.at(self.unit), "back")
        end,
        validate = function(self)
            local waiting, back = self.reads.waiting, self.reads.back
            expect(waiting.after[role] and not waiting.after.tank.loaded,
                "the " .. role .. "'s far end isn't plumbed, or is loaded")
            expectNear("the head while the " .. role .. "'s tank is away", waiting.after.record.head, self.head, T.LITRES)
            expectNear("the basin while the " .. role .. "'s tank is away", waiting.after.basin.litres, 0, T.LITRES)
            -- From the clock wound back to the pass after the pipe went, whichever pass ran it.
            local litres = self.unit.spec.rate * (back.now - (waiting.now - self.gap))
            expectBasin("the filter after its " .. role .. " went", back.after, litres, false)
            expectNear("the head after its " .. role .. " went", back.after.record.head, self.head - litres, T.LITRES)
        end,
    })
end

-- Vanilla's menus ----------------------------------------------------------------------------------------

-- The basin offers vanilla's Drink, Fill and Empty, but no pour into it, though the character
-- carries water; a bucket filled from it holds its water as it was. A Barrel Filter's basin holds
-- tainted water, and Drink warns of it; a crock's or a boiler's, clean, and Drink doesn't; the
-- boiler is a vanilla fireplace, whose fire menu stands beside the fluid menu. Catches a basin
-- vanilla can't reach, one it can pour into past the sand, the clay or the fire, or a taint lost or
-- made up. The crock's bucket holds no more than the one carried, so that one starts part full: a
-- Fill that empties its source ends in an invalid action on a multiplayer client, which clears the
-- queue.
for _, case in ipairs({
    { name = "irrigation_treatment_vanilla_menu_drinks_fills_and_empties_the_basin", entity = BARREL, litres = 20,
        tainted = true, inBucket = 0 },
    { name = "irrigation_treatment_crock_vanilla_menu_drinks_fills_and_empties_the_basin", entity = CROCK, litres = 8,
        tainted = false, inBucket = 5 },
    { name = "irrigation_treatment_boiler_vanilla_menu_drinks_fills_and_empties_the_basin", entity = STONE, litres = 20,
        tainted = false, inBucket = 0 },
}) do
    T.test(case.name, {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.unit = placeUnit(self, spots[1], case.entity)
            fillBasin(self, self.unit, case.litres, case.tainted)
            T.give(self, "items", { { type = "Base.Bucket" }, { type = "Base.WaterBottle" } })
            -- Full, so vanilla's Fill lists only the bucket.
            T.server(self, "treatment.fillCarried", { type = "Base.WaterBottle", fluid = "Water", litres = 10 })
            if case.inBucket > 0 then
                T.server(self, "treatment.fillCarried", { type = "Base.Bucket", fluid = "Water", litres = case.inBucket })
            end
            T.waitFor(self, function()
                return self.items.items[2]:getFluidContainer():isFull()
                    and math.abs(self.items.items[1]:getFluidContainer():getAmount() - case.inBucket) < T.LITRES
            end, "this client's copies of the filled bottle and bucket")
            T.goNextTo(self, spots[1].square)
            T.step(function()
                local copy = T.copyOf(self.unit)
                local context = T.need(self, copy and T.worldMenu(copy), "a world menu for the unit")
                if not context then return end
                local drink = T.optionRunning(context, ISWorldObjectContextMenu.onDrink)
                local fill = T.optionRunning(context, ISWorldObjectContextMenu.onTakeWater)
                self.drink, self.drinkTooltip = T.offered(drink), T.tooltipOf(drink)
                self.fill = T.offered(fill)
                self.empty = T.offered(T.optionRunning(context, ISWorldObjectContextMenu.onFluidEmpty))
                self.pour = T.findNamed(context, context, getText("ContextMenu_AddFluidFromItem")) ~= nil
                if fill then
                    T.choose(fill)
                end
                context:hideAndChildren()
            end)
            readUntil(self, self.unit, "drawn", function(state) return state.basin.litres < case.litres - 1 end)
            T.read(self, "treatment.carried", { type = "Base.Bucket" }, "bucket")
        end,
        validate = function(self)
            expect(self.drink, "the menu offers no Drink")
            local warns = self.drinkTooltip:find(getText("Tooltip_item_TaintedWater"), 1, true) ~= nil
            expect(warns == case.tainted, "Drink's tooltip " .. (warns and "warns" or "doesn't warn")
                .. " of tainted water: " .. self.drinkTooltip)
            expect(self.fill, "the menu offers no Fill for the bucket")
            expect(self.empty, "the menu offers no Empty")
            expect(not self.pour, "the menu offers vanilla's pour into the basin")
            local bucket = self.reads.bucket
            expect(bucket.litres > case.inBucket + 1, "Fill took nothing from the basin")
            expectNear("the basin and bucket", self.reads.drawn.basin.litres + bucket.litres, case.litres + case.inBucket,
                T.LITRES)
            expect(bucket.tainted == case.tainted, "the bucket filled from the basin holds "
                .. (bucket.tainted and "tainted" or "clean") .. " water")
        end,
    })
end

-- Unloaded -------------------------------------------------------------------------------------------------

-- A filter's record waits while its chunk is away: the ten-minute pass leaves its head as it was,
-- however long ago it last ran. Loaded again, one pass treats the whole gap at its rate. Catches a
-- record that treats into a basin it can't reach, or forgets the time it was away.
T.test("irrigation_treatment_record_catches_up_after_its_chunk_reloads", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves",
    instant = true,
    timeoutSeconds = T.RELOAD_SECONDS,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.gap = 5
        self.unit = placeUnit(self, spots[1], BARREL, { fields = { head = 40, ripeHours = Treatment.RIPE_HOURS } })
        T.reload(self, T.at(self.unit), function()
            T.read(self, "treatment.update", T.at(self.unit, { hoursAgo = self.gap }), "away")
        end)
        T.read(self, "treatment.update", T.at(self.unit), "back")
    end,
    validate = function(self)
        T.expectReloaded(self, "filter")
        local away, back = self.reads.away, self.reads.back
        expect(not away.after.loaded, "the filter's chunk stayed loaded on the server")
        expectNear("the head while away", away.after.record.head, 40, T.LITRES)
        -- From the clock wound back while away to the pass after the reload, whichever pass ran it.
        local litres = self.unit.spec.rate * (back.now - (away.now - self.gap))
        expectBasin("the server, back", back.after, litres, false)
        expectNear("the head, back", back.after.record.head, 40 - litres, T.LITRES)
    end,
})

-- The Filter Crock ------------------------------------------------------------------------------------------

local UNFIRED = "EnhancedIrrigation.FilterCrockUnfired"
-- A bucket other than the one Take Down gives when it doesn't know, so a test sees the right one come back.
local FORGED_BUCKET = "Base.BucketForged"

-- Shape Filter Crock at a pottery wheel makes an unfired crock from the clay and charcoal, with
-- water from the carried bottle. Catches a recipe the wheel won't make, or one that leaves its
-- inputs.
T.test("irrigation_treatment_crock_shaped_at_a_pottery_wheel", {
    instant = true,
    run = function(self)
        T.craft(self, "EnhancedIrrigation_ShapeFilterCrock", "Base.Clay", { UNFIRED, "Base.Clay", "Base.Charcoal" }, { bench = { "Base.Pottery_Wheel", "crafted_01_65" }, prefer = { "Base.WaterBottle", "Base.Charcoal" }, ready = function()
            T.server(self, "treatment.fillCarried", { type = "Base.WaterBottle", fluid = "Water", litres = 1 })
            T.waitFor(self, function()
                local bottle = T.player():getInventory():getFirstTypeRecurse("Base.WaterBottle")
                return bottle ~= nil and math.abs(bottle:getFluidContainer():getAmount() - 1) < T.LITRES
            end, "this client's copy of the filled bottle")
        end })
    end,
    validate = function(self)
        local craft = self.counts and self.counts.craft or {}
        expect(craft[UNFIRED] == 1, "shaping made " .. tostring(craft[UNFIRED]) .. " unfired crocks")
        expect(craft["Base.Clay"] == 0 and craft["Base.Charcoal"] == 0, "shaping left clay or charcoal")
    end,
})

-- Fire Filter Crock at a kiln makes the crock from the unfired one. Catches a recipe the kiln
-- won't fire.
T.test("irrigation_treatment_crock_fired_in_a_kiln", {
    instant = true,
    run = function(self)
        T.craft(self, "EnhancedIrrigation_FireFilterCrock", UNFIRED, { Treatment.CROCK_ITEM, UNFIRED }, { bench = { "Base.Kiln_Small", "crafted_01_56" }, prefer = { "Base.Charcoal" } })
    end,
    validate = function(self)
        local craft = self.counts and self.counts.craft or {}
        expect(craft[Treatment.CROCK_ITEM] == 1 and craft[UNFIRED] == 0,
            "firing left " .. tostring(craft[UNFIRED]) .. " unfired and made " .. tostring(craft[Treatment.CROCK_ITEM]))
    end,
})

-- The build menu sets a Filter Crock in an empty bucket on a bare square, with its record at once:
-- this client's menu reads its empty head. Take Down, once the crock has seeped water into that
-- bucket, gives back the bucket holding it clean, and the crock, and takes the unit away, record
-- and all. Catches a crock the build menu can't set up, a unit without its record, or Take Down
-- losing the crock, swapping the bucket or spilling its water.
T.test("irrigation_treatment_crock_set_in_a_bucket_and_taken_down", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = T.buildFromMenu(self, "Base." .. CROCK, spots[1], SPRITES[CROCK], { FORGED_BUCKET })
        if not self.unit then return end
        self.unit.spec = Treatment.UNITS[CROCK]
        readUntil(self, self.unit, "built", function(state) return state.record ~= nil end)
        T.waitFor(self, function() return Treatment.summaryOf(T.copyOf(self.unit)) ~= nil end,
            "this client's summary of the crock")
        T.readMenu(self, self.unit, "built")
        self.litres = 6
        fillBasin(self, self.unit, self.litres)
        T.useMenu(self, self.unit, "take down", T.job("treatment", TreatmentJobs.TAKE_DOWN_CROCK), true)
        readUntil(self, self.unit, "taken", function(state) return not state.found end)
        T.count(self, "taken", { Treatment.CROCK_ITEM, FORGED_BUCKET })
        T.read(self, "treatment.carried", { type = FORGED_BUCKET }, "bucket")
    end,
    validate = function(self)
        local built = self.reads.built
        expect(built.entity == CROCK, "the build menu built " .. tostring(built.entity))
        expect(built.record and built.record.head == 0, "the crock has no record, or water in its head")
        expect(built.basin and built.basin.litres == 0 and built.basin.locked, "the crock's basin isn't empty and locked")
        expectLine(self, "built", getText("IGUI_EnhancedIrrigation_Head", 0, Treatment.UNITS[CROCK].head))
        T.expectOffered(self, "take down")
        local taken = self.reads.taken
        expect(not taken.found and not taken.record, "Take Down left the unit or its record")
        local back = self.counts.taken
        expect(back[Treatment.CROCK_ITEM] == 1, "Take Down gave back " .. tostring(back[Treatment.CROCK_ITEM]) .. " crocks")
        expect(back[FORGED_BUCKET] == 1, "Take Down gave back " .. tostring(back[FORGED_BUCKET])
            .. " forged buckets, the crock's record naming " .. tostring(self.reads.built.record.bucket))
        local bucket = self.reads.bucket
        expectNear("the bucket's water", bucket.litres, self.litres, T.LITRES)
        expect(not bucket.tainted, "the bucket came back tainted")
    end,
})

-- Pour In from a bucket of tainted water fills the crock's head and leaves the rest in the bucket;
-- later the bucket under it holds clean water at the crock's rate, on both sides, and
-- the menu says what is still waiting. Scrub Crock is greyed out, as it isn't clogged. Catches a
-- crock that passes taint, runs at the wrong rate, or takes more than it holds.
T.test("irrigation_treatment_crock_seeps_clean_water_from_tainted", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], CROCK)
        T.give(self, "carried", { { type = "Base.Bucket" } })
        T.server(self, "treatment.fillCarried", { type = "Base.Bucket", fluid = "TaintedWater", litres = 10 })
        T.waitFor(self, function() return self.items.carried[1]:getFluidContainer():getAmount() > 10 - T.LITRES end,
            "this client's copy of the filled bucket")
        T.useMenu(self, self.unit, "scrub", T.job("treatment", TreatmentJobs.SCRUB_CROCK), false)
        T.useMenu(self, self.unit, "pour", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.items.carried[1])
        end, true)
        readUntil(self, self.unit, "poured", function(state)
            return state.record and state.record.head + state.basin.litres > self.unit.spec.head - T.LITRES
        end)
        T.read(self, "treatment.carried", { type = "Base.Bucket" }, "bucket")
        self.hours = 12
        run(self, self.unit, "run", { self.hours })
        -- The server's answer decides what this client's copy must come to show.
        T.waitFor(self, function()
            local after = self.reads.run and self.reads.run.steps[1]
            local copy = T.copyOf(self.unit)
            local summary = copy and Treatment.summaryOf(copy)
            return after ~= nil and summary ~= nil and math.abs(summary.head - after.record.head) < 0.1
                and math.abs(copy:getFluidContainer():getAmount() - after.basin.litres) < T.LITRES
        end, "this client's copy of the crock after half a day")
        T.readMenu(self, self.unit, "seeping")
    end,
    validate = function(self)
        local spec = self.unit.spec
        T.expectRefused(self, "scrub", "Tooltip_EnhancedIrrigation_NotClogged")
        T.expectOffered(self, "pour")
        local poured = self.reads.poured
        expectNear("the head and basin after pouring", poured.record.head + poured.basin.litres, spec.head, T.LITRES)
        expectNear("the bucket's water left", self.reads.bucket.litres, 10 - spec.head, T.LITRES)
        local before, after = self.reads.run.before, self.reads.run.steps[1]
        local litres = spec.rate * self.hours
        expectBasin("the server", after, before.basin.litres + litres, false)
        expectBasin("this client", clientBasin(self.unit), before.basin.litres + litres, false)
        expectNear("the head left", after.record.head, before.record.head - litres, T.LITRES)
        local left = after.record.head
        expectLine(self, "seeping", getText("IGUI_EnhancedIrrigation_Head", math.floor(left + 0.5), spec.head))
        expectLine(self, "seeping", getText("IGUI_EnhancedIrrigation_Clogged"), false)
    end,
})

-- Past its litres a crock trickles, and its menu says it's clogged; Scrub Crock, by hand, restores
-- its rate at once. Catches a clog that never comes, or a scrub that leaves it clogged.
T.test("irrigation_treatment_crock_clogged_until_scrubbed", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], CROCK)
        self.hours = 12
        run(self, self.unit, "clogged", { self.hours }, { head = 8, headTainted = true, passed = self.unit.spec.clogLitres })
        waitForCopy(self, self.unit, nil, function(summary) return summary.clogged end,
            "this client's summary of the clogged crock")
        T.readMenu(self, self.unit, "clogged")
        T.useMenu(self, self.unit, "scrub", T.job("treatment", TreatmentJobs.SCRUB_CROCK), true)
        readUntil(self, self.unit, "scrubbed", function(state) return not state.summary.clogged end)
        run(self, self.unit, "after", { self.hours })
    end,
    validate = function(self)
        local spec = self.unit.spec
        local clogged = self.reads.clogged
        expectNear("a clogged crock's half day", clogged.steps[1].basin.litres - clogged.before.basin.litres,
            spec.rate * Treatment.CLOGGED_FACTOR * self.hours, T.LITRES)
        expectLine(self, "clogged", getText("IGUI_EnhancedIrrigation_Clogged"))
        T.expectOffered(self, "scrub")
        local after = self.reads.after
        expectNear("a scrubbed crock's half day", after.steps[1].basin.litres - after.before.basin.litres,
            spec.rate * self.hours, T.LITRES)
        expect(not after.steps[1].basin.tainted, "a scrubbed crock passed tainted water")
    end,
})

-- A hard freeze cracks a crock with water in it, which spills and passes nothing that hour; its menu
-- says so and Pour In is greyed out, so it takes no water again; an empty crock rides it out.
-- Catches frost ignored, a crock that passes water as it cracks, a cracked crock poured into, or an
-- empty one cracked.
T.test("irrigation_treatment_crock_cracks_frozen_full", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.wet = placeUnit(self, spots[1], CROCK)
        self.dry = placeUnit(self, spots[2], CROCK)
        T.server(self, "lines.temperature", { celsius = EnhancedIrrigation.Frost.HARD_FREEZE_CELSIUS - 3 })
        run(self, self.wet, "wet", { 1 }, { head = 5 })
        run(self, self.dry, "dry", { 1 }, { head = 0 })
        waitForCopy(self, self.wet, nil, function(summary) return summary.cracked end,
            "this client's summary of the cracked crock")
        waitForServer(self, self.dry, "dry", "cracked")
        T.readMenu(self, self.wet, "cracked")
        T.readMenu(self, self.dry, "dry")
        T.give(self, "carried", { { type = "Base.Bucket" } })
        T.server(self, "treatment.fillCarried", { type = "Base.Bucket", fluid = "TaintedWater", litres = 5 })
        T.waitFor(self, function() return self.items.carried[1]:getFluidContainer():getAmount() > 5 - T.LITRES end,
            "this client's copy of the filled bucket")
        T.useMenu(self, self.wet, "pour", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.items.carried[1])
        end, false)
    end,
    validate = function(self)
        local wet = self.reads.wet
        expectLine(self, "cracked", getText("IGUI_EnhancedIrrigation_Head", 0, self.wet.spec.head))
        expectNear("the cracked crock's basin", wet.steps[1].basin.litres, wet.before.basin.litres, T.LITRES)
        T.expectWord(self, "dry", getText("IGUI_EnhancedIrrigation_Cracked"), false)
        expectLine(self, "cracked", getText("IGUI_EnhancedIrrigation_Cracked"))
        T.expectRefused(self, "pour", "Tooltip_EnhancedIrrigation_CrockCracked")
    end,
})

-- A crock frost cracked is lost to Take Down, which still gives back the bucket it stood in, with
-- the water it seeped before the frost: the plain bucket Take Down falls back on, as this crock's
-- record never learned which it stood in. Catches the water spilled with the crock, or a cracked
-- crock returned whole.
T.test("irrigation_treatment_crock_take_down_returns_the_bucket_and_its_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], CROCK)
        self.litres = 3
        fillBasin(self, self.unit, self.litres)
        T.server(self, "lines.temperature", { celsius = EnhancedIrrigation.Frost.HARD_FREEZE_CELSIUS - 3 })
        run(self, self.unit, "frozen", { 1 }, { head = self.unit.spec.head })
        T.useMenu(self, self.unit, "take down", T.job("treatment", TreatmentJobs.TAKE_DOWN_CROCK), true)
        readUntil(self, self.unit, "taken", function(state) return not state.found end)
        T.count(self, "back", { Treatment.CROCK_ITEM, Treatment.CROCK_BUCKET })
        T.read(self, "treatment.carried", { type = Treatment.CROCK_BUCKET }, "bucket")
    end,
    validate = function(self)
        local frozen = self.reads.frozen.steps[1]
        expect(frozen.record.cracked, "the frost didn't crack the crock")
        expectNear("the cracked crock's basin", frozen.basin.litres, self.litres, T.LITRES)
        T.expectOffered(self, "take down")
        local taken = self.reads.taken
        expect(not taken.found and not taken.record, "Take Down left the unit or its record")
        local back = self.counts.back
        expect(back[Treatment.CROCK_ITEM] == 0, "Take Down gave back " .. tostring(back[Treatment.CROCK_ITEM])
            .. " crocks from a cracked one")
        expect(back[Treatment.CROCK_BUCKET] == 1, "Take Down gave back " .. tostring(back[Treatment.CROCK_BUCKET])
            .. " plain buckets")
        expectNear("the cracked crock's bucket", self.reads.bucket.litres, self.litres, T.LITRES)
    end,
})

-- The Boilers ------------------------------------------------------------------------------------------

-- The squares round a boiler's that Treatment.wallNear reads, its own first: those around it and,
-- for their east and south edges, the row and column beyond.
local CLEAR = { { 0, 0 } }
for dx = -1, 2 do
    for dy = -1, 2 do
        if dx ~= 0 or dy ~= 0 then
            table.insert(CLEAR, { dx, dy })
        end
    end
end

-- The handle of a bare outdoor square with nothing on the squares around it to put a wall near it,
-- or nil.
local function clearSpot(self)
    local spots = T.layout(self, CLEAR, { bare = true })
    return spots and spots[1]
end

-- Whether the build cursor of `entity` would take `square` (ISBuildIsoEntity:isValid, the
-- entity's OnIsValid among it). Server Lua, loaded after this file, so reached at call time.
local function placeable(entity, square)
    local player = T.player()
    local build = ISBuildIsoEntity:new(player, T.buildEntry("Base." .. entity), 1,
        ISInventoryPaneContextMenu.getContainers(player))
    build.player = player:getPlayerNum()
    return build:isValid(square)
end

local function running(handler)
    return function(context) return T.optionRunning(context, handler) end
end

-- The build menu builds each boiler from its recipe on a clear outdoor square: a vanilla fireplace
-- on both sides, with its record at once. Its menu holds vanilla's Add Fuel and Light beside its
-- own line, which reads the empty drum cold and sound. Catches a recipe the build menu can't build,
-- a boiler that isn't a fire or has no record, or its menu split from the fire's.
for _, entity in ipairs({ STONE, WELDED }) do
    T.test("irrigation_treatment_boiler_" .. (entity == STONE and "stone" or "welded") .. "_built_from_build_menu", {
        instant = true,
        run = function(self)
            local spot = clearSpot(self)
            if not spot then return end
            self.unit = T.buildFromMenu(self, "Base." .. entity, spot, SPRITES[entity])
            if not self.unit then return end
            self.unit.spec = Treatment.UNITS[entity]
            readUntil(self, self.unit, "built", function(state) return state.record ~= nil end)
            T.waitFor(self, function() return Treatment.summaryOf(T.copyOf(self.unit)) ~= nil end,
                "this client's summary of the built boiler")
            T.readMenu(self, self.unit, "built")
            T.step(function()
                local copy = T.copyOf(self.unit)
                self.clientFire = copy ~= nil and instanceof(copy, "IsoFireplace")
            end)
        end,
        validate = function(self)
            local built = self.reads.built
            expect(built.entity == entity, "the build menu built " .. tostring(built.entity))
            expect(built.fireplace, "the built boiler isn't a vanilla fireplace on the server")
            expect(self.clientFire, "this client's copy of the boiler isn't a vanilla fireplace")
            expect(built.record and built.record.head == 0, "the built boiler has no record, or water in its head")
            expect(built.basin and built.basin.litres == 0 and built.basin.locked, "the built boiler's basin isn't empty and locked")
            expectLine(self, "built", getText("IGUI_EnhancedIrrigation_Head", 0, self.unit.spec.head))
            T.expectWord(self, "built", getText("IGUI_EnhancedIrrigation_Cold"))
            T.expectWord(self, "built", getText("IGUI_EnhancedIrrigation_Drum", Treatment.DRUM_CONDITION))
            expectLine(self, "built", campingText.addFuel)
            expectLine(self, "built", campingText.lightCampfire)
        end,
    })
end

-- The build cursor takes each boiler on a clear outdoor square, but not indoors, nor once a wall
-- stands on an edge of the square. Catches a fire built in a house or against its wall, or a boiler
-- that can't be built anywhere.
T.test("irrigation_treatment_boiler_refused_indoors_or_by_a_wall", {
    instant = true,
    run = function(self)
        local clear = clearSpot(self)
        local indoors = clear and T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not indoors then return end
        self.placed = {}
        T.step(function()
            for _, entity in ipairs({ STONE, WELDED }) do
                self.placed[entity] = { clear = placeable(entity, clear.square),
                    indoors = placeable(entity, indoors[1].square) }
            end
        end)
        local east = { x = clear.x + 1, y = clear.y, z = clear.z }
        T.server(self, "treatment.wall", T.at(east, { sprite = T.WALL_WEST }))
        T.waitFor(self, function()
            return getSquare(east.x, east.y, east.z):getProperties():has(IsoFlagType.collideW)
        end, "this client's copy of the wall")
        T.step(function()
            for entity, placed in pairs(self.placed) do
                placed.walled = placeable(entity, clear.square)
            end
        end)
    end,
    validate = function(self)
        for _, entity in ipairs({ STONE, WELDED }) do
            local placed = self.placed[entity]
            expect(placed.clear, "the build cursor refuses the " .. entity .. " on a clear outdoor square")
            expect(not placed.indoors, "the build cursor takes the " .. entity .. " indoors")
            expect(not placed.walled, "the build cursor takes the " .. entity .. " beside a wall")
        end
    end,
})

-- Queues placing a stone boiler on a bare square and adding fuel from vanilla's fire menu on it, as
-- self.unit and self.reads.fuelled. A box of tissues burns a use at a time: a fuel item used up
-- whole leaves vanilla's Add Fuel invalid on a multiplayer client (ISBBQAddFuel:isValid), which
-- clears the queue the test waits in.
local function fuelled(self)
    local spots = T.layout(self, { { 0, 0 } }, { bare = true })
    if not spots then return false end
    self.unit = placeUnit(self, spots[1], STONE)
    T.give(self, "fire", { { type = "Base.TissueBox" }, { type = "Base.Splinters" }, { type = "Base.Lighter" } })
    T.useMenu(self, self.unit, "add fuel", running(ISCampingMenu.onAddFuel), true)
    readUntil(self, self.unit, "fuelled", function(state) return (state.fuel or 0) > 0 end)
    return true
end

-- Queues a wait for this client's copy of the boiler burning with vanilla's flames on it, then
-- reads its menu into "burning".
local function burning(self)
    T.waitFor(self, function()
        local copy = T.copyOf(self.unit)
        return copy ~= nil and copy:isLit() and copy:hasAnimatedAttachments()
    end, "this client's copy of the boiler burning, with vanilla's flames")
    T.readMenu(self, self.unit, "burning")
end

-- Vanilla's fire menu on the boiler adds fuel and offers to light it; lit as vanilla's Light leaves
-- it, this client draws vanilla's flames on it, the boiler's own line says it's heating and the fire
-- menu offers Put Out. Catches a boiler vanilla's fire menu can't fuel, one that burns without
-- flames, or a fire the boiler's line doesn't see.
T.test("irrigation_treatment_boiler_vanilla_fuels_it_and_draws_its_flames", {
    mpOnly = "in single player irrigation_treatment_boiler_vanilla_lights_and_puts_it_out runs this path with "
        .. "vanilla's own Light and Put Out",
    instant = true,
    run = function(self)
        if not fuelled(self) then return end
        T.useMenu(self, self.unit, "light", running(ISCampingMenu.onLightFromLiterature), false)
        setFire(self, self.unit, "lit", true, FUEL)
        burning(self)
        T.useMenu(self, self.unit, "put out", running(ISBBQMenu.onExtinguish), false)
    end,
    validate = function(self)
        T.expectOffered(self, "add fuel")
        expect(self.reads.fuelled.fuel > 0, "Add Fuel gave the boiler no fuel")
        T.expectOffered(self, "light")
        T.expectWord(self, "burning", getText("IGUI_EnhancedIrrigation_Heating"))
        T.expectOffered(self, "put out")
    end,
})

-- Vanilla's fire menu adds fuel to the boiler, and its Light, with splinters and a lighter, lights
-- it: this client draws vanilla's flames on it and the boiler's line says it's heating. Its Put Out
-- puts it out. Catches a boiler vanilla's fire menu can't fuel or its own fire actions can't run.
T.test("irrigation_treatment_boiler_vanilla_lights_and_puts_it_out", {
    spOnly = "on a multiplayer client vanilla's Light and Put Out end invalid when the server's change "
        .. "to the fire arrives first (ISBBQLightFromLiterature and ISBBQExtinguish check the fire's "
        .. "state), which clears the queue the test waits in; the fire's sync is the other boiler tests'",
    instant = true,
    run = function(self)
        if not fuelled(self) then return end
        T.useMenu(self, self.unit, "light", running(ISCampingMenu.onLightFromLiterature), true)
        readUntil(self, self.unit, "lit", function(state) return state.lit end)
        burning(self)
        T.useMenu(self, self.unit, "put out", running(ISBBQMenu.onExtinguish), true)
        readUntil(self, self.unit, "out", function(state) return not state.lit end)
    end,
    validate = function(self)
        T.expectOffered(self, "add fuel")
        expect(self.reads.fuelled.fuel > 0, "Add Fuel gave the boiler no fuel")
        T.expectOffered(self, "light")
        expect(self.reads.lit.lit, "Light didn't light the boiler")
        T.expectWord(self, "burning", getText("IGUI_EnhancedIrrigation_Heating"))
        T.expectOffered(self, "put out")
        expect(not self.reads.out.lit, "Put Out left the boiler burning")
    end,
})

-- Raw water waits in a lit boiler's head while the drum heats, and its menu says so; once hot, the
-- boiler passes clean water at its rate, and its menu says so. Put out, the hot drum passes on while
-- it cools, then nothing, and its menu says it's cold; a boiler never lit passes nothing. Catches
-- water passed before it's safe, a boiler that never passes, one that keeps passing cold, or the
-- taint carried through.
T.test("irrigation_treatment_boiler_passes_clean_water_only_while_hot", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], STONE)
        self.cold = placeUnit(self, spots[2], WELDED)
        -- More than three hours of the boiler's water, so the head lasts the test, in the drum before
        -- the fire is lit so that it never burns dry.
        self.head = self.unit.spec.rate * 4
        run(self, self.unit, "raw", {}, { head = self.head, headTainted = true })
        setFire(self, self.unit, "lit", true, FUEL)
        T.readMenu(self, self.unit, "heating")
        -- Each run starts the drum at the heat the steps before left it, which a ten-minute pass in
        -- between would have moved on a little.
        run(self, self.unit, "heating", { 1 }, { hotHours = 0 })
        run(self, self.unit, "hot", { 1 })
        waitForServer(self, self.unit, "hot", "hot")
        T.readMenu(self, self.unit, "hot")
        setFire(self, self.unit, "out", false)
        run(self, self.unit, "cooling", { 1, 1 }, { hotHours = Treatment.HEAT_MAX_HOURS })
        waitForServer(self, self.unit, "cooling", "hot")
        T.readMenu(self, self.unit, "cooled")
        run(self, self.cold, "cold", { 2 }, { head = self.head, headTainted = true })
        T.readMenu(self, self.cold, "cold")
    end,
    validate = function(self)
        local rate = self.unit.spec.rate
        local heating = self.reads.heating
        expectNear("the first hour's water", heating.steps[1].basin.litres - heating.before.basin.litres, 0, T.LITRES)
        T.expectWord(self, "heating", getText("IGUI_EnhancedIrrigation_Heating"))
        local hot = self.reads.hot
        expectBasin("the hot hour's water", hot.steps[1], hot.before.basin.litres + rate, false)
        T.expectWord(self, "hot", getText("IGUI_EnhancedIrrigation_Hot"))
        T.expectWord(self, "hot", getText("IGUI_EnhancedIrrigation_Drum",
            Treatment.DRUM_CONDITION - 2 * Treatment.WEAR_WET))
        local cooling = self.reads.cooling
        expectNear("the first hour put out", cooling.steps[1].basin.litres - cooling.before.basin.litres,
            rate * (Treatment.HEAT_MAX_HOURS - Treatment.HOT_HOURS) / Treatment.COOLING, T.LITRES)
        expectNear("the second hour put out", cooling.steps[2].basin.litres - cooling.steps[1].basin.litres, 0, T.LITRES)
        T.expectWord(self, "cooled", getText("IGUI_EnhancedIrrigation_Cold"))
        expectNear("a boiler never lit", self.reads.cold.steps[1].basin.litres, 0, T.LITRES)
        T.expectWord(self, "cold", getText("IGUI_EnhancedIrrigation_Cold"))
    end,
})

-- A boiler lit with nothing in its drum scorches it fast. Worn nearly through, water poured in
-- goes with the drum as its fire burns it through, running out rather than passing; burnt through,
-- its menu says so and Pour In is refused. Patch Drum, put out and with a welder's kit, restores it
-- to less than new, and its menu says how much; a second patch would leave it no better and is
-- refused. A drum that cooled while holed comes back from its patch cold, and passes nothing unlit.
-- Catches a dry fire that doesn't wear, a drum burnt through that keeps its water or passes it, a
-- holed drum poured into, a patch that restores it new, or one that finds it as hot as when it
-- failed.
T.test("irrigation_treatment_boiler_scorches_dry_and_is_patched", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], WELDED)
        setFire(self, self.unit, "lit", true, FUEL)
        run(self, self.unit, "scorched", { 1 })
        -- Burnt dry to less than an hour's wear with water in it, then put out at once, as the fire's
        -- minutes until the pour would wear it on dry; lit again once the water is in.
        T.step(function()
            local condition = self.reads.scorched.steps[1].record.condition
            run(self, self.unit, "burnt", { (condition - Treatment.WEAR_WET / 2) / Treatment.WEAR_DRY })
            setFire(self, self.unit, "doused", false)
        end)
        T.give(self, "carried", { { type = "Base.Bucket" } })
        T.server(self, "treatment.fillCarried", { type = "Base.Bucket", fluid = "Water", litres = 5 })
        T.waitFor(self, function() return self.items.carried[1]:getFluidContainer():getAmount() > 5 - T.LITRES end,
            "this client's copy of the filled bucket")
        T.useMenu(self, self.unit, "pour", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.items.carried[1])
        end, true)
        readUntil(self, self.unit, "poured", function(state) return state.record and state.record.head > 0 end)
        setFire(self, self.unit, "relit", true, FUEL)
        run(self, self.unit, "holed", { 1 })
        waitForServer(self, self.unit, "holed", "burntThrough")
        T.readMenu(self, self.unit, "burnt")
        T.server(self, "treatment.fillCarried", { type = "Base.Bucket", fluid = "Water", litres = 5 })
        T.waitFor(self, function() return self.items.carried[1]:getFluidContainer():getAmount() > 5 - T.LITRES end,
            "this client's copy of the refilled bucket")
        T.useMenu(self, self.unit, "holed pour", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.items.carried[1])
        end, false)
        setFire(self, self.unit, "out", false)
        run(self, self.unit, "cooled", { 2 })
        T.setPerk(self, Perks.MetalWelding, 2)
        T.give(self, "kit", { { type = "Base.WeldingMask" }, { type = "Base.SmallSheetMetal" }, { type = "Base.BlowTorch" },
            { type = "Base.WeldingRods" } })
        T.useMenu(self, self.unit, "patch", T.job("treatment", TreatmentJobs.PATCH_DRUM), true)
        readUntil(self, self.unit, "patched", function(state) return not state.summary.burntThrough end)
        waitForServer(self, self.unit, "patched", "condition")
        T.readMenu(self, self.unit, "patched")
        run(self, self.unit, "after patch", { 1 }, { head = 20, headTainted = true })
        T.useMenu(self, self.unit, "again", T.job("treatment", TreatmentJobs.PATCH_DRUM), false)
        T.count(self, "used", { "Base.SmallSheetMetal" })
    end,
    validate = function(self)
        expect(self.reads.scorched.steps[1].summary.condition == Treatment.DRUM_CONDITION - Treatment.WEAR_DRY,
            "an hour burning dry left the drum at " .. tostring(self.reads.scorched.steps[1].summary.condition))
        T.expectOffered(self, "pour")
        local holed = self.reads.holed
        expect(holed.before.record.head > 0, "the drum held no water as its last hour began")
        expect(holed.steps[1].summary.burntThrough, "the wet drum's last hour didn't burn it through")
        expectNear("the head of a drum burnt through", holed.steps[1].record.head, 0, T.LITRES)
        expectNear("a burnt-through boiler's hour", holed.steps[1].basin.litres, holed.before.basin.litres, T.LITRES)
        T.expectWord(self, "burnt", getText("IGUI_EnhancedIrrigation_BurntThrough"))
        T.expectRefused(self, "holed pour", "Tooltip_EnhancedIrrigation_BurntThrough")
        T.expectOffered(self, "patch")
        T.expectWord(self, "patched", getText("IGUI_EnhancedIrrigation_Drum",
            Treatment.DRUM_CONDITION - Treatment.PATCH_LOSS))
        T.expectRefused(self, "again", "Tooltip_EnhancedIrrigation_DrumSound")
        T.expectWord(self, "patched", getText("IGUI_EnhancedIrrigation_Cold"))
        local after = self.reads["after patch"]
        expectNear("a patched, unlit boiler's hour", after.steps[1].basin.litres, after.before.basin.litres, T.LITRES)
        expect(self.counts.used["Base.SmallSheetMetal"] == 0, "Patch Drum left the sheet metal")
    end,
})

-- Plumb Inlet from a raw tank on the boiler's level and Plumb Outlet to a clean one, from the
-- boiler's menu: lit, its first hour fills the drum from the raw tank, and its second passes clean
-- water at its rate on into the clean tank. Catches a boiler the pipes can't reach, water lost or
-- made on the way, or the taint carried into the clean tank.
T.test("irrigation_treatment_boiler_plumbed_from_raw_to_clean", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 }, { 0, 3 } }, { bare = true })
        if not spots then return end
        self.raw = 100
        self.unit = placeUnit(self, spots[1], STONE)
        self.tank = T.placeTank(self, spots[2], "lidded", self.raw, true)
        self.clean = T.placeTank(self, spots[3], "lidded")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = 2 } })
        T.useMenu(self, self.unit, "inlet", T.job("link", LinkJobs.PLUMB_INLET, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.unit, "inlet plumbed", function(state) return state.inlet end)
        T.useOption(self, function() return T.copyOf(self.unit) end, "outlet",
            T.job("link", LinkJobs.PLUMB_OUTLET, Links.encode(T.at(self.clean), "iron")), true)
        readUntil(self, self.unit, "plumbed", function(state) return state.outlet end)
        setFire(self, self.unit, "lit", true, FUEL)
        -- From a cold drum, which a ten-minute pass since the fire was lit would have warmed a little.
        T.read(self, "treatment.run", T.at(self.unit, { hours = { 1, 1 }, fields = { hotHours = 0 }, tank = T.at(self.tank),
            into = T.at(self.clean) }), "hours")
    end,
    validate = function(self)
        T.expectOffered(self, "inlet")
        T.expectOffered(self, "outlet")
        local rate = self.unit.spec.rate
        local before, first, second = self.reads.hours.before, self.reads.hours.steps[1], self.reads.hours.steps[2]
        local function out(state) return state.basin.litres + state.into.litres end
        expectNear("the drum after the first hour", first.record.head + out(first) - out(before), self.raw, T.LITRES)
        expectNear("the first hour's water", out(first) - out(before), 0, T.LITRES)
        expectNear("the second hour's water", out(second) - out(first), rate, T.LITRES)
        expectNear("the basin after the second hour", second.basin.litres, 0, T.LITRES)
        expect(not second.into.tainted, "the clean tank's water is tainted")
        expectNear("the raw tank", second.tank.litres, 0, T.LITRES)
    end,
})
