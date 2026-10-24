require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsFixtures.lua:
-- fixtures placed, read, plumbed and run on the authority. Only registers handlers, so a --stay
-- rerun loads it again.
--
-- What these place is removed by its square when the test ends, not by the object: a test that
-- unloads and reloads the square leaves the first object behind as a stale copy.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

local function fixtureAt(args)
    return mod().Fixtures.fixtureAt(args.x, args.y, args.z)
end

--- The fixture as plain values: what vanilla's menus and actions read off it, its buffer and what
--- that holds, and whether it is plumbed, the mod's way or vanilla's.
local function describe(fixture)
    local fluid = fixture:getFluidContainer()
    return {
        found = true,
        buffer = fluid ~= nil,
        inBuffer = fluid and fluid:getAmount() or 0,
        amount = fixture:getFluidAmount(),
        tainted = fixture:isTaintedWater(),
        hasWater = fixture:hasWater(),
        external = fixture:getUsesExternalWaterSource(),
        linked = mod().Links.roleAt({ x = fixture:getX(), y = fixture:getY(), z = fixture:getZ() }, "fixture") ~= nil,
    }
end

--- The fixture at args' x, y, z (describe), and the tank at `args.tank` ({ x, y, z }) if given,
--- as Server.stateAt sees it.
local function stateAt(args)
    local square = Server.squareAt(args)
    local fixture = square and fixtureAt(args)
    local state = fixture and describe(fixture) or { found = false }
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    return state
end

local function removeFixtureAt(x, y, z)
    local fixture = mod().Fixtures.fixtureAt(x, y, z)
    if fixture then
        fixture:getSquare():transmitRemoveItemFromSquare(fixture)
    end
end

-- Places the fixture tile `args.sprite` at x, y, z: a washer as the game makes one
-- (IsoClothingWasher), with `args.combo` a washer-dryer (IsoCombinationWasherDryer), anything else
-- a plain object. With `args.plumbed`, plumbed the vanilla way (ISPlumbItem:complete), as a save
-- from before the mod holds it; with `args.buffer` = { litres, tainted }, given a buffer holding
-- that much. Answers its state. Removed, with its links, when the test ends.
handler("fixtures.place", function(_, args, defer)
    local square = Server.squareAt(args)
    if not square then
        return nil, "a loaded square for " .. tostring(args.sprite)
    end
    local fixture
    if args.washer or args.combo then
        local Kind = args.combo and IsoCombinationWasherDryer or IsoClothingWasher
        fixture = Kind.new(getCell(), square, getSprite(args.sprite))
        fixture:createContainersFromSpriteProperties()
        square:AddTileObject(fixture)
        if isServer() then
            fixture:transmitCompleteItemToClients()
        end
    else
        fixture = PZHarness.Fixtures.newTile(square, args.sprite)
    end
    defer(function()
        Server.unlinkAt(args.x, args.y, args.z)
        removeFixtureAt(args.x, args.y, args.z)
    end)
    if args.plumbed then
        fixture:getModData().canBeWaterPiped = false
        fixture:setUsesExternalWaterSource(true)
        fixture:transmitModData()
        fixture:sendObjectChange(IsoObjectChange.USES_EXTERNAL_WATER_SOURCE, { value = true })
    end
    if args.buffer then
        local buffer = mod().FixtureSystem.ensureBuffer(fixture)
        if buffer:getAmount() > 0 then
            buffer:removeFluid(buffer:getAmount(), false)
        end
        if args.buffer.litres > 0 then
            buffer:addFluid(args.buffer.tainted and FluidType.TaintedWater or FluidType.Water, args.buffer.litres)
        end
        fixture:sync()
    end
    return stateAt(args)
end)

handler("fixtures.state", function(_, args)
    return stateAt(args)
end)

-- Plumbs the fixture at x, y, z to the tank at `args.tank` as the jobs leave it, with `args.lengths`
-- lengths of `args.kind` pipe, or none as vanilla's Plumb does, without the job.
handler("fixtures.plumb", function(_, args)
    local fixture = fixtureAt(args)
    local tank = mod().Tanks.tankAt(args.tank.x, args.tank.y, args.tank.z)
    if not (fixture and tank) then
        return nil, "the fixture and its tank on the server"
    end
    mod().FixtureSystem.plumb(fixture, tank, args.kind, args.lengths or 0, nil)
    return stateAt(args)
end)

-- Runs the plumbing job `args.job` with `args.with` at the fixture at x, y, z through the
-- authority's own perform (what the action's complete() calls). Answers whether it was done and
-- the fixture's state after, so a test sees the server refuse what its menu would have greyed out.
handler("fixtures.perform", function(player, args)
    local fixture = fixtureAt(args)
    if not fixture then
        return nil, "the server's fixture at " .. tostring(args.x) .. "," .. tostring(args.y)
    end
    local done = mod().LinkSystem.perform(player, args.job, fixture, args.with)
    local state = stateAt(args)
    state.done = done == true
    return state
end)

-- Takes `args.litres` out of the fixture's buffer at x, y, z, as a drink or a wash does, then runs a
-- link pass (LinkSystem:pass) of each of `args.passes` hours, which refills every plumbed fixture's
-- buffer from its tank. Answers the state after the draw and after each pass, with the tank's. All
-- in one call, so the ten-minute event can't run a pass of its own in between.
handler("fixtures.refill", function(_, args)
    local fixture = fixtureAt(args)
    if not (fixture and fixture:getFluidContainer()) then
        return nil, "a fixture with a buffer on the server"
    end
    fixture:getFluidContainer():removeFluid(args.litres, false)
    fixture:sync()
    local reply = { drawn = stateAt(args), passes = {} }
    for _, hours in ipairs(args.passes) do
        mod().LinkSystem.instance:pass(hours)
        table.insert(reply.passes, stateAt(args))
    end
    return reply
end)

-- What the load hook does to a fixture vanilla plumbed (FixtureSystem.convert), at once. Answers
-- whether there was nothing more to do.
handler("fixtures.convert", function(_, args)
    local fixture = fixtureAt(args)
    if not fixture then
        return nil, "the fixture on the server"
    end
    return { finished = mod().FixtureSystem.convert(fixture) }
end)
