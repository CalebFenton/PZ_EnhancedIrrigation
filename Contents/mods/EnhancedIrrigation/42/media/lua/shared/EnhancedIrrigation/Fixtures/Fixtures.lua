-- Plumbed fixtures: the sinks, baths, showers, toilets and washers the game marks waterPiped, each
-- plumbed to one tank. A plumbed fixture holds its own water in a FluidContainer, its buffer, the
-- size of vanilla's reserve for it, which its tank refills. Vanilla's drink, fill, wash and washer
-- read the buffer, and the engine keeps its taint (docs/research.md, "Fixture buffers, run in
-- game"). While the town's water runs to it, that wins and the buffer waits empty. The pipe is a
-- link of the role `fixture`.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
local Squares = require "cf_commonlib/Squares"

EnhancedIrrigation = EnhancedIrrigation or {}
local Fixtures = {}
EnhancedIrrigation.Fixtures = Fixtures

local Tanks = EnhancedIrrigation.Tanks

-- Litres a buffer holds when its tile names no reserve: washers and showers have none in vanilla.
local DEFAULT_LITRES = 20
-- A tile's waterAmount from which vanilla treats its water as endless (IsoObject.isWaterInfinite).
local INFINITE_LITRES = 9999
-- Litres an hour a tank refills a buffer: a sink's reserve every ten minutes, so a bath refills in
-- under an hour and a running washer, which draws a litre a minute, never runs dry while the tank
-- holds out.
Fixtures.REFILL_RATE = 120

--- Whether `isoObject` is a fixture the game pipes water to: a waterPiped tile that isn't a tank.
function Fixtures.isFixture(isoObject)
    local sprite = isoObject and isoObject:getSprite()
    local props = sprite and sprite:getProperties()
    return props ~= nil and props:has(IsoFlagType.waterPiped) and not Tanks.isTank(isoObject)
end

--- The fixture on `square`, or nil. Takes a nil square.
function Fixtures.fixtureOn(square)
    return Squares.findObjectOn(square, Fixtures.isFixture)
end

--- The fixture on the loaded square x, y, z, or nil.
function Fixtures.fixtureAt(x, y, z)
    return Fixtures.fixtureOn(getCell():getGridSquare(x, y, z))
end

-- The reads below mirror IsoObject's getReserveWaterMax, getReserveWaterAmount and isWaterInfinite,
-- which are private, so Lua can't call them. The public getFluidCapacity and getFluidAmount reach
-- them only for a fixture without a buffer, and read the buffer first once it has one.

local function tileNumber(isoObject, name)
    local value = isoObject:getSprite():getProperties():get(name)
    return value and tonumber(value) or nil
end

-- What vanilla wrote into `fixture`'s modData under `key` (IsoObject.setReserveWaterAmount), or nil.
local function recorded(fixture, key)
    return fixture:hasModData() and fixture:getModData()[key] or nil
end

--- The litres `fixture`'s buffer holds: vanilla's reserve for it (IsoObject.getReserveWaterMax), what
--- vanilla recorded on its first draw before what its tile says.
function Fixtures.capacityOf(fixture)
    return recorded(fixture, "waterMaxAmount") or tileNumber(fixture, "waterMaxAmount")
        or recorded(fixture, "waterAmount") or tileNumber(fixture, "waterAmount") or DEFAULT_LITRES
end

--- The litres left in `fixture`'s vanilla reserve, the water its pipes hold after the shutoff
--- (IsoObject.getReserveWaterAmount): none on a square the map cuts off from the water, else
--- modData.waterAmount once vanilla has drawn on it, else its tile's.
function Fixtures.reserveOf(fixture)
    local square = fixture:getSquare()
    if square ~= nil and square:isNoWater() then
        return 0
    end
    return recorded(fixture, "waterAmount") or tileNumber(fixture, "waterAmount") or 0
end

--- Whether endless water runs to `fixture`, as vanilla decides (IsoObject.isWaterInfinite): a tile
--- that says so, or the town's water, before the shutoff, in a room, on a square the map doesn't cut
--- off, to a fixture not drawing on vanilla's rooftop plumbing and never moved, since one set down by
--- a player is flagged canBeWaterPiped and draws none.
function Fixtures.townWaterRuns(fixture)
    local tile = tileNumber(fixture, "waterAmount")
    if tile and tile >= INFINITE_LITRES then
        return true
    end
    local square = fixture:getSquare()
    return square ~= nil and square:getRoom() ~= nil
        and fixture:getSprite():getProperties():has(IsoFlagType.waterPiped)
        and not fixture:getUsesExternalWaterSource() and not square:isNoWater()
        and getGameTime():getWorldAgeDaysSinceBegin() < getSandboxOptions():getWaterShutModifier()
        and recorded(fixture, "canBeWaterPiped") ~= true
end

--- Whether vanilla's Plumb makes this mod's link, keeping the tank's taint (the PlumbingKeepsTaint
--- sandbox option), rather than vanilla's rooftop plumbing, which serves every drop clean.
function Fixtures.plumbingKeepsTaint()
    return SandboxVars.EnhancedIrrigation.PlumbingKeepsTaint == true
end

return Fixtures
