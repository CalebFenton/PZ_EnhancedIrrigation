require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsSprinklers.lua and
-- of the pumped-line tests in EnhancedIrrigationTestsPumps.lua and EnhancedIrrigationTestsPumpHouse:
-- a line run for set hours by what runs it on the authority (a hand pump's PumpSystem.pump, a Pump
-- House's own pass, a tap's Flow.run from its tank) or aged by its records' own pass, with the
-- squares a sprinkler waters read before and after in the same call, so no ten-minute pass, rain
-- or vanilla's drying lands between. Pumps, lines, tanks and crops are placed by the other handler
-- files. Only registers handlers, so a --stay rerun loads it again.
--
-- A square is { x, y, z }; `args.squares` lists those to read.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

-- What the square `at` holds: its crop's `water` and `health` (nil without one), whether a line
-- tile lies on it (`line`), and its soil's `soak`: that tile's, or off the line what every line
-- record in a sprinkler's reach keeps of it, added up, so a soak kept twice reads twice. Not
-- Sprinklers.holderOf, which stops at the first holder and so would hide a second.
local function readSquare(at)
    local EI = mod()
    local reply = { x = at.x, y = at.y, z = at.z, soak = 0 }
    local plant = SFarmingSystem.instance:getLuaObjectAt(at.x, at.y, at.z)
    if plant and plant.state ~= "plow" then
        reply.water, reply.health = plant.waterLvl, plant.health
    end
    local line = EI.Lines.recordAt(at.x, at.y, at.z)
    if line then
        reply.line, reply.soak = true, line.soak
        return reply
    end
    local reach = EI.Sprinklers.ALONG
    for dx = -reach, reach do
        for dy = -reach, reach do
            local holder = EI.Lines.recordAt(at.x - dx, at.y - dy, at.z)
            local soak = holder and holder.sprinklerSoak and holder.sprinklerSoak[EI.Sprinklers.offsetKey(dx, dy)]
            reply.soak = reply.soak + (soak or 0)
        end
    end
    return reply
end

local function readSquares(args)
    local squares = {}
    for i, at in ipairs(args.squares or {}) do
        squares[i] = readSquare(at)
    end
    return squares
end

-- Sets the crop on each of `args.squares` to `args.water` water points, when given, so what a pass
-- gives them is measured from room made in the same call, whatever passes ran before it.
local function setWater(args)
    if not args.water then
        return
    end
    for _, at in ipairs(args.squares or {}) do
        local plant = SFarmingSystem.instance:getLuaObjectAt(at.x, at.y, at.z)
        if plant and plant.state ~= "plow" then
            plant.waterLvl = args.water
            plant:saveData()
        end
    end
end

-- The record of the pump at args' x, y, z as plain values, or nil without one.
local function pumpFields(args)
    local record = args.x and mod().Pumps.recordAt(args.x, args.y, args.z)
    if not record then
        return nil
    end
    local fields = {}
    for _, key in ipairs(mod().PumpObject.SAVED_FIELDS) do
        fields[key] = record[key]
    end
    return fields
end

-- What a handler answers of the state before or after: the squares, the pump's record and the
-- tank at `args.tank`.
local function stateOf(args)
    return { squares = readSquares(args), pump = pumpFields(args), tank = args.tank and Server.stateAt(args.tank) or nil }
end

handler("sprinklers.read", function(_, args)
    return stateOf(args)
end)

-- Sets `args.fields` on the hand pump's record, its clock to now, then has the character work it
-- for each of `args.hours` in turn, as the Pump action's runs do (PumpSystem.pump). Answers the
-- state `before` and `after`, and why the last run stopped, `stopped`.
handler("sprinklers.pump", function(player, args)
    local pump = mod().Pumps.pumpAt(args.x, args.y, args.z)
    local record = mod().Pumps.recordAt(args.x, args.y, args.z)
    if not (pump and record) then
        return nil, "the pump at " .. args.x .. "," .. args.y
    end
    for key, value in pairs(args.fields or {}) do
        record[key] = value
    end
    record.lastHour = mod().now()
    local reply = { before = stateOf(args) }
    for _, hours in ipairs(args.hours) do
        reply.stopped = mod().PumpSystem.pump(player, pump, hours)
    end
    reply.after = stateOf(args)
    return reply
end)

-- Sets `args.fields` on the Pump House's record and the crops of `args.squares` to `args.water`
-- (setWater), winds its clock back `args.hoursAgo` hours and runs its ten-minute pass
-- (PumpObject.update). Answers the clock's time, `now`, and the state `before` and `after`.
handler("sprinklers.house", function(_, args)
    local record = mod().Pumps.recordAt(args.x, args.y, args.z)
    if not record then
        return nil, "the record of the Pump House at " .. args.x .. "," .. args.y
    end
    for key, value in pairs(args.fields or {}) do
        record[key] = value
    end
    if args.hoursAgo then
        record.lastHour = mod().now() - args.hoursAgo
    end
    setWater(args)
    local reply = { now = mod().now(), before = stateOf(args) }
    record:update()
    reply.after = stateOf(args)
    return reply
end)

-- Runs the line tapped at `args.tap` for `args.hours` from the tank its tap draws on, as Water from
-- Tank does (TapSystem.run). Answers the state `before` and `after`, and why it `stopped`, if it did.
handler("sprinklers.flow", function(_, args)
    local tap = mod().Lines.lineAt(args.tap.x, args.tap.y, args.tap.z)
    if not tap then
        return nil, "the tap tile at " .. args.tap.x .. "," .. args.tap.y
    end
    local reply = { before = stateOf(args) }
    reply.stopped = mod().TapSystem.run(tap, args.hours)
    reply.after = stateOf(args)
    return reply
end)

-- Runs each line tile of `args.tiles` as though `args.hours` had passed since its last pass, as
-- the ten-minute pass does. Answers the state `before` and `after`.
handler("sprinklers.age", function(_, args)
    local records = {}
    for i, at in ipairs(args.tiles) do
        records[i] = mod().Lines.recordAt(at.x, at.y, at.z)
        if not records[i] then
            return nil, "a line record at " .. at.x .. "," .. at.y
        end
    end
    local reply = { before = stateOf(args) }
    for _, record in ipairs(records) do
        record.lastHour = mod().now() - args.hours
        record:update()
    end
    reply.after = stateOf(args)
    return reply
end)
