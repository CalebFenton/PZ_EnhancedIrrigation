require "PZHarness/ServerHandlers"
require "PZHarness/ServerFixtures"
require "PZHarness/ServerRecords"
require "PZHarness/Fixtures"
require "PZHarness/ServerChecks"
local Build = require "EnhancedIrrigation/Debug/EnhancedIrrigationDebugBuild"
local Squares = require "cf_commonlib/Squares"

-- Development only, not published. The server's half of EnhancedIrrigationTestLib.lua; it returns
-- what the other handler files share. Server Lua loads after shared, so the EnhancedIrrigation
-- table every handler file keeps as EI exists when they load; the mod's server modules on it exist
-- only on the authority, so the handlers look them up (EI.PumpSystem) when they run. Named to sort
-- before the handler files, so that a --stay rerun loads it again (RELOAD_FILES) before the files
-- that require it.
--
-- What these place is removed by its square when the test ends (PZHarness.trackSquare), not by
-- the object: the jobs under test replace a stand's object with a barrel's and back, and the
-- vanilla lid swaps it again. The `remove` test setting unlinks it first.

local handler = PZHarness.serverHandler
local Fixtures = PZHarness.Fixtures
local EI = EnhancedIrrigation

local Server = {}

--- The line record at `at`'s x, y, z; fails the test as missing without one.
function Server.lineRecordAt(at)
    return PZHarness.need(EI.Lines.recordAt(at.x, at.y, at.z), "a line record at " .. at.x .. "," .. at.y .. "," .. at.z)
end

--- The pump record, a hand pump's or a Pump House's, at args' x, y, z, or nil.
function Server.pumpRecordAt(args)
    return EI.Pumps.recordAt(args.x, args.y, args.z)
end

--- Whether `object` is one of the things the tank tests place: a stand, with or without its barrel,
--- a tank, a treatment unit, a pump, or a well, which isn't a tank.
function Server.isPlaced(object)
    return EI.Stands.isStand(object) or EI.Stands.isRaised(object) or EI.Tanks.isTank(object)
        or EI.Treatment.isUnit(object) or EI.Pumps.isPump(object) or EI.entityName(object) == "Well"
end

--- Removes the placed thing (Server.isPlaced) at x, y, z the way the game removes an object.
function Server.removeAt(x, y, z)
    local square = getSquare(x, y, z)
    local object = square and Squares.findObjectOn(square, Server.isPlaced)
    if object then
        square:transmitRemoveItemFromSquare(object)
    end
end

--- Takes every link with an end on x, y, z out of the list without giving its pipe back, so a link
--- a test made doesn't outlive it.
function Server.unlinkAt(x, y, z)
    local system = EI.LinkSystem.instance
    for _, link in ipairs(EI.Links.linksAt({ x = x, y = y, z = z })) do
        system:removeLink(link)
    end
end

--- Builds the tile `args.sprite` on `square` as the build menu builds it (Build.tile), its record
--- made by `system`'s OnCreate, which may replace the object. Removed, with its links and record,
--- when the test ends.
function Server.placeEntity(player, square, args, defer, kind, system, prepare)
    local at = { kind = kind, x = args.x, y = args.y, z = args.z }
    PZHarness.Records.track(defer, player, at)
    local built = PZHarness.need(Build.tile(square, args.sprite))
    local created = system.onCreate({ thumpable = built })
    local object = created and created.object or built
    object:transmitCompleteItemToClients()
    local record = PZHarness.Records.at(at)
    if prepare then
        prepare(record)
    end
    PZHarness.Records.set(record, args.fields, nil, 0)
    record:sendSummary()
end

-- The object as plain values: which of the mod's things it is, its tile and entity, and as a tank
-- its level and water.
local function describe(object)
    local state = {
        found = true,
        sprite = object:getSprite() and object:getSprite():getName() or nil,
        entity = EI.entityName(object),
        isStand = EI.Stands.isStand(object),
        isRaised = EI.Stands.isRaised(object),
        isTank = EI.Tanks.isTank(object),
        health = object:getHealth(),
    }
    if state.isTank then
        local fluid = object:getFluidContainer()
        state.level = EI.Tanks.levelOf(object)
        state.litres = fluid:getAmount()
        state.capacity = fluid:getCapacity()
        state.tainted = fluid:isTainted()
    end
    return state
end

--- What stands at args' x, y, z (describe), whether the square is `loaded`, and how many `links`
--- have an end there.
function Server.stateAt(args)
    local square = Fixtures.squareAt(args)
    if not square then
        return { loaded = false, found = false }
    end
    local object = Squares.findObjectOn(square, Server.isPlaced)
    local state = object and describe(object) or { found = false }
    state.loaded = true
    state.links = #EI.Links.linksAt({ x = args.x, y = args.y, z = args.z })
    return state
end

-- Squares -------------------------------------------------------------------------------------------

-- What the square `at` holds: its crop's `water` and `health` (nil without one), whether a line
-- tile lies on it (`line`), and its soil's `soak`: that tile's, or off the line what every line
-- record in a sprinkler's reach keeps of it, added up, so a soak kept twice reads twice. Not
-- Sprinklers.keeperOf, which stops at the first keeper and so would hide a second.
local function readSquare(at)
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

--- Each of `squares` ({ x, y, z }) as readSquare reads it, or nil without `squares`.
function Server.readSquares(squares)
    if not squares then
        return nil
    end
    local read = {}
    for i, at in ipairs(squares) do
        read[i] = readSquare(at)
    end
    return read
end

--- Sets the crop on each of `squares` to `water` water points, when given, so what a pass gives
--- them is measured from room made in the same call, whatever passes ran before it.
function Server.setWater(squares, water)
    if not water then
        return
    end
    for _, at in ipairs(squares or {}) do
        local plant = SFarmingSystem.instance:getLuaObjectAt(at.x, at.y, at.z)
        if plant and plant.state ~= "plow" then
            plant.waterLvl = water
            plant:saveData()
        end
    end
end

-- Tanks ---------------------------------------------------------------------------------------------

-- Places the tile `args.sprite` (the stand, a raised barrel, a vanilla barrel) at x, y, z as the
-- build menu builds it, without its OnCreate, on a floor laid for it if the square has none (a
-- tank on the storey above), holding `args.litres` of water (tainted when `args.tainted`), and
-- sends it to the clients with its water: a sync sent after can reach a client before the object
-- does, which drops it. Answers its state (Server.stateAt). Removed, its links and the floor laid
-- for it with it, when the test ends.
handler("tanks.place", function(player, args, defer)
    local square = PZHarness.squareFor(args, defer, true)
    PZHarness.trackSquare(defer, player, args)
    local object = PZHarness.need(Build.tile(square, args.sprite, args.litres, args.tainted))
    object:transmitCompleteItemToClients()
    return Server.stateAt(args)
end)

handler("tanks.read", function(_, args)
    return Server.stateAt(args)
end)

handler("tanks.remove", function(_, args)
    Server.removeAt(args.x, args.y, args.z)
    return Server.stateAt(args)
end)

-- Holds ---------------------------------------------------------------------------------------------

-- How each held feature's record is found at args' x, y, z.
local HELD = { line = Server.lineRecordAt, pump = Server.pumpRecordAt }

-- Holds the tap (`args.feature` "line") or pump ("pump") at x, y, z for a stand-in for another
-- player named `args.as`, as their Water from Tank or Pump holds it once the work starts, and
-- leaves it silent from then on, as a client's action goes that disconnects mid-run: it never runs
-- again nor lets go. Let go when the test ends. Answers whether it held.
handler("holds.hold", function(_, args, defer)
    local record = PZHarness.need(HELD[args.feature](args), "the " .. args.feature .. " record at " .. args.x .. "," .. args.y)
    local standIn = { character = { getUsername = function() return args.as end } }
    defer(function() EI.Holds.release(standIn) end)
    return { held = EI.Holds.hold(record, standIn) }
end)

-- Dates the hold on the tap or pump at x, y, z (`args.feature` as holds.hold) back past
-- Holds.LAPSE_MS, as if its action had been silent that long, so the test doesn't wait it out in
-- real time.
handler("holds.lapse", function(_, args)
    local record = HELD[args.feature](args)
    PZHarness.need(record and record.heldMs, "a held " .. args.feature .. " at " .. args.x .. "," .. args.y)
    record.heldMs = getTimestampMs() - EI.Holds.LAPSE_MS - 1
    return {}
end)

-- Makes each held action of the class named `args.action` (EnhancedIrrigationWaterAction,
-- EnhancedIrrigationPumpAction) the multiplayer server starts from now run every `args.ms` real
-- milliseconds until the test ends, so a test sees a walk-off, a dry tank or a full one in a frame
-- or two rather than a second. A run counts world time since the last, so the water doesn't
-- depend on it.
handler("holds.runEvery", function(_, args, defer)
    local Action = _G[args.action]
    -- The action's own setting, nil while it reads its base's.
    local before = rawget(Action, "RUN_MS")
    Action.RUN_MS = args.ms
    defer(function() Action.RUN_MS = before end)
    return {}
end)

-- Treatment units -----------------------------------------------------------------------------------

--- The treatment unit at args' x, y, z, or nil.
function Server.treatmentUnitAt(args)
    return EI.Treatment.unitOn(getCell():getGridSquare(args.x, args.y, args.z))
end

--- The treatment unit record at args' x, y, z, or nil.
function Server.treatmentRecordAt(args)
    return EI.Treatment.recordAt(args.x, args.y, args.z)
end

--- The unit at args' x, y, z as plain values: whether its square is `loaded` and it stands there,
--- its record's fields and summary (`record`, `summary`, nil without one), what its basin holds,
--- whether it has an `inlet` and an `outlet`, whether it is a vanilla `fireplace` and its fire
--- (`lit`, `fuel` in minutes), and the tanks at `args.tank` and `args.into` ({ x, y, z }) if given,
--- as Server.stateAt sees them.
function Server.treatmentStateAt(args)
    local square = Fixtures.squareAt(args)
    local unit = square and Server.treatmentUnitAt(args)
    local record = Server.treatmentRecordAt(args)
    local here = { x = args.x, y = args.y, z = args.z }
    local state = {
        loaded = square ~= nil, found = unit ~= nil,
        inlet = EI.Links.roleAt(here, "inlet") ~= nil, outlet = EI.Links.roleAt(here, "outlet") ~= nil,
    }
    if record then
        state.record = Fixtures.fieldsOf(record, EI.TreatmentObject.SAVED_FIELDS)
        state.summary = record:buildSummary()
    end
    if unit then
        local basin = unit:getFluidContainer()
        state.entity = EI.entityName(unit)
        state.fireplace = instanceof(unit, "IsoFireplace")
        if state.fireplace then
            state.lit, state.fuel = unit:isLit(), unit:getFuelAmount()
        end
        state.basin = { litres = basin:getAmount(), capacity = basin:getCapacity(), tainted = basin:isTainted() }
    end
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    state.into = args.into and Server.stateAt(args.into) or nil
    return state
end

return Server
