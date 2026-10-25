require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. Time runs here through the record's own advance, or its update
-- after a set gap, all in one call, so the clock and the ten-minute event don't decide what a test
-- sees. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler
local EI = EnhancedIrrigation

local unitAt, recordAt, stateAt = Server.treatmentUnitAt, Server.treatmentRecordAt, Server.treatmentStateAt

-- Places the unit as Server.placeEntity does (a boiler's OnCreate makes its fireplace), on a floor
-- laid for it if the square has none (a unit on the storey above). Answers its state.
handler("treatment.place", function(_, args, defer)
    local square, missing = Server.squareFor(args, defer, true)
    if not square then
        return nil, missing
    end
    local record
    record, missing = Server.placeEntity(square, args, defer, EI.TreatmentSystem, recordAt)
    if not record then
        return nil, missing
    end
    return stateAt(args)
end)

handler("treatment.state", function(_, args)
    return stateAt(args)
end)

-- Advances the unit's record by each of `args.hours` as time passing does, after setting
-- `args.fields`, telling the clients each change. Answers the state before (`before`) and after
-- each hour (`steps`).
handler("treatment.run", function(_, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the unit at " .. args.x .. "," .. args.y
    end
    Server.setFields(record, args.fields, 0)
    local reply = { before = stateAt(args), steps = {} }
    for _, hours in ipairs(args.hours or {}) do
        record:advance(hours)
        record:afterChange()
        table.insert(reply.steps, stateAt(args))
    end
    return reply
end)

-- Runs the ten-minute pass on the unit's record, loaded or not, its clock first wound back
-- `args.hoursAgo` hours if given. Answers `now` and the states before and after in one call, so no
-- ten-minute event runs in between.
handler("treatment.update", function(_, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the unit at " .. args.x .. "," .. args.y
    end
    Server.setFields(record, nil, args.hoursAgo)
    local reply = { now = EI.now(), before = stateAt(args) }
    record:update()
    reply.after = stateAt(args)
    return reply
end)

-- Sets the fire of the boiler at x, y, z as vanilla's Add Fuel, Light and Put Out leave it:
-- `args.fuel` minutes of fuel if given, then lit or put out as `args.lit` says, told to the
-- clients as vanilla tells them (IsoFireplace's STATE change). Then runs the record's ten-minute
-- pass, which notes the fire, as one does within ten minutes of a player's lighting it. Answers
-- the state.
handler("treatment.fire", function(_, args)
    local unit, record = unitAt(args), recordAt(args)
    if not (unit and record and instanceof(unit, "IsoFireplace")) then
        return nil, "the boiler at " .. args.x .. "," .. args.y
    end
    if args.fuel then
        unit:setFuelAmount(args.fuel)
    end
    if args.lit then
        unit:turnOn()
    else
        unit:extinguish()
    end
    unit:sendObjectChange(IsoObjectChange.STATE)
    record:update()
    return stateAt(args)
end)
