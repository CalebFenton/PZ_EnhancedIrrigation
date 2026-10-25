-- The authority's record of one pump. Like a treatment unit's, it waits while the squares its water
-- comes from or goes to aren't loaded, keeping its clock, and catches the whole gap up once they
-- are.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpWater"
require "EnhancedIrrigation/Parts"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Lines/LineSystem"
require "EnhancedIrrigation/Pumps/PumpHouse"

EnhancedIrrigation = EnhancedIrrigation or {}

local Sprites, Pumps, Links = EnhancedIrrigation.Sprites, EnhancedIrrigation.Pumps, EnhancedIrrigation.Links

local PumpObject = EnhancedIrrigation.ObjectSystem.Object:derive("EnhancedIrrigation_Pump")
EnhancedIrrigation.PumpObject = PumpObject

-- The world's save format: renaming one loses it from saves. unit: the pump's entity script name,
-- a key of Pumps.ENTITIES, so the record knows its numbers unloaded too; seal: the full type of the
-- seal fitted, nil for none; sealWear: the litres lifted on it; condition: the body's, worn by the
-- litres lifted; intake: { x, y } of the natural water the hose drinks from, nil for none, kept so
-- an unloaded river still counts; lastHour: when time last reached it. A Pump House's: part: the
-- full type of the pump part fitted, nil for none; partCondition, a float, and partCeiling: its
-- condition and the most a repair restores, as its item carried them; on: its switch; timer:
-- { item, start, minutes } of the timer fitted (Valves.lua), nil for none; running: whether it ran
-- at its last pass; grid: whether the grid powered it then; payer: { x, y, z } of the generator
-- that pays for its power, payerFuel: that generator's fuel when last seen, and owedFuel: what it
-- burned since its square was last loaded.
PumpObject.SAVED_FIELDS = { "unit", "seal", "sealWear", "condition", "intake", "lastHour", "part", "partCondition",
    "partCeiling", "on", "timer", "running", "grid", "payer", "payerFuel", "owedFuel" }

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

-- The chunk loaded again: show its timer; the next pass catches up the time it was away.
function PumpObject:stateToIsoObject(isoObject)
    self:show()
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

--- Fits the pump part `item` in the Pump House, as worn as it is, the fraction of a point it was
--- taken out with included, with the ceiling it carries.
function PumpObject:fitPart(item)
    self.part = item:getFullType()
    self.partCondition = item:getCondition() + (item:getModData()[Pumps.FRACTION_KEY] or 0)
    self.partCeiling = EnhancedIrrigation.Parts.ceilingOf(item)
end

--- Takes the Pump House's part out and switches it off. Returns the part as an item, as worn as it
--- was: its whole points as its condition and the rest with it, which Fit Pump adds back, so a
--- part never gains condition by being taken out; and with its ceiling.
function PumpObject:takeOutPart()
    local item = instanceItem(self.part)
    local whole = math.floor(self.partCondition)
    item:setCondition(whole)
    local fraction = self.partCondition - whole
    item:getModData()[Pumps.FRACTION_KEY] = fraction > 0 and fraction or nil
    EnhancedIrrigation.Parts.setCeiling(item, self.partCeiling)
    self.part, self.partCondition, self.partCeiling = nil, nil, nil
    self.on, self.running = nil, nil
    return item
end

--- Mends the Pump House's part: its ceiling lowered by a repair's loss, and it restored to that.
function PumpObject:repairPart()
    self.partCeiling = EnhancedIrrigation.Parts.restores(self.partCeiling, Pumps.REPAIR_LOSS)
    self.partCondition = self.partCeiling
end

--- Finds again where the hose drinks, while the pump's square is loaded (PumpWater.intakeFor),
--- keeping the one it had while that square is unloaded or still water.
function PumpObject:findIntake()
    if not getCell():getGridSquare(self.x, self.y, self.z) then
        return
    end
    local intake = EnhancedIrrigation.PumpWater.intakeFor(self, self.intake)
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

-- Time -----------------------------------------------------------------------------------------------

-- Whether every square the pump's water could come from or go to is loaded: the 3x3 around it,
-- where a well, tank or trough it draws from stands, and its outlet's far end. A river intake counts
-- as loaded, as its water doesn't change. Waiting for all of them means the mod never moves water
-- it can't see.
local function endsLoaded(record)
    if not EnhancedIrrigation.loadedAround(record.x, record.y, record.z) then
        return false
    end
    local into = Links.farEnd(record, "pump")
    return into == nil or EnhancedIrrigation.chunkLoaded(into.x, into.y, into.z)
end

--- `hours` of time on the pump up to now, in steps of an hour at most. Time alone runs only a Pump
--- House (PumpHouse.step); a hand pump runs only while worked. Does nothing while the pump is
--- unloaded.
function PumpObject:advance(hours)
    local pump = self:getIsoObject()
    if not (pump and self:isHouse()) then
        return
    end
    local from = EnhancedIrrigation.now() - hours
    while hours > 0 do
        local step = math.min(1, hours)
        EnhancedIrrigation.PumpHouse.step(self, pump, step, from)
        hours, from = hours - step, from + step
    end
end

--- Brings the record up to now while every square it reaches is loaded (endsLoaded); otherwise it
--- keeps its lastHour, so the whole gap is caught up once they are (at most LONGEST_PASS).
function PumpObject:catchUp()
    local pump = self:getIsoObject()
    if pump and endsLoaded(self) then
        self:findIntake()
        EnhancedIrrigation.ObjectSystem.Object.catchUp(self)
        if self:isHouse() then
            EnhancedIrrigation.PumpHouse.settle(self, pump)
        end
    end
end

-- While unloaded a pump doesn't run, yet afterChange would tell its outlet's line the running of
-- its last pass, marking a tile laid or a line split since as run by it.
function PumpObject:update()
    if self:getIsoObject() then
        EnhancedIrrigation.ObjectSystem.Object.update(self)
    end
end

--- Whether the pump runs now: a hand pump while someone works it, a Pump House while running at its
--- last pass.
function PumpObject:isRunning()
    if self:isHouse() then
        return self.running == true
    end
    return self.holder ~= nil
end

-- A Pump House's overlay: its timer, if one is fitted.
local function isTimerOverlay(name)
    return name == Sprites.HOUSE_TIMER
end

--- Shows a Pump House's timer by its plug while one is fitted. Does nothing while its chunk is
--- unloaded, or at a hand pump.
function PumpObject:show()
    local pump = self:getIsoObject()
    if pump and self:isHouse() then
        EnhancedIrrigation.ObjectSystem.showOverlays(pump, isTimerOverlay, self.timer and { Sprites.HOUSE_TIMER } or {})
    end
end

-- Shows and tells the clients, and the tiles of the line its outlet feeds whether it runs them.
function PumpObject:afterChange()
    self:show()
    self:sendSummary()
    local b = Links.farEnd(self, "pump")
    if b then
        EnhancedIrrigation.LineSystem.setRunning(b.x, b.y, b.z, self:isRunning())
    end
end

-- What every client keeps, as the menu words it, rounded, so wear that changes nothing a player
-- sees sends nothing: a hand pump's seal and body, and who works it now; a Pump House's part, its
-- condition and ceiling, its switch, its timer and whether it runs now; and where the hose drinks.
function PumpObject:buildSummary()
    if self:isHouse() then
        local timer = self.timer
        return {
            part = self.part,
            partCondition = self.part and math.ceil(self.partCondition) or nil,
            partCeiling = self.partCeiling,
            burntOut = self:isBurntOut(),
            on = self.on == true,
            timer = timer and { item = timer.item, start = timer.start, minutes = timer.minutes },
            running = self.running == true,
            intake = self.intake,
        }
    end
    local sealLitres = Pumps.sealLitres(self.seal)
    return {
        seal = self.seal,
        sealPercent = sealLitres and math.ceil(100 * self:sealLeft() / sealLitres) or 0,
        sealWorn = self:sealLeft() <= 0,
        condition = math.ceil(self.condition),
        wornOut = self:isWornOut(),
        intake = self.intake,
        heldBy = self.heldBy,
    }
end

return PumpObject
