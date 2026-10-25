-- The hands-on jobs at a hand pump or a Pump House. A job's `with` is the seal, pump part or timer
-- carried, or a timer's setting (Valves.decodeTimer).

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpWater"
require "EnhancedIrrigation/Parts"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/Power"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpJobs = {}
EnhancedIrrigation.PumpJobs = PumpJobs

local Jobs = EnhancedIrrigation.Jobs
local Pumps = EnhancedIrrigation.Pumps
local Valves = EnhancedIrrigation.Valves

PumpJobs.PUMP = "Pump"
PumpJobs.REPLACE_SEAL = "ReplaceSeal"
PumpJobs.FIT_PUMP = "FitPump"
PumpJobs.TAKE_OUT_PUMP = "TakeOutPump"
PumpJobs.TURN_ON = "TurnOn"
PumpJobs.TURN_OFF = "TurnOff"
PumpJobs.REPAIR_PUMP = "RepairPump"
PumpJobs.FIT_TIMER = "FitTimer"
PumpJobs.TAKE_TIMER = "TakeTimer"
PumpJobs.SET_TIMER = "SetTimer"

-- Minutes to take a hand pump's cap off, swap the cup on its plunger and screw it back.
local SEAL_MINUTES = 10
-- Minutes to bolt a pump part into a Pump House and wire it up, to take one out, to flip its
-- switch, and to rewind and reseal a burnt pump.
local FIT_MINUTES = 15
local TAKE_OUT_MINUTES = 10
local SWITCH_MINUTES = 1
local REPAIR_MINUTES = 30
-- Minutes to screw a timer into a Pump House's switch wiring and to take it out.
local TIMER_MINUTES = 5
local TAKE_TIMER_MINUTES = 3

local function exhausted(character)
    return character:getStats():get(CharacterStat.ENDURANCE) <= Pumps.EXHAUSTED
end

-- A Pump House's summary as this side knows it, when `pump` is one; else nil.
local function houseSummary(pump)
    return Pumps.isHouse(pump) and Pumps.currentSummary(pump) or nil
end

-- Why a job that needs a part fitted in the Pump House `pump` is refused, or nil, and its summary.
local function fittedBlocker(pump)
    local summary = houseSummary(pump)
    if not summary then
        return Jobs.UNKNOWN
    end
    return not summary.part and "Tooltip_EnhancedIrrigation_NoPumpFitted" or nil, summary
end

local SCREWDRIVER = EnhancedIrrigation.Materials.SCREWDRIVER
local screwdriver = EnhancedIrrigation.Materials.holds(SCREWDRIVER)

local function isPart(item)
    return Pumps.partSpec(item:getFullType()) ~= nil
end

local function isSeal(item)
    return Pumps.sealLitres(item:getFullType()) ~= nil
end

-- A timer that switches a Pump House (Valves.ITEMS `house`).
local function isHouseTimer(item)
    local spec = Valves.ITEMS[item:getFullType()]
    return spec ~= nil and spec.house == true
end

PumpJobs.JOBS = {
    -- Worked for as long as the character keeps at it, so it has no minutes of its own.
    [PumpJobs.PUMP] = {
        blocker = function(character, pump)
            -- Someone else works the handle.
            local summary = Pumps.currentSummary(pump)
            if summary and summary.heldBy and summary.heldBy ~= character:getUsername() then
                return "Tooltip_EnhancedIrrigation_PumpInUse"
            end
            local into, refusal = EnhancedIrrigation.PumpWater.flowOf(pump)
            if not into then
                return refusal
            end
            return exhausted(character) and "Tooltip_EnhancedIrrigation_Exhausted" or nil
        end,
    },
    -- The old seal is worn to nothing, so it doesn't come back.
    [PumpJobs.REPLACE_SEAL] = {
        minutes = SEAL_MINUTES, position = "Mid", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump, item)
            local spec = Pumps.specOf(pump)
            if not (spec and spec.kind == "hand") then
                return Jobs.UNKNOWN
            end
            if not Jobs.carries(character, item, isSeal) then
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
        minutes = FIT_MINUTES, position = "Low", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump, item)
            local summary = houseSummary(pump)
            if not summary then
                return Jobs.UNKNOWN
            end
            if summary.part then
                return "Tooltip_EnhancedIrrigation_PumpFitted"
            end
            return not Jobs.carries(character, item, isPart) and "Tooltip_EnhancedIrrigation_NoPumpPart" or nil
        end,
        materials = { SCREWDRIVER },
    },
    [PumpJobs.TAKE_OUT_PUMP] = {
        minutes = TAKE_OUT_MINUTES, position = "Low", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump) return (fittedBlocker(pump)) end,
        materials = { SCREWDRIVER },
    },
    -- Like a washer's switch (ISWorldObjectContextMenuLogic.toggleClothingWasher), greyed out
    -- without power.
    [PumpJobs.TURN_ON] = {
        minutes = SWITCH_MINUTES, position = "Mid",
        blocker = function(character, pump)
            local refusal, summary = fittedBlocker(pump)
            if refusal then
                return refusal
            end
            if summary.on then
                return Jobs.UNKNOWN
            end
            if summary.burntOut then
                return "Tooltip_EnhancedIrrigation_PumpBurntOut"
            end
            return not EnhancedIrrigation.Power.powered(pump) and "IGUI_RadioRequiresPowerNearby" or nil
        end,
    },
    [PumpJobs.TURN_OFF] = {
        minutes = SWITCH_MINUTES, position = "Mid",
        blocker = function(character, pump)
            local summary = houseSummary(pump)
            return not (summary and summary.on) and Jobs.UNKNOWN or nil
        end,
    },
    -- The burnt windings and the shaft seal made good from scrap, as Patch Drum mends a boiler: each
    -- repair restores less.
    [PumpJobs.REPAIR_PUMP] = {
        minutes = REPAIR_MINUTES, position = "Low", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump)
            local refusal, summary = fittedBlocker(pump)
            if refusal then
                return refusal
            end
            return EnhancedIrrigation.Parts.mendRefusal(summary.partCondition, summary.partCeiling, Pumps.REPAIR_LOSS,
                "Tooltip_EnhancedIrrigation_PumpTooRepaired", "Tooltip_EnhancedIrrigation_PumpSound")
        end,
        materials = {
            { skill = "Electricity", level = 2 },
            SCREWDRIVER,
            { item = "Base.ElectronicsScrap", need = 1 },
            { item = "Base.TirePiece", need = 1 },
        },
    },
    -- The timer goes in as the item carried, taken by the job itself.
    [PumpJobs.FIT_TIMER] = {
        minutes = TIMER_MINUTES, position = "Mid", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump, item)
            local summary = houseSummary(pump)
            if not summary then
                return Jobs.UNKNOWN
            end
            if summary.timer then
                return "Tooltip_EnhancedIrrigation_HasTimer"
            end
            return not Jobs.carries(character, item, isHouseTimer) and "Tooltip_EnhancedIrrigation_NoTimer" or nil
        end,
        materials = { SCREWDRIVER },
    },
    [PumpJobs.TAKE_TIMER] = {
        minutes = TAKE_TIMER_MINUTES, position = "Mid", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump)
            local summary = houseSummary(pump)
            return not (summary and summary.timer) and "Tooltip_EnhancedIrrigation_NoTimerHere" or nil
        end,
        materials = { SCREWDRIVER },
    },
    [PumpJobs.SET_TIMER] = {
        minutes = SWITCH_MINUTES, position = "Mid",
        blocker = function(character, pump, with)
            local summary = houseSummary(pump)
            if not (summary and summary.timer) then
                return "Tooltip_EnhancedIrrigation_NoTimerHere"
            end
            return not Valves.decodeTimer(with) and Jobs.UNKNOWN or nil
        end,
    },
}

Jobs.define(PumpJobs)

return PumpJobs
