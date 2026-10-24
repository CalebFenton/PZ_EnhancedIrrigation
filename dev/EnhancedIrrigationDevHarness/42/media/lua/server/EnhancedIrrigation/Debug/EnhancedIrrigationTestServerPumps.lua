require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsPumps.lua: pumps
-- placed as the build menu leaves them, read, worked for set hours and plumbed on the authority,
-- a square of river water laid by one, the character's endurance set, and the multiplayer Pump
-- action's run interval shortened. Pumping for set hours runs the authority's own sum
-- (PumpSystem.pump) in one call, so the clock doesn't decide it. Only registers handlers, so a
-- --stay rerun loads it again.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

local function pumpAt(args)
    return mod().Pumps.pumpAt(args.x, args.y, args.z)
end

local function recordAt(args)
    return mod().Pumps.recordAt(args.x, args.y, args.z)
end

-- The record's saved fields, as plain values.
local function recordState(record)
    local state = {}
    for _, key in ipairs(mod().PumpObject.SAVED_FIELDS) do
        state[key] = record[key]
    end
    return state
end

--- The pump at args' x, y, z as plain values: whether it stands there (`found`), its `entity`,
--- its record's fields and summary (nil without one), whether it has an `outlet`, the `source` it
--- draws from now ({ kind, litres, dry }), the tank at `args.tank` as Server.stateAt sees it, the
--- litres in the own container of the well at `args.well`, and `player`'s `endurance`.
local function stateAt(player, args)
    local pump = Server.squareAt(args) and pumpAt(args)
    local record = recordAt(args)
    local state = { found = pump ~= nil, outlet = mod().Pumps.outletOf(args) ~= nil,
        endurance = player:getStats():get(CharacterStat.ENDURANCE) }
    if pump then
        local outlet = mod().Pumps.outletOf(args)
        local source = mod().Pumps.sourceOf(pump, record and record.intake, outlet and outlet.b)
        state.entity = mod().entityName(pump)
        state.source = source and { kind = source.kind, litres = source.litres, dry = source.dry == true } or nil
    end
    if record then
        state.record = recordState(record)
        state.summary = record:buildSummary()
    end
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    local wellSquare = args.well and Server.squareAt(args.well)
    local well = wellSquare and mod().findObjectOn(wellSquare, function(object)
        return mod().entityName(object) == "Well"
    end)
    state.wellLitres = well and well:getFluidContainer() and well:getFluidContainer():getAmount() or nil
    return state
end

-- Sets `fields` (saved fields) on `record`, and its clock to now, so only the hours a handler runs
-- count.
local function setFields(record, fields)
    for key, value in pairs(fields or {}) do
        record[key] = value
    end
    record.lastHour = mod().now()
end

-- Places the pump tile `args.sprite` at x, y, z as the build menu builds it, its record made as its
-- OnCreate makes it, then sends it to the clients, with `args.fields` set on the record. Answers
-- its state. Removed, with its links and record, when the test ends.
handler("pumps.place", function(player, args, defer)
    local square = Server.squareAt(args)
    if not square then
        return nil, "a loaded square for " .. tostring(args.sprite)
    end
    local built, missing = Server.build(square, args.sprite, nil, nil, true)
    if not built then
        return nil, missing
    end
    Server.removeWhenDone(args, defer)
    defer(function()
        local record = recordAt(args)
        if record then
            mod().PumpSystem.System.instance:removeLuaObject(record)
        end
    end)
    mod().PumpSystem.onCreate({ thumpable = built })
    built:transmitCompleteItemToClients()
    local record = recordAt(args)
    if not record then
        return nil, "the pump's record after its OnCreate"
    end
    setFields(record, args.fields)
    record:sendSummary()
    return stateAt(player, args)
end)

handler("pumps.state", function(player, args)
    return stateAt(player, args)
end)

-- Sets `args.fields` on the pump's record and plumbs its outlet to the tank at `args.tank` with a
-- length of iron pipe, as Plumb Outlet does once its job is done. Answers the state.
handler("pumps.link", function(player, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the pump at " .. args.x .. "," .. args.y
    end
    setFields(record, args.fields)
    mod().LinkSystem.instance:addLink(args, args.tank, "iron", 1, { 100 }, "pump")
    record:sendSummary()
    return stateAt(player, args)
end)

-- Sets `args.fields` on the pump's record, then has the character work it for each of `args.hours`
-- in turn, as the Pump action's runs do (PumpSystem.pump). Answers the state once the fields are
-- set, `before`, and after each run, in `steps`, each with the run's `stopped` key, if any.
handler("pumps.run", function(player, args)
    local pump, record = pumpAt(args), recordAt(args)
    if not (pump and record) then
        return nil, "the pump at " .. args.x .. "," .. args.y
    end
    setFields(record, args.fields)
    local reply = { before = stateAt(player, args), steps = {} }
    for _, hours in ipairs(args.hours or {}) do
        local stopped = mod().PumpSystem.pump(player, pump, hours)
        local state = stateAt(player, args)
        state.stopped = stopped
        table.insert(reply.steps, state)
    end
    return reply
end)

-- Lays a square of river water (blends_natural_02_0, the game's own water floor) as an object on
-- x, y, z, which marks the square water at once, sent to the clients; taken away when the test
-- ends. No river is near the test world's spawn.
handler("pumps.water", function(_, args, defer)
    local square = Server.squareAt(args)
    if not square then
        return nil, "a loaded square at " .. args.x .. "," .. args.y
    end
    local water = PZHarness.Fixtures.newTile(square, "blends_natural_02_0")
    defer(function()
        if water:getObjectIndex() ~= -1 then
            square:transmitRemoveItemFromSquare(water)
        end
    end)
    return { water = square:getProperties():has(IsoFlagType.water) }
end)

-- Sets the character's endurance to `args.value` and fatigue to `args.fatigue`, and tells its
-- client, until the test ends.
handler("pumps.endurance", function(player, args, defer)
    local stats = player:getStats()
    local before = { endurance = stats:get(CharacterStat.ENDURANCE), fatigue = stats:get(CharacterStat.FATIGUE) }
    local function set(values)
        stats:set(CharacterStat.ENDURANCE, values.endurance)
        stats:set(CharacterStat.FATIGUE, values.fatigue)
        if isServer() then
            syncPlayerStats(player, SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.ENDURANCE)
                + SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.FATIGUE))
        end
    end
    set({ endurance = args.value, fatigue = args.fatigue })
    defer(function() set(before) end)
    return { endurance = stats:get(CharacterStat.ENDURANCE) }
end)

-- Makes a Pump action the multiplayer server starts from now run the pump every `args.ms` real
-- milliseconds until the test ends, so a test sees a full tank in a frame or two rather than a
-- second. The pump counts world time since its last run, so the water lifted doesn't depend on it.
handler("pumps.runEvery", function(_, args, defer)
    local Action = EnhancedIrrigationPumpAction
    local before = Action.RUN_MS
    Action.RUN_MS = args.ms
    defer(function() Action.RUN_MS = before end)
    return {}
end)

-- Holds the pump at x, y, z for a stand-in for another player named `args.as`, as their Pump holds
-- it once the work starts, and leaves it silent from then on, as a client's action goes that
-- disconnects mid-run: it never runs the pump again nor lets go. Let go when the test ends.
-- Answers whether it held the pump.
handler("pumps.hold", function(_, args, defer)
    local pump = pumpAt(args)
    if not pump then
        return nil, "the pump at " .. args.x .. "," .. args.y
    end
    local standIn = { character = { getUsername = function() return args.as end } }
    defer(function() mod().PumpSystem.release(standIn) end)
    return { held = mod().PumpSystem.hold(pump, standIn) }
end)

-- Dates the hold on the pump at x, y, z back past PumpSystem.HOLD_LAPSE_MS, as if its action had
-- been silent that long, so the test doesn't wait it out in real time.
handler("pumps.lapseHold", function(_, args)
    local record = recordAt(args)
    if not (record and record.heldMs) then
        return nil, "a held pump at " .. args.x .. "," .. args.y
    end
    record.heldMs = getTimestampMs() - mod().PumpSystem.HOLD_LAPSE_MS - 1
    return {}
end)
