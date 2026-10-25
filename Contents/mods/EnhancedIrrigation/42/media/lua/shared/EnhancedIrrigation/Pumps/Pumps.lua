-- Pumps lift water from a source beside them through one outlet into a tank, which a pump fills up
-- to its lift above its floor whatever the filling rule says, or into a garden line, which it drives
-- as a tap's tank does. Water moves only while something runs it: a hand pump while a character
-- works it, a Pump House while it is switched on or its timer holds it open, with a part fitted and
-- power.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/GlobalObjects"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Parts"

EnhancedIrrigation = EnhancedIrrigation or {}
local Pumps = {}
EnhancedIrrigation.Pumps = Pumps

local Tanks, Links, Lines = EnhancedIrrigation.Tanks, EnhancedIrrigation.Links, EnhancedIrrigation.Lines

Pumps.SYSTEM_NAME = "enhanced_irrigation_pump"

-- Every pump's tile, for load hooks.
Pumps.SPRITES = { EnhancedIrrigation.Sprites.WOODEN_HAND_PUMP, EnhancedIrrigation.Sprites.IRON_HAND_PUMP,
    EnhancedIrrigation.Sprites.PUMP_HOUSE_WOOD, EnhancedIrrigation.Sprites.PUMP_HOUSE_METAL }

-- Each pump's entity script name: `kind`, "hand" (run only while worked) or "house" (run by time);
-- `lift`, the storeys above its floor it fills a tank to; `rate`, the litres a game minute it
-- moves; `push`, the head it gives a garden line it feeds; `wearLitres`, the litres that take a
-- point of its body's condition; `squeals`, whether it squeals as it works; `noise`, the radius
-- and volume of the sound zombies hear while it works. A hand pump's rate fills a rain barrel in
-- an hour or two of sweat (design, Starting numbers); wood squeals, loud enough to carry.
Pumps.ENTITIES = {
    EnhancedIrrigation_WoodenHandPump = {
        kind = "hand", lift = 1, rate = 6, push = 2, wearLitres = 300, squeals = true,
        noise = { radius = 15, volume = 15 },
    },
    EnhancedIrrigation_IronHandPump = {
        kind = "hand", lift = 2, rate = 8, push = 2, wearLitres = 1500,
        noise = { radius = 8, volume = 8 },
    },
    -- A Pump House is a box for one pump part (PARTS), which gives it its numbers; empty, it lifts
    -- nothing.
    EnhancedIrrigation_PumpHouseWood = { kind = "house" },
    EnhancedIrrigation_PumpHouseMetal = { kind = "house" },
}

-- A new pump's body condition; at none it is worn out and lifts nothing until rebuilt.
Pumps.BODY_CONDITION = 100

Pumps.APPLIANCE_PUMP = "EnhancedIrrigation.AppliancePump"
Pumps.UTILITY_PUMP = "EnhancedIrrigation.UtilityPump"

-- The pump parts a Pump House takes, by full type: `lift`, `rate`, `push` and `noise` as ENTITIES';
-- `wearPerHour`, the condition an hour of running takes; `draw`, the generator fuel an hour of
-- running burns in vanilla's own units, before the GeneratorFuelConsumption option (IsoGenerator):
-- a washer's for the pump out of one. A washer's pump is made for a drum's few minutes of draining,
-- so it lifts little and burns out soon; a utility pump is made to run.
Pumps.PARTS = {
    [Pumps.APPLIANCE_PUMP] = { lift = 1, rate = 6, push = 2, wearPerHour = 1, draw = 0.09,
        noise = { radius = 10, volume = 10 } },
    [Pumps.UTILITY_PUMP] = { lift = 2, rate = 20, push = 3, wearPerHour = 0.5, draw = 0.2,
        noise = { radius = 20, volume = 20 } },
}

-- How many times as fast a pump part wears running with nothing to draw: the water it moves is what
-- cools its seal and bearings.
Pumps.DRY_WEAR = 10

-- The item modData key of the wear past its whole points a part taken out carries, as an item's
-- condition is whole; what each Repair Pump takes off its ceiling (Parts.restores); and the ceiling
-- of a Utility Pump made from a Blower Fan.
Pumps.FRACTION_KEY = "EnhancedIrrigation_conditionFraction"
Pumps.REPAIR_LOSS = 10
Pumps.MADE_CEILING = 80

-- The seals a hand pump takes, best first, and the litres each lifts before it is worn through:
-- leather holds a cup's shape longest, a plunger's rubber cup least (design, Pumps).
Pumps.SEALS = {
    { type = "Base.LeatherStrips", litres = 3000 },
    { type = "Base.TirePiece", litres = 2000 },
    { type = "Base.TarpPiece", litres = 1200 },
    { type = "Base.Plunger", litres = 600 },
}
local SEAL_LITRES = {}
for _, seal in ipairs(Pumps.SEALS) do
    SEAL_LITRES[seal.type] = seal.litres
end

-- Endurance an hour of working a hand pump takes: Renewable Energy's treadmill's, as hard as a
-- run on one; and the endurance at which the character gives up, vanilla's Exhausted moodle
-- (MoodleStat.ENDURANCE), where a sprint stops too.
Pumps.ENDURANCE_PER_HOUR = 0.6
Pumps.EXHAUSTED = 0.1

-- Litres below which a source counts as dry, or a tank as full.
Pumps.LEAST_LITRES = 0.01

-- The Tooltip key saying how high a pump of each lift fills a tank.
Pumps.LIFT_KEYS = {
    [1] = "Tooltip_EnhancedIrrigation_LiftsOneStorey",
    [2] = "Tooltip_EnhancedIrrigation_LiftsTwoStoreys",
}

--- The spec of `isoObject`'s pump (a row of ENTITIES), or nil when it isn't one.
function Pumps.specOf(isoObject)
    return EnhancedIrrigation.entitySpec(isoObject, Pumps.ENTITIES)
end

function Pumps.isPump(isoObject)
    return Pumps.specOf(isoObject) ~= nil
end

function Pumps.isHouse(isoObject)
    local spec = Pumps.specOf(isoObject)
    return spec ~= nil and spec.kind == "house"
end

--- The row of PARTS of the pump part `part` (a full type), or nil when it is none.
function Pumps.partSpec(part)
    return part and Pumps.PARTS[part] or nil
end

--- The numbers `pump` lifts by, as this side sees it: a hand pump's own row of ENTITIES, a Pump
--- House's fitted part's row of PARTS, or nil for a Pump House with none.
function Pumps.liftingSpec(pump)
    local spec = Pumps.specOf(pump)
    if spec and spec.kind == "house" then
        local summary = Pumps.currentSummary(pump)
        return summary and Pumps.partSpec(summary.part) or nil
    end
    return spec
end

--- OnCreate of Make Utility Pump (Recipes.txt).
function Pumps.onMadePump(craftRecipeData)
    EnhancedIrrigation.Parts.made(craftRecipeData, Pumps.MADE_CEILING)
end

--- The pump on `square`, or nil. Takes a nil square.
function Pumps.pumpOn(square)
    return EnhancedIrrigation.findObjectOn(square, Pumps.isPump)
end

--- The pump on the loaded square x, y, z, or nil.
function Pumps.pumpAt(x, y, z)
    return Pumps.pumpOn(getCell():getGridSquare(x, y, z))
end

--- The litres `seal` (a full type) lifts before it wears through, or nil when it is no seal.
function Pumps.sealLitres(seal)
    return seal and SEAL_LITRES[seal] or nil
end

--- Whether a tank at `tankLevel` is in reach of a pump of `spec` on floor `pumpZ`: no higher than
--- its lift above the pump.
function Pumps.lifts(spec, tankLevel, pumpZ)
    return tankLevel <= pumpZ + spec.lift
end

--- The garden lines the outlet of `pump` reaches, loaded on this side, nearest first: for each, its
--- nearest tile, { line, at, distance }.
function Pumps.linesInReach(pump)
    local found, seen = {}, {}
    for _, entry in ipairs(Links.inReach(pump, Lines.lineAt)) do
        local key = EnhancedIrrigation.squareKey(entry.at.x, entry.at.y, entry.at.z)
        if not seen[key] then
            for _, tile in ipairs(Lines.component(entry.at.x, entry.at.y, entry.at.z)) do
                seen[EnhancedIrrigation.squareKey(tile.x, tile.y, tile.z)] = true
            end
            table.insert(found, { line = entry.found, at = entry.at, distance = entry.distance })
        end
    end
    return found
end

--- The litres an hour a pump lifting by `spec` (a row of ENTITIES or PARTS) moves with water.
function Pumps.perHour(spec)
    return spec.rate * 60
end

-- A pump holds no water of its own, so a summary needs nothing added.
EnhancedIrrigation.GlobalObjects.addAccessors(Pumps, function() end)

return Pumps
