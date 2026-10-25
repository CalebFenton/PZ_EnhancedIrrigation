-- The authority's side of treatment units: their Global Object System, a record for each unit
-- built, and the jobs of TreatmentJobs done for real.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Treatment/TreatmentObject"
require "EnhancedIrrigation/Treatment/Boiler"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentSystem = {}
EnhancedIrrigation.TreatmentSystem = TreatmentSystem

local Treatment, TreatmentJobs = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs

TreatmentSystem.System = EnhancedIrrigation.ObjectSystem.define({
    name = "Treatment",
    sprites = Treatment.SPRITES,
    owner = Treatment,
    Object = EnhancedIrrigation.TreatmentObject,
    isObject = Treatment.isUnit,
})

-- Swaps the built `thumpable` for a vanilla fireplace of its tile, given its entity's components
-- (its basin, and the name that makes it a unit), as vanilla's Barrel Oven's OnCreate makes one
-- (BuildRecipeCode.barrelOven): the game's fire menus, burn-down and sync then run its fire.
-- Returns the fireplace.
local function makeFireplace(thumpable)
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
        unit = makeFireplace(unit)
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
        Treatment.recordOf(unit):takeFrom(item:getFluidContainer(), math.huge)
        item:syncItemFields()
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

return TreatmentSystem
