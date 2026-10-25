-- What the mod counts as a tank, and how high its water stands. A tank is a fixed store of water
-- the game already has (a rain collector or barrel, an amphora) or a barrel on a Tank Stand. Its
-- level is the floor it stands on, plus one on a stand.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Tanks = {}
EnhancedIrrigation.Tanks = Tanks

-- Each tank's entity script name; `raised` for the barrels on a Tank Stand, which Stands adds. A
-- well isn't one: its water stands underground, below any line or tank it could feed by gravity, so
-- only a pump (docs/design.md, Pumps) draws from it.
Tanks.ENTITIES = {
    RainCollector = {},
    RainCollector_Tarp = {},
    RainCollectorRound = {},
    RainCollectorRoundClosed = {},
    RainCollectorRound_Tarp = {},
    RainCollectorRound_TarpClosed = {},
    Amphora = {},
    AmphoraClosed = {},
}

--- Whether `isoObject` is a tank: one of the entities above, with its water container.
function Tanks.isTank(isoObject)
    return EnhancedIrrigation.entitySpec(isoObject, Tanks.ENTITIES) ~= nil and isoObject:getFluidContainer() ~= nil
end

--- The level `object`'s water stands at: its floor, plus one for a tank on a stand. Anything else
--- that holds or carries water, a treatment unit or a line tile, stands on its floor.
function Tanks.levelOf(object)
    local spec = EnhancedIrrigation.entitySpec(object, Tanks.ENTITIES)
    return object:getZ() + (spec and spec.raised and 1 or 0)
end

--- The tank on `square`, or nil. Takes a nil square.
function Tanks.tankOn(square)
    return EnhancedIrrigation.findObjectOn(square, Tanks.isTank)
end

--- The tank on the loaded square x, y, z, or nil when there is none or the square isn't loaded.
function Tanks.tankAt(x, y, z)
    return Tanks.tankOn(getCell():getGridSquare(x, y, z))
end

--- The tanks a pipe at x, y, z can reach the way vanilla's plumbing reaches: on its square or one
--- of the eight around it, on its floor or the one above. Loaded squares only.
function Tanks.tanksReaching(x, y, z)
    local found = {}
    for dz = 0, 1 do
        for dx = -1, 1 do
            for dy = -1, 1 do
                local tank = Tanks.tankAt(x + dx, y + dy, z + dz)
                if tank then
                    table.insert(found, tank)
                end
            end
        end
    end
    return found
end

--- Whether water from `tank` comes out of an outlet (a tap, a hole, a fixture) on floor `z`.
function Tanks.hasPressureFor(tank, z)
    return Tanks.levelOf(tank) >= z + 1
end

--- The tanks reaching an outlet at x, y, z (Tanks.tanksReaching) that stand high enough to push
--- water out of it.
function Tanks.pushingAt(x, y, z)
    local found = {}
    for _, tank in ipairs(Tanks.tanksReaching(x, y, z)) do
        if Tanks.hasPressureFor(tank, z) then
            table.insert(found, tank)
        end
    end
    return found
end

function Tanks.litres(tank)
    return tank:getFluidContainer():getAmount()
end

--- Takes up to `litres` out of `tank`, sends what it holds then to the clients (which also fires
--- OnWaterAmountChange) and returns how many it took. Authority only.
function Tanks.take(tank, litres)
    local container = tank:getFluidContainer()
    local taken = math.min(litres, container:getAmount())
    if taken > 0 then
        container:removeFluid(taken, false)
        tank:sync()
    end
    return taken
end

return Tanks
