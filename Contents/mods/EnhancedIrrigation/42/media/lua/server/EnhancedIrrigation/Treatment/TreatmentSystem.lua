-- The authority's side of treatment units (shared/EnhancedIrrigation/Treatment.lua): their Global
-- Object System, a record for each unit built, the jobs of TreatmentJobs done for real, and what
-- an inlet or outlet link (LinkSystem.lua) moves into a unit's head or out of its basin.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Treatment"
require "EnhancedIrrigation/TreatmentJobs"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Treatment/TreatmentObject"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentSystem = {}
EnhancedIrrigation.TreatmentSystem = TreatmentSystem

local Tanks = EnhancedIrrigation.Tanks
local Treatment, TreatmentJobs = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs
local LinkJobs = EnhancedIrrigation.LinkJobs

-- A flow smaller than this isn't worth a sync to every client.
local LEAST_LITRES = 0.01

TreatmentSystem.System = EnhancedIrrigation.ObjectSystem.define({
    name = "Treatment",
    sprites = Treatment.SPRITES,
    owner = Treatment,
    Object = EnhancedIrrigation.TreatmentObject,
    isObject = Treatment.isUnit,
})

--- The SpriteConfig OnCreate of every unit's entity (Entities.txt), which the build menu calls on
--- the authority once the unit stands on its square (ISBuildIsoEntity:setInfo): its record, at
--- once, as nothing else announces a built entity to the system (OnObjectAdded fires only on a
--- multiplayer client). Returns nothing, so the build menu sends the unit on as it is. A crock's
--- record also notes which bucket the build took (the build menu's chosen inputs), for Take Down.
function TreatmentSystem.onCreate(params)
    TreatmentSystem.System.instance:loadIsoObject(params.thumpable)
    local record = Treatment.recordOf(params.thumpable)
    if not (record and record:spec().kind == "crock" and params.craftRecipeData) then
        return
    end
    local used = params.craftRecipeData:getAllConsumedItems()
    for i = 0, used:size() - 1 do
        if used:get(i):hasTag(ItemTag.BUCKET) then
            record.bucket = used:get(i):getFullType()
        end
    end
end

-- Jobs -----------------------------------------------------------------------------------------------

-- What each job does at `unit`, whose record TreatmentSystem.perform brought up to now. Returns
-- whether it was done.
local DO = {
    -- The container keeps what the head has no room for.
    [TreatmentJobs.POUR_IN] = function(character, unit, item)
        local record = Treatment.recordOf(unit)
        local fluid = item:getFluidContainer()
        local litres = math.min(fluid:getAmount(), record:spec().head - record.head)
        local tainted = fluid:isTainted()
        fluid:removeFluid(litres, false)
        item:syncItemFields()
        record:fill(litres, tainted)
        return true
    end,
    [TreatmentJobs.CLEAN_FILTER] = function(character, unit)
        Treatment.recordOf(unit):clean()
        return true
    end,
    [TreatmentJobs.SCRUB_CROCK] = function(character, unit)
        Treatment.recordOf(unit):scrub()
        return true
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
        EnhancedIrrigation.giveItems(character, bucket)
        if not cracked then
            EnhancedIrrigation.giveItems(character, Treatment.CROCK_ITEM)
        end
        return true
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

--- Fills the head of the unit at the `b` end of the inlet `link` from the tank at its `a` end by up
--- to `litres`, while both are loaded, the tank stands at least level with the unit (design, Tanks
--- and height) and holds water and nothing else; the taint goes with it. Returns the tank when any
--- water moved.
function TreatmentSystem.feed(link, litres)
    local tank, unit = Tanks.tankAt(link.a.x, link.a.y, link.a.z), Treatment.unitAt(link.b.x, link.b.y, link.b.z)
    local record = unit and Treatment.recordOf(unit)
    if not (tank and record) or not LinkJobs.runsFor("inlet", Tanks.levelOf(tank), Treatment.levelOf(unit)) then
        return nil
    end
    local fluid = tank:getFluidContainer()
    if not Treatment.isWater(fluid) then
        return nil
    end
    record:catchUp()
    litres = math.min(litres, fluid:getAmount(), record:spec().head - record.head)
    if litres < LEAST_LITRES then
        return nil
    end
    local tainted = fluid:isTainted()
    fluid:removeFluid(litres, false)
    record:fill(litres, tainted)
    record:afterChange()
    return tank
end

--- Empties the basin of the unit at the `a` end of the outlet `link` into the tank at its `b` end by
--- up to `litres`, while both are loaded and the tank stands no higher than the unit, as far as the
--- tank has room; the mixture moves as it is. Returns the tank when any water moved.
function TreatmentSystem.drain(link, litres)
    local unit, tank = Treatment.unitAt(link.a.x, link.a.y, link.a.z), Tanks.tankAt(link.b.x, link.b.y, link.b.z)
    if not (unit and tank) or not LinkJobs.runsFor("outlet", Tanks.levelOf(tank), Treatment.levelOf(unit)) then
        return nil
    end
    local basin, fluid = unit:getFluidContainer(), tank:getFluidContainer()
    litres = math.min(litres, basin:getAmount(), fluid:getFreeCapacity())
    if litres < LEAST_LITRES then
        return nil
    end
    FluidContainer.Transfer(basin, fluid, litres)
    unit:sync()
    return tank
end

return TreatmentSystem
