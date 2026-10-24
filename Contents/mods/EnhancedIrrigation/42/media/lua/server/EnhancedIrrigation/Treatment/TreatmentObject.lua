-- The authority's record of one treatment unit (shared/EnhancedIrrigation/Treatment.lua): the raw
-- water in its head and what time and use have done to it. Time tops the head up from an inlet's
-- tank and treats it into the basin as its kind says (KINDS); Pour In and the jobs
-- (TreatmentSystem.lua) change the rest. Unlike a line tile's, a unit's record waits while its chunk
-- is unloaded, as the basin it fills lives on the unit, and catches up the whole gap when it loads,
-- its inlet feeding it through the gap as it would have loaded.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Treatment"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Lines/LineObject"

EnhancedIrrigation = EnhancedIrrigation or {}

local Treatment, Lines, Tanks = EnhancedIrrigation.Treatment, EnhancedIrrigation.Lines, EnhancedIrrigation.Tanks
local LinkJobs = EnhancedIrrigation.LinkJobs

local TreatmentObject = EnhancedIrrigation.ObjectSystem.Object:derive("EnhancedIrrigation_Treatment")
EnhancedIrrigation.TreatmentObject = TreatmentObject

-- A head with less than this left counts as empty.
local LEAST_LITRES = 0.001
-- A draw from an inlet's tank smaller than this isn't worth a sync to every client.
local LEAST_DRAWN = 0.01

-- The world's save format: renaming one loses it from saves. unit: the unit's entity script name,
-- a key of Treatment.UNITS, so the record knows its numbers unloaded too; head: litres of raw water
-- waiting; headTainted: whether any of it is tainted; passed: litres treated since the last
-- cleaning; ripeHours: wet hours the sand's film has grown; dryHours: hours since the head ran dry;
-- cracked: a crock frost split; bucket: the full type of the bucket a crock stands in; lastHour:
-- when time last reached it.
TreatmentObject.SAVED_FIELDS = { "unit", "head", "headTainted", "passed", "ripeHours", "dryHours", "cracked",
    "bucket", "lastHour" }

function TreatmentObject:initNew()
    self.head = 0
    self.headTainted = false
    self.passed = 0
    self.ripeHours = 0
    self.dryHours = 0
    self.cracked = false
    self.lastHour = EnhancedIrrigation.now()
end

-- A unit without a record: a fresh one, or one whose record was lost with the system's save file.
function TreatmentObject:stateFromIsoObject(isoObject)
    self:initNew()
    self.unit = EnhancedIrrigation.entityName(isoObject)
    self.summary = self:buildSummary()
end

-- The chunk loaded again; the next pass catches up the time it was away.
function TreatmentObject:stateToIsoObject(isoObject)
end

function TreatmentObject:spec()
    return self.unit and Treatment.UNITS[self.unit]
end

--- Adds `litres` of raw water to the head, `tainted` or not; the caller kept to its room.
function TreatmentObject:fill(litres, tainted)
    self.head = self.head + litres
    self.headTainted = self.headTainted or tainted == true
end

--- The tank the unit's inlet draws from: the one at the far end of its inlet link, while it is
--- loaded and stands at least level with `unit` (design, Tanks and height); or nil.
function TreatmentObject:inletTank(unit)
    local link = Treatment.linkOf(self, "inlet")
    local tank = link and Tanks.tankAt(link.a.x, link.a.y, link.a.z)
    if tank and LinkJobs.runsFor("inlet", Tanks.levelOf(tank), Treatment.levelOf(unit)) then
        return tank
    end
    return nil
end

--- Tops the head up from `tank` with what a link carries in `hours`, while the tank holds water and
--- nothing else; the taint goes with it. Returns whether any moved.
function TreatmentObject:draw(tank, hours)
    local fluid = tank:getFluidContainer()
    if not Treatment.isWater(fluid) then
        return false
    end
    -- Read when called: LinkSystem.lua requires this file.
    local carried = EnhancedIrrigation.LinkSystem.LINK_RATE * hours
    local litres = math.min(carried, fluid:getAmount(), self:spec().head - self.head)
    if litres < LEAST_DRAWN then
        return false
    end
    local tainted = fluid:isTainted()
    fluid:removeFluid(litres, false)
    self:fill(litres, tainted)
    return true
end

--- Takes `litres` out of the head into the basin of `unit` as `fluid` (a FluidType), as far as the
--- basin has room, counting them passed. The basin is locked to everything else (Treatment.lua).
--- Returns the litres moved.
function TreatmentObject:pass(unit, litres, fluid)
    local basin = unit:getFluidContainer()
    litres = math.min(litres, self.head, basin:getFreeCapacity())
    if litres <= 0 then
        return 0
    end
    basin:setInputLocked(false)
    basin:addFluid(fluid, litres)
    basin:setInputLocked(true)
    self.head = self.head - litres
    self.passed = self.passed + litres
    if self.head < LEAST_LITRES then
        self.head = 0
        self.headTainted = false
    end
    self.basinChanged = true
    return litres
end

--- The air temperature at the unit, as a garden line's (LineObject.temperatureAt): a room warms it.
function TreatmentObject:temperature()
    return EnhancedIrrigation.LineObject.temperatureAt(self)
end

-- Kinds ---------------------------------------------------------------------------------------------

--- What an hour or less of time does to a unit of each kind: `step(record, unit, spec, hours)`.
TreatmentObject.KINDS = {}

--- Whether the sand filter's film is grown: it cleans what passes.
function TreatmentObject:isRipe()
    return self.ripeHours >= Treatment.RIPE_HOURS
end

--- Whether the sand has passed its litres since the last cleaning.
function TreatmentObject:isClogged(spec)
    return spec.clogLitres ~= nil and self.passed >= spec.clogLitres
end

-- The film grows while water stands on the sand and dies after two dry days, or when a hard freeze
-- turns the water on it to ice, which also stops the flow. A grown film passes clean water; an
-- unripe one passes the head's own.
TreatmentObject.KINDS.sand = {
    step = function(record, unit, spec, hours)
        if record.head > 0 then
            record.dryHours = 0
            if record:temperature() <= Lines.HARD_FREEZE_CELSIUS then
                record.ripeHours = 0
                return
            end
            record.ripeHours = math.min(Treatment.RIPE_HOURS, record.ripeHours + hours)
        else
            record.dryHours = record.dryHours + hours
            if record.dryHours >= Treatment.DRY_DEATH_HOURS then
                record.ripeHours = 0
            end
        end
        local fluid = (record:isRipe() or not record.headTainted) and FluidType.Water or FluidType.TaintedWater
        local rate = spec.rate * (record:isClogged(spec) and Treatment.CLOGGED_FACTOR or 1)
        record:pass(unit, rate * hours, fluid)
    end,
}

-- Water freezing in the crock's pores splits it: a hard freeze with any water in it cracks it, and
-- the water runs out through the crack. A cracked crock passes nothing; fire a new one. Whole, it
-- passes clean water whatever went in, slowed to a trickle once clogged.
TreatmentObject.KINDS.crock = {
    step = function(record, unit, spec, hours)
        if record.cracked then
            return
        end
        if record.head > 0 and record:temperature() <= Lines.HARD_FREEZE_CELSIUS then
            record.cracked = true
            record.head = 0
            record.headTainted = false
            return
        end
        local rate = spec.rate * (record:isClogged(spec) and Treatment.CLOGGED_FACTOR or 1)
        record:pass(unit, rate * hours, FluidType.Water)
    end,
}

-- Time -----------------------------------------------------------------------------------------------

--- `hours` of time on the unit, in steps of an hour at most, the inlet topping the head up before
--- each, so a long catch-up drains the head and then dries the sand in order, unless the inlet keeps
--- it wet. Does nothing while the unit is unloaded.
function TreatmentObject:advance(hours)
    local unit = self:getIsoObject()
    local spec = unit and Treatment.specOf(unit)
    if not spec or hours <= 0 then
        return
    end
    local kind = TreatmentObject.KINDS[spec.kind]
    local tank = self:inletTank(unit)
    while hours > 0 do
        local step = math.min(1, hours)
        if tank and self:draw(tank, step) then
            self.drewFrom = tank
        end
        kind.step(self, unit, spec, step)
        hours = hours - step
    end
end

--- Brings the record up to now while its unit is loaded; an unloaded one keeps its lastHour, so the
--- whole gap is caught up once it loads (at most LONGEST_PASS).
function TreatmentObject:catchUp()
    if self:getIsoObject() then
        self:advance(self:elapsedHours())
    end
end

function TreatmentObject:update()
    if not self:getIsoObject() then
        return
    end
    self:catchUp()
    self:afterChange()
end

-- Sends the basin the clients drink from on, the tank the inlet drew from, and the summary, when
-- they changed.
function TreatmentObject:afterChange()
    local unit = self:getIsoObject()
    if unit and self.basinChanged then
        unit:sync()
    end
    if self.drewFrom then
        Tanks.sync(self.drewFrom)
    end
    self.basinChanged, self.drewFrom = nil, nil
    self:sendSummary()
end

--- Clean Filter: the clogged top of the sand stirred and skimmed, which tears the film.
function TreatmentObject:clean()
    self.passed = 0
    self.ripeHours = math.min(self.ripeHours, Treatment.CLEANED_RIPE_HOURS)
end

--- Scrub Crock: the clogged skin of the clay scrubbed off; nothing grows on a crock to tear.
function TreatmentObject:scrub()
    self.passed = 0
end

-- What every client keeps: the head, to the tenth of a litre, and the state the menu words, in
-- whole hours, so a pass that changes nothing a player sees sends nothing.
function TreatmentObject:buildSummary()
    local spec = self:spec()
    return {
        head = math.floor(self.head * 10 + 0.5) / 10,
        headTainted = self.headTainted,
        ripeHours = math.floor(self.ripeHours),
        dryHours = math.floor(self.dryHours),
        clogged = spec ~= nil and self:isClogged(spec),
        cracked = self.cracked == true,
    }
end

return TreatmentObject
