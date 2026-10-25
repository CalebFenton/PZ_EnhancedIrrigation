require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Fixtures/Fixtures"
require "EnhancedIrrigation/UI/LinkMenu"
require "EnhancedIrrigation/UI/FixtureMenu"

-- Plumbed fixtures: plumbing a sink to a tank from its menu and through vanilla's own Plumb, the
-- buffer that tank refills and the engine serves vanilla's drink, fill and wash from, taint and all,
-- the town's water winning while it runs, converting a fixture vanilla plumbed, and the washer's
-- switch. Refills run on the server in one call, so the clock doesn't decide them. In a room the
-- town's water wins until the shutoff, so tests of a buffer's own water there set the shutoff to
-- day 0.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Links, LinkJobs, Fixtures = EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Fixtures
local LinkMenu = EnhancedIrrigation.LinkMenu

-- A white bathroom sink and a washing machine: vanilla flags both waterPiped.
local SINK = "fixtures_sinks_01_0"
local WASHER = "appliances_laundry_01_0"
local TANK_LITRES = 50
-- A bath facing east, its two tiles west to east (their SpriteGridPos 0,0 and 1,0).
local BATH = { "fixtures_bathroom_01_26", "fixtures_bathroom_01_27" }

-- Vanilla's reserve for a fixture's tile, which its buffer holds: the tile's waterMaxAmount, else its
-- waterAmount (IsoObject.getReserveWaterMax).
local function tileReserve(sprite)
    local props = getSprite(sprite):getProperties()
    return tonumber(props:get("waterMaxAmount") or props:get("waterAmount"))
end

-- A sink's buffer. Vanilla's sink holds what Fixtures falls back to for a tile without a reserve, so
-- only the bath, which holds more, shows the tile's reserve read.
local function sinkLitres()
    return tileReserve(SINK)
end

local function bathLitres()
    return tileReserve(BATH[1])
end

-- Fixtures ------------------------------------------------------------------------------------------

-- What vanilla's menus and actions read off this client's copy of the fixture, or nil without one.
local function clientState(handle)
    local fixture = T.copyOf(handle)
    if not fixture then
        return nil
    end
    local fluid = fixture:getFluidContainer()
    return {
        buffer = fluid ~= nil,
        inBuffer = fluid and fluid:getAmount() or 0,
        amount = fixture:getFluidAmount(),
        tainted = fixture:isTaintedWater(),
        hasWater = fixture:hasWater(),
        external = fixture:getUsesExternalWaterSource(),
    }
end

-- Queues a wait until this client's copy of the fixture satisfies `holds(state)`.
local function waitForCopy(self, handle, holds, what)
    T.waitFor(self, function()
        local state = clientState(handle)
        return state ~= nil and holds(state)
    end, what)
end

-- Queues the server's view of the fixture, with the tank's, into self.reads[label] once
-- `done(state)` holds.
local function readUntil(self, fixture, tank, label, done)
    T.readUntil(self, "fixtures.state", T.at(fixture, { tank = tank and T.at(tank) }), label, done)
end

local function expectFixture(who, state, want)
    if not expect(state ~= nil and state.found ~= false, who .. " has no fixture") then
        return
    end
    expect(state.buffer, who .. ": the fixture has no buffer")
    expectNear(who .. ": the fixture's water", state.amount, want.litres, T.LITRES)
    expect(state.tainted == want.tainted, who .. ": the fixture's water is " .. (state.tainted and "tainted" or "clean"))
    expectNear(who .. ": the fixture's buffer", state.inBuffer, want.litres, T.LITRES)
    expect(not state.external, who .. ": the fixture still draws on vanilla's rooftop plumbing")
end

local function expectTankLitres(who, state, litres)
    if expect(state and state.found, who .. ": no tank") then
        expectNear(who .. ": the tank's water", state.litres, litres, T.LITRES)
    end
end

-- Plumb to Tank -------------------------------------------------------------------------------------

-- Plumb to Tank from a sink's menu lays the pipe chosen to a raised barrel, and the
-- sink fills at once from it with the barrel's tainted water, which this client's copy serves as
-- tainted. The sink stands in no room: the mod's plumbing doesn't need one, as vanilla's does.
-- Catches a fixture plumbed without its pipe, a buffer that cleans the water, or plumbing that
-- needs a room.
T.test("irrigation_fixtures_plumb_to_tank_fills_and_keeps_taint", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.sink = T.placeFixture(self, spots[1], SINK)
        self.tank = T.placeTank(self, spots[2], "raised", TANK_LITRES, true)
        T.givePlumbing(self, 1)
        local with = Links.encode(T.at(self.tank), "iron")
        T.useMenu(self, self.sink, "plumb", T.job("link", LinkJobs.PLUMB_FIXTURE, with), true)
        readUntil(self, self.sink, self.tank, "plumbed", function(state) return state.linked end)
        waitForCopy(self, self.sink, function(state) return state.buffer and state.amount > sinkLitres() - T.LITRES end,
            "this client's copy of the filled sink")
        T.count(self, "left", { "Base.MetalPipe", "Base.PipeWrench" })
    end,
    validate = function(self)
        T.expectOffered(self, "plumb")
        local plumbed = self.reads.plumbed
        expect(plumbed.linked, "the server didn't plumb the sink")
        expectFixture("the server", plumbed, { litres = sinkLitres(), tainted = true })
        expectFixture("this client", clientState(self.sink), { litres = sinkLitres(), tainted = true })
        expectTankLitres("the server", plumbed.tank, TANK_LITRES - sinkLitres())
        expect(T.counted(self, "Base.MetalPipe") == 0, "plumbing left the iron pipe")
        expect(T.counted(self, "Base.PipeWrench") == 1, "plumbing used up the pipe wrench")
    end,
})

-- A tank on the sink's own level can't push water out of it: the menu greys it out saying so, and
-- the server refuses on its own. Catches a fixture plumbed to a tank with no head.
T.test("irrigation_fixtures_need_a_tank_a_storey_up", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.sink = T.placeFixture(self, spots[1], SINK)
        self.tank = T.placeTank(self, spots[2], "ground", TANK_LITRES)
        T.givePlumbing(self, 1)
        T.useMenu(self, self.sink, "ground barrel", function(context)
            return T.findNamed(context, LinkMenu.tankLabel(T.at(self.sink), T.at(self.tank)))
        end, false)
        T.read(self, "fixtures.perform", T.at(self.sink, { job = LinkJobs.PLUMB_FIXTURE,
            with = Links.encode(T.at(self.tank), "iron") }), "forced")
    end,
    validate = function(self)
        T.expectOptionRefused(self, "ground barrel", "Tooltip_EnhancedIrrigation_FixtureNoPressure")
        local forced = self.reads.forced
        expect(forced.done == false and not forced.linked, "the server plumbed a sink to a tank on its level")
    end,
})

-- Every ten minutes the tank refills the buffer at Fixtures.REFILL_RATE, to its capacity and no
-- further; drawn dry, the sink gives nothing, its vanilla reserve held back. Catches a refill all at
-- once, one that overfills, none, or the reserve served clean between refills.
T.test("irrigation_fixtures_refill_from_the_tank", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.sink = T.placeFixture(self, spots[1], SINK)
        self.tank = T.placeTank(self, spots[2], "raised", 4 * TANK_LITRES)
        T.server(self, "fixtures.plumb", T.at(self.sink, { tank = T.at(self.tank) }))
        -- Emptied, then a pass that refills half the sink, then one long enough for more than the rest.
        self.firstHours = sinkLitres() / 2 / Fixtures.REFILL_RATE
        T.read(self, "fixtures.refill", T.at(self.sink, { tank = T.at(self.tank), litres = sinkLitres(),
            passes = { self.firstHours, 1 } }), "refill")
    end,
    validate = function(self)
        local refill = self.reads.refill
        expectNear("the drawn sink's water", refill.drawn.amount, 0, T.LITRES)
        local half, full = refill.passes[1], refill.passes[2]
        expectNear("the sink's water after a short pass", half.amount, sinkLitres() / 2, T.LITRES)
        expectTankLitres("after a short pass", half.tank, 4 * TANK_LITRES - sinkLitres() - sinkLitres() / 2)
        expectNear("the sink's water after a long pass", full.amount, sinkLitres(), T.LITRES)
        expectTankLitres("after a long pass", full.tank, 4 * TANK_LITRES - 2 * sinkLitres())
    end,
})

-- Unplumb from the sink gives back the pipe, and the tank refills it no more; the sink
-- keeps its buffer, and gets back the vanilla reserve plumbing held back, clean. Catches pipe lost to
-- Unplumb, a refill through a link that's gone, or the reserve lost.
T.test("irrigation_fixtures_unplumb_gives_back_the_pipe", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.sink = T.placeFixture(self, spots[1], SINK)
        self.tank = T.placeTank(self, spots[2], "raised", TANK_LITRES)
        T.server(self, "fixtures.plumb", T.at(self.sink, { tank = T.at(self.tank), kind = "iron", lengths = 1 }))
        T.waitFor(self, function() return #T.clientLinks(self.sink, "fixture") > 0 end, "this client's copy of the link")
        T.step(function() self.viewed = #T.clientLinks(self.sink, "fixture") > 0 end)
        T.give(self, "tools", { { type = "Base.PipeWrench" } })
        T.useMenu(self, self.sink, "unplumb", T.job("link", LinkJobs.UNPLUMB, Links.encode(T.at(self.tank))), true)
        readUntil(self, self.sink, nil, "unplumbed", function(state) return not state.linked end)
        T.count(self, "left", { "Base.MetalPipe" })
        T.read(self, "fixtures.refill", T.at(self.sink, { litres = sinkLitres(), passes = { 1 } }), "refill")
        waitForCopy(self, self.sink, function(state)
            return state.inBuffer < T.LITRES and math.abs(state.amount - sinkLitres()) < T.LITRES
        end, "this client's copy of the drawn sink, its reserve back")
    end,
    validate = function(self)
        T.expectOffered(self, "unplumb")
        expect(self.viewed, "this client's own copy of the list never had the sink's link")
        expect(not self.reads.unplumbed.linked, "the server kept the link")
        expect(T.counted(self, "Base.MetalPipe") == 1, "Unplumb gave back " .. T.counted(self, "Base.MetalPipe")
            .. " iron pipe, not 1")
        local after = self.reads.refill.passes[1]
        expect(after.buffer, "the unplumbed sink lost its buffer")
        expectNear("the unplumbed sink's buffer after a pass", after.inBuffer, 0, T.LITRES)
        for who, state in pairs({ ["the server"] = after, ["this client"] = clientState(self.sink) }) do
            if expect(state ~= nil, who .. " has no sink") then
                expectNear(who .. ": the unplumbed sink's reserve", state.amount, sinkLitres(), T.LITRES)
                expect(not state.tainted, who .. ": the unplumbed sink's reserve is tainted")
            end
        end
    end,
})

-- Vanilla's Plumb ----------------------------------------------------------------------------------

-- Queues a sink in a room under a barrel of tainted water one storey up, and vanilla's Plumb chosen
-- from its menu by a character with a pipe wrench and no pipe. Sets self.sink, self.tank and
-- self.menu.plumb.
local function plumbUnderTank(self)
    local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
    if not spots then return false end
    self.sink = T.placeFixture(self, spots[1], SINK)
    self.tank = T.placeTank(self, spots[1], "above", TANK_LITRES, true)
    T.give(self, "tools", { { type = "Base.PipeWrench" } })
    T.useMenu(self, self.sink, "plumb", T.running(ISWorldObjectContextMenu.onPlumbItem), true)
    return true
end

-- With PlumbingKeepsTaint on (the default), vanilla's Plumb makes the mod's link to the barrel above
-- with no pipe: the sink serves the barrel's water tainted, its menu drops vanilla's Plumb and
-- offers Unplumb. Catches a rooftop barrel still purifying, or a plumbed sink offered Plumb again.
T.test("irrigation_fixtures_vanilla_plumb_keeps_taint", {
    instant = true,
    sandbox = { WaterShutModifier = 0 },
    run = function(self)
        if not plumbUnderTank(self) then return end
        readUntil(self, self.sink, self.tank, "plumbed", function(state) return state.linked end)
        waitForCopy(self, self.sink, function(state) return state.buffer and state.tainted end,
            "this client's copy of the plumbed sink")
        T.useOption(self, function() return T.copyOf(self.sink) end, "plumb again", T.running(ISWorldObjectContextMenu.onPlumbItem), false)
        T.useOption(self, function() return T.copyOf(self.sink) end, "unplumb",
            T.job("link", LinkJobs.UNPLUMB, Links.encode(T.at(self.tank))), false)
        T.count(self, "left", { "Base.PipeWrench" })
    end,
    validate = function(self)
        T.expectOffered(self, "plumb")
        local plumbed = self.reads.plumbed
        expectFixture("the server", plumbed, { litres = sinkLitres(), tainted = true })
        expectFixture("this client", clientState(self.sink), { litres = sinkLitres(), tainted = true })
        expectTankLitres("the server", plumbed.tank, TANK_LITRES - sinkLitres())
        expect(not self.menu["plumb again"].found, "the plumbed sink's menu still offers vanilla's Plumb")
        T.expectOffered(self, "unplumb")
        expect(T.counted(self, "Base.PipeWrench") == 1, "vanilla's Plumb used up the pipe wrench")
    end,
})

-- With PlumbingKeepsTaint off, vanilla's Plumb is vanilla's: the sink draws on the barrel above,
-- served clean, with no link and no buffer. Catches the option ignored.
T.test("irrigation_fixtures_vanilla_plumb_untouched_when_option_off", {
    instant = true,
    sandbox = { PlumbingKeepsTaint = false },
    run = function(self)
        if not plumbUnderTank(self) then return end
        readUntil(self, self.sink, nil, "plumbed", function(state) return state.external end)
        waitForCopy(self, self.sink, function(state) return state.external end, "this client's copy of the plumbed sink")
    end,
    validate = function(self)
        T.expectOffered(self, "plumb")
        local plumbed = self.reads.plumbed
        expect(plumbed.external and not plumbed.linked and not plumbed.buffer,
            "the sink isn't plumbed the vanilla way: external " .. tostring(plumbed.external) .. ", linked "
            .. tostring(plumbed.linked) .. ", buffer " .. tostring(plumbed.buffer))
        local client = clientState(self.sink)
        expect(client and client.external and not client.tainted, "this client's sink doesn't serve the barrel clean")
    end,
})

-- Vanilla's Plumb on a bath reaches a barrel one storey up over either of its tiles, as vanilla's
-- plumbing searches around every tile of a fixture's sprite grid: plumbed from the tile two squares
-- from the barrel, the bath fills from it, tainted. Catches a reach measured from the clicked tile
-- alone, which refuses the job vanilla's menu offered.
T.test("irrigation_fixtures_vanilla_plumb_reaches_over_a_whole_bath", {
    instant = true,
    sandbox = { WaterShutModifier = 0 },
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 2, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.bath = T.placeFixture(self, spots[1], BATH[1])
        T.placeFixture(self, spots[2], BATH[2])
        self.tank = T.placeTank(self, spots[3], "above", 2 * bathLitres(), true)
        T.give(self, "tools", { { type = "Base.PipeWrench" } })
        T.useMenu(self, self.bath, "plumb", T.running(ISWorldObjectContextMenu.onPlumbItem), true)
        readUntil(self, self.bath, self.tank, "plumbed", function(state) return state.linked end)
    end,
    validate = function(self)
        T.expectOffered(self, "plumb")
        local plumbed = self.reads.plumbed
        expectFixture("the server", plumbed, { litres = bathLitres(), tainted = true })
        expectTankLitres("the server", plumbed.tank, bathLitres())
    end,
})

-- Vanilla's Plumb takes any barrel on the floor above within a tile of the sink, not only the one
-- vanilla's plumbing prefers now. That one shifts as the barrels fill and drain while the job runs.
-- With an empty barrel over the sink and one holding water beside it, which vanilla prefers, the job
-- toward the empty barrel is neither greyed out nor refused, and plumbs the sink to it. A barrel two
-- tiles off is out of reach. Catches the job refused unless it names vanilla's preferred barrel.
T.test("irrigation_fixtures_vanilla_plumb_takes_any_barrel_within_reach", {
    instant = true,
    sandbox = { PlumbingKeepsTaint = true },
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 }, { 2, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.sink = T.placeFixture(self, spots[1], SINK)
        self.empty = T.placeTank(self, spots[1], "above")
        self.full = T.placeTank(self, spots[2], "above", TANK_LITRES)
        self.far = T.placeTank(self, spots[3], "above", TANK_LITRES)
        T.give(self, "tools", { { type = "Base.PipeWrench" } })
        self.toEmpty, self.toFar = Links.encode(T.at(self.empty)), Links.encode(T.at(self.far))
        T.step(function()
            local sink = T.copyOf(self.sink)
            local source = sink:FindExternalWaterSource()
            self.preferred = source and EnhancedIrrigation.squareOf(source)
            self.emptyRefusal = LinkJobs.refusal(T.player(), LinkJobs.PLUMB_ABOVE, sink, self.toEmpty)
            self.farRefusal = LinkJobs.refusal(T.player(), LinkJobs.PLUMB_ABOVE, sink, self.toFar)
        end)
        T.batch(function()
            T.read(self, "fixtures.perform", T.at(self.sink, { job = LinkJobs.PLUMB_ABOVE, with = self.toFar }), "far")
            T.read(self, "fixtures.perform", T.at(self.sink, { job = LinkJobs.PLUMB_ABOVE, with = self.toEmpty,
                tank = T.at(self.empty) }), "plumbed")
            T.read(self, "tanks.read", T.at(self.full), "full")
        end)
    end,
    validate = function(self)
        -- Unless vanilla prefers the full barrel, plumbing to the empty one can't show the job
        -- accepts a barrel other than vanilla's choice.
        expect(self.preferred and EnhancedIrrigation.sameSquare(self.preferred, T.at(self.full)),
            "vanilla's plumbing doesn't prefer the barrel holding water")
        expect(self.emptyRefusal == nil, "Plumb Above toward the empty barrel is refused: " .. tostring(self.emptyRefusal))
        expect(self.farRefusal == "Tooltip_EnhancedIrrigation_OutOfReach",
            "Plumb Above toward a barrel two tiles off is refused with " .. tostring(self.farRefusal))
        local far = self.reads.far
        expect(far.done == false and not far.linked, "the server plumbed the sink to a barrel two tiles off")
        local plumbed = self.reads.plumbed
        expect(plumbed.done and plumbed.linked, "the server refused to plumb the sink to the empty barrel")
        expect(plumbed.tank and plumbed.tank.links == 1, "the empty barrel has "
            .. tostring(plumbed.tank and plumbed.tank.links) .. " links, not the sink's")
        expect(self.reads.full.links == 0, "the sink was plumbed to the barrel vanilla prefers, not the one chosen")
    end,
})

-- Converting what vanilla plumbed ------------------------------------------------------------------

-- Queues a sink in a room plumbed the vanilla way, as a save from before the mod holds it, under a
-- barrel of tainted water one storey up. Sets self.sink and self.tank.
local function placePlumbed(self)
    local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
    if not spots then return false end
    self.tank = T.placeTank(self, spots[1], "above", TANK_LITRES, true)
    self.sink = T.placeFixture(self, spots[1], SINK, { plumbed = true })
    waitForCopy(self, self.sink, function(state) return state.external end, "this client's copy of the plumbed sink")
    return true
end

local function readConverted(self)
    readUntil(self, self.sink, self.tank, "converted", function(state) return state.linked and state.buffer end)
    waitForCopy(self, self.sink, function(state) return state.buffer and not state.external end,
        "this client's copy of the converted sink")
end

local function expectConverted(self)
    local converted = self.reads.converted
    expect(converted.linked, "the converted sink isn't plumbed to its barrel")
    expectFixture("the server", converted, { litres = sinkLitres(), tainted = true })
    expectFixture("this client", clientState(self.sink), { litres = sinkLitres(), tainted = true })
    expectTankLitres("the server", converted.tank, TANK_LITRES - sinkLitres())
end

-- A save from before the mod: the load hook finds the vanilla-plumbed sink as its chunk loads and
-- puts it on a link to its barrel. Catches old saves' rooftop barrels still purifying.
T.test("irrigation_fixtures_plumbed_sink_converts_on_load", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves, so its load hook never runs",
    instant = true,
    sandbox = { WaterShutModifier = 0 },
    timeoutSeconds = T.CHUNK_RELOAD_SECONDS,
    run = function(self)
        if not placePlumbed(self) then return end
        T.reloadChunk(self, T.at(self.sink))
        readConverted(self)
    end,
    validate = function(self)
        expectConverted(self)
    end,
})

-- What the load hook does on a multiplayer server reaches the clients that already hold the sink:
-- the plumbing flag, canBeWaterPiped and the new buffer. Catches a conversion only the server sees.
T.test("irrigation_fixtures_converted_sink_reaches_clients", {
    mpOnly = "single player has one copy of the sink, which irrigation_fixtures_plumbed_sink_converts_on_load covers",
    instant = true,
    sandbox = { WaterShutModifier = 0 },
    run = function(self)
        if not placePlumbed(self) then return end
        T.read(self, "fixtures.convert", T.at(self.sink), "convert")
        readConverted(self)
    end,
    validate = function(self)
        expect(self.reads.convert.finished, "the server found no barrel to convert the sink from")
        expectConverted(self)
    end,
})

-- What a buffer does in vanilla's menus ------------------------------------------------------------

-- A sink with a buffer of tainted water offers vanilla's Drink, warning of the taint, Fill and Wash;
-- a bucket filled from it is tainted and the sink goes down by what it took. Catches the engine
-- cleaning a buffer's water on its way out.
T.test("irrigation_fixtures_vanilla_menus_keep_taint", {
    instant = true,
    sandbox = { WaterShutModifier = 0 },
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        -- A dirty rag puts Wash in the menu (ISWorldObjectContextMenuLogic.doWashClothingMenu).
        T.give(self, "items", { { type = "Base.Bucket" }, { type = "Base.RippedSheetsDirty" } })
        self.sink = T.placeFixture(self, spots[1], SINK, { buffer = { litres = sinkLitres(), tainted = true } })
        T.goNextTo(self, spots[1].square)
        T.step(function()
            local sink = T.copyOf(self.sink)
            local context = T.need(self, sink and T.worldMenu(sink), "a world menu for the sink")
            if not context then return end
            local drink = T.optionRunning(context, ISWorldObjectContextMenu.onDrink)
            local fill = T.optionRunning(context, ISWorldObjectContextMenu.onTakeWater)
            self.drink, self.drinkTooltip = T.offered(drink), T.tooltipOf(drink)
            self.fill = T.offered(fill)
            self.wash = T.offered(T.findNamed(context, getText("ContextMenu_Wash")))
            if fill then
                T.choose(fill)
            end
            context:hideAndChildren()
        end)
        local left = sinkLitres() - 10
        readUntil(self, self.sink, nil, "drawn", function(state) return state.amount < left + T.LITRES end)
        T.waitFor(self, function()
            local bucket = self.items.items and self.items.items[1]
            return bucket ~= nil and bucket:getFluidContainer():getAmount() > 10 - T.LITRES
        end, "this client's copy of the filled bucket")
    end,
    validate = function(self)
        expect(self.drink, "the sink's menu offers no Drink")
        expect(self.drinkTooltip:find(getText("Tooltip_item_TaintedWater"), 1, true) ~= nil,
            "Drink's tooltip doesn't warn of tainted water: " .. self.drinkTooltip)
        expect(self.fill, "the sink's menu offers no Fill for the bucket")
        expect(self.wash, "the sink's menu offers no Wash for the dirty rag")
        expectFixture("the server, drawn", self.reads.drawn, { litres = sinkLitres() - 10, tainted = true })
        local water = self.items.items[1]:getFluidContainer()
        expectNear("the bucket's water", water:getAmount(), 10, T.LITRES)
        expect(water:isTainted(), "the bucket filled from a tainted sink holds clean water")
    end,
})

-- Before the water shutoff the town's water wins at a plumbed sink in a room: it runs clean and
-- endless from a tank of tainted water, which it doesn't draw, and a pass empties what was poured
-- into its buffer, whose taint the engine reads first. Catches plumbing that cuts a house off the
-- town's water before the shutoff, or a town tap reading tainted.
T.test("irrigation_fixtures_town_water_wins_while_it_runs", {
    instant = true,
    sandbox = { WaterShutModifier = 30 },
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.sink = T.placeFixture(self, spots[1], SINK, { buffer = { litres = 5, tainted = true } })
        self.tank = T.placeTank(self, spots[1], "above", TANK_LITRES, true)
        T.server(self, "fixtures.plumb", T.at(self.sink, { tank = T.at(self.tank) }))
        T.read(self, "fixtures.refill", T.at(self.sink, { tank = T.at(self.tank), litres = 0, passes = { 1 } }), "refill")
        waitForCopy(self, self.sink, function(state) return state.inBuffer < T.LITRES end,
            "this client's copy of the emptied buffer")
        T.goNextTo(self, spots[1].square)
        T.step(function()
            self.client = clientState(self.sink)
            local context = T.need(self, T.copyOf(self.sink) and T.worldMenu(T.copyOf(self.sink)), "a world menu for the sink")
            if not context then return end
            local drink = T.optionRunning(context, ISWorldObjectContextMenu.onDrink)
            self.drink, self.drinkTooltip = T.offered(drink), T.tooltipOf(drink)
            context:hideAndChildren()
        end)
    end,
    validate = function(self)
        local after = self.reads.refill.passes[1]
        for who, state in pairs({ ["the server"] = after, ["this client"] = self.client }) do
            if expect(state ~= nil, who .. " has no sink") then
                expect(state.amount > TANK_LITRES and state.hasWater and not state.tainted,
                    who .. ": the plumbed sink doesn't give the town's clean water (" .. state.amount .. " L"
                    .. (state.tainted and ", tainted)" or ")"))
                expectNear(who .. ": the plumbed sink's buffer", state.inBuffer, 0, T.LITRES)
            end
        end
        expectTankLitres("the server", after.tank, TANK_LITRES)
        expect(self.drink, "the plumbed sink's menu offers no Drink")
        expect(self.drinkTooltip:find(getText("Tooltip_item_TaintedWater"), 1, true) == nil,
            "Drink's tooltip warns of tainted water at a town tap")
    end,
})

-- A buffer comes back with its chunk, water, taint and all. Catches a reload that refills it from
-- the tile's reserve or drops it.
T.test("irrigation_fixtures_buffer_survives_reload", {
    instant = true,
    timeoutSeconds = T.CHUNK_RELOAD_SECONDS,
    sandbox = { WaterShutModifier = 0 },
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        -- Not a sink's full reserve, so a reload that refilled it from the tile would show.
        self.sink = T.placeFixture(self, spots[1], SINK, { buffer = { litres = 12, tainted = true } })
        T.reloadChunk(self, T.at(self.sink))
        readUntil(self, self.sink, nil, "reloaded", function(state) return state.found ~= false end)
        waitForCopy(self, self.sink, function(state) return state.buffer end, "this client's copy of the reloaded sink")
    end,
    validate = function(self)
        expectFixture("the server, reloaded", self.reads.reloaded, { litres = 12, tainted = true })
        expectFixture("this client, reloaded", clientState(self.sink), { litres = 12, tainted = true })
    end,
})

-- The washer's switch ------------------------------------------------------------------------------

-- A washer with a buffer has vanilla's Turn On once in its menu, which vanilla gives only a washer
-- drawing the town's water. Catches the switch lost, or shown twice.
T.test("irrigation_fixtures_washer_keeps_its_switch", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.washer = T.placeFixture(self, spots[1], WASHER, { washer = true, buffer = { litres = sinkLitres() } })
        T.goNextTo(self, spots[1].square)
        T.step(function()
            local washer = T.copyOf(self.washer)
            self.isWasher = washer ~= nil and instanceof(washer, "IsoClothingWasher")
            local context = T.need(self, washer and T.worldMenu(washer), "a world menu for the washer")
            if not context then return end
            self.switches = 0
            T.findOption(context, function(option)
                if option.name == getText("ContextMenu_Turn_On") then
                    self.switches = self.switches + 1
                end
                return false
            end)
            context:hideAndChildren()
        end)
    end,
    validate = function(self)
        expect(self.isWasher, "this client's copy of the washer isn't a washing machine")
        expect(self.switches == 1, "the washer's menu has " .. tostring(self.switches) .. " Turn On options, not 1")
    end,
})
