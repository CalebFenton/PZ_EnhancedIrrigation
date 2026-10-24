-- The authority's record of one treatment unit (shared/EnhancedIrrigation/Treatment/Treatment.lua): the raw
-- water in its head and what time and use have done to it. Time tops the head up from an inlet's
-- tank and treats it into the basin as its kind says (KINDS); Pour In and the jobs
-- (TreatmentSystem.lua) change the rest. Unlike a line tile's, a unit's record waits while its chunk
-- is unloaded, as the basin it fills lives on the unit, and catches up the whole gap when it loads,
-- its inlet feeding it through the gap as it would have loaded. A boiler's fire is vanilla's
-- fireplace, which the record reads, never runs.

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

-- A head with less than this left counts as empty.
local LEAST_LITRES = 0.001
-- A draw from an inlet's tank smaller than this isn't worth a sync to every client.
local LEAST_DRAWN = 0.01

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

--- Adds `litres` of raw water to the head, `tainted` or not; the caller kept to its room.
function TreatmentObject:fill(litres, tainted)
    self.head = self.head + litres
    self.headTainted = self.headTainted or tainted == true
end

--- The tank the unit's inlet draws from: the one at the far end of its inlet link, while it is
--- loaded and stands at least level with `unit` (design, Tanks and height); or nil.
function TreatmentObject:inletTank(unit)
    local link = Links.roleAt(self, "inlet")
    local at = link and Links.otherEnd(link, self)
    local tank = at and Tanks.tankAt(at.x, at.y, at.z)
    if tank and Treatment.runsFor("inlet", tank, unit) then
        return tank
    end
    return nil
end

--- Whether a boiler's drum has burnt through: a hole that holds nothing.
function TreatmentObject:isBurntThrough()
    return self.condition ~= nil and self.condition <= 0
end

--- Tops the head up from `tank` with what a link carries in `hours`, while the tank holds water and
--- nothing else and the head can hold it; the taint goes with it. Returns whether any moved.
function TreatmentObject:draw(tank, hours)
    local fluid = tank:getFluidContainer()
    if self:isBurntThrough() or not Treatment.isWater(fluid) then
        return false
    end
    local litres = math.min(Links.RATE * hours, fluid:getAmount(), self:spec().head - self.head)
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
        if record.head > 0 and Frost.isHard(record) then
            record.cracked = true
            record.head = 0
            record.headTainted = false
            return
        end
        local rate = spec.rate * (record:isClogged(spec) and Treatment.CLOGGED_FACTOR or 1)
        record:pass(unit, rate * hours, FluidType.Water)
    end,
}

-- A drum this close to HOT_HOURS counts as hot: heat added up in ten-minute passes falls short of a
-- whole hour by a rounding.
local HOT_SLACK = 1e-6

--- Whether a boiler's drum is hot enough to make its water safe.
function TreatmentObject:isHot()
    return (self.hotHours or 0) >= Treatment.HOT_HOURS - HOT_SLACK
end

-- How much of `lit` hours of fire then `unlit` hours without a drum of heat `hotHours` spends hot,
-- and its heat after: the fire warms it an hour of heat an hour up to HEAT_MAX_HOURS, and it cools
-- COOLING times as fast. Worked through within the step, so ten-minute passes and an hour's
-- catch-up pass the same water.
local function heat(hotHours, lit, unlit)
    local hot = math.max(0, lit - math.max(0, Treatment.HOT_HOURS - hotHours))
    hotHours = math.min(Treatment.HEAT_MAX_HOURS, hotHours + lit)
    hot = hot + math.min(unlit, math.max(0, (hotHours - Treatment.HOT_HOURS) / Treatment.COOLING))
    return hot, math.max(0, hotHours - Treatment.COOLING * unlit)
end

-- The longest a fire lit since the last pass can have burned: the ten-minute pass's span, as a
-- player can light one only while the boiler is loaded, where the passes run.
local PASS_HOURS = 10 / 60

-- The boiler's fire is the fireplace's: vanilla burns its fuel down a minute a minute while its
-- square is loaded, catches a reloaded one up from the world's clock as it loads, and puts it out
-- when the fuel runs out. The record notes the fire after every pass and, catching up, burns what
-- it noted down the same way: a fire lit at lastHour burned from the gap's start for as long as
-- its fuel then lasted, whatever order the game's catch-up and the record's run in after a reload.
-- A fire burning now that wasn't then, or was refuelled since, burned at least the last pass's
-- span. The fire heats the drum (heat); while hot it passes clean water at its rate. Fire wears
-- the drum, slowly while water carries the heat off and fast run dry; burnt through, its water
-- runs out and it holds and passes nothing.
TreatmentObject.KINDS.boiler = {
    init = function(record)
        record.hotHours = 0
        record.condition = Treatment.DRUM_CONDITION
        record.ceiling = Treatment.DRUM_CONDITION
        record.fireLit = false
        record.fuel = 0
    end,
    begin = function(record, unit, hours)
        local noted = record.fireLit and record.fuel / 60 or 0
        record.burnLeft = math.min(hours, unit:isLit() and math.max(noted, PASS_HOURS) or noted)
    end,
    step = function(record, unit, spec, hours)
        local lit = math.min(hours, record.burnLeft)
        record.burnLeft = record.burnLeft - lit
        if record:isBurntThrough() then
            -- A holed drum still warms and cools with the fire under it, so a patch finds it only as
            -- hot as a fire has kept it since.
            local _
            _, record.hotHours = heat(record.hotHours, lit, hours - lit)
            return
        end
        local wear = record.head > 0 and Treatment.WEAR_WET or Treatment.WEAR_DRY
        record.condition = math.max(0, record.condition - wear * lit)
        local hot
        hot, record.hotHours = heat(record.hotHours, lit, hours - lit)
        if record:isBurntThrough() then
            record.head = 0
            record.headTainted = false
            return
        end
        record:pass(unit, spec.rate * hot, FluidType.Water)
    end,
    finish = function(record, unit)
        record.fireLit, record.fuel, record.burnLeft = unit:isLit(), unit:getFuelAmount(), nil
    end,
}

-- Time -----------------------------------------------------------------------------------------------

--- `hours` of time on the unit, in steps of an hour at most, the inlet topping the head up before
--- each, so a long catch-up drains the head and then dries the sand in order, unless the inlet keeps
--- it wet. A kind may look at the unit before the steps (`begin`) and, however short the time, after
--- (`finish`). Does nothing while the unit is unloaded.
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
    if kind.finish then
        kind.finish(self, unit)
    end
end

--- Whether the unit's inlet runs from a square this side hasn't loaded: its tank may hold water
--- that would have kept the head topped up, which can't be known until it loads. A loaded square
--- with no tank on it feeds nothing, and the unit runs on.
function TreatmentObject:inletUnloaded()
    local link = Links.roleAt(self, "inlet")
    local at = link and Links.otherEnd(link, self)
    return at ~= nil and getCell():getGridSquare(at.x, at.y, at.z) == nil
end

--- Brings the record up to now while its unit is loaded, and its inlet's tank too if it has one;
--- otherwise it keeps its lastHour, so the whole gap is caught up once both load (at most
--- LONGEST_PASS), the inlet feeding it through the gap as it would have.
function TreatmentObject:catchUp()
    if self:getIsoObject() and not self:inletUnloaded() then
        EnhancedIrrigation.ObjectSystem.Object.catchUp(self)
    end
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

--- Patch Drum: the patch restores the drum to a little less than the last one did.
function TreatmentObject:patch()
    self.ceiling = self.ceiling - Treatment.PATCH_LOSS
    self.condition = self.ceiling
end

-- What every client keeps: the head and the state the menu words, rounded, so a pass that changes
-- nothing a player sees sends nothing.
function TreatmentObject:buildSummary()
    local spec = self:spec()
    return {
        head = math.floor(self.head * 10 + 0.5) / 10,
        headTainted = self.headTainted,
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
