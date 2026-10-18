require "PZHarness/TestLib"
require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Debug/EnhancedIrrigationProbe"

-- Phase 1 of docs/design.md, the throwaway proof that a plumbed fixture can carry its tank's water
-- in a FluidContainer of its own (EnhancedIrrigationProbe.lua). Each test places a sink the way
-- the mod would leave one and plays it through vanilla: the right-click menu, filling a bucket,
-- an unload and reload of its chunk, and vanilla's own Plumb on a sink under a rooftop barrel.
-- The real fixture code and its tests replace these once they pass in single player and --mp.

local T = PZHarness.Test
local player, expect, expectNear = T.player, T.expect, T.expectNear
local Probe = EnhancedIrrigationProbe

-- How long this client may take to show what the server changed.
local SYNC_MS = 5000
-- How long a chunk may take to unload behind the character, or load again in front of it.
local LOAD_MS = 60000
-- Tiles the character goes away for a reload, as Renewable Energy's chunk reload tests go: well
-- past this client's chunk map, so it saves the sink's chunk and lets it go.
local AWAY = 600
-- A test with a reload outlasts the runner's 30 s.
local RELOAD_SECONDS = 150
local LITRES = 0.05

-- Queues a wait until `condition()` holds or `ms` pass; validate checks what it waited for.
local function waitFor(condition, ms, what)
    local sinceMs
    T.waitUntil(function()
        sinceMs = sinceMs or getTimestampMs()
        return condition() or getTimestampMs() - sinceMs > ms
    end, math.huge, what)
end

local function sinkArgs(square)
    return { x = square:getX(), y = square:getY(), z = square:getZ(), sprite = Probe.SINK }
end

local function copyOf(args)
    return Probe.find(args.x, args.y, args.z, args.sprite)
end

-- This client's view of the object at `args`, or nil without one.
local function clientState(args)
    local object = copyOf(args)
    return object and Probe.describe(object) or nil
end

-- Queues a wait until this client's copy at `args` satisfies `holds(state)`.
local function waitForCopy(args, holds, what)
    waitFor(function()
        local state = clientState(args)
        return state ~= nil and holds(state)
    end, SYNC_MS, what)
end

-- The option that runs vanilla's `handler`, in `menu` or any submenu under it. A get-up option
-- (ISContextMenu:addGetUpOption) carries the handler as its first parameter.
local function findOption(root, menu, handler)
    for _, option in ipairs(menu.options) do
        if option.onSelect == handler or option.param1 == handler then
            return option
        end
        local sub = option.subOption and root:getSubMenu(option.subOption)
        local found = sub and findOption(root, sub, handler)
        if found then
            return found
        end
    end
    return nil
end

local function findNamed(root, menu, name)
    for _, option in ipairs(menu.options) do
        if option.name == name then
            return option
        end
        local sub = option.subOption and root:getSubMenu(option.subOption)
        local found = sub and findNamed(root, sub, name)
        if found then
            return found
        end
    end
    return nil
end

-- Clicks `option` as ISContextMenu:onMouseUp does. A get-up option's handler would run only when
-- its ISWaitWhileGettingUp completes, outside the test's step, and so queue its actions behind the
-- test's later waits; the character stands, so the handler runs here at once instead.
local function choose(option)
    if option.onSelect == ISContextMenu.onGetUpAndThen then
        option.param1(option.param2, option.param3, option.param4, option.param5, option.param6, option.param7,
            option.param8, option.param9, option.param10)
        return
    end
    option.onSelect(option.target, option.param1, option.param2, option.param3, option.param4, option.param5,
        option.param6, option.param7, option.param8, option.param9, option.param10)
end

local function offered(option)
    return option ~= nil and not option.notAvailable
end

-- Queues a trip `AWAY` tiles east and back, so this client saves the chunk at `args`, lets it go
-- and loads it again. Sets self.clientUnloaded, self.serverUnloaded (in single player the same
-- game; a multiplayer server keeps chunks loaded long after the character leaves, so there the
-- trip reloads only this client's copy, sent again by the server) and self.chunkLoads, the
-- LoadChunk events for the sink's chunk: none would mean it came back from a cache with its state.
local function reload(self, args)
    local p = player()
    -- A teleport from inside a timed action doesn't stick, so OnTick makes it.
    local target, home
    T.onTick(self, function()
        if target then
            p:teleportTo(target[1], target[2], target[3])
            target = nil
        end
    end)
    local loads = 0
    local function onLoadChunk(chunk)
        local origin = chunk:getGridSquare(0, 0, 0)
        local dx, dy = origin and args.x - origin:getX(), origin and args.y - origin:getY()
        if origin and dx >= 0 and dx < 8 and dy >= 0 and dy < 8 then
            loads = loads + 1
        end
    end
    Events.LoadChunk.Add(onLoadChunk)
    T.defer(self, function() Events.LoadChunk.Remove(onLoadChunk) end)
    T.step(function()
        home = { p:getX(), p:getY(), p:getZ() }
        target = { args.x + AWAY + 0.5, args.y + 0.5, 0 }
    end)
    waitFor(function() return getCell():getGridSquare(args.x, args.y, args.z) == nil end, LOAD_MS,
        "this client to unload the sink's square")
    T.server(self, "probe.state", args)
    T.step(function()
        self.clientUnloaded = getCell():getGridSquare(args.x, args.y, args.z) == nil
        self.serverUnloaded = not self.server["probe.state"].loaded
        target = home
    end)
    waitFor(function() return copyOf(args) ~= nil end, LOAD_MS, "this client to load the sink again")
    T.step(function() self.chunkLoads = loads end)
end

local function expectReloaded(self)
    expect(self.clientUnloaded, "the sink's chunk didn't unload on this client")
    expect((self.chunkLoads or 0) > 0, "the sink's chunk came back without LoadChunk, from a cache")
    if not isClient() then
        expect(self.serverUnloaded, "the sink's chunk didn't unload")
    end
end

local function expectState(who, state, want)
    if not expect(state ~= nil, who .. " has no sink") then
        return
    end
    expect(state.buffer, who .. ": the sink has no FluidContainer")
    expectNear(who .. ": the sink's water", state.amount, want.litres, LITRES)
    expectNear(who .. ": the sink's capacity", state.capacity, Probe.SINK_LITRES, LITRES)
    expect(state.tainted == want.tainted, who .. ": the sink's water is " .. (state.tainted and "tainted" or "clean")
        .. " (" .. tostring(state.fluidName) .. ")")
    expect(state.canBeWaterPiped, who .. ": the sink isn't marked canBeWaterPiped")
    expect(not state.external, who .. ": the sink still draws on vanilla's rooftop plumbing")
end

T.test("irrigation_probe_buffer_keeps_taint_through_vanilla_menus", {
    instant = true,
    run = function(self)
        local square = T.need(self, (T.squares(self, 1, { indoors = true }) or {})[1], "a free indoor square for a sink")
        if not square then return end
        self.sink = sinkArgs(square)
        -- A dirty rag puts Wash in the menu (ISWorldObjectContextMenuLogic.doWashClothingMenu).
        T.give(self, "items", { { type = "Base.Bucket" }, { type = "Base.RippedSheetsDirty" } })
        T.server(self, "probe.sink", { x = self.sink.x, y = self.sink.y, z = self.sink.z,
            buffer = { litres = Probe.SINK_LITRES, tainted = true } })
        waitForCopy(self.sink, function(state) return state.buffer and state.amount > Probe.SINK_LITRES - LITRES end,
            "this client's copy of the sink's buffer")
        T.goNextTo(self, square)
        T.step(function()
            local sink = copyOf(self.sink)
            if not T.need(self, sink, "this client's copy of the sink") then return end
            self.before = Probe.describe(sink)
            local context = ISWorldObjectContextMenu.createMenu(0, { sink }, 0, 0)
            if not T.need(self, type(context) == "table", "a world menu for the sink") then return end
            local drink = findOption(context, context, ISWorldObjectContextMenu.onDrink)
            local fill = findOption(context, context, ISWorldObjectContextMenu.onTakeWater)
            self.drink = offered(drink)
            self.drinkTooltip = drink and drink.toolTip and drink.toolTip.description or ""
            self.fill = offered(fill)
            self.wash = offered(findNamed(context, context, getText("ContextMenu_Wash")))
            if fill then
                choose(fill)
            end
            context:hideAndChildren()
        end)
        local left = Probe.SINK_LITRES - 10
        T.serverUntil(self, "probe.state", self.sink, function(reply)
            return reply.found and reply.state.amount < left + LITRES
        end)
        waitForCopy(self.sink, function(state) return state.amount < left + LITRES end, "this client's copy of the drawn sink")
        waitFor(function()
            local bucket = self.items.items and self.items.items[1]
            return bucket ~= nil and bucket:getFluidContainer():getAmount() > 10 - LITRES
        end, SYNC_MS, "this client's copy of the filled bucket")
    end,
    validate = function(self)
        expectState("the server, placed", self.server["probe.sink"], { litres = Probe.SINK_LITRES, tainted = true })
        expectState("this client, placed", self.before, { litres = Probe.SINK_LITRES, tainted = true })
        expect(self.drink, "the sink's menu offers no Drink")
        expect(self.drinkTooltip:find(getText("Tooltip_item_TaintedWater"), 1, true) ~= nil,
            "Drink's tooltip doesn't warn of tainted water: " .. tostring(self.drinkTooltip))
        expect(self.fill, "the sink's menu offers no Fill for the bucket")
        expect(self.wash, "the sink's menu offers no Wash for the dirty rag")
        local reply = self.server["probe.state"]
        expectState("the server, drawn", reply and reply.state, { litres = Probe.SINK_LITRES - 10, tainted = true })
        expectState("this client, drawn", clientState(self.sink), { litres = Probe.SINK_LITRES - 10, tainted = true })
        local bucket = self.items.items and self.items.items[1]
        local water = bucket and bucket:getFluidContainer()
        if expect(water ~= nil, "this client has no bucket") then
            expectNear("the bucket's water", water:getAmount(), 10, LITRES)
            expect(water:isTainted(), "the bucket filled from a tainted sink holds clean water")
        end
    end,
})

T.test("irrigation_probe_empty_buffer_gives_no_town_water", {
    instant = true,
    -- The town's water still runs, so a sink without a buffer would give it.
    sandbox = { WaterShutModifier = 30 },
    run = function(self)
        local squares = T.need(self, T.squares(self, 2, { indoors = true }), "two free indoor squares for sinks")
        if not squares then return end
        self.sink = sinkArgs(squares[1])
        self.plain = sinkArgs(squares[2])
        T.server(self, "probe.sink", { x = self.sink.x, y = self.sink.y, z = self.sink.z, buffer = { litres = 0 } })
        T.server(self, "probe.plainSink", { x = self.plain.x, y = self.plain.y, z = self.plain.z })
        waitForCopy(self.sink, function(state) return state.buffer and state.canBeWaterPiped end,
            "this client's copy of the empty buffer")
        waitForCopy(self.plain, function() return true end, "this client's copy of the plain sink")
        T.goNextTo(self, squares[1])
        T.step(function()
            local sink = copyOf(self.sink)
            if not T.need(self, sink, "this client's copy of the sink") then return end
            self.client = Probe.describe(sink)
            self.plainClient = clientState(self.plain)
            local context = ISWorldObjectContextMenu.createMenu(0, { sink }, 0, 0)
            if not T.need(self, type(context) == "table", "a world menu for the sink") then return end
            self.drink = findOption(context, context, ISWorldObjectContextMenu.onDrink) ~= nil
            context:hideAndChildren()
        end)
    end,
    validate = function(self)
        local plain = self.plainClient
        if expect(plain ~= nil, "this client has no plain sink") then
            expect(plain.amount > Probe.SINK_LITRES and not plain.tainted,
                "the plain sink beside it gives no town water, so this test proves nothing (" .. plain.amount .. " L)")
        end
        for who, state in pairs({ ["the server"] = self.server["probe.sink"], ["this client"] = self.client }) do
            if expect(state ~= nil, who .. " has no sink") then
                expectNear(who .. ": the empty buffer's water", state.amount, 0, LITRES)
                expect(not state.hasWater, who .. ": the empty buffer still has water")
            end
        end
        expect(not self.drink, "the empty buffer's menu offers Drink")
    end,
})

T.test("irrigation_probe_buffer_survives_unload_and_reload", {
    instant = true,
    timeoutSeconds = RELOAD_SECONDS,
    run = function(self)
        local square = T.need(self, (T.squares(self, 1, { indoors = true }) or {})[1], "a free indoor square for a sink")
        if not square then return end
        self.sink = sinkArgs(square)
        -- Not a sink's full reserve, so a reload that refilled it from the sprite would show.
        T.server(self, "probe.sink", { x = self.sink.x, y = self.sink.y, z = self.sink.z,
            buffer = { litres = 12, tainted = true } })
        waitForCopy(self.sink, function(state) return state.buffer and state.amount > 12 - LITRES end,
            "this client's copy of the sink's buffer")
        reload(self, self.sink)
        T.serverUntil(self, "probe.state", self.sink, function(reply) return reply.loaded end, LOAD_MS)
    end,
    validate = function(self)
        expectReloaded(self)
        local reply = self.server["probe.state"]
        expectState("the server, reloaded", reply and reply.state, { litres = 12, tainted = true })
        expectState("this client, reloaded", clientState(self.sink), { litres = 12, tainted = true })
    end,
})

-- Queues a sink under a rain collector of tainted water, plumbed the vanilla way: the character,
-- holding a pipe wrench, picks Plumb from the sink's menu. Sets self.sink, self.tank,
-- self.plumbOffered and self.plumbed, this client's view of the sink once plumbed.
local function plumbUnderTank(self, square)
    self.sink = sinkArgs(square)
    self.tank = { x = self.sink.x, y = self.sink.y, z = self.sink.z + 1, sprite = Probe.TANK_SPRITE }
    T.give(self, "items", { { type = "Base.PipeWrench" } })
    T.server(self, "probe.plainSink", { x = self.sink.x, y = self.sink.y, z = self.sink.z })
    T.server(self, "probe.tankAbove", { x = self.sink.x, y = self.sink.y, z = self.sink.z, litres = 50 })
    waitForCopy(self.tank, function(state) return state.amount > 50 - LITRES end, "this client's copy of the tank")
    waitForCopy(self.sink, function() return true end, "this client's copy of the sink")
    T.goNextTo(self, square)
    T.step(function()
        local sink = copyOf(self.sink)
        if not T.need(self, sink, "this client's copy of the sink") then return end
        local context = ISWorldObjectContextMenu.createMenu(0, { sink }, 0, 0)
        if not T.need(self, type(context) == "table", "a world menu for the sink") then return end
        local plumb = findOption(context, context, ISWorldObjectContextMenu.onPlumbItem)
        self.plumbOffered = offered(plumb)
        if plumb then
            choose(plumb)
        end
        context:hideAndChildren()
    end)
    waitForCopy(self.sink, function(state) return state.external end, "this client's copy of the plumbed sink")
    T.step(function()
        self.plumbed = clientState(self.sink)
    end)
end

local function expectPlumbed(self)
    expect(self.plumbOffered, "vanilla's menu doesn't offer Plumb for a sink under a rain collector")
    local plumbed = self.plumbed
    if expect(plumbed ~= nil and plumbed.external, "vanilla's Plumb didn't plumb the sink") then
        -- The premise of the override: vanilla serves the barrel's tainted water clean.
        expect(not plumbed.tainted, "vanilla's plumbed sink serves the barrel's water tainted")
    end
end

-- Queues the server's view of the sink once converted, and of its tank, and a wait for this
-- client to show the conversion.
local function readConverted(self)
    T.serverUntil(self, "probe.state", self.sink, function(reply)
        return reply.found and reply.state.buffer and not reply.state.external
    end, LOAD_MS)
    T.server(self, "probe.tankState", self.tank)
    waitForCopy(self.sink, function(state) return state.buffer and not state.external end,
        "this client's copy of the converted sink")
end

local function expectConverted(self)
    local reply = self.server["probe.state"]
    expectState("the server, converted", reply and reply.state, { litres = Probe.SINK_LITRES, tainted = true })
    expectState("this client, converted", clientState(self.sink), { litres = Probe.SINK_LITRES, tainted = true })
    local tank = self.server["probe.tankState"]
    if expect(tank and tank.found, "the server has no tank") then
        expectNear("the tank's water after the sink's buffer filled", tank.state.amount, 50 - Probe.SINK_LITRES, LITRES)
    end
end

-- A save from before the mod: the load hook (EnhancedIrrigationTestServerProbe.lua) finds the
-- vanilla-plumbed sink as its chunk loads and converts it.
T.test("irrigation_probe_plumbed_sink_converts_on_load", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves, so its load hook never runs",
    instant = true,
    timeoutSeconds = RELOAD_SECONDS,
    run = function(self)
        local square = T.need(self, (T.squares(self, 1, { indoors = true }) or {})[1], "a free indoor square for a sink")
        if not square then return end
        plumbUnderTank(self, square)
        reload(self, self.sink)
        readConverted(self)
    end,
    validate = function(self)
        expectPlumbed(self)
        expectReloaded(self)
        expectConverted(self)
    end,
})

-- What the load hook does on a multiplayer server reaches the clients that already hold the
-- sink: the plumbing flag, the canBeWaterPiped modData and the new buffer.
T.test("irrigation_probe_converted_sink_reaches_clients", {
    instant = true,
    run = function(self)
        local square = T.need(self, (T.squares(self, 1, { indoors = true }) or {})[1], "a free indoor square for a sink")
        if not square then return end
        plumbUnderTank(self, square)
        T.server(self, "probe.convert", self.sink)
        readConverted(self)
    end,
    validate = function(self)
        expectPlumbed(self)
        expect(self.server["probe.convert"] == true, "the server found no tank to convert the sink from")
        expectConverted(self)
    end,
})
