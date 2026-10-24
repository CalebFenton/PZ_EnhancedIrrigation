-- The authority's side of treatment units (shared/EnhancedIrrigation/Treatment/Treatment.lua): their Global
-- Object System, a record for each unit built, the jobs of TreatmentJobs done for real, and what
-- an outlet link (LinkSystem.lua) moves out of a unit's basin. What an inlet link moves into its
-- head is the record's time (TreatmentObject.advance).

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Treatment/TreatmentObject"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentSystem = {}
EnhancedIrrigation.TreatmentSystem = TreatmentSystem

local Tanks = EnhancedIrrigation.Tanks
local Treatment, TreatmentJobs = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs

TreatmentSystem.System = EnhancedIrrigation.ObjectSystem.define({
    name = "Treatment",
    sprites = Treatment.SPRITES,
    owner = Treatment,
    Object = EnhancedIrrigation.TreatmentObject,
    isObject = Treatment.isUnit,
})

--- Swaps the built `thumpable` for a vanilla fireplace of its tile, given its entity's components
--- (its basin, and the name that makes it a unit), as vanilla's Barrel Oven's OnCreate makes one
--- (BuildRecipeCode.barrelOven): the game's fire menus, burn-down and sync then run its fire.
--- Returns the fireplace.
function TreatmentSystem.makeFireplace(thumpable)
    local square = thumpable:getSquare()
    local fireplace = IsoFireplace.new(getCell(), square, thumpable:getSprite())
    GameEntityFactory.CreateIsoObjectEntity(fireplace, thumpable:getEntityScript(), true)
    square:AddTileObject(fireplace)
    thumpable:removeFromWorld()
    thumpable:removeFromSquare()
    thumpable:setSquare(nil)
    return fireplace
end

--- The SpriteConfig OnCreate of every unit's entity (Entities.txt), which the build menu calls on
--- the authority once the unit stands on its square (ISBuildIsoEntity:setInfo): its record, at
--- once, as nothing else announces a built entity to the system (OnObjectAdded fires only on a
--- multiplayer client). A boiler becomes a fireplace first, which the build menu sends on in the
--- built object's place; other units go as they are. A crock's record also notes which bucket the
--- build took (the build menu's chosen inputs), for Take Down.
function TreatmentSystem.onCreate(params)
    local unit, result = params.thumpable, nil
    if Treatment.specOf(unit).kind == "boiler" then
        unit = TreatmentSystem.makeFireplace(unit)
        result = { replaceObject = true, object = unit }
    end
    TreatmentSystem.System.instance:loadIsoObject(unit)
    local record = Treatment.recordOf(unit)
    if record and record:spec().kind == "crock" and params.craftRecipeData then
        local used = params.craftRecipeData:getAllConsumedItems()
        for i = 0, used:size() - 1 do
            if used:get(i):hasTag(ItemTag.BUCKET) then
                record.bucket = used:get(i):getFullType()
            end
        end
    end
    return result
end

-- Jobs -----------------------------------------------------------------------------------------------

-- What each job does at `unit`, whose record TreatmentSystem.perform brought up to now.
local DO = {
    -- The container keeps what the head has no room for.
    [TreatmentJobs.POUR_IN] = function(character, unit, item)
        local record = Treatment.recordOf(unit)
        local fluid = item:getFluidContainer()
        local litres = math.min(fluid:getAmount(), record:headRoom())
        local tainted = fluid:isTainted()
        fluid:removeFluid(litres, false)
        item:syncItemFields()
        record:fill(litres, tainted)
    end,
    [TreatmentJobs.CLEAN_FILTER] = function(character, unit)
        Treatment.recordOf(unit):clean()
    end,
    [TreatmentJobs.SCRUB_CROCK] = function(character, unit)
        Treatment.recordOf(unit):scrub()
    end,
    -- The bucket comes back holding the basin's water as it is; the crock, unless frost split it.
    -- Removing the unit removes its record (SGlobalObjectSystem.OnObjectAboutToBeRemoved).
    [TreatmentJobs.TAKE_DOWN_CROCK] = function(character, unit)
        local record = Treatment.recordOf(unit)
        local bucket = instanceItem(record.bucket or Treatment.CROCK_BUCKET)
        local basin = unit:getFluidContainer()
        FluidContainer.Transfer(basin, bucket:getFluidContainer(), basin:getAmount())
        local cracked = record.cracked
        unit:getSquare():transmitRemoveItemFromSquare(unit)
        EnhancedIrrigation.Materials.giveItems(character, bucket)
        if not cracked then
            EnhancedIrrigation.Materials.giveItems(character, Treatment.CROCK_ITEM)
        end
    end,
    [TreatmentJobs.PATCH_DRUM] = function(character, unit)
        Treatment.recordOf(unit):patch()
    end,
}

--- Does `job` at `unit` with `with` for `character` on the authority (Jobs.perform), on the unit as
--- time has left it, then shows and tells what changed. Returns whether it was done.
function TreatmentSystem.perform(character, job, unit, with)
    local record = Treatment.recordOf(unit)
    if not record then
        return false
    end
    local x, y, z = unit:getX(), unit:getY(), unit:getZ()
    record:catchUp()
    local done = EnhancedIrrigation.Jobs.perform(TreatmentJobs, DO, character, job, unit, with)
    -- Unless the job took the unit away, and its record with it.
    if Treatment.recordAt(x, y, z) == record then
        record:afterChange()
    end
    return done
end

-- Links ----------------------------------------------------------------------------------------------

--- Empties the basin of the unit at the `a` end of the outlet `link` into the tank at its `b` end by
--- up to `litres`, while both are loaded and the tank stands no higher than the unit, as far as the
--- tank has room; the mixture moves as it is. Returns the tank when any water moved.
function TreatmentSystem.drain(link, litres)
    local unit, tank = Treatment.unitAt(link.a.x, link.a.y, link.a.z), Tanks.tankAt(link.b.x, link.b.y, link.b.z)
    if not (unit and tank) or not Treatment.runsFor("outlet", tank, unit) then
        return nil
    end
    local basin, fluid = unit:getFluidContainer(), tank:getFluidContainer()
    litres = math.min(litres, basin:getAmount(), fluid:getFreeCapacity())
    if litres < EnhancedIrrigation.Links.LEAST_FLOW then
        return nil
    end
    FluidContainer.Transfer(basin, fluid, litres)
    unit:sync()
    return tank
end

return TreatmentSystem
