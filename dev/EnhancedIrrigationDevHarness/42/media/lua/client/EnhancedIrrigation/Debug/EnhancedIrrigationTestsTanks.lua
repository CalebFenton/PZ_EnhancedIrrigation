require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLibTanks"
require "EnhancedIrrigation/StandJobs"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Links/LinkView"

-- Tanks and the Tank Stand (docs/design.md, "Tanks and height", "Connections"): building a stand,
-- setting a barrel on it and taking it down, the raised barrel as a tank a level up through the
-- vanilla lid, plumbing tanks together and taking the pipe out, and how water moves through a link.
-- Each job goes through the game: the build menu, the right-click menu and its timed action, the
-- authority's complete(). What the menu greys out, the server is also asked to do directly, to show
-- it refuses on its own. Link passes run through a server handler, so the clock doesn't decide them.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Stands, Links = EnhancedIrrigation.Sprites, EnhancedIrrigation.Stands, EnhancedIrrigation.Links
local StandJobs, LinkJobs, LineJobs = EnhancedIrrigation.StandJobs, EnhancedIrrigation.LinkJobs, EnhancedIrrigation.LineJobs
local Pipes = EnhancedIrrigation.Pipes

-- The barrel the tests lift: vanilla's lidded rain barrel, which no rain fills meanwhile, so an
-- empty one stays empty and a filled one holds what the test put in.
local BARREL = T.TANKS.lidded.sprite
-- What a player is given to place it, and the type the item then has in hand (Stands.BARRELS).
local BARREL_ITEM = "Moveables." .. BARREL
local BARREL_HELD = "Base." .. BARREL
local LITRES = 0.05
-- What a link pass carries at the link's full rate (tanks.flow): less than the tests' tanks hold,
-- so the rate shows before the water levels.
local PASS_LITRES = 60

-- Queues standing next to `handle`'s tile and T.useOption on this client's copy of it.
local function useMenu(self, handle, label, find, choose)
    T.goNextTo(self, handle.square)
    T.useOption(self, function() return T.tankCopy(handle) end, label, find, choose)
end

local function job(feature, id, with)
    return function(context) return T.jobOption(context, feature, id, with) end
end

-- Queues a vanilla barrel moveable at `handle` put down and picked up again as a player does, so
-- the character carries the item vanilla's pickup gives.
local function pickUpVanillaBarrel(self, handle)
    local placed = T.placeAsPlayer(self, handle.square, BARREL_ITEM, BARREL)
    T.pickUpAsPlayer(self, placed, BARREL)
    T.waitFor(self, function() return T.player():getInventory():getFirstTypeRecurse(BARREL_HELD) ~= nil end,
        "the barrel vanilla's pickup gives")
end

local function counted(self, fullType)
    return self.counts.left and self.counts.left[fullType] or 0
end

-- Stands -----------------------------------------------------------------------------------------

-- The build menu builds a Tank Stand from its recipe on a bare square.
T.test("irrigation_tanks_stand_built_from_build_menu", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.stand = T.buildFromMenu(self, "Base." .. Stands.STAND_ENTITY, spots[1], Sprites.STAND)
        if not self.stand then return end
        T.read(self, "tanks.read", T.at(self.stand), "built")
    end,
    validate = function(self)
        expect(self.canBuild and self.validSquare, "the build menu can't build a Tank Stand from its materials on a bare square")
        local built = self.reads.built
        expect(built.isStand, "the build menu built " .. tostring(built.entity) .. ", not a Tank Stand")
        expect(built.sprite == Sprites.STAND, "the built stand is drawn as " .. tostring(built.sprite))
    end,
})

-- Set Barrel on Stand turns an empty barrel carried into a tank a level up, on both sides.
T.test("irrigation_tanks_barrel_set_on_stand_from_menu", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.stand = T.placeTank(self, spots[1], "stand")
        pickUpVanillaBarrel(self, spots[2])
        useMenu(self, self.stand, "set barrel", job("stand", StandJobs.SET_BARREL), true)
        T.waitFor(self, function() return T.tankCopy(self.stand, Sprites.RAISED_BARREL_CLOSED) ~= nil end,
            "this client's copy of the barrel on the stand")
        T.batch(function()
            T.read(self, "tanks.read", T.at(self.stand), "raised")
            T.count(self, "left", { BARREL_HELD })
        end)
        T.step(function() self.clientLevel = T.clientLevel(self.stand) end)
    end,
    validate = function(self)
        T.expectOffered(self, "set barrel")
        local raised, z = self.reads.raised, self.stand.z
        expect(raised.isRaised and raised.isTank, "the barrel on the stand isn't a raised tank")
        expect(raised.level == z + 1, "the raised barrel's level is " .. tostring(raised.level) .. ", not " .. (z + 1))
        expectNear("the raised barrel's water", raised.litres, 0, LITRES)
        expect(counted(self, BARREL_HELD) == 0, "setting the barrel on the stand left " .. counted(self, BARREL_HELD)
            .. " barrels carried")
        expect(self.clientLevel == z + 1, "this client sees the raised barrel at level " .. tostring(self.clientLevel))
    end,
})

-- Set Barrel on Stand is greyed out, saying why, without a barrel and for a barrel holding water,
-- and the server refuses the full one on its own.
T.test("irrigation_tanks_set_barrel_refused_without_an_empty_barrel", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.stand = T.placeTank(self, spots[1], "stand")
        useMenu(self, self.stand, "no barrel", job("stand", StandJobs.SET_BARREL), false)
        -- A barrel vanilla would never let the character pick up: one holding water.
        T.server(self, "tanks.giveBarrel", { barrel = BARREL, litres = 20 })
        T.useOption(self, function() return T.tankCopy(self.stand) end, "full barrel", job("stand", StandJobs.SET_BARREL),
            false)
        T.read(self, "tanks.perform", T.at(self.stand, { feature = "stand", job = StandJobs.SET_BARREL, barrel = true }),
            "forced")
    end,
    validate = function(self)
        T.expectRefused(self, "no barrel", "Tooltip_EnhancedIrrigation_NoBarrel")
        T.expectRefused(self, "full barrel", "Tooltip_EnhancedIrrigation_BarrelNotEmpty")
        local forced = self.reads.forced
        expect(forced.done == false, "the server set a barrel holding water on the stand")
        expect(forced.isStand, "the stand is gone after a refused Set Barrel on Stand")
    end,
})

-- Raised barrels ---------------------------------------------------------------------------------

-- Vanilla's Open Lid swaps the raised barrel's object, and it stays a raised tank with its water.
T.test("irrigation_tanks_raised_barrel_stays_a_raised_tank_through_the_lid", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.tank = T.placeTank(self, spots[1], "raisedLidded", 30)
        T.step(function() self.levelBefore = T.clientLevel(self.tank) end)
        useMenu(self, self.tank, "open lid", function(context)
            return T.findNamed(context, context, getText("ContextMenu_OpenLid"))
        end, true)
        T.waitFor(self, function() return T.tankCopy(self.tank, Sprites.RAISED_BARREL) ~= nil end,
            "this client's copy of the opened barrel")
        T.read(self, "tanks.read", T.at(self.tank), "opened")
        T.step(function() self.levelAfter = T.clientLevel(self.tank) end)
    end,
    validate = function(self)
        local z = self.tank.z
        expect(self.levelBefore == z + 1, "this client sees the raised barrel at level " .. tostring(self.levelBefore))
        T.expectOffered(self, "open lid")
        local opened = self.reads.opened
        expect(opened.entity == "EnhancedIrrigation_RaisedBarrel", "opening the lid made " .. tostring(opened.entity))
        expect(opened.isRaised and opened.isTank, "the opened barrel isn't a raised tank")
        expect(opened.level == z + 1, "the opened barrel's level is " .. tostring(opened.level))
        -- Open, it may catch a little rain meanwhile.
        expectNear("the opened barrel's water", opened.litres, 30, 1)
        expect(self.levelAfter == z + 1, "this client sees the opened barrel at level " .. tostring(self.levelAfter))
    end,
})

-- Take Barrel Down is greyed out for a barrel holding water, and the server refuses it on its own.
T.test("irrigation_tanks_take_down_refused_while_holding_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.tank = T.placeTank(self, spots[1], "raisedLidded", 5)
        useMenu(self, self.tank, "take down", job("stand", StandJobs.TAKE_DOWN), false)
        T.batch(function()
            T.read(self, "tanks.perform", T.at(self.tank, { feature = "stand", job = StandJobs.TAKE_DOWN }), "forced")
            T.count(self, "left", { BARREL_HELD })
        end)
    end,
    validate = function(self)
        T.expectRefused(self, "take down", "Tooltip_EnhancedIrrigation_EmptyBarrelFirst")
        local forced = self.reads.forced
        expect(forced.done == false, "the server took down a barrel holding water")
        expect(forced.isRaised, "the raised barrel is gone after a refused Take Barrel Down")
        expectNear("the refused barrel's water", forced.litres, 5, LITRES)
        expect(counted(self, BARREL_HELD) == 0, "a refused Take Barrel Down gave " .. counted(self, BARREL_HELD) .. " barrels")
    end,
})

-- Take Barrel Down leaves the stand and gives the very item vanilla's own pickup gives.
T.test("irrigation_tanks_take_down_gives_vanillas_barrel_and_the_stand", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.tank = T.placeTank(self, spots[1], "raisedLidded")
        -- Vanilla's own item for the same barrel, which the one taken down should match. Then it
        -- goes, as two barrels are more than a character carries.
        pickUpVanillaBarrel(self, spots[2])
        T.batch(function()
            T.read(self, "tanks.barrels", {}, "vanilla")
            T.server(self, "tanks.dropBarrels", {})
        end)
        T.waitFor(self, function() return T.player():getInventory():getFirstTypeRecurse(BARREL_HELD) == nil end,
            "this client to let go of vanilla's barrel")
        useMenu(self, self.tank, "take down", job("stand", StandJobs.TAKE_DOWN), true)
        T.waitFor(self, function() return T.tankCopy(self.tank, Sprites.STAND) ~= nil end, "this client's copy of the stand")
        T.batch(function()
            T.read(self, "tanks.read", T.at(self.tank), "stand")
            T.read(self, "tanks.barrels", { dropped = true }, "after")
        end)
    end,
    validate = function(self)
        T.expectOffered(self, "take down")
        local stand = self.reads.stand
        expect(stand.isStand and stand.sprite == Sprites.STAND, "taking the barrel down left " .. tostring(stand.entity))
        local vanilla, after = self.reads.vanilla.barrels, self.reads.after.barrels
        if not (expect(#vanilla == 1, "vanilla's pickup gave " .. #vanilla .. " barrels")
                and expect(#after == 1, "Take Barrel Down gave " .. #after .. " barrels")) then
            return
        end
        local barrel = after[1]
        for _, key in ipairs({ "fullType", "worldSprite", "hasFluid", "containerName" }) do
            expect(barrel[key] == vanilla[1][key], "a carried barrel's " .. key .. " is " .. tostring(barrel[key])
                .. ", vanilla's " .. tostring(vanilla[1][key]))
        end
        expectNear("a carried barrel's weight", barrel.weight, vanilla[1].weight, LITRES)
        expectNear("a carried barrel's capacity", barrel.capacity, vanilla[1].capacity, LITRES)
        expectNear("a carried barrel's water", barrel.litres, 0, LITRES)
    end,
})

-- Wells -------------------------------------------------------------------------------------------

-- Whether `option` queues the link job `id`, toward any square, with any pipe.
local function linkJob(id)
    return function(context)
        return T.findOption(context, context, function(option)
            return option.onSelect == EnhancedIrrigationAction.queue and option.param1 == "link" and option.param2 == id
        end)
    end
end

-- A well's water stands underground, so nothing draws on it by gravity: a well on the floor over a
-- line tile gives Fit Tap no tank a storey up, and Plumb to Tank at a barrel near a well lists no
-- tank. Catches a well counted as a tank.
T.test("irrigation_tanks_well_feeds_nothing_by_gravity", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        local tile = spots[1]
        T.placeTank(self, tile, "wellAbove")
        self.barrel = T.placeTank(self, spots[2], "raisedLidded")
        T.placeLine(self, { tile }, "iron")
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = 4 } })
        T.goNextTo(self, tile.square)
        T.useOption(self, function() return T.lineObject(tile) end, "fit tap", job("line", LineJobs.TAP), false)
        T.useOption(self, function() return T.tankCopy(self.barrel) end, "plumb to the well", linkJob(LinkJobs.PLUMB),
            false)
        T.useOption(self, function() return T.tankCopy(self.barrel) end, "no tank in reach", function(context)
            return T.findNamed(context, context, getText("ContextMenu_EnhancedIrrigation_NoTankInReach"))
        end, false)
    end,
    validate = function(self)
        T.expectRefused(self, "fit tap", "Tooltip_EnhancedIrrigation_NoTankForTap")
        expect(not self.menu["plumb to the well"].found, "Plumb to Tank lists a well")
        expect(self.menu["no tank in reach"].found, "Plumb to Tank doesn't say no other tank is in reach")
    end,
})

-- Plumb to Tank ----------------------------------------------------------------------------------

-- Plumb to Tank is greyed out, with no list of tanks, for a character who doesn't know how, and the
-- server refuses it on its own, taking no pipe.
T.test("irrigation_tanks_plumb_refused_without_the_knowledge", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 4, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.low = T.placeTank(self, spots[1], "lidded")
            self.high = T.placeTank(self, spots[2], "raisedLidded")
        end)
        T.knowRecipes(self, { LinkJobs.RECIPE }, false)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = 2 } })
        useMenu(self, self.low, "plumb", function(context)
            return T.findNamed(context, context, getText("ContextMenu_EnhancedIrrigation_PlumbToTank"))
        end, false)
        T.batch(function()
            T.read(self, "tanks.perform", T.at(self.low, { feature = "link", job = LinkJobs.PLUMB,
                with = Links.encode(T.at(self.high)) }), "forced")
            T.count(self, "left", { "Base.MetalPipe" })
        end)
    end,
    validate = function(self)
        T.expectRefused(self, "plumb")
        expect(not (self.menu.plumb and self.menu.plumb.submenu), "Plumb to Tank lists tanks to a character who doesn't know how")
        local forced = self.reads.forced
        expect(forced.done == false, "the server plumbed for a character who doesn't know how")
        expect(forced.links == 0, "the refused plumbing left " .. tostring(forced.links) .. " links")
        expect(counted(self, "Base.MetalPipe") == 2, "the refused plumbing took pipe: " .. counted(self, "Base.MetalPipe") .. " left")
    end,
})

-- Plumb to Tank reaches a tank Links.MAX_TILES away, taking the lengths that run needs, and no
-- farther: one tile past it is neither listed nor plumbed by the server. Plumbed, the tank moves
-- from Plumb to Tank's list to Unplumb's.
T.test("irrigation_tanks_plumb_to_tank_up_to_max_tiles", {
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
        self.lengths = Links.lengthsFor(Links.distance(T.at(self.low), T.at(self.high)))
        T.knowRecipes(self, { LinkJobs.RECIPE }, true)
        -- Iron needs no joint.
        T.give(self, "tools", { { type = "Base.PipeWrench" },
            { type = "Base.MetalPipe", count = self.lengths * Pipes.KINDS.iron.perLength } })
        local with, past = Links.encode(T.at(self.high)), Links.encode(T.at(self.far))
        useMenu(self, self.low, "one tile past", job("link", LinkJobs.PLUMB, past), false)
        T.read(self, "tanks.perform", T.at(self.low, { feature = "link", job = LinkJobs.PLUMB, with = past }), "forced")
        local low = function() return T.tankCopy(self.low) end
        T.useOption(self, low, "at the limit", job("link", LinkJobs.PLUMB, with), true)
        T.readUntil(self, "tanks.links", T.at(self.low), "links", function(reply) return #reply.links > 0 end)
        T.count(self, "left", { "Base.MetalPipe", "Base.PipeWrench" })
        T.waitFor(self, function() return #T.clientLinks(self.low) > 0 end, "this client's copy of the link")
        T.useOption(self, low, "unplumb", job("link", LinkJobs.UNPLUMB, with), false)
        T.useOption(self, low, "plumb again", job("link", LinkJobs.PLUMB, with), false)
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

-- Unplumb gives back every length Plumb to Tank took, each as worn as it went in, and this client
-- drops the link. Catches pipe kept in the walls, or every length back at one condition.
T.test("irrigation_tanks_unplumb_gives_back_the_pipe", {
    instant = true,
    run = function(self)
        -- Far enough apart for more than one length.
        local spots = T.layout(self, { { 0, 0 }, { 2 * Links.TILES_PER_LENGTH + 1, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.a = T.placeTank(self, spots[1], "lidded")
            self.b = T.placeTank(self, spots[2], "lidded")
        end)
        local iron = Pipes.KINDS.iron
        local count = Links.lengthsFor(Links.distance(T.at(self.a), T.at(self.b))) * iron.perLength
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
        local with = Links.encode(T.at(self.b))
        useMenu(self, self.a, "plumb", job("link", LinkJobs.PLUMB, with), true)
        T.waitFor(self, function() return #T.clientLinks(self.a) > 0 and #ironConditions() == 0 end,
            "this client's copy of the link, the pipe gone into it")
        T.useOption(self, function() return T.tankCopy(self.a) end, "unplumb", job("link", LinkJobs.UNPLUMB, with), true)
        T.readUntil(self, "tanks.links", T.at(self.a), "links", function(reply) return #reply.links == 0 end)
        T.waitFor(self, function() return #ironConditions() == count end, "this client's copy of the pipe given back")
        T.waitFor(self, function() return #T.clientLinks(self.a) == 0 end, "this client to drop the link")
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

-- Two tanks on one level fill toward equal, no faster than the link carries.
T.test("irrigation_tanks_link_levels_tanks_on_one_level", {
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        self.start = 300
        -- Not in a T.batch: the flow call would go out across these waits for this client's
        -- copies, and move the water before they see it.
        self.a = T.placeTank(self, spots[1], "lidded", self.start)
        self.b = T.placeTank(self, spots[2], "lidded")
        T.read(self, "tanks.flow", T.at(self.a, { to = T.at(self.b), litres = PASS_LITRES, passes = 3 }), "flow")
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
-- clean water there; a ground tank never fills a raised one.
T.test("irrigation_tanks_link_fills_downhill_never_uphill", {
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
            T.read(self, "tanks.flow", T.at(self.raised, { to = T.at(self.ground), litres = PASS_LITRES, passes = 2 }),
                "downhill")
            T.read(self, "tanks.flow", T.at(self.groundFull, { to = T.at(self.raisedEmpty), litres = PASS_LITRES }), "uphill")
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

-- A link whose tank is gone from its loaded square goes at the next pass, on this client too.
T.test("irrigation_tanks_link_dropped_when_its_tank_goes", {
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        -- Not in a T.batch: the removal would go out across these waits for this client's copies.
        self.a = T.placeTank(self, spots[1], "lidded")
        self.b = T.placeTank(self, spots[2], "lidded")
        T.batch(function()
            T.read(self, "tanks.link", T.at(self.a, { to = T.at(self.b), kind = "iron", lengths = 1 }), "linked")
            T.server(self, "tanks.remove", T.at(self.b))
            T.read(self, "tanks.pass", T.at(self.a), "after")
        end)
        T.waitFor(self, function() return #T.clientLinks(self.a) == 0 end, "this client to drop the link")
    end,
    validate = function(self)
        expect(self.reads.linked.links == 1, "the link wasn't made")
        expect(self.reads.after.links == 0, "a link whose tank is gone outlived the pass")
    end,
})

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
T.test("irrigation_tanks_links_keep_the_newest_list", {
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 3, 0 } }, { bare = true })
        if not spots then return end
        T.batch(function()
            self.a = T.placeTank(self, spots[1], "lidded")
            self.b = T.placeTank(self, spots[2], "lidded")
        end)
        T.read(self, "tanks.link", T.at(self.a, { to = T.at(self.b), kind = "iron", lengths = 1 }), "linked")
        T.waitFor(self, function() return viewedLinks(self.a) == 1 end, "this client's copy of the link")
        -- Notes each list's version as it lands, before the view takes or ignores it.
        T.step(function()
            local LinkView = EnhancedIrrigation.LinkView
            local original = LinkView.OnServerCommand
            self.landed = {}
            LinkView.OnServerCommand = function(view, command, args)
                if command == "links" then
                    self.landed[args.version] = true
                end
                original(view, command, args)
            end
            T.defer(self, function() LinkView.OnServerCommand = original end)
        end)
        T.read(self, "tanks.staleLinks", {}, "stale")
        T.waitFor(self, function() return self.landed[self.reads.stale.version] end, "the stale list of links")
        T.step(function() self.kept = viewedLinks(self.a) end)
    end,
    validate = function(self)
        expect(self.reads.linked.links == 1, "the link wasn't made")
        expect(self.kept == 1, "this client took a list of links older than the one it had")
    end,
})
