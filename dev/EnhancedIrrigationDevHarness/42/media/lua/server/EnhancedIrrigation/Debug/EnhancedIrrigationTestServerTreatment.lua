require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of the treatment unit tests: placing units,
-- reading them and running their records. Time runs here through the record's own advance, or its
-- update after a set gap, all in one call, so the clock and the ten-minute event don't decide what a
-- test sees. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

local recordAt, stateAt = Server.treatmentRecordAt, Server.treatmentStateAt

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
    Server.setFields(record, args.fields, 0)
    record:sendSummary()
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
