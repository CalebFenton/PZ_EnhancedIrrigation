require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkClient"
require "EnhancedIrrigation/UI/LinkMenu"

-- Pipe between tanks: plumbing tanks together from the right-click menu and taking the pipe out,
-- how water moves through a link, and this client's copy of the list. What the menu greys out, the
-- server is also asked to do directly (tanks.perform), to show it refuses on its own. Link passes
-- run through the server's link handlers, so the clock doesn't decide them.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Links, LinkJobs, Pipes = EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs, EnhancedIrrigation.Pipes

local LITRES = 0.05
-- What a link pass carries at the link's full rate (links.flow): less than the tests' tanks hold,
-- so the rate shows before the water levels.
local PASS_LITRES = 60

local function useMenu(self, handle, label, find, choose)
    T.goNextTo(self, handle.square)
    T.useOption(self, function() return T.tankCopy(handle) end, label, find, choose)
end

local function job(id, with)
    return function(context) return T.jobOption(context, "link", id, with) end
end

local function counted(self, fullType)
    return self.counts.left and self.counts.left[fullType] or 0
end

-- The links with an end on the handle's square, as the menus see them: in single player that is the
-- server's list, so only a multiplayer run waits here on this client's copy.
local function clientLinks(handle)
    return Links.linksAt(T.at(handle))
end

-- The lengths a run of `tiles` tiles on one level takes.
local function lengthsFor(tiles)
    return math.ceil(tiles / Links.TILES_PER_LENGTH)
end

-- How Unplumb names buried pipe to an empty spot `tiles` tiles east.
local function buriedPipeEast(tiles)
    return getText("ContextMenu_EnhancedIrrigation_BuriedPipeToEmpty", tiles, getText("IGUI_EnhancedIrrigation_Direction_E"))
end

-- The conditions of the iron pipe this client's character carries, lowest first.
local function ironConditions()
    local items = T.player():getInventory():getAllTypeRecurse(Pipes.KINDS.iron.item)
    local conditions = {}
    for i = 0, items:size() - 1 do
        table.insert(conditions, items:get(i):getCondition())
    end
    table.sort(conditions)
    return conditions
end

-- Plumb to Tank ----------------------------------------------------------------------------------

-- Plumb to Tank is greyed out, with no list of tanks, for a character who doesn't know how, and the
-- server refuses it on its own, taking no pipe. Catches the knowledge checked only by the menu.
T.test("irrigation_links_plumb_refused_without_the_knowledge", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 4, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.low = T.placeTank(self, spots[1], "lidded")
            self.high = T.placeTank(self, spots[2], "raisedLidded")
        end)
        self.pipes = 2
        T.knowRecipes(self, { LinkJobs.RECIPE }, false)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = self.pipes } })
        useMenu(self, self.low, "plumb", function(context)
            return T.findNamed(context, context, getText("ContextMenu_EnhancedIrrigation_PlumbToTank"))
        end, false)
        T.batch(function()
            T.read(self, "tanks.perform", T.at(self.low, { feature = "link", job = LinkJobs.PLUMB,
                with = Links.encode(T.at(self.high), "iron") }), "forced")
            T.count(self, "left", { "Base.MetalPipe" })
        end)
    end,
    validate = function(self)
        T.expectRefused(self, "plumb")
        expect(not (self.menu.plumb and self.menu.plumb.submenu), "Plumb to Tank lists tanks to a character who doesn't know how")
        local forced = self.reads.forced
        expect(forced.done == false, "the server plumbed for a character who doesn't know how")
        expect(forced.links == 0, "the refused plumbing left " .. tostring(forced.links) .. " links")
        expect(counted(self, "Base.MetalPipe") == self.pipes, "the refused plumbing took pipe: "
            .. counted(self, "Base.MetalPipe") .. " left")
    end,
})

-- A well's water stands underground, so no pipe fills from it: Plumb to Tank at a barrel near a well
-- lists no tank and says none is in reach. Catches a well counted as a tank.
T.test("irrigation_links_plumb_lists_no_well", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        T.placeTank(self, spots[1], "wellAbove")
        self.barrel = T.placeTank(self, spots[2], "raisedLidded")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = 4 } })
        useMenu(self, self.barrel, "plumb to the well", function(context)
            return T.findOption(context, context, function(option)
                return option.onSelect == EnhancedIrrigationAction.queue and option.param1 == "link"
                    and option.param2 == LinkJobs.PLUMB
            end)
        end, false)
        T.useOption(self, function() return T.tankCopy(self.barrel) end, "no tank in reach", function(context)
            return T.findNamed(context, context, getText("ContextMenu_EnhancedIrrigation_NoTankInReach"))
        end, false)
    end,
    validate = function(self)
        expect(not self.menu["plumb to the well"].found, "Plumb to Tank lists a well")
        expect(self.menu["no tank in reach"].found, "Plumb to Tank doesn't say no other tank is in reach")
    end,
})

-- Plumb to Tank reaches a tank Links.MAX_TILES away, taking the lengths that run needs, and no
-- farther: one tile past it is neither listed nor plumbed by the server. Plumbed, the tank moves
-- from Plumb to Tank's list to Unplumb's. Catches the reach off by one, or the wrong pipe taken.
T.test("irrigation_links_plumb_to_tank_up_to_max_tiles", {
    instant = true,
    run = function(self)
        local reach = Links.MAX_TILES
        local spots = T.layout(self, { { 0, 0 }, { reach, 0 }, { reach + 1, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.low = T.placeTank(self, spots[1], "lidded")
            self.high = T.placeTank(self, spots[2], "raisedLidded")
            self.far = T.placeTank(self, spots[3], "lidded")
        end)
        self.lengths = lengthsFor(reach)
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        -- Iron needs no joint.
        T.give(self, "tools", { { type = "Base.PipeWrench" },
            { type = "Base.MetalPipe", count = self.lengths * Pipes.KINDS.iron.perLength } })
        local with, past = Links.encode(T.at(self.high), "iron"), Links.encode(T.at(self.far), "iron")
        useMenu(self, self.low, "one tile past", job(LinkJobs.PLUMB, past), false)
        T.read(self, "tanks.perform", T.at(self.low, { feature = "link", job = LinkJobs.PLUMB, with = past }), "forced")
        local low = function() return T.tankCopy(self.low) end
        T.useOption(self, low, "at the limit", job(LinkJobs.PLUMB, with), true)
        T.readUntil(self, "links.read", T.at(self.low), "links", function(reply) return #reply.links > 0 end)
        T.count(self, "left", { "Base.MetalPipe", "Base.PipeWrench" })
        T.waitFor(self, function() return #clientLinks(self.low) > 0 end, "this client's copy of the link")
        T.useOption(self, low, "unplumb", job(LinkJobs.UNPLUMB, Links.encode(T.at(self.high))), false)
        T.useOption(self, low, "plumb again", job(LinkJobs.PLUMB, with), false)
    end,
    validate = function(self)
        expect(not self.menu["one tile past"].found, "Plumb to Tank lists a tank " .. (Links.MAX_TILES + 1) .. " tiles away")
        local forced = self.reads.forced
        expect(forced.done == false, "the server plumbed to a tank out of reach")
        expect(forced.links == 0, "the refused plumbing left " .. tostring(forced.links) .. " links")
        T.expectOffered(self, "at the limit")
        local links = self.reads.links.links
        if expect(#links == 1, "the server has " .. #links .. " links at the tank") then
            expect(links[1].kind == "iron" and links[1].lengths == self.lengths,
                "the link is " .. tostring(links[1].lengths) .. " lengths of " .. tostring(links[1].kind) .. ", not "
                .. self.lengths .. " of iron")
        end
        expect(counted(self, "Base.MetalPipe") == 0, "plumbing left " .. counted(self, "Base.MetalPipe") .. " iron pipe")
        expect(counted(self, "Base.PipeWrench") == 1, "plumbing used up the pipe wrench")
        expect(self.menu.unplumb.found, "Unplumb doesn't list the plumbed tank")
        expect(not self.menu["plumb again"].found, "Plumb to Tank still lists a tank already plumbed to")
    end,
})

-- Plumb to Tank lays the pipe the player picks from what they carry, each kind listed under the
-- tank with what the run takes: carrying iron and lead, the lead chosen goes in and the iron stays;
-- plastic without glue is greyed out for its joints. Catches pipe picked for the player.
T.test("irrigation_links_plumb_lays_the_pipe_chosen", {
    instant = true,
    run = function(self)
        local apart = 3
        local spots = T.layout(self, { { 0, 0 }, { apart, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.a = T.placeTank(self, spots[1], "lidded")
            self.b = T.placeTank(self, spots[2], "lidded")
        end)
        local lengths = lengthsFor(apart)
        local iron, lead, plastic = Pipes.KINDS.iron, Pipes.KINDS.lead, Pipes.KINDS.plastic
        self.ironCount = lengths * iron.perLength
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = iron.item, count = self.ironCount },
            { type = lead.item, count = lengths * lead.perLength }, { type = plastic.item, count = lengths * plastic.perLength } })
        local function plumb(kind)
            return job(LinkJobs.PLUMB, Links.encode(T.at(self.b), kind))
        end
        local a = function() return T.tankCopy(self.a) end
        useMenu(self, self.a, "iron", plumb("iron"), false)
        T.useOption(self, a, "plastic", plumb("plastic"), false)
        T.useOption(self, a, "lead", plumb("lead"), true)
        T.readUntil(self, "links.read", T.at(self.a), "links", function(reply) return #reply.links > 0 end)
        T.count(self, "left", { iron.item, lead.item })
    end,
    validate = function(self)
        T.expectOffered(self, "iron")
        T.expectRefused(self, "plastic")
        T.expectOffered(self, "lead")
        local links = self.reads.links.links
        if expect(#links == 1, "the server has " .. #links .. " links at the tank") then
            expect(links[1].kind == "lead", "the link is " .. tostring(links[1].kind) .. " pipe, not the lead chosen")
        end
        local iron, lead = Pipes.KINDS.iron.item, Pipes.KINDS.lead.item
        expect(counted(self, lead) == 0, "plumbing left " .. counted(self, lead) .. " lead pipe")
        expect(counted(self, iron) == self.ironCount, "plumbing with lead took iron pipe: " .. counted(self, iron) .. " left")
    end,
})

-- Unplumb gives back every length Plumb to Tank took, each as worn as it went in, and this client
-- drops the link. Catches pipe kept in the walls, or every length back at one condition.
T.test("irrigation_links_unplumb_gives_back_the_pipe", {
    instant = true,
    run = function(self)
        -- Far enough apart for more than one length.
        local apart = 2 * Links.TILES_PER_LENGTH + 1
        local spots = T.layout(self, { { 0, 0 }, { apart, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.a = T.placeTank(self, spots[1], "lidded")
            self.b = T.placeTank(self, spots[2], "lidded")
        end)
        local iron = Pipes.KINDS.iron
        local count = lengthsFor(apart) * iron.perLength
        local most = instanceItem(iron.item):getConditionMax()
        -- Each length worn differently, so one condition for all would show. Iron needs no joint.
        self.laid = {}
        local items = { { type = "Base.PipeWrench" } }
        for i = 1, count do
            self.laid[i] = math.floor(most * i / (count + 1))
            table.insert(items, { type = iron.item, condition = self.laid[i] })
        end
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", items)
        useMenu(self, self.a, "plumb", job(LinkJobs.PLUMB, Links.encode(T.at(self.b), "iron")), true)
        T.waitFor(self, function() return #clientLinks(self.a) > 0 and #ironConditions() == 0 end,
            "this client's copy of the link, the pipe gone into it")
        T.useOption(self, function() return T.tankCopy(self.a) end, "unplumb",
            job(LinkJobs.UNPLUMB, Links.encode(T.at(self.b))), true)
        T.readUntil(self, "links.read", T.at(self.a), "links", function(reply) return #reply.links == 0 end)
        T.waitFor(self, function() return #ironConditions() == count end, "this client's copy of the pipe given back")
        T.waitFor(self, function() return #clientLinks(self.a) == 0 end, "this client to drop the link")
    end,
    validate = function(self)
        T.expectOffered(self, "plumb")
        T.expectOffered(self, "unplumb")
        local links = self.reads.links.links
        expect(#links == 0, "the server still has " .. #links .. " links after Unplumb")
        local back = ironConditions()
        for i, condition in ipairs(self.laid) do
            expect(back[i] == condition, "length " .. i .. " came back at condition " .. tostring(back[i])
                .. ", laid at " .. condition)
        end
    end,
})

-- Link flow --------------------------------------------------------------------------------------

-- Two tanks on one level fill toward equal, no faster than the link carries. Catches a link that
-- overshoots, or ignores its rate.
T.test("irrigation_links_levels_tanks_on_one_level", {
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.start = 300
        -- Not in a T.batch: the flow call would go out across these waits for this client's
        -- copies, and move the water before they see it.
        self.a = T.placeTank(self, spots[1], "lidded", self.start)
        self.b = T.placeTank(self, spots[2], "lidded")
        T.read(self, "links.flow", T.at(self.a, { to = T.at(self.b), litres = PASS_LITRES, passes = 3 }), "flow")
    end,
    validate = function(self)
        local passes = self.reads.flow.passes
        if not expect(#passes == 3, "the flow ran " .. #passes .. " passes") then return end
        -- The same barrels: equal fill is equal litres.
        local a, b = self.start, 0
        for i, pass in ipairs(passes) do
            local moved = math.min(PASS_LITRES, (a - b) / 2)
            a, b = a - moved, b + moved
            expectNear("the fuller tank after pass " .. i, pass.a.litres, a, LITRES)
            expectNear("the emptier tank after pass " .. i, pass.b.litres, b, LITRES)
        end
    end,
})

-- A raised tank empties into a lower one, though the lower ends fuller, carrying its taint into the
-- clean water there; a ground tank never fills a raised one. Catches water levelled by fill rather
-- than by height, or taint left behind.
T.test("irrigation_links_fills_downhill_never_uphill", {
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 }, { 0, 2 }, { 3, 2 } }, { bare = true })
        if not spots then return end
        self.high, self.low = 100, 20
        -- Not in a T.batch, as in the levelling test.
        self.raised = T.placeTank(self, spots[1], "raisedLidded", self.high, true)
        self.ground = T.placeTank(self, spots[2], "lidded", self.low)
        self.groundFull = T.placeTank(self, spots[3], "lidded", self.high)
        self.raisedEmpty = T.placeTank(self, spots[4], "raisedLidded")
        T.batch(function()
            T.read(self, "links.flow", T.at(self.raised, { to = T.at(self.ground), litres = PASS_LITRES, passes = 2 }),
                "downhill")
            T.read(self, "links.flow", T.at(self.groundFull, { to = T.at(self.raisedEmpty), litres = PASS_LITRES }), "uphill")
        end)
        T.waitFor(self, function()
            local tank = EnhancedIrrigation.Tanks.tankOn(self.ground.square)
            return tank ~= nil and tank:getFluidContainer():isTainted()
        end, "this client's copy of the lower barrel, tainted")
    end,
    validate = function(self)
        local down = self.reads.downhill.passes
        if expect(#down == 2, "the downhill flow ran " .. #down .. " passes") then
            local high, low = self.high, self.low
            for i, pass in ipairs(down) do
                local moved = math.min(PASS_LITRES, high)
                high, low = high - moved, low + moved
                expectNear("the raised barrel after pass " .. i, pass.a.litres, high, LITRES)
                expectNear("the ground barrel after pass " .. i, pass.b.litres, low, LITRES)
            end
            expect(down[1].b.tainted, "the clean barrel the tainted one filled isn't tainted")
        end
        local up = self.reads.uphill.passes
        if expect(#up == 1, "the uphill flow ran " .. #up .. " passes") then
            expectNear("the ground barrel linked to a raised one", up[1].a.litres, self.high, LITRES)
            expectNear("the raised barrel linked to a ground one", up[1].b.litres, 0, LITRES)
        end
    end,
})

-- Buried pipe ------------------------------------------------------------------------------------

-- A tank taken off a plumbed square leaves its pipe buried: the link outlives a pass, moving no
-- water, and the tank left names it under Unplumb as pipe to an empty spot. A tank set on that
-- square again is on the link at once, and Plumb to Tank lays no second pipe to it. Catches a link
-- dropped with its tank, one that needs plumbing again, or two links between the same squares.
T.test("irrigation_links_buried_pipe_stays_and_reconnects", {
    instant = true,
    run = function(self)
        self.apart = 3
        local spots = T.layout(self, { { 0, 0 }, { self.apart, 0 } }, { bare = true })
        if not spots then return end
        self.start = 100
        -- Not in a T.batch: the link and the removal would go out across these waits for this
        -- client's copies.
        self.a = T.placeTank(self, spots[1], "lidded", self.start)
        self.b = T.placeTank(self, spots[2], "lidded")
        local with = Links.encode(T.at(self.b))
        T.batch(function()
            T.read(self, "links.make", T.at(self.a, { to = T.at(self.b), kind = "iron", lengths = 1 }), "linked")
            T.server(self, "tanks.remove", T.at(self.b))
            T.read(self, "links.pass", T.at(self.a, { litres = PASS_LITRES }), "bare")
        end)
        T.waitFor(self, function() return T.tankCopy(self.b) == nil end, "this client to lose the tank taken away")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = 2 } })
        useMenu(self, self.a, "unplumb the bare end", job(LinkJobs.UNPLUMB, with), false)
        self.again = T.placeTank(self, spots[2], "lidded")
        local plumbWith = Links.encode(T.at(self.b), "iron")
        T.useOption(self, function() return T.tankCopy(self.a) end, "plumb again", job(LinkJobs.PLUMB, plumbWith), false)
        T.batch(function()
            T.read(self, "tanks.perform", T.at(self.a, { feature = "link", job = LinkJobs.PLUMB, with = plumbWith }),
                "forced")
            T.read(self, "links.pass", T.at(self.a, { litres = PASS_LITRES, other = T.at(self.again) }), "joined")
        end)
    end,
    validate = function(self)
        expect(self.reads.linked.links == 1, "the link wasn't made")
        local bare = self.reads.bare
        expect(bare.links == 1, "the link went with its tank")
        expectNear("the tank left, after a pass with no tank at the other end", bare.litres, self.start, LITRES)
        T.expectOffered(self, "unplumb the bare end")
        local want = buriedPipeEast(self.apart)
        local named = self.menu["unplumb the bare end"].name
        expect(named == want, "Unplumb names the bare end " .. tostring(named) .. ", not " .. want)
        expect(not self.menu["plumb again"].found, "Plumb to Tank lists the tank set back on the plumbed square")
        local forced = self.reads.forced
        expect(forced.done == false and forced.links == 1, "the server laid a second pipe between the same squares: "
            .. tostring(forced.links) .. " links")
        local joined, moved = self.reads.joined, math.min(PASS_LITRES, self.start / 2)
        expectNear("the tank left, once a tank stands at the other end again", joined.litres, self.start - moved, LITRES)
        expectNear("the tank set on the bare end", joined.other.litres, moved, LITRES)
    end,
})

-- With both tanks gone the buried pipe is still found by the floor where one stood: Unplumb there
-- names the far end as an empty spot and gives back every length. Catches pipe only a tank reaches.
T.test("irrigation_links_unplumb_from_the_bare_floor", {
    instant = true,
    run = function(self)
        -- Far enough apart for more than one length.
        self.apart = 2 * Links.TILES_PER_LENGTH + 1
        local spots = T.layout(self, { { 0, 0 }, { self.apart, 0 } }, { bare = true })
        if not spots then return end
        self.a = T.placeTank(self, spots[1], "lidded")
        self.b = T.placeTank(self, spots[2], "lidded")
        local lengths = lengthsFor(self.apart)
        T.batch(function()
            T.read(self, "links.make", T.at(self.a, { to = T.at(self.b), kind = "iron", lengths = lengths }), "linked")
            T.server(self, "tanks.remove", T.at(self.a))
            T.server(self, "tanks.remove", T.at(self.b))
        end)
        T.waitFor(self, function() return T.tankCopy(self.a) == nil and T.tankCopy(self.b) == nil end,
            "this client to lose both tanks")
        T.give(self, "tools", { { type = "Base.PipeWrench" } })
        T.goNextTo(self, self.a.square)
        T.useOption(self, function() return self.a.square:getFloor() end, "unplumb",
            job(LinkJobs.UNPLUMB, Links.encode(T.at(self.b))), true)
        T.readUntil(self, "links.read", T.at(self.a), "links", function(reply) return #reply.links == 0 end)
        self.count = lengths * Pipes.KINDS.iron.perLength
        T.waitFor(self, function() return #ironConditions() == self.count end, "this client's copy of the pipe given back")
    end,
    validate = function(self)
        expect(self.reads.linked.links == 1, "the link wasn't made")
        T.expectOffered(self, "unplumb")
        local want = buriedPipeEast(self.apart)
        local named = self.menu.unplumb.name
        expect(named == want, "the bare floor's Unplumb names the pipe " .. tostring(named) .. ", not " .. want)
        expect(#self.reads.links.links == 0, "the server still has the link after Unplumb from the floor")
        expect(#ironConditions() == self.count, "Unplumb from the floor gave back " .. #ironConditions() .. " iron pipe, not "
            .. self.count)
    end,
})

-- This client's list ------------------------------------------------------------------------------

-- How many links with an end on the handle's square this client's own copy of the list holds, which
-- the server's commands set in single player too.
local function viewedLinks(handle)
    local at, count = T.at(handle), 0
    for _, link in ipairs(Links.clientSystem.links) do
        if Links.otherEnd(link, at) then
            count = count + 1
        end
    end
    return count
end

-- A list of links overtaken on its way here, which lands after the newer one, changes nothing.
-- Catches this client dropping links on a stale list.
T.test("irrigation_links_keep_the_newest_list", {
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.a = T.placeTank(self, spots[1], "lidded")
            self.b = T.placeTank(self, spots[2], "lidded")
        end)
        T.read(self, "links.make", T.at(self.a, { to = T.at(self.b), kind = "iron", lengths = 1 }), "linked")
        T.waitFor(self, function() return viewedLinks(self.a) == 1 end, "this client's copy of the link")
        -- Notes each list's version as it lands, before the view takes or ignores it.
        T.step(function()
            local LinkClient = EnhancedIrrigation.LinkClient
            local original = LinkClient.OnServerCommand
            self.landed = {}
            LinkClient.OnServerCommand = function(view, command, args)
                if command == "links" then
                    self.landed[args.version] = true
                end
                original(view, command, args)
            end
            T.defer(self, function() LinkClient.OnServerCommand = original end)
        end)
        T.read(self, "links.stale", {}, "stale")
        T.waitFor(self, function() return self.landed[self.reads.stale.version] end, "the stale list of links")
        T.step(function() self.kept = viewedLinks(self.a) end)
    end,
    validate = function(self)
        expect(self.reads.linked.links == 1, "the link wasn't made")
        expect(self.kept == 1, "this client took a list of links older than the one it had")
    end,
})
