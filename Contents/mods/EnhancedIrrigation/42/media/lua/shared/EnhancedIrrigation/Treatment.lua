-- Treatment units: placed things that make raw water safe (docs/design.md, Making water safe). A
-- unit holds raw water waiting to be treated, its head, as a number of litres in the authority's
-- record (server/EnhancedIrrigation/Treatment/TreatmentObject.lua), tainted or not as a whole, as
-- vanilla's water is; treats it at its own rate; and puts the result in its basin, the unit's own
-- FluidContainer, from which vanilla's menus drink, fill and empty. The basin is input-locked, so
-- water reaches it only through the unit. Water reaches the head by Pour In (TreatmentJobs.lua) or
-- an inlet link from a tank; an outlet link takes the basin's water on to a tank (Links.lua). What
-- a kind does is in its rows here and in TreatmentObject.KINDS, not spread through the code.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/GlobalObjects"

EnhancedIrrigation = EnhancedIrrigation or {}
local Treatment = {}
EnhancedIrrigation.Treatment = Treatment

Treatment.SYSTEM_NAME = "enhanced_irrigation_treatment"

-- Every unit's tile, for load hooks.
Treatment.SPRITES = { EnhancedIrrigation.Sprites.BARREL_FILTER, EnhancedIrrigation.Sprites.BRICK_FILTER,
    EnhancedIrrigation.Sprites.FILTER_CROCK }

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

-- Pour In ---------------------------------------------------------------------------------------------

-- Litres a minute poured from a carried container, about vanilla's pour.
Treatment.POUR_LITRES_PER_MINUTE = 4

-- Each unit's entity script name: `kind`, the row of KINDS (and of TreatmentObject.KINDS) that says
-- how it treats; `head`, the litres of raw water it holds; `rate`, the litres an hour it treats;
-- `clogLitres`, the litres it passes before it clogs; `plumbed`, whether it takes inlet and outlet
-- links. Its basin's size is its entity's FluidContainer's. A Barrel Filter's rate is a household's
-- daily water in a day (design, Starting numbers); a Brick Filter's bigger bed of sand scales its
-- numbers. A Filter Crock seeps one person's drinking and cooking water in a day; it holds about
-- what a bucket does.
Treatment.UNITS = {
    EnhancedIrrigation_BarrelFilter = { kind = "sand", head = 50, rate = 4, clogLitres = 2000, plumbed = true },
    EnhancedIrrigation_BrickFilter = { kind = "sand", head = 200, rate = 16, clogLitres = 8000, plumbed = true },
    EnhancedIrrigation_FilterCrock = { kind = "crock", head = 8, rate = 10 / 24, clogLitres = 300 },
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

--- The level of `unit`'s water, as a tank's (Tanks.levelOf): a unit stands on its floor.
function Treatment.levelOf(unit)
    return unit:getZ()
end

--- Whether `fluid` (a FluidContainer) holds water and nothing else, tainted or not: all a unit
--- takes, as nothing in it treats anything else.
function Treatment.isWater(fluid)
    return fluid ~= nil and fluid:isWaterOnlySource()
end

--- The link of `role` ("inlet" or "outlet") of the unit on the square `at` ({ x, y, z }), or nil.
function Treatment.linkOf(at, role)
    local Links = EnhancedIrrigation.Links
    for _, link in ipairs(Links and Links.all() or {}) do
        local unitEnd = role == "inlet" and link.b or link.a
        if link[role] and EnhancedIrrigation.sameSquare(unitEnd, at) then
            return link
        end
    end
    return nil
end

-- What the menu says ---------------------------------------------------------------------------------

-- Each kind's words for its state, from its summary, as a list of texts.
Treatment.KINDS = {
    sand = {
        words = function(summary)
            local words = {}
            if summary.clogged then
                table.insert(words, getText("IGUI_EnhancedIrrigation_Clogged"))
            end
            if summary.ripeHours >= Treatment.RIPE_HOURS then
                table.insert(words, getText("IGUI_EnhancedIrrigation_Ripe"))
            else
                table.insert(words, getText("IGUI_EnhancedIrrigation_Ripening",
                    math.ceil(Treatment.RIPE_HOURS - summary.ripeHours)))
            end
            if summary.head <= 0 and summary.dryHours >= 1 then
                table.insert(words, getText("IGUI_EnhancedIrrigation_DryFor", math.floor(summary.dryHours)))
            end
            return words
        end,
    },
    -- Fired clay with charcoal pores passes only clean water, so its state is whether it still can.
    crock = {
        words = function(summary)
            if summary.cracked then
                return { getText("IGUI_EnhancedIrrigation_Cracked") }
            end
            return summary.clogged and { getText("IGUI_EnhancedIrrigation_Clogged") } or {}
        end,
    },
}

--- The menu's line for a unit of `spec` with `summary`: the raw water waiting, then its state.
function Treatment.statusText(spec, summary)
    local text = getText("IGUI_EnhancedIrrigation_Head", math.floor(summary.head + 0.5), spec.head)
    local words = Treatment.KINDS[spec.kind].words(summary)
    return #words > 0 and text .. ", " .. table.concat(words, ", ") or text
end

-- A unit's basin is its own container, which every side holds, so a summary needs nothing added.
EnhancedIrrigation.GlobalObjects.addAccessors(Treatment, function() end)

return Treatment
