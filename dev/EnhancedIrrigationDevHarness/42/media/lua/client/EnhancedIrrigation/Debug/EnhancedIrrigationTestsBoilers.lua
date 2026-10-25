require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibTreatment"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/UI/TreatmentMenu"
require "ISUI/ISBBQMenu"
require "Camping/ISCampingMenu"

-- Time runs on the server through the record's own advance for set hours, so the clock doesn't
-- decide what a test sees.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Links, LinkJobs, Treatment = EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Treatment
local TreatmentJobs = EnhancedIrrigation.TreatmentJobs
local placeUnit, readUntil, run, waitForServer = T.placeUnit, T.readUnitUntil, T.runUnit, T.waitForUnitServer
local setFire, FUEL, expectLine, expectBasin = T.setFire, T.FUEL, T.expectLine, T.expectBasin
local SPRITES = T.TREATMENT_SPRITES

local STONE, WELDED = "EnhancedIrrigation_BoilerStone", "EnhancedIrrigation_BoilerWelded"

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
            self.unit.spec = Treatment.ENTITIES[entity]
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
        -- Enough of the boiler's water that the head lasts the test, in the drum before
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

T.vanillaBasinTest({ name = "irrigation_treatment_boiler_vanilla_menu_drinks_fills_and_empties_the_basin",
    entity = STONE, litres = 20, tainted = false, inBucket = 0 })
