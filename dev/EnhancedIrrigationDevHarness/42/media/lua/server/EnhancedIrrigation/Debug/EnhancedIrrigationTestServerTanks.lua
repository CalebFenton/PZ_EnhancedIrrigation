require "PZHarness/ServerHandlers"
require "PZHarness/ServerFixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsTanks.lua: what
-- only the authority does to stands, tanks and links, called with PZHarness.Test.server; placing
-- and reading them is EnhancedIrrigationTestServer.lua's. Only registers handlers, so a --stay
-- rerun loads it again.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

-- Removes, when the test ends, whatever stand or tank stands at x, y, z then, and its links: for
-- what the test builds through the game.
handler("tanks.track", function(_, args, defer)
    Server.removeWhenDone(args, defer)
    return {}
end)

-- Removes the stand or tank at x, y, z now, the way the game removes an object.
handler("tanks.remove", function(_, args)
    Server.removeAt(args.x, args.y, args.z)
    return Server.stateAt(args)
end)

-- Gives the character the barrel moveable of the vanilla tile `args.barrel` as the mod's Take
-- Barrel Down makes it, holding `args.litres` of water: a barrel vanilla would never let the
-- character pick up.
handler("tanks.giveBarrel", function(player, args)
    local EI = mod()
    local spec
    for _, entry in ipairs(EI.Stands.BARRELS) do
        if entry.barrel == args.barrel then
            spec = entry
        end
    end
    if not spec then
        return nil, "a barrel of the tile " .. tostring(args.barrel)
    end
    local item = EI.StandSystem.barrelItem(spec, player:getCurrentSquare())
    if (args.litres or 0) > 0 then
        item:getFluidContainer():addFluid(FluidType.Water, args.litres)
    end
    return { given = { PZHarness.giveItem(player, item) } }
end)

local function isBarrelItem(item)
    return mod().Stands.barrelSpec(item) ~= nil
end

local function describeBarrel(item)
    local fluid = item:getFluidContainer()
    return {
        fullType = item:getFullType(),
        worldSprite = item:getWorldSprite(),
        weight = item:getActualWeight(),
        hasFluid = fluid ~= nil,
        capacity = fluid and fluid:getCapacity() or 0,
        litres = fluid and fluid:getAmount() or 0,
        containerName = fluid and fluid:getContainerName() or nil,
    }
end

-- The barrel moveables the server's copy of the character carries, as plain values; with
-- `args.dropped`, also those on the squares around them, which then go away: a barrel too heavy
-- to carry lands at the character's feet (Actions.addOrDropItem).
handler("tanks.barrels", function(player, args)
    local barrels = {}
    local carried = player:getInventory():getAllEvalRecurse(isBarrelItem)
    for i = 0, carried:size() - 1 do
        table.insert(barrels, describeBarrel(carried:get(i)))
    end
    local here = args.dropped and player:getCurrentSquare()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local square = here and getSquare(here:getX() + dx, here:getY() + dy, here:getZ())
            local objects = square and square:getWorldObjects()
            for i = (objects and objects:size() or 0) - 1, 0, -1 do
                local object = objects:get(i)
                if isBarrelItem(object:getItem()) then
                    table.insert(barrels, describeBarrel(object:getItem()))
                    if isServer() then
                        square:transmitRemoveItemFromSquare(object)
                    end
                    square:removeWorldObject(object)
                end
            end
        end
    end
    return { barrels = barrels }
end)

-- Takes every barrel moveable from the server's copy of the character.
handler("tanks.dropBarrels", function(player)
    local carried = player:getInventory():getAllEvalRecurse(isBarrelItem)
    for i = carried:size() - 1, 0, -1 do
        mod().takeItem(player, carried:get(i))
    end
    return {}
end)

-- The system whose perform does each action feature's jobs.
local SYSTEMS = { stand = "StandSystem", link = "LinkSystem" }

-- Runs the job `args.job` of the action feature `args.feature` at the object at x, y, z through the
-- authority's own perform (what the action's complete() calls), with `args.with`, or with the first
-- barrel moveable carried when `args.barrel`. Answers whether it was done and the object's state
-- after, so a test sees the server refuse what its menu would have greyed out.
handler("tanks.perform", function(player, args)
    local EI = mod()
    local square = Server.squareAt(args)
    local object = square and EI.findObjectOn(square, Server.isPlaced)
    if not object then
        return nil, "the server's object at " .. tostring(args.x) .. "," .. tostring(args.y)
    end
    local with = args.with
    if args.barrel then
        local carried = EI.Stands.barrelsCarried(player)[1]
        with = carried and carried.item
    end
    local done = EI[SYSTEMS[args.feature]].perform(player, args.job, object, with)
    local state = Server.stateAt(args)
    state.done = done == true
    return state
end)

-- Plumbs x, y, z to `args.to` ({ x, y, z }) with `args.lengths` lengths of `args.kind`, as Plumb to
-- Tank leaves it, without the job. Dropped when the test ends.
handler("tanks.link", function(_, args, defer)
    local a, b = { x = args.x, y = args.y, z = args.z }, args.to
    mod().LinkSystem.instance:addLink(a, b, args.kind, args.lengths)
    defer(function() Server.unlinkAt(a.x, a.y, a.z) end)
    return Server.stateAt(args)
end)

-- The links with an end on x, y, z, as the server keeps them.
handler("tanks.links", function(_, args)
    local links = {}
    for _, link in ipairs(mod().Links.linksAt({ x = args.x, y = args.y, z = args.z })) do
        table.insert(links, { a = link.a, b = link.b, kind = link.kind, lengths = link.lengths })
    end
    return { links = links }
end)

-- Sends every client an empty list one change older than the last sent, as a list overtaken on its
-- way would arrive. Answers the stale list's `version`.
handler("tanks.staleLinks", function()
    local system = mod().LinkSystem.instance
    local stale = system.version - 1
    system:sendCommand("links", { links = {}, version = stale })
    return { version = stale }
end)

-- Plumbs x, y, z to `args.to` as tanks.link does and runs `args.passes` link passes
-- (LinkSystem:pass), each as long as the link takes to carry `args.litres` at its full rate,
-- answering both tanks' states after each in `passes`. All in one call, so the ten-minute event
-- can't run a pass of its own in between.
handler("tanks.flow", function(_, args, defer)
    local system = mod().LinkSystem.instance
    local a, b = { x = args.x, y = args.y, z = args.z }, args.to
    system:addLink(a, b, args.kind or "iron", args.lengths or 1)
    defer(function() Server.unlinkAt(a.x, a.y, a.z) end)
    local passes = {}
    for _ = 1, args.passes or 1 do
        system:pass(args.litres / mod().LinkSystem.LINK_RATE)
        table.insert(passes, { a = Server.stateAt(a), b = Server.stateAt(b) })
    end
    return { passes = passes }
end)

-- One link pass of an hour (LinkSystem:pass). Answers the state at x, y, z after.
handler("tanks.pass", function(_, args)
    mod().LinkSystem.instance:pass(1)
    return Server.stateAt(args)
end)
