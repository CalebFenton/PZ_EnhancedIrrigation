-- The authority's record of one pump (shared/EnhancedIrrigation/Pumps.lua): its seal and how far
-- it has worn, its body's condition, and where its hose drinks. Lifting water wears both
-- (PumpObject.lift). Like a treatment unit's, a pump's record waits while its square, the squares
-- it draws from or its outlet's tank aren't loaded, keeping its clock, and catches the whole gap up
-- once they are; time alone moves no water through a hand pump, which runs only while worked.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/ObjectSystem"

EnhancedIrrigation = EnhancedIrrigation or {}

local Pumps = EnhancedIrrigation.Pumps

local PumpObject = EnhancedIrrigation.ObjectSystem.Object:derive("EnhancedIrrigation_Pump")
EnhancedIrrigation.PumpObject = PumpObject

-- The world's save format: renaming one loses it from saves. unit: the pump's entity script name,
-- a key of Pumps.UNITS, so the record knows its numbers unloaded too; seal: the full type of the
-- seal fitted, nil for none; sealWear: the litres lifted on it; condition: the body's, worn by the
-- litres lifted; intake: { x, y } of the natural water the hose drinks from, nil for none, kept so
-- an unloaded river still counts; lastHour: when time last reached it.
PumpObject.SAVED_FIELDS = { "unit", "seal", "sealWear", "condition", "intake", "lastHour" }

function PumpObject:initNew()
    self.sealWear = 0
    self.condition = Pumps.BODY_CONDITION
    self.lastHour = EnhancedIrrigation.now()
end

-- A pump without a record: a fresh one, or one whose record was lost with the system's save file,
-- which then has no seal it knows of until one is fitted.
function PumpObject:stateFromIsoObject(isoObject)
    self:initNew()
    self.unit = EnhancedIrrigation.entityName(isoObject)
    self:findIntake()
    self.summary = self:buildSummary()
end

-- The chunk loaded again; the next pass catches up the time it was away.
function PumpObject:stateToIsoObject(isoObject)
end

function PumpObject:spec()
    return self.unit and Pumps.UNITS[self.unit]
end

--- The litres the seal fitted has left to lift, 0 without one.
function PumpObject:sealLeft()
    local litres = Pumps.sealLitres(self.seal)
    return litres and math.max(0, litres - self.sealWear) or 0
end

function PumpObject:isWornOut()
    return self.condition <= 0
end

--- Fits `seal` (a full type), new.
function PumpObject:fitSeal(seal)
    self.seal = seal
    self.sealWear = 0
end

--- Finds again where the hose drinks, while the pump's square is loaded (Pumps.intakeFor), keeping
--- the one it had while that square is unloaded or still water.
function PumpObject:findIntake()
    if not getCell():getGridSquare(self.x, self.y, self.z) then
        return
    end
    local intake = Pumps.intakeFor(self, self.intake)
    self.intake = intake and { x = intake.x, y = intake.y } or nil
end

--- The litres a lift of `litres` can take before the seal or the body gives out.
function PumpObject:canLift(litres)
    local spec = self:spec()
    return math.max(0, math.min(litres, self:sealLeft(), self.condition * spec.wearLitres))
end

--- Wears the seal and the body by `litres` lifted. What's left of either below the least a pump
--- moves counts as spent: the litres a draw hands back are a float, which can fall a hair short of
--- the last litres asked for and leave a seal or body that lifts nothing but never wears out.
function PumpObject:lift(litres)
    local wearLitres = self:spec().wearLitres
    self.sealWear = self.sealWear + litres
    if self:sealLeft() < Pumps.LEAST_LITRES then
        self.sealWear = Pumps.sealLitres(self.seal) or self.sealWear
    end
    self.condition = math.max(0, self.condition - litres / wearLitres)
    if self.condition * wearLitres < Pumps.LEAST_LITRES then
        self.condition = 0
    end
end

-- Kinds ---------------------------------------------------------------------------------------------

--- What an hour or less of time does to a pump of each kind: `step(record, pump, spec, hours)`, or
--- none when time alone does nothing. A hand pump runs only while worked.
PumpObject.KINDS = {
    hand = {},
}

-- Time -----------------------------------------------------------------------------------------------

local function loaded(at)
    return getCell():getGridSquare(at.x, at.y, at.z) ~= nil
end

--- Whether every square the pump's water could come from or go to is loaded: its own, the eight
--- around it that hold a well, tank or trough, and its outlet's far end. A river intake counts as
--- loaded, as its water doesn't change. Links reach ten tiles, so these load together; waiting for
--- all of them means the mod never moves water it can't see.
function PumpObject:endsLoaded()
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not loaded({ x = self.x + dx, y = self.y + dy, z = self.z }) then
                return false
            end
        end
    end
    local outlet = Pumps.outletOf(self)
    return outlet == nil or loaded(outlet.b)
end

--- `hours` of time on the pump, in steps of an hour at most, as its kind says. Does nothing while
--- the pump is unloaded.
function PumpObject:advance(hours)
    local pump = self:getIsoObject()
    local spec = pump and Pumps.specOf(pump)
    local kind = spec and PumpObject.KINDS[spec.kind]
    if not (kind and kind.step) then
        return
    end
    while hours > 0 do
        local step = math.min(1, hours)
        kind.step(self, pump, spec, step)
        hours = hours - step
    end
end

--- Brings the record up to now while every square it reaches is loaded (endsLoaded); otherwise it
--- keeps its lastHour, so the whole gap is caught up once they are (at most LONGEST_PASS).
function PumpObject:catchUp()
    if self:getIsoObject() and self:endsLoaded() then
        self:findIntake()
        self:advance(self:elapsedHours())
    end
end

function PumpObject:update()
    if not self:getIsoObject() then
        return
    end
    self:catchUp()
    self:afterChange()
end

function PumpObject:afterChange()
    self:sendSummary()
end

-- What every client keeps: the seal and the body as the menu words them, rounded, so lifting that
-- changes nothing a player sees sends nothing, and where the hose drinks.
function PumpObject:buildSummary()
    local sealLitres = Pumps.sealLitres(self.seal)
    return {
        seal = self.seal,
        sealLeft = sealLitres and math.ceil(100 * self:sealLeft() / sealLitres) or 0,
        sealWorn = self:sealLeft() <= 0,
        condition = math.ceil(self.condition),
        wornOut = self:isWornOut(),
        intake = self.intake,
    }
end

return PumpObject
