require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/Frost"
require "EnhancedIrrigation/UI/TreatmentMenu"

-- The Filter Crock: shaped and fired, set in a bucket and taken down, seeping clean water, clogging
-- and cracking in frost. Time runs on the server through the record's own advance for set hours, so
-- the clock doesn't decide what a test sees.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Treatment, TreatmentJobs = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs
local placeUnit, readUntil, run, waitForCopy = T.placeUnit, T.readUnitUntil, T.runUnit, T.waitForUnitCopy
local waitForServer, fillBasin, expectLine, expectBasin = T.waitForUnitServer, T.fillBasin, T.expectLine, T.expectBasin
local clientBasin, SPRITES = T.clientBasin, T.TREATMENT_SPRITES

local CROCK = "EnhancedIrrigation_FilterCrock"

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

-- The crock's basin through vanilla's menus (T.vanillaBasinTest).
T.vanillaBasinTest({ name = "irrigation_treatment_crock_vanilla_menu_drinks_fills_and_empties_the_basin",
    entity = CROCK, litres = 8, tainted = false, inBucket = 5 })
