require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Stands/StandJobs"
require "EnhancedIrrigation/UI/StandMenu"

-- The Tank Stand: building it from the build menu, setting a barrel on it, the raised barrel through
-- the vanilla lid, and taking the barrel down. Each job goes through the build menu or the
-- right-click menu and its timed action; what the menu greys out, the server is also asked to do
-- directly (T.job), to show it refuses on its own.

local T = EnhancedIrrigationTest
local expect, expectNear, expectEqual = T.expect, T.expectNear, T.expectEqual
local Sprites, Stands, StandJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Stands, EnhancedIrrigation.StandJobs
local Tanks = EnhancedIrrigation.Tanks

-- Vanilla's lidded rain barrel, which no rain fills meanwhile, so an empty one stays empty and a
-- filled one holds what the test put in.
local BARREL = T.TANKS.lidded.sprite
-- What a player is given to place it, and the type the item then has in hand (Stands.BARRELS).
local BARREL_ITEM = "Moveables." .. BARREL
local BARREL_HELD = "Base." .. BARREL

-- Queues a vanilla barrel moveable at `handle` put down and picked up again as a player does, so
-- the character carries the item vanilla's pickup gives.
local function pickUpVanillaBarrel(self, handle)
    local placed = T.placeAsPlayer(self, handle.square, BARREL_ITEM, BARREL)
    T.pickUpAsPlayer(self, placed, BARREL)
    T.waitForCarried(self, BARREL_HELD, "the barrel vanilla's pickup gives")
end

-- This client's level of the tank on the handle's square, or nil without one.
local function clientLevel(handle)
    local tank = Tanks.tankOn(getSquare(handle.x, handle.y, handle.z))
    return tank and Tanks.levelOf(tank) or nil
end

-- The build menu builds a Tank Stand on a bare square. Set Barrel on Stand turns the empty barrel
-- vanilla's pickup gave into a tank a level up, on both sides; Take Barrel Down leaves the stand
-- and gives back the very item vanilla's pickup gave. Catches a stand the build menu can't place, a
-- barrel kept in hand, a raised barrel at ground level, or a barrel item vanilla wouldn't recognise
-- as its own.
T.test("irrigation_stands_built_and_a_barrel_set_on_it_and_taken_down", {
    instant = true,
    run = function(self)
        self.stand = T.buildTile(self, "Base." .. Stands.STAND_ENTITY, Sprites.TANK_STAND)
        if not self.stand then return end
        T.read(self, "tanks.read", T.at(self.stand), "built")
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        pickUpVanillaBarrel(self, spots[1])
        T.read(self, "stands.barrels", {}, "vanilla")
        T.useMenu(self, self.stand, "set barrel", T.findJob("stand", StandJobs.SET_BARREL), true)
        T.waitFor(self, function() return T.copyOf(self.stand, Sprites.RAISED_BARREL_CLOSED) ~= nil end,
            "this client's copy of the barrel on the stand")
        T.batch(function()
            T.read(self, "tanks.read", T.at(self.stand), "raised")
            T.count(self, "left", { BARREL_HELD })
        end)
        T.step(function() self.clientLevel = clientLevel(self.stand) end)
        T.useOption(self, function() return T.copyOf(self.stand, Sprites.RAISED_BARREL_CLOSED) end, "take down",
            T.findJob("stand", StandJobs.TAKE_DOWN), true)
        T.waitFor(self, function() return T.copyOf(self.stand, Sprites.TANK_STAND) ~= nil end,
            "this client's copy of the stand again")
        T.batch(function()
            T.read(self, "tanks.read", T.at(self.stand), "stand")
            -- A barrel too heavy to carry lands at the character's feet (Actions.addOrDropItem).
            T.read(self, "stands.barrels", { dropped = true }, "after")
        end)
    end,
    validate = function(self)
        expect(self.reads.built.isStand, "the build menu built " .. tostring(self.reads.built.entity) .. ", not a Tank Stand")
        T.expectOffered(self, "set barrel")
        local raised, z = self.reads.raised, self.stand.z
        expect(raised.isRaised and raised.isTank, "the barrel on the stand isn't a raised tank")
        expectEqual("the raised barrel's level", raised.level, z + 1)
        expectNear("the raised barrel's water", raised.litres, 0, T.LITRES)
        expectEqual("barrels carried after setting the barrel on the stand", T.counted(self, BARREL_HELD), 0)
        expectEqual("the raised barrel's level on this client", self.clientLevel, z + 1)
        T.expectOffered(self, "take down")
        expect(self.reads.stand.isStand, "taking the barrel down left " .. tostring(self.reads.stand.entity))
        local vanilla, after = self.reads.vanilla.barrels, self.reads.after.barrels
        if not (expectEqual("barrels vanilla's pickup gave", #vanilla, 1)
                and expectEqual("barrels Take Barrel Down gave", #after, 1)) then
            return
        end
        for _, key in ipairs({ "fullType", "worldSprite", "hasFluid", "containerName" }) do
            expectEqual("a carried barrel's " .. key .. " against vanilla's", after[1][key], vanilla[1][key])
        end
        expectNear("a carried barrel's water", after[1].litres, 0, T.LITRES)
    end,
})

-- Set Barrel on Stand is greyed out, saying why, without a barrel and for a barrel holding water,
-- and the server refuses the full one on its own. Catches a full barrel lifted.
T.test("irrigation_stands_set_barrel_refused_without_an_empty_barrel", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.stand = T.placeTank(self, spots[1], "stand")
        T.useMenu(self, self.stand, "no barrel", T.findJob("stand", StandJobs.SET_BARREL), false)
        -- A barrel vanilla would never let the character pick up: one holding water.
        T.server(self, "stands.giveBarrel", { barrel = BARREL, litres = 20 })
        T.useOption(self, function() return T.copyOf(self.stand) end, "full barrel", T.findJob("stand", StandJobs.SET_BARREL), false)
        -- The barrel given, by the id this client has of it once given.
        T.step(function()
            T.job(self, "stand", StandJobs.SET_BARREL, self.stand, { id = self.items["stands.giveBarrel"][1]:getID() },
                "forced", { reads = T.stateReads("tanks.read", self.stand) })
        end)
    end,
    validate = function(self)
        T.expectOptionRefused(self, "no barrel", "Tooltip_EnhancedIrrigation_NoBarrel")
        T.expectOptionRefused(self, "full barrel", "Tooltip_EnhancedIrrigation_BarrelNotEmpty")
        local forced = self.reads.forced
        expectEqual("the server's refusal to set a barrel holding water on the stand", forced.reason,
            "Tooltip_EnhancedIrrigation_BarrelNotEmpty")
        expect(forced.ok == false, "the server set a barrel holding water on the stand")
        expect(forced.after.state.isStand, "the stand is gone after a refused Set Barrel on Stand")
    end,
})

-- Vanilla's Open Lid swaps the raised barrel's object, and it stays a raised tank with its water.
-- Indoors, where no rain falls into it once open. Catches the lid turning it into vanilla's ground
-- barrel, or its water lost in the swap.
T.test("irrigation_stands_raised_barrel_stays_a_raised_tank_through_the_lid", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true, indoors = true })
        if not spots then return end
        self.litres = 30
        self.tank = T.placeTank(self, spots[1], "raisedLidded", self.litres)
        T.step(function() self.levelBefore = clientLevel(self.tank) end)
        T.useMenu(self, self.tank, "open lid", function(context)
            return T.findNamed(context, getText("ContextMenu_OpenLid"))
        end, true)
        T.waitFor(self, function() return T.copyOf(self.tank, Sprites.RAISED_BARREL) ~= nil end,
            "this client's copy of the opened barrel")
        T.read(self, "tanks.read", T.at(self.tank), "opened")
        T.step(function() self.levelAfter = clientLevel(self.tank) end)
    end,
    validate = function(self)
        local z = self.tank.z
        expectEqual("the raised barrel's level on this client", self.levelBefore, z + 1)
        T.expectOffered(self, "open lid")
        local opened = self.reads.opened
        expect(opened.isRaised and opened.isTank, "opening the lid made " .. tostring(opened.entity)
            .. ", not a raised tank")
        expectEqual("the opened barrel's level", opened.level, z + 1)
        expectNear("the opened barrel's water", opened.litres, self.litres, T.LITRES)
        expectEqual("the opened barrel's level on this client", self.levelAfter, z + 1)
    end,
})

-- Take Barrel Down is greyed out for a barrel holding water, and the server refuses it on its own.
-- Catches a full barrel taken down, its water lost.
T.test("irrigation_stands_take_down_refused_while_holding_water", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.litres = 5
        self.tank = T.placeTank(self, spots[1], "raisedLidded", self.litres)
        T.useMenu(self, self.tank, "take down", T.findJob("stand", StandJobs.TAKE_DOWN), false)
        T.batch(function()
            T.job(self, "stand", StandJobs.TAKE_DOWN, self.tank, nil, "forced", { reads = T.stateReads("tanks.read", self.tank) })
            T.count(self, "left", { BARREL_HELD })
        end)
    end,
    validate = function(self)
        T.expectOptionRefused(self, "take down", "Tooltip_EnhancedIrrigation_EmptyBarrelFirst")
        local forced = self.reads.forced
        expectEqual("the server's refusal to take down a barrel holding water", forced.reason,
            "Tooltip_EnhancedIrrigation_EmptyBarrelFirst")
        expect(forced.ok == false, "the server took down a barrel holding water")
        expect(forced.after.state.isRaised, "the raised barrel is gone after a refused Take Barrel Down")
        expectNear("the refused barrel's water", forced.after.state.litres, self.litres, T.LITRES)
        expectEqual("barrels a refused Take Barrel Down gave", T.counted(self, BARREL_HELD), 0)
    end,
})
