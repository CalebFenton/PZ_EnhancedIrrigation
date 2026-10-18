require "PZHarness/ServerFixtures"
require "EnhancedIrrigation/Debug/EnhancedIrrigationProbe"

-- Development only, not published. The server's half of EnhancedIrrigationTestsProbe.lua: what
-- only the authority does to fixtures and tanks, called with PZHarness.Test.server. A --stay rerun
-- loads this file again, so it only registers handlers and the load hook.
--
-- What these place is removed by its square and sprite when the test ends, not by the object:
-- a test that unloads and reloads the square leaves the first object behind as a stale copy.

local Probe = EnhancedIrrigationProbe
local handler = PZHarness.serverHandler

local function removeAt(x, y, z, sprite)
    local object = Probe.find(x, y, z, sprite)
    if object then
        object:getSquare():transmitRemoveItemFromSquare(object)
    end
end

-- A sink on the square at x, y, z; with `args.buffer` = { litres, tainted }, a buffer of a sink's
-- reserve holding that much. Answers the sink as Probe.describe sees it. Two names, so a test
-- placing both kinds keeps both answers (T.server files each under its handler's name).
local function placeSink(_, args, defer)
    local square = getSquare(args.x, args.y, args.z)
    if not square then
        return nil, "a loaded square for a sink"
    end
    local sink = PZHarness.Fixtures.newTile(square, Probe.SINK)
    defer(function() removeAt(args.x, args.y, args.z, Probe.SINK) end)
    if args.buffer then
        Probe.addBuffer(sink, Probe.SINK_LITRES, args.buffer.litres, args.buffer.tainted)
    end
    return Probe.describe(sink)
end
handler("probe.sink", placeSink)
handler("probe.plainSink", placeSink)

-- A rain collector one storey above x, y, z holding `args.litres` of tainted water, on a wooden
-- floor if the square above has none, as a player builds one on a roof.
handler("probe.tankAbove", function(_, args, defer)
    local z = args.z + 1
    local above = getCell():createNewGridSquare(args.x, args.y, z, true)
    if not above then
        return nil, "the square above loaded on the server"
    end
    if not above:getFloor() then
        local floor = above:addFloor("carpentry_02_58")
        defer(function()
            if floor:getObjectIndex() ~= -1 then
                above:transmitRemoveItemFromSquare(floor)
            end
            getCell():checkHaveRoof(args.x, args.y)
        end)
    end
    local script = getScriptManager():getGameEntityScript(Probe.TANK_ENTITY)
    if not script then
        return nil, "the entity script " .. Probe.TANK_ENTITY
    end
    local tank = IsoThumpable.new(getCell(), above, Probe.TANK_SPRITE, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(tank, script, true)
    above:AddSpecialObject(tank)
    tank:getFluidContainer():addFluid(FluidType.TaintedWater, args.litres)
    if isServer() then
        tank:transmitCompleteItemToClients()
    end
    defer(function() removeAt(args.x, args.y, z, Probe.TANK_SPRITE) end)
    return Probe.describe(tank)
end)

-- The object drawn as `args.sprite` at x, y, z as Probe.describe sees it: `loaded` says whether
-- the square is, `found` whether the object is on it.
local function stateAt(_, args)
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then
        return { loaded = false }
    end
    local object = PZHarness.Fixtures.objectWithSprite(square, args.sprite)
    return { loaded = true, found = object ~= nil, state = object and Probe.describe(object) or nil }
end
handler("probe.state", stateAt)
handler("probe.tankState", stateAt)

-- What the load hook does to the sink at x, y, z, at once. Answers whether it found the tank.
handler("probe.convert", function(_, args)
    local sink = Probe.find(args.x, args.y, args.z, Probe.SINK)
    if not sink then
        return nil, "the sink on the server"
    end
    return Probe.convert(sink)
end)

-- Converts plumbed probe sinks as their chunk loads, which is when a save from before the mod
-- would first show them. Ticks later, since the storey above, with the tank, may not be in the
-- cell yet while the chunk's squares are still loading (IsoChunk.doLoadGridsquare).
local pending = {}
-- MapObjects keeps one loader per sprite and priority; single player loads the client and server
-- folders into one state.
local LOAD_PRIORITY = 7
-- A sink whose tank is gone stays plumbed the vanilla way rather than being retried forever.
local TRIES = 60

local function queuePlumbed(object)
    if object:getUsesExternalWaterSource() then
        table.insert(pending, { object = object, tries = 0 })
    end
end

local function convertPending()
    if #pending == 0 then
        return
    end
    local waiting = {}
    for _, entry in ipairs(pending) do
        entry.tries = entry.tries + 1
        if entry.object:getObjectIndex() ~= -1 and not Probe.convert(entry.object) and entry.tries < TRIES then
            table.insert(waiting, entry)
        end
    end
    pending = waiting
end

MapObjects.OnLoadWithSprite(Probe.SINK, queuePlumbed, LOAD_PRIORITY)
-- A --stay rerun loads this file again: the earlier copy's tick handler goes.
if Probe.convertPending then
    Events.OnTick.Remove(Probe.convertPending)
end
Probe.convertPending = convertPending
Events.OnTick.Add(convertPending)
