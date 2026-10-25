require "PZHarness/ServerHandlers"
require "PZHarness/ServerFixtures"

-- Development only, not published. Test handlers for the barrel moveables the authority gives,
-- finds and takes. Only registers handlers, so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local EI = EnhancedIrrigation

-- Gives the character the barrel moveable of the vanilla tile `args.barrel` as the mod's Take
-- Barrel Down makes it, holding `args.litres` of water: a barrel vanilla would never let the
-- character pick up.
handler("stands.giveBarrel", function(player, args)
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
    return EI.Stands.barrelSpec(item) ~= nil
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
handler("stands.barrels", function(player, args)
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
handler("stands.dropBarrels", function(player)
    local carried = player:getInventory():getAllEvalRecurse(isBarrelItem)
    for i = carried:size() - 1, 0, -1 do
        EI.Materials.takeItem(player, carried:get(i))
    end
    return {}
end)
