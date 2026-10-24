require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Links"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/Treatment"
require "EnhancedIrrigation/TreatmentJobs"
require "EnhancedIrrigation/UI/TankMenu"
require "EnhancedIrrigation/UI/TreatmentMenu"

-- The sand filters (Treatment.lua, TreatmentJobs.lua, TreatmentObject.lua, TreatmentSystem.lua,
-- TreatmentMenu.lua, the inlet and outlet jobs of LinkJobs, their entities in Entities.txt):
-- building them from the build menu, Pour In, what passes into the basin ripe and unripe, the film
-- dying dry or frozen, clogging and Clean Filter, the inlet and outlet links and their heights, the
-- basin in vanilla's menus, and the record catching up after its chunk reloads. Units are placed,
-- read and run by EnhancedIrrigationTestServerTreatment.lua; time runs there through the record's
-- own advance for set hours, so the clock doesn't decide it.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Links, LinkJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Treatment, TreatmentJobs, TankMenu = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs,
    EnhancedIrrigation.TankMenu

local LITRES = 0.05
local BARREL, BRICK = "EnhancedIrrigation_BarrelFilter", "EnhancedIrrigation_BrickFilter"
local SPRITES = { [BARREL] = Sprites.BARREL_FILTER, [BRICK] = Sprites.BRICK_FILTER }
-- The empty sack a bag of sand or gravel leaves (its ReplaceOnDeplete).
local SACK = "Base.EmptySandbag"

-- Units -----------------------------------------------------------------------------------------------

local function copyOf(handle)
    return T.objectWithSprite(getSquare(handle.x, handle.y, handle.z), handle.sprite)
end

--- Queues placing the unit `entity` at `handle` (up `opts.up` storeys), with `opts.fields` on its
--- record and `opts.basin` = { litres, tainted } in its basin, and a wait for this client's copy and
--- its summary. Returns its handle, with `spec`.
local function placeUnit(self, handle, entity, opts)
    opts = opts or {}
    local up = opts.up or 0
    local unit = { x = handle.x, y = handle.y, z = handle.z + up, sprite = SPRITES[entity],
        spec = Treatment.UNITS[entity], square = up == 0 and handle.square or nil }
    T.server(self, "treatment.place", T.at(unit, { sprite = unit.sprite, fields = opts.fields, basin = opts.basin }))
    local litres = opts.basin and opts.basin.litres or 0
    T.waitFor(self, function()
        unit.square = getSquare(unit.x, unit.y, unit.z)
        local copy = copyOf(unit)
        return copy ~= nil and Treatment.summaryOf(copy) ~= nil
            and math.abs(copy:getFluidContainer():getAmount() - litres) < LITRES
    end, "this client's copy of the " .. entity)
    return unit
end

-- Queues the server's view of the unit, with the tank's if given, into self.reads[label].
local function read(self, unit, label, tank)
    T.read(self, "treatment.state", T.at(unit, { tank = tank and T.at(tank) }), label)
end

local function readUntil(self, unit, label, done, tank)
    T.readUntil(self, "treatment.state", T.at(unit, { tank = tank and T.at(tank) }), label, done)
end

-- Queues `fields` set on the unit's record and a run of each of `hours`, into self.reads[label]
-- ({ before, steps }).
local function run(self, unit, label, hours, fields)
    T.read(self, "treatment.run", T.at(unit, { hours = hours, fields = fields }), label)
end

-- Queues a wait until this client's copy of the unit holds `litres` in its basin, if given, and its
-- summary satisfies `holds(summary)`, if given.
local function waitForCopy(self, unit, litres, holds, what)
    T.waitFor(self, function()
        local copy = copyOf(unit)
        local summary = copy and Treatment.summaryOf(copy)
        return summary ~= nil and (not litres or math.abs(copy:getFluidContainer():getAmount() - litres) < LITRES)
            and (not holds or holds(summary))
    end, what)
end

local function useMenu(self, unit, label, find, choose)
    T.goNextTo(self, unit.square)
    T.useOption(self, function() return copyOf(unit) end, label, find, choose)
end

local function job(id, with)
    return function(context) return T.jobOption(context, "treatment", id, with) end
end

local function linkJob(id, with)
    return function(context) return T.jobOption(context, "link", id, with) end
end

-- Queues the names of every option in the unit's menu into self.names[label].
local function readMenu(self, unit, label)
    self.names = self.names or {}
    T.step(function()
        local copy = copyOf(unit)
        local context = T.need(self, copy and T.worldMenu(copy), "a world menu for " .. label)
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

-- Expects (`want`, or not) a line of the menu self.names[label] read to contain `text`.
local function expectLine(self, label, text, want)
    local found = false
    for _, name in ipairs(self.names and self.names[label] or {}) do
        found = found or name:find(text, 1, true) ~= nil
    end
    expect(found == (want ~= false), label .. ": the menu " .. (found and "says " or "doesn't say ") .. text)
end

local function expectBasin(who, state, litres, tainted)
    if not expect(state and state.basin, who .. ": no unit") then return end
    expectNear(who .. ": the basin's water", state.basin.litres, litres, LITRES)
    if litres > 0 then
        expect(state.basin.tainted == tainted, who .. ": the basin's water is " .. (state.basin.tainted and "tainted" or "clean"))
    end
end

-- This client's copy's basin as the state expectBasin reads.
local function clientBasin(unit)
    local copy = copyOf(unit)
    local basin = copy and copy:getFluidContainer()
    return basin and { basin = { litres = basin:getAmount(), tainted = basin:isTainted() } } or nil
end

-- The option of the submenu named by `nameKey` in `context` for which `matches(option)` holds, or
-- nil.
local function inSubmenu(context, nameKey, matches)
    local parent = T.findNamed(context, context, getText(nameKey))
    local sub = parent and parent.subOption and context:getSubMenu(parent.subOption)
    return sub and T.findOption(context, sub, matches) or nil
end

-- Building ----------------------------------------------------------------------------------------------

-- The build menu builds each filter from its recipe on a bare square, with its record at once:
-- this client's menu reads its state. The tools stay and every bag of sand or gravel leaves its
-- empty sack. Catches a recipe the build menu can't build, a filter without its record, or the
-- bags used up whole.
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
            T.count(self, "left", { SACK, "Base.Sandbag", "Base.Gravelbag" })
            T.waitFor(self, function() return Treatment.summaryOf(copyOf(self.unit)) ~= nil end,
                "this client's summary of the built filter")
            readMenu(self, self.unit, "built")
        end,
        validate = function(self)
            expect(self.canBuild and self.validSquare, "the build menu can't build the filter from its materials on a bare square")
            local built = self.reads.built
            expect(built.entity == entity, "the build menu built " .. tostring(built.entity))
            expect(built.record and built.record.head == 0, "the built filter has no record, or water in its head")
            expect(built.basin and built.basin.litres == 0 and built.basin.locked, "the built filter's basin isn't empty and locked")
            local bags = 0
            for _, item in ipairs(self.items.materials or {}) do
                local fullType = item:getFullType()
                bags = bags + ((fullType == "Base.Sandbag" or fullType == "Base.Gravelbag") and 1 or 0)
            end
            local left = self.counts.left
            expect(left[SACK] == bags, "building left " .. tostring(left[SACK]) .. " empty sacks of " .. bags .. " bags")
            expect(left["Base.Sandbag"] == 0 and left["Base.Gravelbag"] == 0, "building left full bags")
            expectLine(self, "built", getText("IGUI_EnhancedIrrigation_Ripening", Treatment.RIPE_HOURS))
        end,
    })
end

-- Pour In ------------------------------------------------------------------------------------------------

-- Pour In from a carried bucket of tainted water fills the head as far as it has room, the bucket
-- keeping the rest, and the head is tainted. A can of petrol is greyed out, and so, with the head
-- full, is the bucket. Catches water lost or created, the taint dropped, or anything but water on
-- the sand.
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
            return bucket:getFluidContainer():getAmount() > 10 - LITRES and can:getFluidContainer():getAmount() > 5 - LITRES
        end, "this client's copies of the filled bucket and can")
        T.step(function() self.bucket, self.can = self.items.carried[1], self.items.carried[2] end)
        useMenu(self, self.unit, "petrol", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.can)
        end, false)
        useMenu(self, self.unit, "pour", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.bucket)
        end, true)
        readUntil(self, self.unit, "poured", function(state)
            return state.record and state.record.head + state.basin.litres > head - LITRES
        end)
        T.read(self, "treatment.carried", { type = "Base.Bucket" }, "bucket")
        T.waitFor(self, function()
            local summary = Treatment.summaryOf(copyOf(self.unit))
            return summary ~= nil and summary.head > head - 1
        end, "this client's summary of the full head")
        useMenu(self, self.unit, "full", function(context)
            return T.jobOption(context, "treatment", TreatmentJobs.POUR_IN, self.bucket)
        end, false)
    end,
    validate = function(self)
        local head = Treatment.UNITS[BARREL].head
        T.expectRefused(self, "petrol", "Tooltip_EnhancedIrrigation_OnlyWater")
        T.expectOffered(self, "pour")
        local poured = self.reads.poured
        expectNear("the head and basin after pouring", poured.record.head + poured.basin.litres, head, LITRES)
        expect(poured.record.headTainted, "the head poured from a tainted bucket is clean")
        local bucket = self.reads.bucket
        expectNear("the bucket's water left", bucket.litres, 10 - self.room, LITRES)
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
        expectNear("the head left", after.record.head, 20 - litres, LITRES)
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
        readMenu(self, self.unit, "ripe")
        useMenu(self, self.unit, "clean", job(TreatmentJobs.CLEAN_FILTER), false)
    end,
    validate = function(self)
        local litres = self.unit.spec.rate * self.hours
        local after = self.reads.run.steps[1]
        expectBasin("the server", after, litres, false)
        expectBasin("this client", clientBasin(self.unit), litres, false)
        expectLine(self, "ripe", getText("IGUI_EnhancedIrrigation_Ripe"))
        T.expectRefused(self, "clean", "Tooltip_EnhancedIrrigation_NotClogged")
    end,
})

-- Two days with an empty head kill the film, which ripens from nothing again: an hour short of
-- them it's still ripe; at them it's dead, the menu says it's ripening and how long it's been dry,
-- and a tainted head passes tainted. Catches a film that never dies, or dies early.
T.test("irrigation_treatment_two_dry_days_kill_the_layer", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL)
        run(self, self.unit, "dry", { Treatment.DRY_DEATH_HOURS - 1, 1 }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
        waitForCopy(self, self.unit, 0, function(summary) return summary.ripeHours == 0 end,
            "this client's summary of the dead film")
        readMenu(self, self.unit, "dead")
        run(self, self.unit, "fed", { 1 }, { head = 10, headTainted = true })
    end,
    validate = function(self)
        local steps = self.reads.dry.steps
        expect(steps[1].record.ripeHours == Treatment.RIPE_HOURS, "the film died before two dry days")
        expect(steps[2].record.ripeHours == 0, "the film lived through two dry days")
        expectLine(self, "dead", getText("IGUI_EnhancedIrrigation_Ripening", Treatment.RIPE_HOURS))
        expectLine(self, "dead", getText("IGUI_EnhancedIrrigation_DryFor", Treatment.DRY_DEATH_HOURS))
        expectBasin("the server, fed again", self.reads.fed.steps[1], self.unit.spec.rate, true)
    end,
})

-- A hard freeze with water on the sand kills the film and passes nothing that hour; a filter with
-- an empty head keeps its film. Catches frost ignored, or a dry filter killed by it.
T.test("irrigation_treatment_hard_freeze_kills_the_layer", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.wet = placeUnit(self, spots[1], BARREL)
        self.dry = placeUnit(self, spots[2], BARREL)
        T.server(self, "lines.temperature", { celsius = EnhancedIrrigation.Lines.HARD_FREEZE_CELSIUS - 3 })
        run(self, self.wet, "wet", { 1 }, { head = 20, ripeHours = Treatment.RIPE_HOURS })
        run(self, self.dry, "dry", { 1 }, { head = 0, ripeHours = Treatment.RIPE_HOURS })
    end,
    validate = function(self)
        local wet, dry = self.reads.wet.steps[1], self.reads.dry.steps[1]
        expect(wet.record.ripeHours == 0, "a hard freeze left the wet film alive")
        expectNear("the frozen filter's basin", wet.basin.litres, 0, LITRES)
        expect(dry.record.ripeHours == Treatment.RIPE_HOURS, "a hard freeze killed the film of a filter with an empty head")
    end,
})

-- Clogging and cleaning ----------------------------------------------------------------------------

-- Past its litres a filter trickles, and its menu says it's clogged; Clean Filter, with a shovel,
-- restores the rate, and the film ripens for a day: tainted water passes again. Catches a clog
-- that never comes, a cleaning that leaves it clogged, or one that leaves the film ripe.
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
        readMenu(self, self.unit, "clogged")
        T.give(self, "tools", { { type = "Base.Shovel" } })
        useMenu(self, self.unit, "clean", job(TreatmentJobs.CLEAN_FILTER), true)
        readUntil(self, self.unit, "cleaned", function(state) return state.record.passed == 0 end)
        run(self, self.unit, "after", { 1 }, { head = 20, headTainted = true })
    end,
    validate = function(self)
        local spec = self.unit.spec
        local clogged = self.reads.clogged
        expectNear("a clogged filter's hour", clogged.steps[1].basin.litres - clogged.before.basin.litres,
            spec.rate * Treatment.CLOGGED_FACTOR, LITRES)
        expect(clogged.steps[1].basin.tainted == false, "a ripe clogged filter passed tainted water")
        expectLine(self, "clogged", getText("IGUI_EnhancedIrrigation_Clogged"))
        T.expectOffered(self, "clean")
        local cleaned = self.reads.cleaned
        expect(cleaned.record.passed == 0, "Clean Filter left the filter clogged")
        expectNear("the film's hours after a cleaning", cleaned.record.ripeHours, Treatment.CLEANED_RIPE_HOURS, 0.5)
        local after = self.reads.after
        expectNear("a cleaned filter's hour", after.steps[1].basin.litres - after.before.basin.litres, spec.rate, LITRES)
        expect(after.steps[1].basin.tainted, "a filter ripening after a cleaning passed a tainted head clean")
    end,
})

-- Links -------------------------------------------------------------------------------------------------

-- Plumb Inlet from a filter's menu to a raw tank on its level lays the pipe chosen, and a link pass
-- tops the head up from the tank, taint and all. Catches an inlet that draws nothing, overfills, or
-- cleans on the way in.
T.test("irrigation_treatment_inlet_fills_the_head_from_a_tank", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.unit = placeUnit(self, spots[1], BARREL)
        self.tank = T.placeTank(self, spots[2], "lidded", 100, true)
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe" } })
        useMenu(self, self.unit, "inlet", linkJob(LinkJobs.PLUMB_INLET, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.unit, "plumbed", function(state) return state.inlet end)
        T.read(self, "treatment.pass", T.at(self.unit, { hours = 1, tank = T.at(self.tank) }), "passed")
        T.count(self, "left", { "Base.MetalPipe" })
    end,
    validate = function(self)
        T.expectOffered(self, "inlet")
        expect(self.reads.plumbed.inlet, "the server didn't plumb the inlet")
        expect(self.counts.left["Base.MetalPipe"] == 0, "plumbing the inlet left the iron pipe")
        local passed = self.reads.passed
        expectNear("the head after a pass", passed.record.head, self.unit.spec.head, LITRES)
        expect(passed.record.headTainted, "the head filled from a tainted tank is clean")
        expectNear("the water drawn", passed.tank.litres + passed.record.head + passed.basin.litres, 100, LITRES)
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
        T.useOption(self, function() return copyOf(self.unit) end, "lower tank", function(context)
            local label = TankMenu.tankLabel(T.at(self.unit), T.at(self.tank))
            return inSubmenu(context, "ContextMenu_EnhancedIrrigation_PlumbInlet", function(option)
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

-- Plumb Outlet to a clean tank on the filter's level lays the pipe, and a pass empties the basin
-- into it; a raised barrel, a level up, is greyed out saying so. Catches an outlet that leaves the
-- basin full, or one that runs uphill.
T.test("irrigation_treatment_outlet_fills_a_tank_no_higher", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 }, { 0, 2 } }, { bare = true })
        if not spots then return end
        self.litres = 30
        self.unit = placeUnit(self, spots[1], BARREL, { basin = { litres = self.litres } })
        self.tank = T.placeTank(self, spots[2], "lidded")
        self.high = T.placeTank(self, spots[3], "raised")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe" } })
        useMenu(self, self.unit, "higher tank", function(context)
            local label = TankMenu.tankLabel(T.at(self.unit), T.at(self.high))
            return inSubmenu(context, "ContextMenu_EnhancedIrrigation_PlumbOutlet", function(option)
                return option.name == label
            end)
        end, false)
        T.useOption(self, function() return copyOf(self.unit) end, "outlet",
            linkJob(LinkJobs.PLUMB_OUTLET, Links.encode(T.at(self.tank), "iron")), true)
        readUntil(self, self.unit, "plumbed", function(state) return state.outlet end)
        T.read(self, "treatment.pass", T.at(self.unit, { hours = 1, tank = T.at(self.tank) }), "passed")
    end,
    validate = function(self)
        T.expectRefused(self, "higher tank", "Tooltip_EnhancedIrrigation_OutletTankTooHigh")
        T.expectOffered(self, "outlet")
        local passed = self.reads.passed
        expect(passed.outlet, "the server didn't plumb the outlet")
        expectNear("the basin after a pass", passed.basin.litres, 0, LITRES)
        expectNear("the clean tank after a pass", passed.tank.litres, self.litres, LITRES)
        expect(not passed.tank.tainted, "the clean tank's water is tainted")
    end,
})

-- Vanilla's menus ----------------------------------------------------------------------------------------

-- The option in `context`, in any submenu, that runs vanilla's `handler`. A get-up option carries
-- its handler as its first parameter.
local function optionRunning(context, handler)
    return T.findOption(context, context, function(option)
        return option.onSelect == handler or option.param1 == handler
    end)
end

-- The basin offers vanilla's Drink, warning of taint, Fill and Empty, but no pour into it, though
-- the character carries water; a bucket filled from it holds its tainted water. Catches a basin
-- vanilla can't reach, or one it can pour into past the sand.
T.test("irrigation_treatment_vanilla_menu_drinks_fills_and_empties_the_basin", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.litres = 20
        self.unit = placeUnit(self, spots[1], BARREL, { basin = { litres = self.litres, tainted = true } })
        T.give(self, "items", { { type = "Base.Bucket" }, { type = "Base.WaterBottle" } })
        -- Full, so vanilla's Fill lists only the bucket.
        T.server(self, "treatment.fillCarried", { type = "Base.WaterBottle", fluid = "Water", litres = 10 })
        T.waitFor(self, function() return self.items.items[2]:getFluidContainer():isFull() end,
            "this client's copy of the filled bottle")
        T.goNextTo(self, spots[1].square)
        T.step(function()
            local copy = copyOf(self.unit)
            local context = T.need(self, copy and T.worldMenu(copy), "a world menu for the filter")
            if not context then return end
            local drink = optionRunning(context, ISWorldObjectContextMenu.onDrink)
            local fill = optionRunning(context, ISWorldObjectContextMenu.onTakeWater)
            self.drink, self.drinkTooltip = T.offered(drink), T.tooltipOf(drink)
            self.fill = T.offered(fill)
            self.empty = T.offered(optionRunning(context, ISWorldObjectContextMenu.onFluidEmpty))
            self.pour = T.findNamed(context, context, getText("ContextMenu_AddFluidFromItem")) ~= nil
            if fill then
                T.choose(fill)
            end
            context:hideAndChildren()
        end)
        readUntil(self, self.unit, "drawn", function(state) return state.basin.litres < self.litres - 1 end)
        T.read(self, "treatment.carried", { type = "Base.Bucket" }, "bucket")
    end,
    validate = function(self)
        expect(self.drink, "the filter's menu offers no Drink")
        expect(self.drinkTooltip:find(getText("Tooltip_item_TaintedWater"), 1, true) ~= nil,
            "Drink's tooltip doesn't warn of tainted water: " .. self.drinkTooltip)
        expect(self.fill, "the filter's menu offers no Fill for the bucket")
        expect(self.empty, "the filter's menu offers no Empty")
        expect(not self.pour, "the filter's menu offers vanilla's pour into the basin")
        local bucket = self.reads.bucket
        expectNear("the basin and bucket", self.reads.drawn.basin.litres + bucket.litres, self.litres, LITRES)
        expect(bucket.tainted, "the bucket filled from a tainted basin holds clean water")
    end,
})

-- Unloaded -------------------------------------------------------------------------------------------------

-- A filter's record waits while its chunk is away: the ten-minute pass leaves it as it was, clock
-- and all, however long ago it last ran. Loaded again, one pass treats the whole gap at its rate.
-- Catches a record that treats into a basin it can't reach, or forgets the time it was away.
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
        expect((self.chunkLoads or 0) > 0, "the filter's chunk came back without LoadChunk, from a cache")
        local away, back = self.reads.away, self.reads.back
        expect(not away.after.loaded, "the filter's chunk stayed loaded on the server")
        expectNear("the head while away", away.after.record.head, 40, LITRES)
        expectNear("the clock while away", away.after.record.lastHour, away.now - self.gap, 0.01)
        -- From the clock wound back while away to the pass after the reload, whichever pass ran it.
        local litres = self.unit.spec.rate * (back.now - (away.now - self.gap))
        expectBasin("the server, back", back.after, litres, false)
        expectNear("the head, back", back.after.record.head, 40 - litres, LITRES)
    end,
})
