-- The authority's side of pumps (shared/EnhancedIrrigation/Pumps.lua): their Global Object System,
-- a record for each pump built, the jobs of PumpJobs done for real, and the water a pump lifts
-- from its source into its outlet's tank.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/PumpJobs"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Pumps/PumpObject"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpSystem = {}
EnhancedIrrigation.PumpSystem = PumpSystem

local Pumps, PumpJobs, Tanks = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs, EnhancedIrrigation.Tanks

PumpSystem.System = EnhancedIrrigation.ObjectSystem.define({
    name = "Pump",
    sprites = Pumps.SPRITES,
    owner = Pumps,
    Object = EnhancedIrrigation.PumpObject,
    isObject = Pumps.isPump,
})

--- The SpriteConfig OnCreate of every pump's entity (Entities.txt), which the build menu calls on
--- the authority once the pump stands on its square (ISBuildIsoEntity:setInfo): its record, at
--- once, as nothing else announces a built entity to the system, with the seal the build took (the
--- build menu's chosen inputs) fitted new.
function PumpSystem.onCreate(params)
    local pump = params.thumpable
    PumpSystem.System.instance:loadIsoObject(pump)
    local record = Pumps.recordOf(pump)
    if record and params.craftRecipeData then
        local used = params.craftRecipeData:getAllConsumedItems()
        for i = 0, used:size() - 1 do
            local fullType = used:get(i):getFullType()
            if Pumps.sealLitres(fullType) then
                record:fitSeal(fullType)
            end
        end
        record:sendSummary()
    end
    return nil
end

-- Jobs -----------------------------------------------------------------------------------------------

-- What each job does at `pump`, whose record PumpSystem.perform brought up to now. Returns whether
-- it was done.
local DO = {
    [PumpJobs.REPLACE_SEAL] = function(character, pump, item)
        Pumps.recordOf(pump):fitSeal(item:getFullType())
        return true
    end,
}

--- Does `job` at `pump` with `with` for `character` on the authority (Jobs.perform), then shows
--- and tells what changed. Returns whether it was done.
function PumpSystem.perform(character, job, pump, with)
    local record = Pumps.recordOf(pump)
    if not record then
        return false
    end
    record:catchUp()
    local done = EnhancedIrrigation.Jobs.perform(PumpJobs, DO, character, job, pump, with)
    record:afterChange()
    return done
end

-- Pumping --------------------------------------------------------------------------------------------

-- Moves `litres` from `source` (Pumps.sourceOf) into `fluid` (a FluidContainer) and returns the
-- litres moved. A well's or river's water comes from its tile, which is endless (vanilla's own
-- draw, IsoObject.transferFluidTo), never from a well's own container, which vanilla never draws
-- either; a tank or trough gives its mixture, taint and all, and syncs. A river whose square isn't
-- loaded is still water, always tainted.
local function draw(source, fluid, litres)
    if source.object then
        return source.object:transferFluidTo(fluid, litres)
    end
    fluid:addFluid(FluidType.TaintedWater, litres)
    return litres
end

-- Takes the endurance `hours` of hard work at a hand pump cost from `character`, and on a
-- multiplayer server tells its client, which doesn't learn of a server's change to a stat by
-- itself.
local function tire(character, hours)
    character:getStats():remove(CharacterStat.ENDURANCE, Pumps.ENDURANCE_PER_HOUR * hours)
    if isServer() then
        syncPlayerStats(character, SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.ENDURANCE))
    end
end

--- `character` works the hand pump `pump` for `hours`: it lifts its rate from its source into its
--- outlet's tank, as far as the tank has room, a finite source has water and the seal and body
--- last, wears them by what it lifted, and tires the character; zombies hear it. Returns the
--- Tooltip key of why the work stops now (the tank full, the source dry, the seal or pump worn
--- out, the character exhausted), or nil while it goes on.
function PumpSystem.pump(character, pump, hours)
    local record = Pumps.recordOf(pump)
    if not record then
        return "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    record:catchUp()
    local tank, source = PumpJobs.flowOf(pump)
    if not tank then
        return source
    end
    local spec = Pumps.specOf(pump)
    local fluid = tank:getFluidContainer()
    local litres = math.min(spec.rate * 60 * hours, fluid:getFreeCapacity())
    if not source.infinite then
        litres = math.min(litres, source.litres)
    end
    litres = record:canLift(litres)
    if litres > 0 then
        local moved = draw(source, fluid, litres)
        record:lift(moved)
        Tanks.sync(tank)
    end
    if hours > 0 then
        tire(character, hours)
        addSound(character, pump:getX(), pump:getY(), pump:getZ(), spec.noise.radius, spec.noise.volume)
    end
    record:afterChange()
    return PumpJobs.refusal(character, PumpJobs.PUMP, pump)
end

return PumpSystem
