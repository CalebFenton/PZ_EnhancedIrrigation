require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsValves.lua: a valve
-- put on a tap as Fit Valve leaves it, and a valve's clock wound back as though the hours had gone
-- by, then run by its own pass (ValveSystem.update), the crops and tank read after in the same call
-- so no vanilla pass lands between. Lines, tanks and crops are placed by the other
-- handler files. Only registers handlers, so a --stay rerun loads it again.
--
-- A tile is { x, y, z }; `args.tiles` lists the crops to read.

local handler = PZHarness.serverHandler

-- The valve on the record's tap as plain values, and whether it runs the line now.
local function valveOf(record)
    local valve = record.valve
    if not valve then
        return { open = record.valveOpen == true }
    end
    return { item = valve.item, start = valve.start, minutes = valve.minutes, untilHour = valve.untilHour,
        open = record.valveOpen == true, now = EnhancedIrrigation.now() }
end

-- The water of the crop on each of `tiles`, nil where there is none, and the litres of the tank on
-- `tank`, if given.
local function readWater(args)
    local reply = { crops = {} }
    for i, at in ipairs(args.tiles or {}) do
        local plant = SFarmingSystem.instance:getLuaObjectAt(at.x, at.y, at.z)
        reply.crops[i] = plant and plant.waterLvl or false
    end
    if args.tank then
        local tank = EnhancedIrrigation.Tanks.tankAt(args.tank.x, args.tank.y, args.tank.z)
        reply.litres = tank and EnhancedIrrigation.Tanks.litres(tank) or nil
    end
    return reply
end

-- Puts the valve `args.item` on the tap at x, y, z as Fit Valve does.
handler("valves.place", function(_, args)
    local record, missing = Server.lineRecordAt(args)
    if not record then return nil, missing end
    EnhancedIrrigation.ValveSystem.fit(record, instanceItem(args.item))
    record:afterChange()
    return valveOf(record)
end)

handler("valves.read", function(_, args)
    local record, missing = Server.lineRecordAt(args)
    if not record then return nil, missing end
    return { valve = valveOf(record) }
end)

-- Winds the clock of the valve on the tap at x, y, z back `args.hours`, a wind-up's end with it, as
-- though they had gone by since it last ran, and runs it. Answers the crops and tank after.
handler("valves.age", function(_, args)
    local record, missing = Server.lineRecordAt(args)
    if not record then return nil, missing end
    local valve = record.valve
    if not valve then
        return nil, "a valve on the tap at " .. args.x .. "," .. args.y
    end
    valve.lastHour = (valve.lastHour or EnhancedIrrigation.now()) - args.hours
    if valve.untilHour then
        valve.untilHour = valve.untilHour - args.hours
    end
    EnhancedIrrigation.ValveSystem.update(record)
    local reply = readWater(args)
    reply.valve = valveOf(record)
    return reply
end)
