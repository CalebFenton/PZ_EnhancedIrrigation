-- The authority's record of one treatment unit: the raw water in its head and what time and use
-- have done to it. Time tops the head up from an inlet's tank, treats it into the basin as its kind
-- says (KINDS) and empties the basin into an outlet's tank; Pour In and the jobs change the rest.
-- Unlike a line tile's, a unit's record waits while its chunk is unloaded, as the basin it fills
-- lives on the unit, and catches up the whole gap when it loads, its inlet and outlet running
-- through the gap as they would have loaded.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Frost"
require "EnhancedIrrigation/ObjectSystem"

EnhancedIrrigation = EnhancedIrrigation or {}

local Treatment, Tanks, Frost = EnhancedIrrigation.Treatment, EnhancedIrrigation.Tanks, EnhancedIrrigation.Frost
local Links = EnhancedIrrigation.Links

local TreatmentObject = EnhancedIrrigation.ObjectSystem.Object:derive("EnhancedIrrigation_Treatment")
EnhancedIrrigation.TreatmentObject = TreatmentObject

-- Fewer litres than this left in a head count as none, so the rounding of a pass leaves no drop
-- that keeps the sand wet.
local EMPTY_HEAD = 0.001

-- The world's save format: renaming one loses it from saves. unit: the unit's entity script name,
-- a key of Treatment.UNITS, so the record knows its numbers unloaded too; head: litres of raw water
-- waiting; headTainted: whether any of it is tainted; passed: litres treated since the last
-- cleaning; ripeHours: wet hours the sand's film has grown; dryHours: hours since the head ran dry;
-- cracked: a crock frost split; bucket: the full type of the bucket a crock stands in; hotHours: a
-- boiler drum's heat, as hours of fire; condition and ceiling: its drum's condition and what it was
-- last built or patched up to; fireLit and fuel: its fire as it was at lastHour, whether lit and
-- its fuel's minutes; lastHour: when time last reached it.
TreatmentObject.SAVED_FIELDS = { "unit", "head", "headTainted", "passed", "ripeHours", "dryHours", "cracked",
    "bucket", "hotHours", "condition", "ceiling", "fireLit", "fuel", "lastHour" }

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
-- Its kind sets up what only it keeps.
function TreatmentObject:stateFromIsoObject(isoObject)
    self:initNew()
    self.unit = EnhancedIrrigation.entityName(isoObject)
    local kind = TreatmentObject.KINDS[self:spec().kind]
    if kind.init then
        kind.init(self)
    end
    self.summary = self:buildSummary()
end

-- The chunk loaded again; the next pass catches up the time it was away.
function TreatmentObject:stateToIsoObject(isoObject)
end

function TreatmentObject:spec()
    return self.unit and Treatment.UNITS[self.unit]
end

--- The litres of raw water the head has room for.
function TreatmentObject:headRoom()
    return math.max(0, self:spec().head - self.head)
end

--- Takes up to `most` litres of raw water out of `fluid` (a FluidContainer) into the head, as far
--- as `fluid` holds and the head has room, unless that comes to less than `least`; the taint goes
--- with it. Returns the litres taken.
function TreatmentObject:takeFrom(fluid, most, least)
    local litres = math.min(most, fluid:getAmount(), self:headRoom())
    if least and litres < least then
        return 0
    end
    local tainted = fluid:isTainted()
    fluid:removeFluid(litres, false)
    self.head = self.head + litres
    self.headTainted = self.headTainted or tainted
    return litres
end

-- The tank at the far end of `record`'s `role` link ("inlet" or "outlet"), while it is loaded and
-- water runs that way between it and `unit` (Treatment.runsFor); or nil.
local function tankOf(record, unit, role)
    local at = Links.farEnd(record, role)
    local tank = at and Tanks.tankAt(at.x, at.y, at.z)
    if tank and Treatment.runsFor(role, tank, unit) then
        return tank
    end
    return nil
end

--- Tops the head up from `tank` with what a link carries in `hours`, while the tank holds water and
--- nothing else. Returns whether any moved.
function TreatmentObject:draw(tank, hours)
    local fluid = tank:getFluidContainer()
    if self:isBurntThrough() or not Treatment.isWater(fluid) then
        return false
    end
    return self:takeFrom(fluid, Links.RATE * hours, Links.LEAST_FLOW) > 0
end

--- Empties the basin of `unit` into `tank` by what a link carries in `hours`, as far as the tank
--- has room; the mixture moves as it is. Returns whether any moved.
function TreatmentObject:drain(unit, tank, hours)
    if not Links.carry(unit:getFluidContainer(), tank:getFluidContainer(), Links.RATE * hours) then
        return false
    end
    self.basinChanged = true
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
    if self.head < EMPTY_HEAD then
        self:spill()
    end
    self.basinChanged = true
    return litres
end

--- Empties the head: the raw water waiting runs out, and its taint with it.
function TreatmentObject:spill()
    self.head = 0
    self.headTainted = false
end

-- Kinds ---------------------------------------------------------------------------------------------

--- Each kind's time: `step(record, unit, spec, hours)`, what an hour or less does to it; and, if
--- it keeps more, `init(record)` for a new record, `begin(record, unit, hours)` before a run of
--- steps and `finish(record, unit)` after any run, however short.
TreatmentObject.KINDS = {}

--- Whether the sand filter's film is grown: it cleans what passes.
function TreatmentObject:isRipe()
    return self.ripeHours >= Treatment.RIPE_HOURS
end

--- Whether the unit has passed its spec's clogLitres since the last cleaning.
function TreatmentObject:isClogged(spec)
    return spec.clogLitres ~= nil and self.passed >= spec.clogLitres
end

--- The litres an hour the unit treats: its spec's rate, a trickle once clogged.
function TreatmentObject:rate(spec)
    return spec.rate * (self:isClogged(spec) and Treatment.CLOGGED_FACTOR or 1)
end

--- Whether a boiler's drum has burnt through: a hole that holds nothing.
function TreatmentObject:isBurntThrough()
    return self.condition ~= nil and self.condition <= 0
end

-- A drum this close to HOT_HOURS counts as hot: heat added up in ten-minute passes falls short of a
-- whole hour by a rounding.
local HOT_SLACK = 1e-6

--- Whether a boiler's drum is hot enough to make its water safe.
function TreatmentObject:isHot()
    return (self.hotHours or 0) >= Treatment.HOT_HOURS - HOT_SLACK
end

-- The film grows while water stands on the sand and dies once the sand has stood dry long enough
-- (DRY_DEATH_HOURS), or when a hard freeze turns the water on it to ice, which also stops the flow.
-- A grown film passes clean water; an unripe one passes the head's own.
TreatmentObject.KINDS.sand = {
    step = function(record, unit, spec, hours)
        if record.head > 0 then
            record.dryHours = 0
            if Frost.isHard(record) then
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
        record:pass(unit, record:rate(spec) * hours, fluid)
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
        if record.head > 0 and Frost.isHard(record) then
            record.cracked = true
            record:spill()
            return
        end
        record:pass(unit, record:rate(spec) * hours, FluidType.Water)
    end,
}

-- Time -----------------------------------------------------------------------------------------------

--- `hours` of time on the unit, in steps of an hour at most, the inlet topping the head up before
--- each and the outlet emptying the basin after, so a long catch-up drains the head and then dries
--- the sand in order, unless the inlet keeps it wet, and the basin fills only while the outlet
--- can't keep up. Does nothing while the unit is unloaded.
function TreatmentObject:advance(hours)
    local unit = self:getIsoObject()
    local spec = unit and Treatment.specOf(unit)
    if not spec then
        return
    end
    local kind = TreatmentObject.KINDS[spec.kind]
    if hours > 0 then
        if kind.begin then
            kind.begin(self, unit, hours)
        end
        local inlet, outlet = tankOf(self, unit, "inlet"), tankOf(self, unit, "outlet")
        while hours > 0 do
            local step = math.min(1, hours)
            if inlet and self:draw(inlet, step) then
                self.drewFrom = inlet
            end
            kind.step(self, unit, spec, step)
            if outlet and self:drain(unit, outlet, step) then
                self.drainedInto = outlet
            end
            hours = hours - step
        end
    end
    if kind.finish then
        kind.finish(self, unit)
    end
end

-- Whether the far end of `record`'s inlet or outlet is in a chunk this side hasn't loaded: its
-- tank may hold the water, or the room, that would have kept the unit running, which can't be
-- known until it loads. A loaded square with no tank on it feeds and takes nothing, and the unit
-- runs on.
local function endsUnloaded(record)
    for _, role in ipairs({ "inlet", "outlet" }) do
        local at = Links.farEnd(record, role)
        if at and not EnhancedIrrigation.chunkLoaded(at.x, at.y, at.z) then
            return true
        end
    end
    return false
end

--- Brings the record up to now while its unit is loaded, and the tanks at its inlet's and outlet's
--- far ends too; otherwise it keeps its lastHour, so the whole gap is caught up once all load (at
--- most LONGEST_PASS), the pipes running through the gap as they would have.
function TreatmentObject:catchUp()
    if self:getIsoObject() and not endsUnloaded(self) then
        EnhancedIrrigation.ObjectSystem.Object.catchUp(self)
    end
end

-- Sends the basin the clients drink from on, the tanks the inlet drew from and the outlet filled,
-- and the summary, when they changed.
function TreatmentObject:afterChange()
    local unit = self:getIsoObject()
    if unit and self.basinChanged then
        unit:sync()
    end
    if self.drewFrom then
        self.drewFrom:sync()
    end
    if self.drainedInto then
        self.drainedInto:sync()
    end
    self.basinChanged, self.drewFrom, self.drainedInto = nil, nil, nil
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

-- What every client keeps: the head and the state the menu words, rounded, so a pass that changes
-- nothing a player sees sends nothing.
function TreatmentObject:buildSummary()
    local spec = self:spec()
    return {
        head = math.floor(self.head * 10 + 0.5) / 10,
        ripeHours = math.floor(self.ripeHours),
        dryHours = math.floor(self.dryHours),
        clogged = spec ~= nil and self:isClogged(spec),
        cracked = self.cracked == true,
        hot = self:isHot(),
        condition = self.condition and math.ceil(self.condition),
        ceiling = self.ceiling,
        burntThrough = self:isBurntThrough(),
    }
end

return TreatmentObject
