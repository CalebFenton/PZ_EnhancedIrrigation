-- Pumps: placed things that lift water from a source beside them into a tank or a garden line
-- (docs/design.md, Pumps). A pump draws from the first source it finds (Pumps.sourceOf): a well
-- beside it, the fullest tank or trough beside it, or natural water its hose reaches; and it
-- delivers through one outlet, a link with `pump` set from its square (Links.lua) to a tank, which
-- it may fill up to its lift above its floor whatever the filling rule says, or to a tile of a
-- line, which it drives as a tap's tank does, with the push of its spec (Lines/Flow.lua). Water
-- moves only while something runs it: a hand pump while a character works it
-- (TimedActions/EnhancedIrrigationPumpAction.lua), a Pump House while it is switched on, has a
-- pump part fitted and has power. The authority keeps a record of each pump
-- (server/EnhancedIrrigation/Pumps/PumpObject.lua): a hand pump's seal and how worn it and the pump
-- are, a Pump House's part, its switch and who pays for its power, and where its hose drinks.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/GlobalObjects"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Valves"
require "EnhancedIrrigation/Jobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local Pumps = {}
EnhancedIrrigation.Pumps = Pumps

local Tanks, Links, Lines = EnhancedIrrigation.Tanks, EnhancedIrrigation.Links, EnhancedIrrigation.Lines

Pumps.SYSTEM_NAME = "enhanced_irrigation_pump"

-- Every pump's tile, for load hooks.
Pumps.SPRITES = { EnhancedIrrigation.Sprites.WOODEN_HAND_PUMP, EnhancedIrrigation.Sprites.IRON_HAND_PUMP,
    EnhancedIrrigation.Sprites.PUMP_HOUSE_WOOD, EnhancedIrrigation.Sprites.PUMP_HOUSE_METAL }

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
    -- A Pump House is a box for one pump part (PARTS), which gives it its numbers; empty, it lifts
    -- nothing.
    EnhancedIrrigation_PumpHouseWood = { kind = "house" },
    EnhancedIrrigation_PumpHouseMetal = { kind = "house" },
}

-- A new pump's body condition; at none it is worn out and lifts nothing until rebuilt.
Pumps.BODY_CONDITION = 100

Pumps.APPLIANCE_PUMP = "EnhancedIrrigation.AppliancePump"
Pumps.UTILITY_PUMP = "EnhancedIrrigation.UtilityPump"

-- The pump parts a Pump House takes, by full type: `lift`, `rate`, `push` and `noise` as UNITS';
-- `wearPerHour`, the condition an hour of running takes; `draw`, the generator fuel an hour of
-- running burns in vanilla's own units, before the GeneratorFuelConsumption option (IsoGenerator):
-- a washer's for the pump out of one. A washer's pump is made for a drum's few minutes of draining,
-- so it lifts little and burns out within a week of running; a utility pump is made to run, and
-- empties a rain barrel in half an hour (design, Starting numbers).
Pumps.PARTS = {
    [Pumps.APPLIANCE_PUMP] = { lift = 1, rate = 6, push = 2, wearPerHour = 1, draw = 0.09,
        noise = { radius = 10, volume = 10 } },
    [Pumps.UTILITY_PUMP] = { lift = 2, rate = 20, push = 3, wearPerHour = 0.5, draw = 0.2,
        noise = { radius = 20, volume = 20 } },
}

-- How many times as fast a pump part wears running with nothing to draw: the water it moves is what
-- cools its seal and bearings.
Pumps.DRY_WEAR = 10

-- A pump part's condition new, the most a repair restores; the item modData key of a lower ceiling
-- a part carries, made or repaired, absent at that; the key of the wear past its whole points a
-- part taken out carries, as an item's condition is whole; what each Repair Pump takes off the
-- ceiling, as vanilla's repairs fall short; and the ceiling of a Utility Pump made from a Blower
-- Fan, as a home-made pump falls short of a bought one.
Pumps.PART_CONDITION = 100
Pumps.CEILING_KEY = "EnhancedIrrigation_ceiling"
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

-- Tiles a pump's Rubber Hose reaches across the ground to natural water.
Pumps.HOSE_REACH = 3

-- The tiles of vanilla's wells: the stone well and the forest's hand pump. Each is endless clean
-- water whatever its own container holds, which vanilla never draws (IsoObject.isWaterInfinite).
Pumps.WELL_SPRITES = {
    camping_01_16 = true, camping_01_64 = true, camping_01_65 = true, camping_01_66 = true, camping_01_67 = true,
}

-- Litres below which a source counts as dry, or a tank as full.
Pumps.LEAST_LITRES = 0.01

-- The Tooltip key saying how high a pump of each lift fills a tank.
Pumps.LIFT_KEYS = {
    [1] = "Tooltip_EnhancedIrrigation_LiftsOneStorey",
    [2] = "Tooltip_EnhancedIrrigation_LiftsTwoStoreys",
}

--- The spec of `isoObject`'s pump (a row of UNITS), or nil when it isn't one.
function Pumps.specOf(isoObject)
    local name = EnhancedIrrigation.entityName(isoObject)
    return name and Pumps.UNITS[name] or nil
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

--- The numbers `pump` lifts by, as this side sees it: a hand pump's own row of UNITS, a Pump House's
--- fitted part's row of PARTS, or nil for a Pump House with none.
function Pumps.liftingSpec(pump)
    local spec = Pumps.specOf(pump)
    if spec and spec.kind == "house" then
        local summary = Pumps.currentSummary(pump)
        return summary and Pumps.partSpec(summary.part) or nil
    end
    return spec
end

--- The most condition a repair brings the pump part `item` back to.
function Pumps.ceilingOf(item)
    return item:getModData()[Pumps.CEILING_KEY] or Pumps.PART_CONDITION
end

--- Gives the pump part `item` the ceiling `ceiling`, which travels with it.
function Pumps.setCeiling(item, ceiling)
    item:getModData()[Pumps.CEILING_KEY] = ceiling < Pumps.PART_CONDITION and ceiling or nil
end

--- OnCreate of Make Utility Pump (Recipes.txt): the pump comes out at its lower ceiling.
function Pumps.onMadePump(craftRecipeData, character)
    local pump = craftRecipeData:getFirstCreatedItem()
    Pumps.setCeiling(pump, Pumps.MADE_CEILING)
    pump:setCondition(Pumps.MADE_CEILING)
    pump:syncItemFields()
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
    return Links.roleAt(at, "pump")
end

--- The square the outlet of the pump on the square `at` delivers to, or nil without an outlet.
function Pumps.outletEnd(at)
    local outlet = Pumps.outletOf(at)
    return outlet and select(2, Links.ends(outlet)) or nil
end

--- The outlet link of a pump that feeds the line of `tiles` (Lines.component), or nil.
function Pumps.pumpFeeding(tiles)
    for _, link in ipairs(Links.all()) do
        if link.pump then
            local _, into = Links.ends(link)
            for _, tile in ipairs(tiles) do
                if EnhancedIrrigation.sameSquare(into, tile) then
                    return link
                end
            end
        end
    end
    return nil
end

-- A line takes one tap or one pump: two would each run every outlet on it, and a pump would push
-- against a tank. The Tooltip key refusing another feed to a line each kind feeds.
Pumps.FEED_TAKEN = {
    tap = "Tooltip_EnhancedIrrigation_LineHasTap",
    pump = "Tooltip_EnhancedIrrigation_LinePumped",
}

--- What feeds the line of `tiles` (Lines.component): "tap" while a tap is on it, else "pump" while
--- a pump's outlet is plumbed to it, else nil.
function Pumps.feedOf(tiles)
    if Lines.tapIn(tiles) then
        return "tap"
    end
    return Pumps.pumpFeeding(tiles) and "pump" or nil
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

-- Delivery -------------------------------------------------------------------------------------------

--- The level a pump lifts to for `into`, its outlet's tank or line tile: the tank's, or the floor
--- the line lies on.
function Pumps.levelOf(into)
    return Tanks.isTank(into) and Tanks.levelOf(into) or into:getZ()
end

--- What a pump lifting by `spec` (a row of UNITS or PARTS) would lift into, as this side sees it:
--- its outlet's tank, while that stands within its lift and has room, or its outlet's line tile,
--- while its line has no tap; and the source it draws from (Pumps.sourceOf, with the hose's
--- `intake`). Returns the tank or line tile and the source, or nil and the Tooltip key of why it
--- lifts nothing.
function Pumps.deliveryOf(pump, spec, intake)
    local b = Pumps.outletEnd(EnhancedIrrigation.squareOf(pump))
    if not b then
        return nil, "Tooltip_EnhancedIrrigation_NoOutlet"
    end
    local into = Tanks.tankAt(b.x, b.y, b.z) or Lines.lineAt(b.x, b.y, b.z)
    if not into then
        return nil, "Tooltip_EnhancedIrrigation_OutletGone"
    end
    -- A barrel set on a stand at the far end since it was plumbed may stand out of its reach.
    if not Pumps.lifts(spec, Pumps.levelOf(into), pump:getZ()) then
        return nil, Pumps.LIFT_KEYS[spec.lift]
    end
    if Lines.isLine(into) then
        -- A wall knocked down since may have joined it to a tapped line. This pump feeds it too,
        -- so only a tap is another feed.
        if Pumps.feedOf(Lines.component(b.x, b.y, b.z)) == "tap" then
            return nil, Pumps.FEED_TAKEN.tap
        end
    elseif into:getFluidContainer():getFreeCapacity() < Pumps.LEAST_LITRES then
        return nil, "Tooltip_EnhancedIrrigation_OutletFull"
    end
    local source = Pumps.sourceOf(pump, intake, b)
    if not source or source.dry then
        return nil, "Tooltip_EnhancedIrrigation_NoWaterToDraw"
    end
    return into, source
end

--- What the hand pump `pump` would lift into, as this side sees it (Pumps.deliveryOf), unless its
--- body or seal is worn out. Returns the tank or line tile and the source, or nil and the Tooltip
--- key of why it lifts nothing.
function Pumps.flowOf(pump)
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
    return Pumps.deliveryOf(pump, spec, summary.intake)
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

-- The words of a hand pump's `summary`: its seal, then its body.
local function handWords(words, summary)
    if not summary.seal then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoSeal"))
    elseif summary.sealWorn then
        table.insert(words, getText("IGUI_EnhancedIrrigation_SealWornOut"))
    else
        table.insert(words, getText("IGUI_EnhancedIrrigation_Seal", summary.sealLeft))
    end
    table.insert(words, summary.wornOut and getText("IGUI_EnhancedIrrigation_PumpWornOut")
        or getText("IGUI_EnhancedIrrigation_PumpCondition", summary.condition))
end

-- The words of a Pump House's `summary`: its part and how worn, then whether it runs, is off or is
-- switched on with no power, then its timer and how it is set.
local function houseWords(words, summary)
    if not summary.part then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoPumpFitted"))
    else
        local name = getItemNameFromFullType(summary.part)
        table.insert(words, summary.burntOut and getText("IGUI_EnhancedIrrigation_PartBurntOut", name)
            or getText("IGUI_EnhancedIrrigation_PartCondition", name, summary.partCondition))
        table.insert(words, getText(summary.running and "IGUI_EnhancedIrrigation_Running"
            or summary.on and "IGUI_EnhancedIrrigation_NoPower" or "IGUI_EnhancedIrrigation_SwitchedOff"))
    end
    if summary.timer then
        table.insert(words, EnhancedIrrigation.Valves.describe(summary.timer))
    end
end

--- The menu's line for `pump` with `summary`: where it draws; a hand pump's seal and body, or a Pump
--- House's part and switch; the tank it fills or the line it feeds.
function Pumps.statusText(pump, summary)
    local into = Pumps.outletEnd(EnhancedIrrigation.squareOf(pump))
    local words = { Pumps.sourceName(Pumps.sourceOf(pump, summary.intake, into)) }
    if Pumps.isHouse(pump) then
        houseWords(words, summary)
    else
        handWords(words, summary)
    end
    local tank = into and Tanks.tankAt(into.x, into.y, into.z)
    if not into then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoOutlet"))
    elseif tank then
        table.insert(words, getText("IGUI_EnhancedIrrigation_OutletTo", tank:getFluidContainer():getTranslatedContainerName()))
    elseif Lines.lineAt(into.x, into.y, into.z) then
        table.insert(words, getText("IGUI_EnhancedIrrigation_OutletToLine"))
    end
    return table.concat(words, ", ")
end

-- A pump holds no water of its own, so a summary needs nothing added.
EnhancedIrrigation.GlobalObjects.addAccessors(Pumps, function() end)

return Pumps
