-- The authority's side of pumps (shared/EnhancedIrrigation/Pumps/Pumps.lua): their Global Object System,
-- a record for each pump built, the jobs of PumpJobs done for real, who holds each hand pump, and
-- the water a hand pump lifts from its source into its outlet's tank or line. A Pump House runs in
-- its record's own time (Pumps/PumpHouse.lua).

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Pumps/PumpObject"
require "EnhancedIrrigation/Lines/Flow"
require "EnhancedIrrigation/Pumps/PumpHouse"
require "EnhancedIrrigation/Holds"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpSystem = {}
EnhancedIrrigation.PumpSystem = PumpSystem

local Pumps, PumpJobs, Tanks = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs, EnhancedIrrigation.Tanks
local Lines, Flow, PumpObject = EnhancedIrrigation.Lines, EnhancedIrrigation.Flow, EnhancedIrrigation.PumpObject

PumpSystem.System = EnhancedIrrigation.ObjectSystem.define({
    name = "Pump",
    sprites = Pumps.SPRITES,
    owner = Pumps,
    Object = EnhancedIrrigation.PumpObject,
    isObject = Pumps.isPump,
})

-- A pump taken away, smashed or by another mod, no longer runs the line its outlet fed.
function PumpSystem.System:OnObjectAboutToBeRemoved(isoObject)
    local b = self:isValidIsoObject(isoObject) and Pumps.outletEnd(EnhancedIrrigation.squareOf(isoObject))
    SGlobalObjectSystem.OnObjectAboutToBeRemoved(self, isoObject)
    if b and Lines.recordAt(b.x, b.y, b.z) then
        EnhancedIrrigation.LineSystem.showRunning(b.x, b.y, b.z, false)
    end
end

--- The SpriteConfig OnCreate of every pump's entity (Entities.txt), which the build menu calls on
--- the authority once the pump stands on its square (ISBuildIsoEntity:setInfo): its record, at
--- once, as nothing else announces a built entity to the system, with the seal the build took (the
--- build menu's chosen inputs) fitted new. A Pump House is built empty.
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

-- What each job does at `pump`, whose record PumpSystem.perform brought up to now.
local DO = {
    [PumpJobs.REPLACE_SEAL] = function(character, pump, item)
        Pumps.recordOf(pump):fitSeal(item:getFullType())
    end,
    [PumpJobs.FIT_PUMP] = function(character, pump, item)
        EnhancedIrrigation.Materials.takeItem(character, item)
        Pumps.recordOf(pump):fitPart(item)
    end,
    [PumpJobs.TAKE_OUT_PUMP] = function(character, pump)
        EnhancedIrrigation.Materials.giveItems(character, Pumps.recordOf(pump):takeOutPart())
    end,
    -- The time before it was switched on did nothing, so it counts from now.
    [PumpJobs.TURN_ON] = function(character, pump)
        local record = Pumps.recordOf(pump)
        record.on = true
        record.lastHour = EnhancedIrrigation.now()
        EnhancedIrrigation.PumpHouse.settle(record, pump)
    end,
    [PumpJobs.TURN_OFF] = function(character, pump)
        local record = Pumps.recordOf(pump)
        record.on = nil
        EnhancedIrrigation.PumpHouse.settle(record, pump)
    end,
    [PumpJobs.REPAIR_PUMP] = function(character, pump)
        Pumps.recordOf(pump):repairPart()
    end,
    -- The timer's setting starts at nothing: it never opens until set.
    [PumpJobs.FIT_TIMER] = function(character, pump, item)
        EnhancedIrrigation.Materials.takeItem(character, item)
        local record = Pumps.recordOf(pump)
        record.timer = { item = item:getFullType() }
        EnhancedIrrigation.PumpHouse.settle(record, pump)
    end,
    [PumpJobs.TAKE_TIMER] = function(character, pump)
        local record = Pumps.recordOf(pump)
        EnhancedIrrigation.Materials.giveItems(character, instanceItem(record.timer.item))
        record.timer = nil
        EnhancedIrrigation.PumpHouse.settle(record, pump)
    end,
    [PumpJobs.SET_TIMER] = function(character, pump, with)
        local record = Pumps.recordOf(pump)
        record.timer.start, record.timer.minutes = EnhancedIrrigation.Valves.decodeTimer(with)
        EnhancedIrrigation.PumpHouse.settle(record, pump)
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

-- Holding ------------------------------------------------------------------------------------------

--- Holds `pump` for the Pump `action`, unless another action holds it. Returns whether `action`
--- holds it now.
function PumpSystem.hold(pump, action)
    local record = Pumps.recordOf(pump)
    return record ~= nil and EnhancedIrrigation.Holds.hold(record, action)
end

-- Pumping --------------------------------------------------------------------------------------------

-- Takes the endurance `hours` of hard work at a hand pump cost from `character`, and on a
-- multiplayer server tells its client, which doesn't learn of a server's change to a stat by
-- itself.
local function tire(character, hours)
    character:getStats():remove(CharacterStat.ENDURANCE, Pumps.ENDURANCE_PER_HOUR * hours)
    if isServer() then
        syncPlayerStats(character, SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.ENDURANCE))
    end
end

-- The source of the line the hand pump of `record` feeds from `source` (Pumps.sourceOf), as Flow
-- reads one: its spec's push, as much as it lifts an hour, and the draw, which lifts what the line
-- takes as far as a finite source's water and the seal and body last, and wears them by it.
local function lineSource(record, spec, source)
    return {
        push = spec.push,
        perHour = spec.rate * 60,
        pumped = true,
        holds = true,
        draw = function(litres)
            if not source.infinite then
                litres = math.min(litres, source.litres)
            end
            local moved = PumpObject.draw(source, nil, record:canLift(litres))
            record:lift(moved)
            return moved
        end,
    }
end

--- `character` works the hand pump `pump` for `hours`: it lifts its rate from its source into its
--- outlet's tank, as far as the tank has room, a finite source has water and the seal and body
--- last, or drives the line its outlet feeds, lifting what that takes up to its rate; it wears them
--- by what it lifted, and tires the character; zombies hear it. Returns the Tooltip key of why the
--- work stops now (the tank full, the source dry, the seal or pump worn out, the character
--- exhausted), or nil while it goes on.
function PumpSystem.pump(character, pump, hours)
    local record = Pumps.recordOf(pump)
    if not record then
        return "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    record:catchUp()
    local into, source = Pumps.flowOf(pump)
    if not into then
        return source
    end
    local spec = Pumps.specOf(pump)
    if Lines.isLine(into) then
        Flow.run(Lines.recordOf(into), lineSource(record, spec, source), hours)
    else
        local fluid = into:getFluidContainer()
        local litres = math.min(spec.rate * 60 * hours, fluid:getFreeCapacity())
        if not source.infinite then
            litres = math.min(litres, source.litres)
        end
        litres = record:canLift(litres)
        if litres > 0 then
            record:lift(PumpObject.draw(source, fluid, litres))
            Tanks.sync(into)
        end
    end
    if hours > 0 then
        tire(character, hours)
        addSound(character, pump:getX(), pump:getY(), pump:getZ(), spec.noise.radius, spec.noise.volume)
    end
    record:afterChange()
    return PumpJobs.refusal(character, PumpJobs.PUMP, pump)
end

return PumpSystem
