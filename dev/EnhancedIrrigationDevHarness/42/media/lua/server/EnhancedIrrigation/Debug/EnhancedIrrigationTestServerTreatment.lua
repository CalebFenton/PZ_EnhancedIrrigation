require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsTreatment.lua. Time
-- runs here through the record's own advance, or its update after a set gap, all in one call, so
-- the clock and the ten-minute event don't decide what a test sees. Only registers handlers, so a
-- --stay rerun loads it again.

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
--- whether it has an `inlet` and an `outlet`, whether it is a vanilla `fireplace` and its fire
--- (`lit`, `fuel` in minutes), and the tanks at `args.tank` and `args.into` ({ x, y, z }) if given,
--- as Server.stateAt sees them.
local function stateAt(args)
    local square = Server.squareAt(args)
    local unit = square and unitAt(args)
    local record = recordAt(args)
    local here = { x = args.x, y = args.y, z = args.z }
    local state = {
        loaded = square ~= nil, found = unit ~= nil,
        inlet = mod().Links.roleAt(here, "inlet") ~= nil, outlet = mod().Links.roleAt(here, "outlet") ~= nil,
    }
    if record then
        state.record = recordState(record)
        state.summary = record:buildSummary()
    end
    if unit then
        local basin = unit:getFluidContainer()
        state.entity = mod().entityName(unit)
        state.fireplace = instanceof(unit, "IsoFireplace")
        if state.fireplace then
            state.lit, state.fuel = unit:isLit(), unit:getFuelAmount()
        end
        state.basin = {
            litres = basin:getAmount(), capacity = basin:getCapacity(), tainted = basin:isTainted(),
            locked = basin:isInputLocked(),
        }
    end
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    state.into = args.into and Server.stateAt(args.into) or nil
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
-- OnCreate makes it (a boiler's fireplace too), then sends what stands there to the clients, on a
-- floor laid for it if the square has none (a unit on the storey above), with `args.fields` set on
-- the record. Answers its state. Removed, with its links, record and floor, when the test ends.
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
    local built, missing = Server.build(square, args.sprite, nil, nil, true)
    if not built then
        return nil, missing
    end
    Server.removeWhenDone(args, defer)
    defer(function()
        local record = recordAt(args)
        if record then
            mod().TreatmentSystem.System.instance:removeLuaObject(record)
        end
    end)
    local created = mod().TreatmentSystem.onCreate({ thumpable = built })
    local unit = created and created.object or built
    unit:transmitCompleteItemToClients()
    local record = recordAt(args)
    if not record then
        return nil, "the unit's record after its OnCreate"
    end
    setFields(record, args.fields)
    record:sendSummary()
    return stateAt(args)
end)

handler("treatment.state", function(_, args)
    return stateAt(args)
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

-- Advances the unit's record by each of `args.hours` as time passing does, after setting
-- `args.fields`, telling the clients each change. Answers the state before (`before`) and after
-- each hour (`steps`).
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

-- Runs the ten-minute pass on the unit's record, loaded or not, its clock first wound back
-- `args.hoursAgo` hours if given. Answers `now` and the states before and after in one call, so no
-- ten-minute event runs in between.
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

-- Drops every link with an end on x, y, z without giving its pipe back: for an end that can't be
-- reached to unplumb, such as one on a square no chunk has loaded.
handler("treatment.unlink", function(_, args)
    Server.unlinkAt(args.x, args.y, args.z)
    return {}
end)

-- Fills the first carried item of `args.type`, emptied first, with `args.litres` of `args.fluid` (a
-- FluidType name), and sends it to the client.
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
