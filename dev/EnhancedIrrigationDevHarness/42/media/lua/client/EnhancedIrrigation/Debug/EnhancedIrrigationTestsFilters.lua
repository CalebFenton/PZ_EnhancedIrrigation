require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibTreatment"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/Frost"
require "EnhancedIrrigation/UI/LinkMenu"
require "EnhancedIrrigation/UI/TreatmentMenu"

-- Time runs on the server through the record's own advance for set hours, so the clock doesn't
-- decide what a test sees.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Links, LinkJobs, Treatment = EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Treatment
local TreatmentJobs, LinkMenu = EnhancedIrrigation.TreatmentJobs, EnhancedIrrigation.LinkMenu
local placeUnit, readUntil, run, waitForCopy = T.placeUnit, T.readUnitUntil, T.runUnit, T.waitForUnitCopy
local waitForServer, fillBasin, expectLine, expectBasin = T.waitForUnitServer, T.fillBasin, T.expectLine, T.expectBasin
local clientBasin = T.clientBasin

local BARREL_FILTER, BRICK = "EnhancedIrrigation_BarrelFilter", "EnhancedIrrigation_BrickFilter"

-- Building ----------------------------------------------------------------------------------------------

-- The build menu builds each filter from its recipe on a bare square, with its record at once:
-- this client's menu reads its state. Catches a recipe the build menu can't build, or a filter
-- without its record.
for _, entity in ipairs({ BARREL_FILTER, BRICK }) do
    T.test("irrigation_treatment_filter_" .. (entity == BARREL_FILTER and "barrel" or "brick") .. "_built_from_build_menu", {
        instant = true,
        run = function(self)
            T.buildUnit(self, entity)
        end,
        validate = function(self)
            T.expectBuiltUnit(self, entity)
            expectLine(self, "built", getText("IGUI_EnhancedIrrigation_Ripening", Treatment.RIPE_HOURS))
        end,
    })
end

-- Pour In ------------------------------------------------------------------------------------------------

-- Pour In from a carried bucket of tainted water fills the head as far as it has room, the bucket
-- keeping the rest, and the new filter's next hour passes it tainted. A can of petrol is greyed
-- out, and so, with the head full, is the bucket. Catches water lost or created, the taint dropped,
-- or anything but water on the sand.
T.test("irrigation_treatment_filter_pour_in_fills_the_head", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        local head = Treatment.ENTITIES[BARREL_FILTER].head
        self.room = 5
        self.unit = placeUnit(self, spots[1], BARREL_FILTER, { fields = { head = head - self.room } })
        T.give(self, "carried", { { type = "Base.Bucket" }, { type = "Base.PetrolCan" } })
        T.fillCarried(self, "Base.Bucket", "TaintedWater", 10)
        T.fillCarried(self, "Base.PetrolCan", "Petrol", 5)
        local function bucket() return self.items.carried[1] end
        local function can() return self.items.carried[2] end
        T.useMenu(self, self.unit, "petrol", T.job("treatment", TreatmentJobs.POUR_IN, can), false)
        T.useMenu(self, self.unit, "pour", T.job("treatment", TreatmentJobs.POUR_IN, bucket), true)
        readUntil(self, self.unit, "poured", function(state)
            return state.record and state.record.head + state.basin.litres > head - T.LITRES
        end)
        T.readCarried(self, { "Base.Bucket" }, nil, "bucket")
        T.waitFor(self, function()
            local summary = Treatment.summaryOf(T.copyOf(self.unit))
            return summary ~= nil and summary.head > head - 1
        end, "this client's summary of the full head")
        T.useMenu(self, self.unit, "full", T.job("treatment", TreatmentJobs.POUR_IN, bucket), false)
        run(self, self.unit, "hour", { 1 })
    end,
    validate = function(self)
        local head = Treatment.ENTITIES[BARREL_FILTER].head
        T.expectOptionRefused(self, "petrol", "Tooltip_EnhancedIrrigation_OnlyWater")
        T.expectOffered(self, "pour")
        local poured = self.reads.poured
        expectNear("the head and basin after pouring", poured.record.head + poured.basin.litres, head, T.LITRES)
        local hour = self.reads.hour
        expectBasin("the hour's water", hour.steps[1], hour.before.basin.litres + Treatment.ENTITIES[BARREL_FILTER].rate, true)
        local bucket = T.carriedFirst(self, "Base.Bucket", "bucket")
        expectNear("the bucket's water left", bucket.litres, 10 - self.room, T.LITRES)
        expect(bucket.tainted, "the bucket's water left is clean")
        T.expectOptionRefused(self, "full", "Tooltip_EnhancedIrrigation_HeadFull")
    end,
})

-- Through the sand ----------------------------------------------------------------------------------------

-- An unripe Barrel Filter passes its head's water as it is, at its rate: tainted from a tainted
-- head, on both sides. Catches a new filter that cleans, or one that runs at the wrong rate.
T.test("irrigation_treatment_filter_unripe_passes_tainted_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL_FILTER)
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
T.test("irrigation_treatment_filter_ripe_passes_clean_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BRICK)
        self.hours = 2
        run(self, self.unit, "run", { self.hours }, { head = 50, headTainted = true, ripeHours = Treatment.RIPE_HOURS })
        local litres = self.unit.spec.rate * self.hours
        waitForCopy(self, self.unit, litres, nil, "this client's copy of the filled basin")
        T.readMenu(self, function() return T.copyOf(self.unit) end, "ripe")
        T.useMenu(self, self.unit, "clean", T.job("treatment", TreatmentJobs.CLEAN_FILTER), false)
    end,
    validate = function(self)
        local litres = self.unit.spec.rate * self.hours
        local after = self.reads.run.steps[1]
        expectBasin("the server", after, litres, false)
        expectBasin("this client", clientBasin(self.unit), litres, false)
        T.expectWord(self, "ripe", getText("IGUI_EnhancedIrrigation_Ripe"))
        T.expectOptionRefused(self, "clean", "Tooltip_EnhancedIrrigation_NotClogged")
    end,
})

-- Enough hours with an empty head kill the film, which ripens from nothing again: a filter fed a
-- tainted head an hour short of them still passes it clean; one fed at them passes it tainted, and
-- before that its menu says it's ripening and how long it's been dry. Catches a film that never
-- dies, or dies early.
T.test("irrigation_treatment_filter_dry_spell_kills_the_layer", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.short = placeUnit(self, spots[1], BARREL_FILTER)
        self.dead = placeUnit(self, spots[2], BARREL_FILTER)
        run(self, self.short, "short", { Treatment.DRY_DEATH_HOURS - 1 }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
        run(self, self.short, "short fed", { 1 }, { head = 10, headTainted = true })
        run(self, self.dead, "dry", { Treatment.DRY_DEATH_HOURS }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
        waitForServer(self, self.dead, "dry", "ripeHours")
        T.readMenu(self, function() return T.copyOf(self.dead) end, "dead")
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
T.test("irrigation_treatment_filter_hard_freeze_kills_the_layer", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.wet = placeUnit(self, spots[1], BARREL_FILTER)
        self.dry = placeUnit(self, spots[2], BARREL_FILTER)
        T.server(self, "lines.temperature", { celsius = EnhancedIrrigation.Frost.HARD_FREEZE_CELSIUS - 3 })
        run(self, self.wet, "wet", { 1 }, { head = 20, ripeHours = Treatment.RIPE_HOURS })
        run(self, self.dry, "dry", { 1 }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
        waitForServer(self, self.wet, "wet", "ripeHours")
        waitForServer(self, self.dry, "dry", "ripeHours")
        T.readMenu(self, function() return T.copyOf(self.wet) end, "wet")
        T.readMenu(self, function() return T.copyOf(self.dry) end, "dry")
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
T.test("irrigation_treatment_filter_clogged_trickles_until_cleaned", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL_FILTER)
        local spec = self.unit.spec
        run(self, self.unit, "clogged", { 1 }, { head = 20, headTainted = true, ripeHours = Treatment.RIPE_HOURS,
            passed = spec.clogLitres })
        waitForCopy(self, self.unit, nil, function(summary) return summary.clogged end,
            "this client's summary of the clogged filter")
        T.readMenu(self, function() return T.copyOf(self.unit) end, "clogged")
        T.give(self, "tools", { { type = "Base.Shovel" } })
        T.useMenu(self, self.unit, "clean", T.job("treatment", TreatmentJobs.CLEAN_FILTER), true)
        readUntil(self, self.unit, "cleaned", function(state) return not state.summary.clogged end)
        waitForServer(self, self.unit, "cleaned", "clogged")
        T.readMenu(self, function() return T.copyOf(self.unit) end, "cleaned")
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
T.test("irrigation_treatment_filter_inlet_fills_the_head_from_a_tank", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL_FILTER)
        self.tank = T.placeTank(self, spots[2], "lidded", 100, true)
        T.givePlumbing(self, 1)
        T.useMenu(self, self.unit, "inlet", T.job("link", LinkJobs.PLUMB_INLET, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.unit, "plumbed", function(state) return state.inlet end)
        run(self, self.unit, "hour", { 1 }, nil, self.tank)
        T.count(self, "left", { "Base.MetalPipe" })
    end,
    validate = function(self)
        T.expectOffered(self, "inlet")
        expect(self.reads.plumbed.inlet, "the server didn't plumb the inlet")
        expect(T.counted(self, "Base.MetalPipe") == 0, "plumbing the inlet left the iron pipe")
        local spec = self.unit.spec
        local before, after = self.reads.hour.before, self.reads.hour.steps[1]
        expectNear("the head after an hour", after.record.head, spec.head - spec.rate, T.LITRES)
        expectBasin("the hour's water", after, before.basin.litres + spec.rate, true)
        expectNear("the water drawn", after.tank.litres + after.record.head + after.basin.litres, 100, T.LITRES)
    end,
})

-- A tank on a lower floor can't run into a filter's head: the inlet's submenu greys it out saying
-- so, and the server refuses on its own. Catches water piped uphill.
T.test("irrigation_treatment_filter_inlet_refuses_a_lower_tank", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL_FILTER, { up = 1 })
        self.tank = T.placeTank(self, spots[2], "ground", 100)
        T.givePlumbing(self, 1)
        T.useOption(self, function() return T.copyOf(self.unit) end, "lower tank", function(context)
            local label = LinkMenu.tankLabel(T.at(self.unit), T.at(self.tank))
            return T.inSubmenu(context, "ContextMenu_EnhancedIrrigation_PlumbInlet", function(option)
                return option.name == label
            end)
        end, false)
        T.read(self, "jobs.perform", T.at(self.unit, { feature = "link", job = LinkJobs.PLUMB_INLET,
            with = Links.encode(T.at(self.tank), "iron") }), "forced")
    end,
    validate = function(self)
        T.expectOptionRefused(self, "lower tank", "Tooltip_EnhancedIrrigation_InletTankTooLow")
        local forced = self.reads.forced
        expect(forced.done == false and forced.links == 0, "the server plumbed an inlet from a lower tank")
    end,
})

-- Plumb Outlet to a clean tank on the filter's level lays the pipe, and an hour on the filter
-- empties the basin into it; a raised barrel, a level up, is greyed out saying so. Catches an outlet
-- that leaves the basin full, or one that runs uphill.
T.test("irrigation_treatment_filter_outlet_fills_a_tank_no_higher", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 }, { 0, 2 } }, { bare = true })
        if not spots then return end
        self.litres = 30
        self.unit = placeUnit(self, spots[1], BARREL_FILTER)
        fillBasin(self, self.unit, self.litres)
        self.tank = T.placeTank(self, spots[2], "lidded")
        self.high = T.placeTank(self, spots[3], "raised")
        T.givePlumbing(self, 1)
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
        T.expectOptionRefused(self, "higher tank", "Tooltip_EnhancedIrrigation_OutletTankTooHigh")
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
T.test("irrigation_treatment_filter_inlet_keeps_the_film_through_an_absence", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 }, { 0, 3 } }, { bare = true })
        if not spots then return end
        local spec = Treatment.ENTITIES[BARREL_FILTER]
        self.unit = placeUnit(self, spots[1], BARREL_FILTER, { fields = { head = spec.head, headTainted = true,
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
        T.readMenu(self, function() return T.copyOf(self.unit) end, "back")
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
T.test("irrigation_treatment_filter_outlet_drains_through_an_absence", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 }, { 0, 3 } }, { bare = true })
        if not spots then return end
        local spec = Treatment.ENTITIES[BARREL_FILTER]
        self.unit = placeUnit(self, spots[1], BARREL_FILTER, { fields = { head = spec.head, ripeHours = Treatment.RIPE_HOURS } })
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
    T.test("irrigation_treatment_filter_waits_for_an_unloaded_" .. role .. "_tank", {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.gap, self.head = 5, 40
            self.unit = placeUnit(self, spots[1], BARREL_FILTER, { fields = { head = self.head, ripeHours = Treatment.RIPE_HOURS } })
            local far = { x = self.unit.x + 3000, y = self.unit.y, z = self.unit.z }
            T.server(self, "links.make", T.at(self.unit, { to = far, kind = "iron", lengths = 1, role = role }))
            T.read(self, "treatment.update", T.at(self.unit, { hoursAgo = self.gap, tank = far }), "waiting")
            T.server(self, "links.unlink", far)
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

-- Unloaded -------------------------------------------------------------------------------------------------

-- A filter's record waits while its chunk is away: the ten-minute pass leaves its head as it was,
-- however long ago it last ran. Loaded again, one pass treats the whole gap at its rate. Catches a
-- record that treats into a basin it can't reach, or forgets the time it was away.
T.test("irrigation_treatment_filter_record_catches_up_after_its_chunk_reloads", {
    spOnly = T.CHUNK_RELOAD_SP_ONLY,
    instant = true,
    timeoutSeconds = T.CHUNK_RELOAD_SECONDS,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.gap = 5
        self.unit = placeUnit(self, spots[1], BARREL_FILTER, { fields = { head = 40, ripeHours = Treatment.RIPE_HOURS } })
        T.reloadChunk(self, T.at(self.unit), function()
            T.read(self, "treatment.update", T.at(self.unit, { hoursAgo = self.gap }), "away")
        end)
        T.read(self, "treatment.update", T.at(self.unit), "back")
    end,
    validate = function(self)
        local away, back = self.reads.away, self.reads.back
        expect(not away.after.loaded, "the filter's chunk stayed loaded on the server")
        expectNear("the head while away", away.after.record.head, 40, T.LITRES)
        -- From the clock wound back while away to the pass after the reload, whichever pass ran it.
        local litres = self.unit.spec.rate * (back.now - (away.now - self.gap))
        expectBasin("the server, back", back.after, litres, false)
        expectNear("the head, back", back.after.record.head, 40 - litres, T.LITRES)
    end,
})

T.vanillaBasinTest({ name = "irrigation_treatment_filter_vanilla_menu_drinks_fills_and_empties_the_basin",
    entity = BARREL_FILTER, litres = 20, tainted = true, inBucket = 0 })
