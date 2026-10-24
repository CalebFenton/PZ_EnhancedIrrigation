-- Pumps: placed things that lift water from a source beside them into a tank (docs/design.md,
-- Pumps). A pump draws from the first source it finds (Pumps.sourceOf): a well beside it, the
-- fullest tank or trough beside it, or natural water its hose reaches; and it delivers through one
-- outlet, a link with `pump` set from its square to a tank (Links.lua), which it may fill up to
-- its lift above its floor whatever the filling rule says. Water moves only while something runs
-- it: a hand pump while a character works it (TimedActions/EnhancedIrrigationPumpAction.lua). The
-- authority keeps a record of each pump (server/EnhancedIrrigation/Pumps/PumpObject.lua): its seal
-- and how worn it and the pump are, and where its hose drinks.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/GlobalObjects"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links"

EnhancedIrrigation = EnhancedIrrigation or {}
local Pumps = {}
EnhancedIrrigation.Pumps = Pumps

local Tanks, Links = EnhancedIrrigation.Tanks, EnhancedIrrigation.Links

Pumps.SYSTEM_NAME = "enhanced_irrigation_pump"

-- Every pump's tile, for load hooks.
Pumps.SPRITES = { EnhancedIrrigation.Sprites.WOODEN_HAND_PUMP, EnhancedIrrigation.Sprites.IRON_HAND_PUMP }

-- Each pump's entity script name: `kind`, the row of PumpObject.KINDS that says what runs it;
-- `lift`, the storeys above its floor it fills a tank to; `rate`, the litres a game minute it
-- moves; `push`, the head it gives a garden line it feeds; `wearLitres`, the litres that take a
-- point of its body's condition; `squeals`, whether it squeals as it works; `noise`, the radius
-- and volume of the sound zombies hear while it works. A hand pump's rate fills a rain barrel in
-- an hour or two of sweat (design, Starting numbers); iron lifts higher and lasts five times as
-- long as wood, which is also loud enough to carry.
Pumps.UNITS = {
    EnhancedIrrigation_WoodenHandPump = {
        kind = "hand", lift = 1, rate = 6, push = 2, wearLitres = 300, squeals = true,
        noise = { radius = 15, volume = 15 },
    },
    EnhancedIrrigation_IronHandPump = {
        kind = "hand", lift = 2, rate = 8, push = 2, wearLitres = 1500,
        noise = { radius = 8, volume = 8 },
    },
}

-- A new pump's body condition; at none it is worn out and lifts nothing until rebuilt.
Pumps.BODY_CONDITION = 100

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

-- Tiles a pump's Rubber Hose reaches across the ground to natural water.
Pumps.HOSE_REACH = 3

-- The tiles of vanilla's wells: the stone well and the forest's hand pump. Each is endless clean
-- water whatever its own container holds, which vanilla never draws (IsoObject.isWaterInfinite).
Pumps.WELL_SPRITES = {
    camping_01_16 = true, camping_01_64 = true, camping_01_65 = true, camping_01_66 = true, camping_01_67 = true,
}

-- Litres below which a source counts as dry, or a tank as full.
Pumps.LEAST_LITRES = 0.01

--- The spec of `isoObject`'s pump (a row of UNITS), or nil when it isn't one.
function Pumps.specOf(isoObject)
    local name = EnhancedIrrigation.entityName(isoObject)
    return name and Pumps.UNITS[name] or nil
end

function Pumps.isPump(isoObject)
    return Pumps.specOf(isoObject) ~= nil
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

--- The outlet link of the pump on the square `at` ({ x, y, z }), or nil.
function Pumps.outletOf(at)
    for _, link in ipairs(Links.all()) do
        if link.pump and EnhancedIrrigation.sameSquare(link.a, at) then
            return link
        end
    end
    return nil
end

-- Sources --------------------------------------------------------------------------------------------

local function isWell(object)
    local sprite = object:getSprite()
    return sprite ~= nil and Pumps.WELL_SPRITES[sprite:getName()] == true
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
    local reach = Pumps.HOSE_REACH
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
function Pumps.intakeFor(here, intake)
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
--- (`outletEnd`, { x, y, z }, if any); the natural water its hose reaches (Pumps.intakeFor with the
--- `intake` its record keeps); or a tank or trough beside it that is dry. Beside is the eight
--- squares around it on its floor. Returns { kind = "well" | "tank" | "trough" | "river", object
--- (nil for an unloaded river), at, infinite, litres, dry }, or nil when it has none.
function Pumps.sourceOf(pump, intake, outletEnd)
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
    local river = Pumps.intakeFor(here, intake)
    if river then
        local square = getCell():getGridSquare(river.x, river.y, river.z)
        return { kind = "river", object = square and square:getWaterObject(), at = river, infinite = true }
    end
    return dry
end

-- What the menu says ---------------------------------------------------------------------------------

--- The menu's name for `source` (Pumps.sourceOf): the well, the tank's container ("Rain Barrel"),
--- the trough or the river; or that there is nothing to draw when it is nil or dry.
function Pumps.sourceName(source)
    if not source or source.dry then
        return getText("IGUI_EnhancedIrrigation_NoWaterToDraw")
    elseif source.kind == "tank" then
        return source.object:getFluidContainer():getTranslatedContainerName()
    end
    return getText(source.kind == "well" and "IGUI_EnhancedIrrigation_SourceWell"
        or source.kind == "trough" and "IGUI_EnhancedIrrigation_SourceTrough" or "IGUI_EnhancedIrrigation_SourceRiver")
end

--- The menu's line for `pump` with `summary`: where it draws, its seal, its body, where it fills.
function Pumps.statusText(pump, summary)
    local outlet = Pumps.outletOf(EnhancedIrrigation.squareOf(pump))
    local words = { Pumps.sourceName(Pumps.sourceOf(pump, summary.intake, outlet and outlet.b)) }
    if not summary.seal then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoSeal"))
    elseif summary.sealWorn then
        table.insert(words, getText("IGUI_EnhancedIrrigation_SealWornOut"))
    else
        table.insert(words, getText("IGUI_EnhancedIrrigation_Seal", summary.sealLeft))
    end
    table.insert(words, summary.wornOut and getText("IGUI_EnhancedIrrigation_PumpWornOut")
        or getText("IGUI_EnhancedIrrigation_PumpCondition", summary.condition))
    local tank = outlet and Tanks.tankAt(outlet.b.x, outlet.b.y, outlet.b.z)
    if not outlet then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoOutlet"))
    elseif tank then
        table.insert(words, getText("IGUI_EnhancedIrrigation_OutletTo", tank:getFluidContainer():getTranslatedContainerName()))
    end
    return table.concat(words, ", ")
end

-- A pump holds no water of its own, so a summary needs nothing added.
EnhancedIrrigation.GlobalObjects.addAccessors(Pumps, function() end)

return Pumps
