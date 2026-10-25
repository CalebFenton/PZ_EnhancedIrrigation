require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"
local Squares = require "cf_commonlib/Squares"

-- Development only, not published. Pumping for set hours runs the authority's own sums
-- (PumpSystem.run, a Pump House's ten-minute pass) in one call, so the clock doesn't decide them.
-- Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler
local EI = EnhancedIrrigation
local Fixtures = PZHarness.Fixtures

local recordAt = Server.pumpRecordAt

local function pumpAt(args)
    return EI.Pumps.pumpAt(args.x, args.y, args.z)
end

--- The pump, a hand pump or a Pump House, at args' x, y, z as plain values: whether it stands there
--- (`found`), its `entity`, its record's fields and summary (nil without one), whether it has an
--- `outlet`, the `source` it draws from now ({ kind, litres, dry }), the tank at `args.tank` as
--- Server.stateAt sees it, the litres in the own container of the well at `args.well`, the fuel of
--- the generator at `args.generator` and whether it runs, `player`'s `endurance`, and
--- `args.squares` as Server.readSquares reads them.
local function stateAt(player, args)
    local pump = Fixtures.squareAt(args) and pumpAt(args)
    local record = recordAt(args)
    local state = { found = pump ~= nil, outlet = EI.Links.roleAt(args, "pump") ~= nil,
        endurance = player:getStats():get(CharacterStat.ENDURANCE) }
    if pump then
        local source = EI.PumpWater.sourceOf(pump, record and record.intake, EI.Links.farEnd(args, "pump"))
        state.entity = EI.entityName(pump)
        state.source = source and { kind = source.kind, litres = source.litres, dry = source.dry == true } or nil
    end
    if record then
        state.record = Fixtures.fieldsOf(record, EI.PumpObject.SAVED_FIELDS)
        state.summary = record:buildSummary()
    end
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    local wellSquare = args.well and Fixtures.squareAt(args.well)
    local well = wellSquare and Squares.findObjectOn(wellSquare, function(object)
        return EI.entityName(object) == "Well"
    end)
    state.wellLitres = well and well:getFluidContainer() and well:getFluidContainer():getAmount() or nil
    local generatorSquare = args.generator and Fixtures.squareAt(args.generator)
    local generator = generatorSquare and generatorSquare:getGenerator()
    if generator then
        state.generator = { fuel = generator:getFuel(), running = generator:isActivated() }
    end
    state.squares = Server.readSquares(args.squares)
    return state
end

-- Places the pump tile `args.sprite` at x, y, z as Server.placeEntity does, on a new square where
-- there is none. A Pump House is given `args.part` ({ type, condition, ceiling, fraction }, each but
-- the type as a new one's unless given) as Fit Pump fits that item. Answers its state.
handler("pumps.place", function(player, args, defer)
    local square, missing = Server.squareFor(args, defer)
    if not square then
        return nil, missing
    end
    local record
    record, missing = Server.placeEntity(square, args, defer, EI.PumpSystem, recordAt, function(placed)
        if not args.part then return nil end
        local item = instanceItem(args.part.type)
        if not item then
            return "the part " .. tostring(args.part.type)
        end
        if args.part.condition then
            item:setCondition(args.part.condition)
        end
        if args.part.ceiling then
            EI.Parts.setCeiling(item, args.part.ceiling)
        end
        item:getModData()[EI.Pumps.FRACTION_KEY] = args.part.fraction
        placed:fitPart(item)
        return nil
    end)
    if not record then
        return nil, missing
    end
    return stateAt(player, args)
end)

handler("pumps.state", function(player, args)
    return stateAt(player, args)
end)

-- Plumbs the pump's outlet to the tank or line tile at `args.tank` with the new iron pipe Plumb
-- Outlet lays for the run (LinkJobs.pipeFor), as its job does once done. Answers the state.
handler("pumps.link", function(player, args)
    local pump, record = pumpAt(args), recordAt(args)
    if not (pump and record) then
        return nil, "the pump at " .. args.x .. "," .. args.y
    end
    local kind, lengths = EI.LinkJobs.pipeFor(pump, EI.Links.encode(args.tank, "iron"))
    EI.LinkSystem.instance:addLink(EI.squareOf(pump), args.tank, kind, lengths, nil, "pump")
    record:sendSummary()
    return stateAt(player, args)
end)

-- Has the character work the pump for each of `args.hours` in turn, as the Pump action's runs do
-- (PumpSystem.run). Answers the state before, `before`, and after each run, in `steps`, each with
-- the run's `stopped` key, if any.
handler("pumps.run", function(player, args)
    local pump, record = pumpAt(args), recordAt(args)
    if not (pump and record) then
        return nil, "the pump at " .. args.x .. "," .. args.y
    end
    local reply = { before = stateAt(player, args), steps = {} }
    for _, hours in ipairs(args.hours or {}) do
        local stopped = EI.PumpSystem.run(player, pump, hours)
        local state = stateAt(player, args)
        state.stopped = stopped
        table.insert(reply.steps, state)
    end
    return reply
end)

-- Sets `args.fields` on the Pump House's record, winds its clock back `args.hoursAgo` hours, if
-- given, sets the crops of `args.squares` to `args.water` (Server.setWater), and runs its
-- ten-minute pass (PumpObject.update). Answers the clock's time, `now`, and the state before and
-- after, all in one call, so no ten-minute event runs in between.
handler("pumps.update", function(player, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the Pump House at " .. args.x .. "," .. args.y
    end
    Server.setFields(record, args.fields, args.hoursAgo)
    Server.setWater(args.squares, args.water)
    local reply = { now = EI.now(), before = stateAt(player, args) }
    record:update()
    reply.after = stateAt(player, args)
    return reply
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
