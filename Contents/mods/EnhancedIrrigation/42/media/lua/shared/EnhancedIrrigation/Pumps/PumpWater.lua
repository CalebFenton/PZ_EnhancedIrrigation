-- Where a pump's water comes from and where it goes: the well, tank, trough or river it draws
-- from, what its outlet takes, and, on the authority, moving the water.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pumps/Pumps"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpWater = {}
EnhancedIrrigation.PumpWater = PumpWater

local Tanks, Lines, Pumps = EnhancedIrrigation.Tanks, EnhancedIrrigation.Lines, EnhancedIrrigation.Pumps
local Links = EnhancedIrrigation.Links

-- Tiles a pump's Rubber Hose reaches across the ground to natural water.
PumpWater.HOSE_REACH = 3

-- The tiles of vanilla's wells: the stone well and the forest's hand pump. Each is endless clean
-- water whatever its own container holds, which vanilla never draws (IsoObject.isWaterInfinite).
PumpWater.WELL_SPRITES = {
    camping_01_16 = true, camping_01_64 = true, camping_01_65 = true, camping_01_66 = true, camping_01_67 = true,
}

-- Sources --------------------------------------------------------------------------------------------

local function isWell(object)
    local sprite = object:getSprite()
    return sprite ~= nil and PumpWater.WELL_SPRITES[sprite:getName()] == true
end

-- The trough `object` is part of, its master, when it holds water rather than feed: a trough
-- holding feed has no FluidContainer (IsoFeedingTrough.checkContainer).
local function troughOf(object)
    local master = instanceof(object, "IsoFeedingTrough") and object:getMasterTrough()
    return master and master:getFluidContainer() and master or nil
end

local function isWater(square)
    return square ~= nil and square:getProperties():has(IsoFlagType.water)
end

-- The nearest square of natural water the hose of a pump at `here` reaches, on the ground only, as
-- { x, y, z }, or nil.
local function nearestWater(here)
    if here.z ~= 0 then
        return nil
    end
    local best, bestDistance = nil, nil
    local reach = PumpWater.HOSE_REACH
    for dx = -reach, reach do
        for dy = -reach, reach do
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= reach and (not bestDistance or distance < bestDistance)
                    and isWater(getCell():getGridSquare(here.x + dx, here.y + dy, 0)) then
                best, bestDistance = { x = here.x + dx, y = here.y + dy, z = 0 }, distance
            end
        end
    end
    return best
end

--- Where the hose of the pump at `here` drinks: `intake` ({ x, y }, as the record keeps it) while
--- that square is natural water, or isn't loaded to say, as a river doesn't move; else the nearest
--- water in reach; or nil.
function PumpWater.intakeFor(here, intake)
    if intake then
        local square = getCell():getGridSquare(intake.x, intake.y, 0)
        if not square or isWater(square) then
            return { x = intake.x, y = intake.y, z = 0 }
        end
    end
    return nearestWater(here)
end

--- The source the pump `pump` draws from, as this side sees it: the first of a well beside it; the
--- fullest tank or water trough beside it holding water, but not the tank its outlet fills
--- (`outletEnd`, { x, y, z }, if any); the natural water its hose reaches (PumpWater.intakeFor with
--- the `intake` its record keeps); or a tank or trough beside it that is dry. Beside is the eight
--- squares around it on its floor. Returns { kind = "well" | "tank" | "trough" | "river", object
--- (nil for an unloaded river), at, infinite, litres, dry }, or nil when it has none.
function PumpWater.sourceOf(pump, intake, outletEnd)
    local here = EnhancedIrrigation.squareOf(pump)
    local finite, dry = nil, nil
    for dx = -1, 1 do
        for dy = -1, 1 do
            local square = getCell():getGridSquare(here.x + dx, here.y + dy, here.z)
            local objects = square and square:getObjects()
            for i = 0, (objects and objects:size() or 0) - 1 do
                local object = objects:get(i)
                local at = EnhancedIrrigation.squareOf(object)
                if isWell(object) then
                    return { kind = "well", object = object, at = at, infinite = true }
                end
                local trough = troughOf(object)
                local tank = Tanks.isTank(object) and object or nil
                local holder = tank or trough
                if holder and not (tank and outletEnd and EnhancedIrrigation.sameSquare(at, outletEnd)) then
                    local litres = holder:getFluidContainer():getAmount()
                    local entry = { kind = tank and "tank" or "trough", object = holder,
                        at = EnhancedIrrigation.squareOf(holder), litres = litres }
                    if litres >= Pumps.LEAST_LITRES then
                        if not finite or litres > finite.litres then
                            finite = entry
                        end
                    elseif not dry then
                        entry.dry = true
                        dry = entry
                    end
                end
            end
        end
    end
    if finite then
        return finite
    end
    local river = PumpWater.intakeFor(here, intake)
    if river then
        local square = getCell():getGridSquare(river.x, river.y, river.z)
        return { kind = "river", object = square and square:getWaterObject(), at = river, infinite = true }
    end
    return dry
end

-- Delivery -------------------------------------------------------------------------------------------

--- What a pump lifting by `spec` (a row of Pumps.ENTITIES or PARTS) would lift into, as this side
--- sees it: its outlet's tank, while that stands within its lift and has room, or its outlet's line
--- tile, while its line has no tap; and the source it draws from (PumpWater.sourceOf, with the
--- hose's `intake`). Returns the tank or line tile and the source, or nil and the Tooltip key of
--- why it lifts nothing.
function PumpWater.deliveryOf(pump, spec, intake)
    local b = Links.farEnd(EnhancedIrrigation.squareOf(pump), "pump")
    if not b then
        return nil, "Tooltip_EnhancedIrrigation_NoOutlet"
    end
    local into = Tanks.tankAt(b.x, b.y, b.z) or Lines.lineAt(b.x, b.y, b.z)
    if not into then
        return nil, "Tooltip_EnhancedIrrigation_OutletGone"
    end
    -- A barrel set on a stand at the far end since it was plumbed may stand out of its reach.
    if not Pumps.lifts(spec, Tanks.levelOf(into), pump:getZ()) then
        return nil, Pumps.LIFT_KEYS[spec.lift]
    end
    if Lines.isLine(into) then
        -- A wall knocked down since may have joined it to a tapped line. This pump feeds it too,
        -- so only a tap is another feed.
        if Lines.feedOf(Lines.component(b.x, b.y, b.z)) == "tap" then
            return nil, Lines.FEED_TAKEN.tap
        end
    elseif into:getFluidContainer():getFreeCapacity() < Pumps.LEAST_LITRES then
        return nil, "Tooltip_EnhancedIrrigation_OutletFull"
    end
    local source = PumpWater.sourceOf(pump, intake, b)
    if not source or source.dry then
        return nil, "Tooltip_EnhancedIrrigation_NoWaterToDraw"
    end
    return into, source
end

--- What the hand pump `pump` would lift into, as this side sees it (PumpWater.deliveryOf), unless
--- its body or seal is worn out. Returns the tank or line tile and the source, or nil and the
--- Tooltip key of why it lifts nothing.
function PumpWater.handDeliveryOf(pump)
    local spec, summary = Pumps.specOf(pump), Pumps.currentSummary(pump)
    if not (spec and spec.kind == "hand" and summary) then
        return nil, EnhancedIrrigation.Jobs.UNKNOWN
    end
    if summary.wornOut then
        return nil, "Tooltip_EnhancedIrrigation_PumpWornOut"
    end
    if summary.sealWorn then
        return nil, "Tooltip_EnhancedIrrigation_SealWornOut"
    end
    return PumpWater.deliveryOf(pump, spec, summary.intake)
end

-- Moving water ---------------------------------------------------------------------------------------

--- Moves `litres` from `source` (PumpWater.sourceOf) into `fluid` (a FluidContainer), or into a
--- garden line when `fluid` is nil, and returns the litres moved. A well's or river's water comes
--- from its tile, which is endless (vanilla's own draw, IsoObject.transferFluidTo), never from a
--- well's own container, which vanilla never draws either; a tank or trough gives its mixture,
--- taint and all, and is sent to the clients. A river whose square isn't loaded is still water,
--- always tainted. A line's plants take no notice of taint (server/Farming), so a line's water is
--- only counted from an endless source, and taken out of a tank or trough. Authority only.
function PumpWater.draw(source, fluid, litres)
    if not fluid then
        if source.infinite then
            return litres
        end
        return Tanks.take(source.object, litres)
    end
    if not source.object then
        fluid:addFluid(FluidType.TaintedWater, litres)
        return litres
    end
    local moved = source.object:transferFluidTo(fluid, litres)
    if not source.infinite then
        source.object:sync()
    end
    return moved
end

--- Lifts up to `litres` from `source` into the tank `into`, as far as its room and a finite
--- source's water go, and returns the litres moved. Authority only.
function PumpWater.fillTank(source, into, litres)
    local fluid = into:getFluidContainer()
    litres = math.min(litres, fluid:getFreeCapacity())
    if not source.infinite then
        litres = math.min(litres, source.litres)
    end
    if litres <= 0 then
        return 0
    end
    local moved = PumpWater.draw(source, fluid, litres)
    into:sync()
    return moved
end

return PumpWater
