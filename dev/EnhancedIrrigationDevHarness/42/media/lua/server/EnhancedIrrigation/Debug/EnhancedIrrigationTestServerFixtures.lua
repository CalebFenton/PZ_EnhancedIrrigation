require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. Test handlers for fixtures placed, read, plumbed and run on the
-- authority. Only registers handlers, so a --stay rerun loads it again.
--
-- What these place is removed by its square when the test ends, not by the object: a test that
-- unloads and reloads the square leaves the first object behind as a stale copy.

local handler = PZHarness.serverHandler

local EI = EnhancedIrrigation

local function fixtureAt(args)
    return EI.Fixtures.fixtureAt(args.x, args.y, args.z)
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
        linked = EI.Links.roleAt({ x = fixture:getX(), y = fixture:getY(), z = fixture:getZ() }, "fixture") ~= nil,
    }
end

--- The fixture at args' x, y, z (describe), and the tank at `args.tank` ({ x, y, z }) if given,
--- as Server.stateAt sees it.
local function stateAt(args)
    local square = PZHarness.Fixtures.squareAt(args)
    local fixture = square and fixtureAt(args)
    local state = fixture and describe(fixture) or { found = false }
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    return state
end

local function removeFixtureAt(x, y, z)
    local fixture = EI.Fixtures.fixtureAt(x, y, z)
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
    local square = PZHarness.need(PZHarness.Fixtures.squareAt(args), "a loaded square for " .. tostring(args.sprite))
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
    if args.buffer then
        local buffer = EI.FixtureSystem.ensureBuffer(fixture)
        if buffer:getAmount() > 0 then
            buffer:removeFluid(buffer:getAmount(), false)
        end
        if args.buffer.litres > 0 then
            buffer:addFluid(args.buffer.tainted and FluidType.TaintedWater or FluidType.Water, args.buffer.litres)
        end
        fixture:sync()
    end
    if args.plumbed then
        fixture:getModData().canBeWaterPiped = false
        fixture:setUsesExternalWaterSource(true)
        fixture:transmitModData()
        fixture:sendObjectChange(IsoObjectChange.USES_EXTERNAL_WATER_SOURCE, { value = true })
    end
    return stateAt(args)
end)

handler("fixtures.state", function(_, args)
    return stateAt(args)
end)

-- Plumbs the fixture at x, y, z to the tank at `args.tank` as the jobs leave it, with `args.lengths`
-- lengths of `args.kind` pipe, or none as vanilla's Plumb does, without the job.
handler("fixtures.plumb", function(_, args)
    local fixture = PZHarness.need(fixtureAt(args), "the fixture on the server")
    local tank = PZHarness.need(EI.Tanks.tankAt(args.tank.x, args.tank.y, args.tank.z), "the fixture's tank on the server")
    EI.FixtureSystem.plumb(fixture, tank, args.kind, args.lengths or 0, nil)
    return stateAt(args)
end)

-- Takes `args.litres` out of the fixture's buffer at x, y, z, as a drink or a wash does, then runs a
-- link pass (LinkSystem:pass) of each of `args.passes` hours, which refills every plumbed fixture's
-- buffer from its tank. Answers the state after the draw and after each pass, with the tank's. All
-- in one call, so the ten-minute event can't run a pass of its own in between.
handler("fixtures.refill", function(_, args)
    local fixture = fixtureAt(args)
    PZHarness.need(fixture and fixture:getFluidContainer(), "a fixture with a buffer on the server")
    fixture:getFluidContainer():removeFluid(args.litres, false)
    fixture:sync()
    local reply = { drawn = stateAt(args), passes = {} }
    for _, hours in ipairs(args.passes) do
        EI.LinkSystem.instance:pass(hours)
        table.insert(reply.passes, stateAt(args))
    end
    return reply
end)

-- What the load hook does to a fixture vanilla plumbed (FixtureSystem.convert), at once. Answers
-- whether there was nothing more to do.
handler("fixtures.convert", function(_, args)
    local fixture = PZHarness.need(fixtureAt(args), "the fixture on the server")
    return { finished = EI.FixtureSystem.convert(fixture) }
end)
