-- What the mod counts as a tank, and how high its water stands. A tank is a fixed store of water
-- the game already has (a rain collector or barrel, an amphora, a well) or a barrel on a Tank Stand.
-- Its level is the floor it stands on, plus one on a stand: water runs out of a tap, a hole or a
-- fixture only from a level at least one above it, and into another tank only from a level no lower
-- than that tank's.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Tanks = {}
EnhancedIrrigation.Tanks = Tanks

-- Each tank's entity script name; `raised` for the barrels on a Tank Stand.
Tanks.ENTITIES = {
    RainCollector = {},
    RainCollector_Tarp = {},
    RainCollectorRound = {},
    RainCollectorRoundClosed = {},
    RainCollectorRound_Tarp = {},
    RainCollectorRound_TarpClosed = {},
    Amphora = {},
    AmphoraClosed = {},
    Well = {},
    EnhancedIrrigation_RaisedBarrel = { raised = true },
    EnhancedIrrigation_RaisedBarrelClosed = { raised = true },
    EnhancedIrrigation_RaisedBarrel_Tarp = { raised = true },
    EnhancedIrrigation_RaisedBarrel_TarpClosed = { raised = true },
}

local function specOf(isoObject)
    local name = EnhancedIrrigation.entityName(isoObject)
    return name and Tanks.ENTITIES[name]
end

--- Whether `isoObject` is a tank: one of the entities above, with its water container.
function Tanks.isTank(isoObject)
    return specOf(isoObject) ~= nil and isoObject:getFluidContainer() ~= nil
end

--- The level `tank`'s water stands at: its floor, plus one on a Tank Stand.
function Tanks.levelOf(tank)
    return tank:getZ() + (specOf(tank).raised and 1 or 0)
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

--- Whether water from `tank` comes out of an outlet (a tap, a hole, a fixture) on floor `z`: its
--- level stands at least a storey above.
function Tanks.hasPressureFor(tank, z)
    return Tanks.levelOf(tank) >= z + 1
end

function Tanks.litres(tank)
    return tank:getFluidContainer():getAmount()
end

--- Takes up to `litres` out of `tank` and returns how many it took; the clients learn of it with
--- the next sync (Tanks.sync). Authority only.
function Tanks.take(tank, litres)
    local container = tank:getFluidContainer()
    local taken = math.min(litres, container:getAmount())
    if taken > 0 then
        container:removeFluid(taken, false)
    end
    return taken
end

--- Sends `tank`'s water to the clients, which also fires OnWaterAmountChange. Authority only.
function Tanks.sync(tank)
    tank:sync()
end

return Tanks
