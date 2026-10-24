require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of the boiler tests: their fire and the walls
-- that refuse one. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local unitAt, recordAt, stateAt = Server.treatmentUnitAt, Server.treatmentRecordAt, Server.treatmentStateAt

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

-- Puts a wall tile `args.sprite` on x, y, z, sent to the clients, its edge's flags on the square
-- at once. Taken away when the test ends.
handler("treatment.wall", function(_, args, defer)
    local square = Server.squareAt(args)
    if not square then
        return nil, "a loaded square at " .. args.x .. "," .. args.y
    end
    local wall = PZHarness.Fixtures.newTile(square, args.sprite)
    square:RecalcAllWithNeighbours(true)
    defer(function()
        if wall:getObjectIndex() ~= -1 then
            square:transmitRemoveItemFromSquare(wall)
            square:RecalcAllWithNeighbours(true)
        end
    end)
    return {}
end)
