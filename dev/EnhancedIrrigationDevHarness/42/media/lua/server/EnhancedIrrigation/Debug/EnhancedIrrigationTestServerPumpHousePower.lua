require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local EI = EnhancedIrrigation

local recordAt = Server.pumpRecordAt

-- What the Pump House at x, y, z tells a Renewable Energy bank it draws (PumpHouse.bankDraw), with
-- each of `args.cases`' switch, timer, payer and part's condition (the fitted part's unless given)
-- set on its record in turn, and `running` never set, as a bank that cut its power leaves it:
-- { kind, fuel } for each, kind nil when it reports none. A `timer` with `openNow` opens at the
-- hour now for an hour.
handler("pumpHouse.bankDraw", function(_, args)
    local record = recordAt(args)
    local house = record and record:getIsoObject()
    if not house then
        return nil, "the Pump House at " .. args.x .. "," .. args.y
    end
    local condition = record.partCondition
    local draws = {}
    for i, fields in ipairs(args.cases) do
        local timer = fields.timer
        if timer and timer.openNow then
            timer = { item = timer.item, start = math.floor(getGameTime():getTimeOfDay()), minutes = 60 }
        end
        record.on, record.timer, record.payer, record.running = fields.on, timer, fields.payer, nil
        record.partCondition = fields.partCondition or condition
        local kind, fuel = EI.PumpHouse.bankDraw(house)
        draws[i] = { kind = kind, fuel = fuel }
    end
    return { draws = draws }
end)

-- Sets a vanilla generator down on x, y, z, connected, with `args.fuel` in it, and starts it: on a
-- new square where there is none, as on a floor above open ground, whose square only comes to be
-- with it. Answers its fuel. Switched off and taken away when the test ends.
handler("pumpHouse.generator", function(_, args, defer)
    local square, missing = Server.squareFor(args, defer)
    if not square then
        return nil, missing
    end
    local generator = IsoGenerator.new(instanceItem("Base.Generator"), square:getCell(), square)
    defer(function() PZHarness.Fixtures.removePlaced(generator) end)
    generator:setConnected(true)
    generator:setCondition(100)
    generator:setFuel(args.fuel)
    generator:setActivated(true)
    return { fuel = generator:getFuel(), running = generator:isActivated() }
end)

-- Moves the grid's shutoff to a whole day before the day of the world's age now, so the grid is
-- off now and has been for a day or more, until the test ends. Answers the world hour it went off,
-- `shutoff`, worked out by vanilla's rule (SandboxOptions.doesPowerGridExist: the grid is on while
-- getWorldAgeDaysSinceBegin is at most ElecShutModifier) rather than the mod's, `now`, and whether
-- the grid exists.
handler("pumpHouse.shutoff", function(_, args, defer)
    local option = getSandboxOptions():getOptionByName("ElecShutModifier")
    local saved = option:getValue()
    defer(function() option:setValue(saved) end)
    local days = getGameTime():getWorldAgeDaysSinceBegin()
    local shutDay = math.floor(days) - 1
    option:setValue(shutDay)
    local now = EI.now()
    return { shutoff = now - (days - shutDay) * 24, now = now, grid = getSandboxOptions():doesPowerGridExist() }
end)
