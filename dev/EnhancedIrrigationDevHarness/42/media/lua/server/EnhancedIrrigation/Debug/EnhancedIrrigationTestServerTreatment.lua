require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsTreatment.lua:
-- treatment units placed as the build menu leaves them, read, run for set hours and linked on the
-- authority, and the carried containers filled that Pour In takes from. Time runs here through the
-- record's own advance, or its update after a set gap, all in one call, so the clock and the
-- ten-minute event don't decide what a test sees. Only registers handlers, so a --stay rerun loads
-- it again.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

local function unitAt(args)
    return mod().Treatment.unitAt(args.x, args.y, args.z)
end

local function recordAt(args)
    return mod().Treatment.recordAt(args.x, args.y, args.z)
end

-- The record's saved fields, as plain values.
local function recordState(record)
    local state = {}
    for _, key in ipairs(mod().TreatmentObject.SAVED_FIELDS) do
        state[key] = record[key]
    end
    return state
end

--- The unit at args' x, y, z as plain values: whether its square is `loaded` and it stands there,
--- its record's fields and summary (`record`, `summary`, nil without one), what its basin holds,
--- whether it has an `inlet` and an `outlet`, and the tank at `args.tank` ({ x, y, z }) if given, as
--- Server.stateAt sees it.
local function stateAt(args)
    local square = Server.squareAt(args)
    local unit = square and unitAt(args)
    local record = recordAt(args)
    local here = { x = args.x, y = args.y, z = args.z }
    local state = {
        loaded = square ~= nil, found = unit ~= nil,
        inlet = mod().Treatment.linkOf(here, "inlet") ~= nil, outlet = mod().Treatment.linkOf(here, "outlet") ~= nil,
    }
    if record then
        state.record = recordState(record)
        state.summary = record:buildSummary()
    end
    if unit then
        local basin = unit:getFluidContainer()
        state.entity = mod().entityName(unit)
        state.basin = {
            litres = basin:getAmount(), capacity = basin:getCapacity(), tainted = basin:isTainted(),
            locked = basin:isInputLocked(),
        }
    end
    state.tank = args.tank and Server.stateAt(args.tank) or nil
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

-- Places the unit tile `args.sprite` at x, y, z as the build menu builds it, its record made as its
-- OnCreate makes it, on a floor laid for it if the square has none (a unit on the storey above),
-- with `args.fields` set on the record and `args.basin` = { litres, tainted } in its basin. Answers
-- its state. Removed, with its links, record and floor, when the test ends.
handler("treatment.place", function(_, args, defer)
    local square = Server.squareAt(args) or getCell():createNewGridSquare(args.x, args.y, args.z, true)
    if not square then
        return nil, "a square for " .. tostring(args.sprite)
    end
    if not square:getFloor() then
        local floor = square:addFloor("carpentry_02_58")
        defer(function()
            if floor:getObjectIndex() ~= -1 then
                square:transmitRemoveItemFromSquare(floor)
            end
            getCell():checkHaveRoof(args.x, args.y)
        end)
    end
    local unit, missing = Server.build(square, args.sprite)
    if not unit then
        return nil, missing
    end
    Server.removeWhenDone(args, defer)
    defer(function()
        local record = recordAt(args)
        if record then
            mod().TreatmentSystem.System.instance:removeLuaObject(record)
        end
    end)
    mod().TreatmentSystem.onCreate({ thumpable = unit })
    local record = recordAt(args)
    if not record then
        return nil, "the unit's record after its OnCreate"
    end
    setFields(record, args.fields)
    if args.basin then
        local basin = unit:getFluidContainer()
        basin:setInputLocked(false)
        basin:addFluid(args.basin.tainted and FluidType.TaintedWater or FluidType.Water, args.basin.litres)
        basin:setInputLocked(true)
        unit:sync()
    end
    record:sendSummary()
    return stateAt(args)
end)

handler("treatment.state", function(_, args)
    return stateAt(args)
end)

-- Sets `args.fields` on the unit's record, then advances it by each of `args.hours` in turn, as
-- the time passing does (TreatmentObject.advance), and shows and tells the change. Answers the state
-- once the fields are set, `before`, and after each hour, in `steps`.
handler("treatment.run", function(_, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the unit at " .. args.x .. "," .. args.y
    end
    setFields(record, args.fields)
    local reply = { before = stateAt(args), steps = {} }
    for _, hours in ipairs(args.hours or {}) do
        record:advance(hours)
        record:afterChange()
        table.insert(reply.steps, stateAt(args))
    end
    return reply
end)

-- Winds the unit's record's clock back `args.hoursAgo` hours, if given, and runs the ten-minute
-- pass on it (TreatmentObject.update), loaded or not. Answers the clock's time, `now`, and the state
-- before and after, all in one call, so no ten-minute event runs in between.
handler("treatment.update", function(_, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the unit at " .. args.x .. "," .. args.y
    end
    if args.hoursAgo then
        record.lastHour = mod().now() - args.hoursAgo
    end
    local reply = { now = mod().now(), before = stateAt(args) }
    record:update()
    reply.after = stateAt(args)
    return reply
end)

-- Runs a link pass of `args.hours` (LinkSystem:pass) and answers the unit's state after.
handler("treatment.pass", function(_, args)
    mod().LinkSystem.instance:pass(args.hours)
    return stateAt(args)
end)

-- Fills the first carried item of `args.type` with `args.litres` of `args.fluid` (a FluidType
-- name), emptied first, and sends it to the client.
handler("treatment.fillCarried", function(player, args)
    local item = player:getInventory():getFirstTypeRecurse(args.type)
    local fluid = item and item:getFluidContainer()
    if not fluid then
        return nil, "a carried " .. args.type .. " with a fluid container"
    end
    fluid:Empty()
    fluid:addFluid(FluidType[args.fluid], args.litres)
    item:syncItemFields()
    return { litres = fluid:getAmount(), tainted = fluid:isTainted() }
end)

-- What the first carried item of `args.type` holds.
handler("treatment.carried", function(player, args)
    local item = player:getInventory():getFirstTypeRecurse(args.type)
    local fluid = item and item:getFluidContainer()
    if not fluid then
        return nil, "a carried " .. args.type .. " with a fluid container"
    end
    return { litres = fluid:getAmount(), tainted = fluid:isTainted() }
end)
