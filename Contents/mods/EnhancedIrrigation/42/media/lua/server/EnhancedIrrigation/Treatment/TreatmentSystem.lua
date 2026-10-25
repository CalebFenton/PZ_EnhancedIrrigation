-- The authority's side of treatment units: their Global Object System, a record for each unit
-- built, and the jobs of TreatmentJobs done for real.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
local Items = require "cf_commonlib/Items"
local LibObjectSystem = require "cf_commonlib/ObjectSystem"
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
    local bucket = record and record:spec().kind == "crock" and Items.firstConsumed(params.craftRecipeData,
        function(item) return item:hasTag(ItemTag.BUCKET) end)
    if bucket then
        record.bucket = bucket:getFullType()
    end
    return result
end

-- Jobs -----------------------------------------------------------------------------------------------

-- What each job does on the record of `unit`, brought up to now (ObjectSystem.jobSite).
local DO = {
    -- The container keeps what the head has no room for.
    [TreatmentJobs.POUR_IN] = function(character, record, row, unit, item)
        record:takeFrom(item:getFluidContainer(), math.huge)
        item:syncItemFields()
        return true
    end,
    [TreatmentJobs.CLEAN_FILTER] = function(character, record)
        record:clean()
        return true
    end,
    [TreatmentJobs.SCRUB_CROCK] = function(character, record)
        record:scrub()
        return true
    end,
    -- The bucket comes back holding the basin's water as it is; the crock, unless frost split it.
    -- Removing the unit removes its record (SGlobalObjectSystem.OnObjectAboutToBeRemoved).
    [TreatmentJobs.TAKE_DOWN_CROCK] = function(character, record, row, unit)
        local bucket = instanceItem(record.bucket or Treatment.CROCK_BUCKET)
        local basin = unit:getFluidContainer()
        FluidContainer.Transfer(basin, bucket:getFluidContainer(), basin:getAmount())
        local cracked = record.cracked
        unit:getSquare():transmitRemoveItemFromSquare(unit)
        Items.giveItems(character, bucket)
        if not cracked then
            Items.giveItems(character, Treatment.CROCK_ITEM)
        end
        return true
    end,
    [TreatmentJobs.PATCH_DRUM] = function(character, record)
        record:patch()
        return true
    end,
}

--- The authority's side of the treatment jobs (a site of Jobs.perform).
TreatmentSystem.site = LibObjectSystem.jobSite(Treatment, DO)

return TreatmentSystem
