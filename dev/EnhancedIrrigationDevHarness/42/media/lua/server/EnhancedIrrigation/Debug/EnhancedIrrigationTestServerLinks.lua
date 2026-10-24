require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsLinks.lua: links
-- made, read and run on the authority; placing the tanks and running Plumb and Unplumb is
-- EnhancedIrrigationTestServer.lua's. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

-- Plumbs x, y, z to `args.to` ({ x, y, z }) with `args.lengths` lengths of `args.kind`, as Plumb to
-- Tank leaves it, or with `args.role` ("inlet" or "outlet") as Plumb Inlet or Plumb Outlet leaves
-- the unit at x, y, z, without the job. Dropped when the test ends.
handler("links.make", function(_, args, defer)
    local a, b = { x = args.x, y = args.y, z = args.z }, args.to
    mod().LinkSystem.instance:addLink(a, b, args.kind, args.lengths, nil, args.role)
    defer(function() Server.unlinkAt(a.x, a.y, a.z) end)
    return Server.stateAt(args)
end)

-- The kind and lengths of each link with an end on x, y, z, as the server keeps them.
handler("links.read", function(_, args)
    local links = {}
    for _, link in ipairs(mod().Links.linksAt({ x = args.x, y = args.y, z = args.z })) do
        table.insert(links, { kind = link.kind, lengths = link.lengths })
    end
    return { links = links }
end)

-- Sends every client an empty list one change older than the last sent, as a list overtaken on its
-- way would arrive. Answers the stale list's `version`.
handler("links.stale", function()
    local system = mod().LinkSystem.instance
    local stale = system.version - 1
    system:sendCommand("links", { links = {}, version = stale })
    return { version = stale }
end)

-- Plumbs x, y, z to `args.to` with a length of iron pipe, as links.make does, and runs
-- `args.passes` link passes (LinkSystem:pass), each as long as the link takes to carry
-- `args.litres` at its full rate, answering both tanks' states after each in `passes`. All in one
-- call, so the ten-minute event can't run a pass of its own in between.
handler("links.flow", function(_, args, defer)
    local system = mod().LinkSystem.instance
    local a, b = { x = args.x, y = args.y, z = args.z }, args.to
    system:addLink(a, b, "iron", 1)
    defer(function() Server.unlinkAt(a.x, a.y, a.z) end)
    local passes = {}
    for _ = 1, args.passes or 1 do
        system:pass(args.litres / mod().Links.RATE)
        table.insert(passes, { a = Server.stateAt(a), b = Server.stateAt(b) })
    end
    return { passes = passes }
end)

-- One link pass (LinkSystem:pass), as long as a link takes to carry `args.litres` at its full rate.
-- Answers the state at x, y, z after, and at `args.other` ({ x, y, z }) if given.
handler("links.pass", function(_, args)
    mod().LinkSystem.instance:pass(args.litres / mod().Links.RATE)
    local state = Server.stateAt(args)
    state.other = args.other and Server.stateAt(args.other) or nil
    return state
end)
