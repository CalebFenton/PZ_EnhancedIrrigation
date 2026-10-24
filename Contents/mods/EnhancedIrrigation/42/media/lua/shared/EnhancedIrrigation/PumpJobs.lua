-- The hands-on jobs at a pump (Pumps.lua), done on the authority by
-- server/EnhancedIrrigation/Pumps/PumpSystem.lua: at a hand pump, Pump, which runs for as long as
-- the character works the handle (TimedActions/EnhancedIrrigationPumpAction.lua), and Replace Seal,
-- whose `with` is the seal carried; at a Pump House, Fit Pump, whose `with` is the pump part carried,
-- Take Out Pump, Turn On, Turn Off and Repair Pump. A pump's outlet is LinkJobs' Plumb Pump.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Pumps"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpJobs = {}
EnhancedIrrigation.PumpJobs = PumpJobs

local Pumps, Tanks = EnhancedIrrigation.Pumps, EnhancedIrrigation.Tanks

PumpJobs.PUMP = "Pump"
PumpJobs.REPLACE_SEAL = "ReplaceSeal"
PumpJobs.FIT_PUMP = "FitPump"
PumpJobs.TAKE_OUT_PUMP = "TakeOutPump"
PumpJobs.TURN_ON = "TurnOn"
PumpJobs.TURN_OFF = "TurnOff"
PumpJobs.REPAIR_PUMP = "RepairPump"

-- Minutes to take a hand pump's cap off, swap the cup on its plunger and screw it back.
PumpJobs.SEAL_MINUTES = 10
-- Minutes to bolt a pump part into a Pump House and wire it up, to take one out, to flip its
-- switch, and to rewind and reseal a burnt pump.
PumpJobs.FIT_MINUTES = 15
PumpJobs.TAKE_OUT_MINUTES = 10
PumpJobs.SWITCH_MINUTES = 1
PumpJobs.REPAIR_MINUTES = 30

-- The Tooltip key saying how high a pump of each lift fills a tank.
PumpJobs.LIFT_KEYS = {
    [1] = "Tooltip_EnhancedIrrigation_LiftsOneStorey",
    [2] = "Tooltip_EnhancedIrrigation_LiftsTwoStoreys",
}

--- Whether `character` is too tired to work a pump.
function PumpJobs.exhausted(character)
    return character:getStats():get(CharacterStat.ENDURANCE) <= Pumps.EXHAUSTED
end

--- What a pump lifting by `spec` (a row of Pumps.UNITS or Pumps.PARTS) would lift into, as this
--- side sees it: its outlet's tank, while that stands within its lift and has room, and the source
--- it draws from (Pumps.sourceOf, with the hose's `intake`). Returns the tank and the source, or nil
--- and the Tooltip key of why it lifts nothing.
function PumpJobs.deliveryOf(pump, spec, intake)
    local outlet = Pumps.outletOf(EnhancedIrrigation.squareOf(pump))
    if not outlet then
        return nil, "Tooltip_EnhancedIrrigation_NoOutlet"
    end
    local tank = Tanks.tankAt(outlet.b.x, outlet.b.y, outlet.b.z)
    if not tank then
        return nil, "Tooltip_EnhancedIrrigation_TankGone"
    end
    -- A barrel set on a stand at the far end since it was plumbed may stand out of its reach.
    if not Pumps.lifts(spec, Tanks.levelOf(tank), pump:getZ()) then
        return nil, PumpJobs.LIFT_KEYS[spec.lift]
    end
    if tank:getFluidContainer():getFreeCapacity() < Pumps.LEAST_LITRES then
        return nil, "Tooltip_EnhancedIrrigation_OutletFull"
    end
    local source = Pumps.sourceOf(pump, intake, outlet.b)
    if not source or source.dry then
        return nil, "Tooltip_EnhancedIrrigation_NoWaterToDraw"
    end
    return tank, source
end

--- What the hand pump `pump` would lift into, as this side sees it (PumpJobs.deliveryOf), unless
--- its body or seal is worn out. Returns the tank and the source, or nil and the Tooltip key of why
--- it lifts nothing.
function PumpJobs.flowOf(pump)
    local spec, summary = Pumps.specOf(pump), Pumps.currentSummary(pump)
    if not (spec and spec.kind == "hand" and summary) then
        return nil, "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    if summary.wornOut then
        return nil, "Tooltip_EnhancedIrrigation_PumpWornOut"
    end
    if summary.sealWorn then
        return nil, "Tooltip_EnhancedIrrigation_SealWornOut"
    end
    return PumpJobs.deliveryOf(pump, spec, summary.intake)
end

--- What a Pump House's next Repair Pump would restore its part to, from its `summary`: the ceiling,
--- lowered by a repair's loss.
function PumpJobs.repairRestores(summary)
    return summary.partCeiling - Pumps.REPAIR_LOSS
end

-- A Pump House's summary as this side knows it, when `pump` is one; else nil.
local function houseSummary(pump)
    return Pumps.isHouse(pump) and Pumps.currentSummary(pump) or nil
end

-- Why a job that needs a part fitted in the Pump House `pump` is refused, or nil, and its summary.
local function fittedBlocker(pump)
    local summary = houseSummary(pump)
    if not summary then
        return "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    return not summary.part and "Tooltip_EnhancedIrrigation_NoPumpFitted" or nil, summary
end

-- The screwdriver the jobs at a pump hold.
local function screwdriver(character)
    return character:getInventory():getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, EnhancedIrrigation.notBroken)
end

local SCREWDRIVER = { tool = "SCREWDRIVER", item = "Base.Screwdriver" }

--- Whether `item` is a pump part `character` carries.
function PumpJobs.carriesPart(character, item)
    return instanceof(item, "InventoryItem") and Pumps.partSpec(item:getFullType()) ~= nil
        and character:getInventory():containsRecursive(item)
end

PumpJobs.JOBS = {
    -- Worked for as long as the character keeps at it, so it has no minutes of its own.
    [PumpJobs.PUMP] = {
        blocker = function(character, pump)
            -- Someone else works the handle (PumpSystem.hold).
            local summary = Pumps.currentSummary(pump)
            if summary and summary.heldBy and summary.heldBy ~= character:getUsername() then
                return "Tooltip_EnhancedIrrigation_PumpInUse"
            end
            local tank, refusal = PumpJobs.flowOf(pump)
            if not tank then
                return refusal
            end
            return PumpJobs.exhausted(character) and "Tooltip_EnhancedIrrigation_Exhausted" or nil
        end,
    },
    -- The old seal is worn to nothing, so it doesn't come back.
    [PumpJobs.REPLACE_SEAL] = {
        minutes = PumpJobs.SEAL_MINUTES, position = "Mid", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump, item)
            local spec = Pumps.specOf(pump)
            if not (spec and spec.kind == "hand") then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            if not (instanceof(item, "InventoryItem") and Pumps.sealLitres(item:getFullType())
                    and character:getInventory():containsRecursive(item)) then
                return "Tooltip_EnhancedIrrigation_NoSeal"
            end
            local summary = Pumps.currentSummary(pump)
            return summary and summary.wornOut and "Tooltip_EnhancedIrrigation_PumpWornOut" or nil
        end,
        materials = function(character, pump, item)
            local list = { SCREWDRIVER }
            if instanceof(item, "InventoryItem") then
                table.insert(list, { item = item:getFullType(), need = 1 })
            end
            return list
        end,
    },
    -- The part goes in as worn as it is; its item is taken by the job itself, being that one item
    -- rather than any of its type.
    [PumpJobs.FIT_PUMP] = {
        minutes = PumpJobs.FIT_MINUTES, position = "Low", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump, item)
            local summary = houseSummary(pump)
            if not summary then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            if summary.part then
                return "Tooltip_EnhancedIrrigation_PumpFitted"
            end
            return not PumpJobs.carriesPart(character, item) and "Tooltip_EnhancedIrrigation_NoPumpPart" or nil
        end,
        materials = { SCREWDRIVER },
    },
    [PumpJobs.TAKE_OUT_PUMP] = {
        minutes = PumpJobs.TAKE_OUT_MINUTES, position = "Low", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump) return (fittedBlocker(pump)) end,
        materials = { SCREWDRIVER },
    },
    -- Like a washer's switch (ISWorldObjectContextMenuLogic.toggleClothingWasher), greyed out
    -- without power.
    [PumpJobs.TURN_ON] = {
        minutes = PumpJobs.SWITCH_MINUTES, position = "Mid",
        blocker = function(character, pump)
            local refusal, summary = fittedBlocker(pump)
            if refusal then
                return refusal
            end
            if summary.on then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            if summary.burntOut then
                return "Tooltip_EnhancedIrrigation_PumpBurntOut"
            end
            return not Pumps.powered(pump) and "IGUI_RadioRequiresPowerNearby" or nil
        end,
    },
    [PumpJobs.TURN_OFF] = {
        minutes = PumpJobs.SWITCH_MINUTES, position = "Mid",
        blocker = function(character, pump)
            local summary = houseSummary(pump)
            return not (summary and summary.on) and "Tooltip_EnhancedIrrigation_UnknownJob" or nil
        end,
    },
    -- The burnt windings and the shaft seal made good from scrap, as Patch Drum mends a boiler: each
    -- repair restores less.
    [PumpJobs.REPAIR_PUMP] = {
        minutes = PumpJobs.REPAIR_MINUTES, position = "Low", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump)
            local refusal, summary = fittedBlocker(pump)
            if refusal then
                return refusal
            end
            local restores = PumpJobs.repairRestores(summary)
            if restores <= 0 then
                return "Tooltip_EnhancedIrrigation_PumpTooRepaired"
            end
            return summary.partCondition >= restores and "Tooltip_EnhancedIrrigation_PumpSound" or nil
        end,
        materials = {
            { skill = "Electricity", level = 2 },
            SCREWDRIVER,
            { item = "Base.ElectronicsScrap", need = 1 },
            { item = "Base.TirePiece", need = 1 },
        },
    },
}

EnhancedIrrigation.Jobs.define(PumpJobs)

return PumpJobs
