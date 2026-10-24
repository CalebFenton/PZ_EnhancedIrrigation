-- The authority's record of one pump (shared/EnhancedIrrigation/Pumps.lua): a hand pump's seal and
-- how far it has worn, and its body's condition, which lifting water wears (PumpObject.lift); a
-- Pump House's part, its condition, its switch and who pays for its power (Pumps/PumpHouse.lua);
-- and where its hose drinks. Like a treatment unit's, a pump's record waits while its square, the
-- squares it draws from or its outlet's tank aren't loaded, keeping its clock, and catches the
-- whole gap up once they are; time alone moves no water through a hand pump, which runs only while
-- worked, but runs a Pump House that is switched on.

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
-- an unloaded river still counts; lastHour: when time last reached it. A Pump House's: part: the
-- full type of the pump part fitted, nil for none; partCondition, a float, and partCeiling: its
-- condition and the most a repair restores, as its item carried them; on: its switch; running:
-- whether it ran at its last pass; grid: whether the grid powered it then; payer: { x, y, z } of the
-- generator that pays for its power, payerFuel: that generator's fuel when last seen, and owedFuel:
-- what it burned since its square was last loaded.
PumpObject.SAVED_FIELDS = { "unit", "seal", "sealWear", "condition", "intake", "lastHour", "part", "partCondition",
    "partCeiling", "on", "running", "grid", "payer", "payerFuel", "owedFuel" }

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

function PumpObject:isHouse()
    local spec = self:spec()
    return spec ~= nil and spec.kind == "house"
end

--- Whether the Pump House's part is burnt out.
function PumpObject:isBurntOut()
    return self.part ~= nil and self.partCondition <= 0
end

--- Fits the pump part `item` in the Pump House, as worn as it is, with the ceiling it carries.
function PumpObject:fitPart(item)
    self.part = item:getFullType()
    self.partCondition = item:getCondition()
    self.partCeiling = Pumps.ceilingOf(item)
end

--- Takes the Pump House's part out and switches it off. Returns the part as an item, as worn as it
--- was, with its ceiling.
function PumpObject:takeOutPart()
    local item = instanceItem(self.part)
    item:setCondition(math.ceil(self.partCondition))
    Pumps.setCeiling(item, self.partCeiling)
    self.part, self.partCondition, self.partCeiling = nil, nil, nil
    self.on, self.running = nil, nil
    return item
end

--- Mends the Pump House's part: its ceiling lowered by a repair's loss, and it restored to that.
function PumpObject:repairPart()
    self.partCeiling = self.partCeiling - Pumps.REPAIR_LOSS
    self.partCondition = self.partCeiling
end

--- Moves `litres` from `source` (Pumps.sourceOf) into `fluid` (a FluidContainer) and returns the
--- litres moved. A well's or river's water comes from its tile, which is endless (vanilla's own
--- draw, IsoObject.transferFluidTo), never from a well's own container, which vanilla never draws
--- either; a tank or trough gives its mixture, taint and all, and is sent to the clients. A river
--- whose square isn't loaded is still water, always tainted.
function PumpObject.draw(source, fluid, litres)
    if not source.object then
        fluid:addFluid(FluidType.TaintedWater, litres)
        return litres
    end
    local moved = source.object:transferFluidTo(fluid, litres)
    if not source.infinite then
        source.object:sync()
    end
    return moved
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

--- What time does to a pump of each kind: `step(record, pump, spec, hours, from)`, what an hour or
--- less from the world hour `from` does; and `settle(record, pump)`, what follows from how things
--- stand once it has caught up, loaded. A hand pump has neither: it runs only while worked. The
--- Pump House's are Pumps/PumpHouse.lua's.
PumpObject.KINDS = {
    hand = {},
    house = {},
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

--- `hours` of time on the pump up to now, in steps of an hour at most, as its kind says. Does
--- nothing while the pump is unloaded.
function PumpObject:advance(hours)
    local pump = self:getIsoObject()
    local spec = pump and Pumps.specOf(pump)
    local kind = spec and PumpObject.KINDS[spec.kind]
    if not (kind and kind.step) then
        return
    end
    local from = EnhancedIrrigation.now() - hours
    while hours > 0 do
        local step = math.min(1, hours)
        kind.step(self, pump, spec, step, from)
        hours, from = hours - step, from + step
    end
end

--- Brings the record up to now while every square it reaches is loaded (endsLoaded); otherwise it
--- keeps its lastHour, so the whole gap is caught up once they are (at most LONGEST_PASS).
function PumpObject:catchUp()
    local pump = self:getIsoObject()
    if pump and self:endsLoaded() then
        self:findIntake()
        self:advance(self:elapsedHours())
        local spec = Pumps.specOf(pump)
        local kind = spec and PumpObject.KINDS[spec.kind]
        if kind and kind.settle then
            kind.settle(self, pump)
        end
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

-- What every client keeps, as the menu words it, rounded, so wear that changes nothing a player
-- sees sends nothing: a hand pump's seal and body, and who works it now (PumpSystem.hold); a Pump
-- House's part, its condition and ceiling, its switch and whether it runs now; and where the hose
-- drinks.
function PumpObject:buildSummary()
    if self:isHouse() then
        return {
            part = self.part,
            partCondition = self.part and math.ceil(self.partCondition) or nil,
            partCeiling = self.partCeiling,
            burntOut = self:isBurntOut(),
            on = self.on == true,
            running = self.running == true,
            intake = self.intake,
        }
    end
    local sealLitres = Pumps.sealLitres(self.seal)
    return {
        seal = self.seal,
        sealLeft = sealLitres and math.ceil(100 * self:sealLeft() / sealLitres) or 0,
        sealWorn = self:sealLeft() <= 0,
        condition = math.ceil(self.condition),
        wornOut = self:isWornOut(),
        intake = self.intake,
        heldBy = self.heldBy,
    }
end

return PumpObject
