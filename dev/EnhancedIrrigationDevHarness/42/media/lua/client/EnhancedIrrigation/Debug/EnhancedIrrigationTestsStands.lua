require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Stands/StandJobs"
require "EnhancedIrrigation/UI/StandMenu"

-- The Tank Stand: building it from the build menu, setting a barrel on it, the raised barrel through
-- the vanilla lid, and taking the barrel down. Each job goes through the build menu or the
-- right-click menu and its timed action; what the menu greys out, the server is also asked to do
-- directly (tanks.perform), to show it refuses on its own.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
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
    T.waitFor(self, function() return T.player():getInventory():getFirstTypeRecurse(BARREL_HELD) ~= nil end,
        "the barrel vanilla's pickup gives")
end

-- This client's level of the tank on the handle's square, or nil without one.
local function clientLevel(handle)
    local tank = Tanks.tankOn(getSquare(handle.x, handle.y, handle.z))
    return tank and Tanks.levelOf(tank) or nil
end

-- The build menu builds a Tank Stand from its recipe on a bare square. Catches a recipe or entity
-- the build menu can't place.
T.test("irrigation_stands_stand_built_from_build_menu", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.stand = T.buildFromMenu(self, "Base." .. Stands.STAND_ENTITY, spots[1], Sprites.TANK_STAND)
        if not self.stand then return end
        T.read(self, "tanks.read", T.at(self.stand), "built")
    end,
    validate = function(self)
        local built = self.reads.built
        expect(built.isStand, "the build menu built " .. tostring(built.entity) .. ", not a Tank Stand")
        expect(built.sprite == Sprites.TANK_STAND, "the built stand is drawn as " .. tostring(built.sprite))
    end,
})

-- Set Barrel on Stand turns an empty barrel carried into a tank a level up, on both sides. Catches
-- a barrel kept in hand, or a raised barrel at ground level.
T.test("irrigation_stands_barrel_set_on_stand_from_menu", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.stand = T.placeTank(self, spots[1], "stand")
        pickUpVanillaBarrel(self, spots[2])
        T.useMenu(self, self.stand, "set barrel", T.job("stand", StandJobs.SET_BARREL), true)
        T.waitFor(self, function() return T.copyOf(self.stand, Sprites.RAISED_BARREL_CLOSED) ~= nil end,
            "this client's copy of the barrel on the stand")
        T.batch(function()
            T.read(self, "tanks.read", T.at(self.stand), "raised")
            T.count(self, "left", { BARREL_HELD })
        end)
        T.step(function() self.clientLevel = clientLevel(self.stand) end)
    end,
    validate = function(self)
        T.expectOffered(self, "set barrel")
        local raised, z = self.reads.raised, self.stand.z
        expect(raised.isRaised and raised.isTank, "the barrel on the stand isn't a raised tank")
        expect(raised.level == z + 1, "the raised barrel's level is " .. tostring(raised.level) .. ", not " .. (z + 1))
        expectNear("the raised barrel's water", raised.litres, 0, T.LITRES)
        expect(T.counted(self, BARREL_HELD) == 0, "setting the barrel on the stand left " .. T.counted(self, BARREL_HELD)
            .. " barrels carried")
        expect(self.clientLevel == z + 1, "this client sees the raised barrel at level " .. tostring(self.clientLevel))
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
        T.useMenu(self, self.stand, "no barrel", T.job("stand", StandJobs.SET_BARREL), false)
        -- A barrel vanilla would never let the character pick up: one holding water.
        T.server(self, "stands.giveBarrel", { barrel = BARREL, litres = 20 })
        T.useOption(self, function() return T.copyOf(self.stand) end, "full barrel", T.job("stand", StandJobs.SET_BARREL), false)
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

-- Vanilla's Open Lid swaps the raised barrel's object, and it stays a raised tank with its water.
-- Catches the lid turning it into vanilla's ground barrel.
T.test("irrigation_stands_raised_barrel_stays_a_raised_tank_through_the_lid", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 } }, { bare = true })
        if not spots then return end
        self.litres = 30
        self.tank = T.placeTank(self, spots[1], "raisedLidded", self.litres)
        T.step(function() self.levelBefore = clientLevel(self.tank) end)
        T.useMenu(self, self.tank, "open lid", function(context)
            return T.findNamed(context, context, getText("ContextMenu_OpenLid"))
        end, true)
        T.waitFor(self, function() return T.copyOf(self.tank, Sprites.RAISED_BARREL) ~= nil end,
            "this client's copy of the opened barrel")
        T.read(self, "tanks.read", T.at(self.tank), "opened")
        T.step(function() self.levelAfter = clientLevel(self.tank) end)
    end,
    validate = function(self)
        local z = self.tank.z
        expect(self.levelBefore == z + 1, "this client sees the raised barrel at level " .. tostring(self.levelBefore))
        T.expectOffered(self, "open lid")
        local opened = self.reads.opened
        expect(opened.isRaised and opened.isTank, "opening the lid made " .. tostring(opened.entity)
            .. ", not a raised tank")
        expect(opened.level == z + 1, "the opened barrel's level is " .. tostring(opened.level))
        -- Open, it may catch a little rain meanwhile.
        expectNear("the opened barrel's water", opened.litres, self.litres, 1)
        expect(self.levelAfter == z + 1, "this client sees the opened barrel at level " .. tostring(self.levelAfter))
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
        T.useMenu(self, self.tank, "take down", T.job("stand", StandJobs.TAKE_DOWN), false)
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
        expectNear("the refused barrel's water", forced.litres, self.litres, T.LITRES)
        expect(T.counted(self, BARREL_HELD) == 0, "a refused Take Barrel Down gave " .. T.counted(self, BARREL_HELD) .. " barrels")
    end,
})

-- Take Barrel Down leaves the stand and gives the very item vanilla's own pickup gives. Catches a
-- barrel item vanilla wouldn't recognise as its own.
T.test("irrigation_stands_take_down_gives_vanillas_barrel_and_the_stand", {
    instant = true,
    run = function(self)
        local spots = T.layout(self, { { 0, 0 }, { 2, 0 } }, { bare = true })
        if not spots then return end
        self.tank = T.placeTank(self, spots[1], "raisedLidded")
        -- Vanilla's own item for the same barrel, which the one taken down should match. Then it
        -- goes, as two barrels are more than a character carries.
        pickUpVanillaBarrel(self, spots[2])
        T.batch(function()
            T.read(self, "stands.barrels", {}, "vanilla")
            T.server(self, "stands.dropBarrels", {})
        end)
        T.waitFor(self, function() return T.player():getInventory():getFirstTypeRecurse(BARREL_HELD) == nil end,
            "this client to let go of vanilla's barrel")
        T.useMenu(self, self.tank, "take down", T.job("stand", StandJobs.TAKE_DOWN), true)
        T.waitFor(self, function() return T.copyOf(self.tank, Sprites.TANK_STAND) ~= nil end, "this client's copy of the stand")
        T.batch(function()
            T.read(self, "tanks.read", T.at(self.tank), "stand")
            T.read(self, "stands.barrels", { dropped = true }, "after")
        end)
    end,
    validate = function(self)
        T.expectOffered(self, "take down")
        local stand = self.reads.stand
        expect(stand.isStand and stand.sprite == Sprites.TANK_STAND, "taking the barrel down left " .. tostring(stand.entity))
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
        expectNear("a carried barrel's weight", barrel.weight, vanilla[1].weight, T.LITRES)
        expectNear("a carried barrel's capacity", barrel.capacity, vanilla[1].capacity, T.LITRES)
        expectNear("a carried barrel's water", barrel.litres, 0, T.LITRES)
    end,
})
