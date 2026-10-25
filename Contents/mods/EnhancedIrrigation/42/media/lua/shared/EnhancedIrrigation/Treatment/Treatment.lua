-- Treatment units: placed things that make raw water safe (docs/design.md, Making water safe). A
-- unit holds raw water waiting to be treated, its head, as litres in the authority's record,
-- tainted or not as a whole, as vanilla's water is; treats it at its own rate; and puts the result
-- in its basin, the unit's own FluidContainer, from which vanilla's menus drink, fill and empty.
-- The basin is input-locked, so water reaches it only through the unit. What a kind does is in its
-- rows here, in the record's KINDS and in the menu's words, not spread through the code. A boiler
-- is also a vanilla fireplace, which the game's own fire menus fuel, light and put out.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/GlobalObjects"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines/Lines"

EnhancedIrrigation = EnhancedIrrigation or {}
local Treatment = {}
EnhancedIrrigation.Treatment = Treatment

local Tanks = EnhancedIrrigation.Tanks

Treatment.SYSTEM_NAME = "enhanced_irrigation_treatment"

-- Every unit's tile, for load hooks.
Treatment.SPRITES = { EnhancedIrrigation.Sprites.BARREL_FILTER, EnhancedIrrigation.Sprites.BRICK_FILTER,
    EnhancedIrrigation.Sprites.FILTER_CROCK, EnhancedIrrigation.Sprites.BOILER_STONE,
    EnhancedIrrigation.Sprites.BOILER_WELDED }

-- Slow sand filters ----------------------------------------------------------------------------------

-- Wet hours a new layer of sand takes to grow the living film that cleans the water; until then
-- the filter passes water as tainted as it came. Real filters are run to waste until mature.
Treatment.RIPE_HOURS = 72
-- What a cleaning leaves of the film: stirring the top of the sand tears part of it, so it ripens
-- again for a while.
Treatment.CLEANED_RIPE_HOURS = Treatment.RIPE_HOURS - 24
-- Hours with nothing on the sand that kill the film, which lives on what the water brings.
Treatment.DRY_DEATH_HOURS = 48
-- A clogged filter's share of its rate: a trickle, in one visible step rather than a fade.
Treatment.CLOGGED_FACTOR = 0.1

-- Boilers --------------------------------------------------------------------------------------------

-- Hours of fire that bring a cold drum's water to a safe heat (held at 60 °C for half an hour or
-- boiled), and the most heat it banks: a drum that hot stays safe a while after the fire dies.
Treatment.HOT_HOURS = 1
Treatment.HEAT_MAX_HOURS = 2
-- How many times faster an unlit drum loses its heat than a fire gives it: a drum of water in the
-- open air cools fast.
Treatment.COOLING = 2
-- A new drum's condition, and what an hour of fire takes of it: with water in it the water carries
-- the heat off, run dry the steel scorches.
Treatment.DRUM_CONDITION = 100
Treatment.WEAR_WET = 0.5
Treatment.WEAR_DRY = 10
-- What each Patch Drum takes off the condition a patch restores, as vanilla's repairs fall short.
Treatment.PATCH_LOSS = 10

-- Each unit's entity script name: `kind`, its row of TreatmentObject.KINDS and of the menu's words,
-- which say how it treats; `head`, the litres of raw water it holds; `rate`, the litres an hour it
-- treats; `clogLitres`, the litres it passes before it clogs; `plumbed`, whether it takes inlet and
-- outlet links. Its basin's size is its entity's FluidContainer's. A Barrel Filter's rate is a
-- household's daily water in a day (design, Starting numbers); a Brick Filter's bigger bed of sand
-- scales its numbers. A Filter Crock seeps one person's drinking and cooking water in a day; it
-- holds about what a bucket does. A boiler's head is its Metal Drum, and its rate fast clean water
-- for a woodpile; the firebox under it changes only what building it takes.
Treatment.UNITS = {
    EnhancedIrrigation_BarrelFilter = { kind = "sand", head = 50, rate = 4, clogLitres = 2000, plumbed = true },
    EnhancedIrrigation_BrickFilter = { kind = "sand", head = 200, rate = 16, clogLitres = 8000, plumbed = true },
    EnhancedIrrigation_FilterCrock = { kind = "crock", head = 8, rate = 10 / 24, clogLitres = 300 },
    EnhancedIrrigation_BoilerStone = { kind = "boiler", head = 200, rate = 30, plumbed = true },
    EnhancedIrrigation_BoilerWelded = { kind = "boiler", head = 200, rate = 30, plumbed = true },
}

-- The crock Take Down gives back, and the bucket it gives back when its record never learned which
-- one the crock was set in.
Treatment.CROCK_ITEM = "EnhancedIrrigation.FilterCrock"
Treatment.CROCK_BUCKET = "Base.Bucket"

--- The spec of `isoObject`'s unit (a row of UNITS), or nil when it isn't one.
function Treatment.specOf(isoObject)
    local name = EnhancedIrrigation.entityName(isoObject)
    return name and Treatment.UNITS[name] or nil
end

--- Whether `isoObject` is a treatment unit: one of UNITS, with its basin.
function Treatment.isUnit(isoObject)
    return Treatment.specOf(isoObject) ~= nil and isoObject:getFluidContainer() ~= nil
end

--- The unit on `square`, or nil. Takes a nil square.
function Treatment.unitOn(square)
    return EnhancedIrrigation.findObjectOn(square, Treatment.isUnit)
end

--- The unit on the loaded square x, y, z, or nil.
function Treatment.unitAt(x, y, z)
    return Treatment.unitOn(getCell():getGridSquare(x, y, z))
end

--- Whether water runs between `tank` and `unit` through the unit's `role` end: into its head from
--- a tank at least level with it, out of its basin into a tank no higher.
function Treatment.runsFor(role, tank, unit)
    if role == "inlet" then
        return Tanks.levelOf(tank) >= Tanks.levelOf(unit)
    end
    return Tanks.levelOf(unit) >= Tanks.levelOf(tank)
end

--- Whether `fluid` (a FluidContainer) holds water and nothing else, tainted or not: all a unit
--- takes, as nothing in it treats anything else.
function Treatment.isWater(fluid)
    return fluid ~= nil and fluid:isWaterOnlySource()
end

--- Whether a wall (Lines.wallOn) stands on any edge of `square` or of the eight squares around it:
--- a fire wants a clear square on every side. Squares this side hasn't loaded count as clear.
function Treatment.wallNear(square)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    -- The north edges of the three columns and the west edges of the three rows, from the row and
    -- column before the block to the one after it, which holds the block's south and east edges.
    for dx = -1, 2 do
        for dy = -1, 2 do
            local near = getCell():getGridSquare(x + dx, y + dy, z)
            if near and ((dx <= 1 and EnhancedIrrigation.Lines.wallOn(near, true))
                    or (dy <= 1 and EnhancedIrrigation.Lines.wallOn(near, false))) then
                return true
            end
        end
    end
    return false
end

--- The SpriteConfig OnIsValid of the boilers (Entities.txt), which the build cursor asks of each
--- square: a fire goes outdoors and clear of walls, the rule vanilla's fires leave to the player.
function Treatment.canPlaceBoiler(params)
    local square = params.square
    return square ~= nil and square:isOutside() and not Treatment.wallNear(square)
end

-- A unit's basin is its own container, which every side holds, so a summary needs nothing added.
EnhancedIrrigation.GlobalObjects.addAccessors(Treatment, function() end)

return Treatment
