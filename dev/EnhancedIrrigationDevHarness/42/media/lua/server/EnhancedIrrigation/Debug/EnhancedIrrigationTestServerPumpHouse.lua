require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

local recordAt = Server.pumpHouseRecordAt

-- The generator on the square at `at`, or nil.
local function generatorAt(at)
    local square = at and Server.squareAt(at)
    return square and square:getGenerator() or nil
end

-- The Pump House at args' x, y, z as plain values: the clock's time, `now`, its record's saved
-- fields and summary (nil without one), the fuel an hour it tells a Renewable Energy bank it draws
-- (`bankFuel`, nil for none), the tank at `args.tank` as Server.stateAt sees it, the generator at
-- `args.generator`'s fuel and whether it runs, and `args.squares` as Server.readSquares reads them.
local function stateAt(args)
    local record = recordAt(args)
    local state = { now = mod().now() }
    if record then
        state.record = Server.fieldsOf(record, mod().PumpObject.SAVED_FIELDS)
        state.summary = record:buildSummary()
        local house = record:getIsoObject()
        state.bankFuel = house and select(2, mod().PumpHouse.bankDraw(house)) or nil
    end
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    local generator = generatorAt(args.generator)
    if generator then
        state.generator = { fuel = generator:getFuel(), running = generator:isActivated() }
    end
    state.squares = Server.readSquares(args.squares)
    return state
end

handler("pumpHouse.state", function(_, args)
    return stateAt(args)
end)

-- Sets `args.fields` on the Pump House's record, winds its clock back `args.hoursAgo` hours, if
-- given, sets the crops of `args.squares` to `args.water` (Server.setWater), and runs its
-- ten-minute pass (PumpObject.update). Answers the clock's time, `now`, and the state before and
-- after, all in one call, so no ten-minute event runs in between.
handler("pumpHouse.update", function(_, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the Pump House at " .. args.x .. "," .. args.y
    end
    Server.setFields(record, args.fields, args.hoursAgo)
    Server.setWater(args.squares, args.water)
    local reply = { now = mod().now(), before = stateAt(args) }
    record:update()
    reply.after = stateAt(args)
    return reply
end)
