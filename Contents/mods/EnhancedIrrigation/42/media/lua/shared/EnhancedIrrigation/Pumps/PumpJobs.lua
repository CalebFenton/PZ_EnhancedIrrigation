-- The hands-on jobs at a pump (Pumps.lua), done on the authority by
-- server/EnhancedIrrigation/Pumps/PumpSystem.lua: at a hand pump, Pump, which runs for as long as
-- the character works the handle (TimedActions/EnhancedIrrigationPumpAction.lua), and Replace Seal,
-- whose `with` is the seal carried; at a Pump House, Fit Pump, whose `with` is the pump part carried,
-- Take Out Pump, Turn On, Turn Off, Repair Pump, and Fit Timer, Take Off Timer and Set Timer, whose
-- `with`s are the timer carried and its setting (Valves.decodeTimer). A pump's outlet is LinkJobs'
-- Plumb Pump.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Lines/Valves"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpJobs = {}
EnhancedIrrigation.PumpJobs = PumpJobs

local Jobs = EnhancedIrrigation.Jobs
local Pumps, Tanks, Lines = EnhancedIrrigation.Pumps, EnhancedIrrigation.Tanks, EnhancedIrrigation.Lines
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

-- The Tooltip key saying how high a pump of each lift fills a tank.
PumpJobs.LIFT_KEYS = {
    [1] = "Tooltip_EnhancedIrrigation_LiftsOneStorey",
    [2] = "Tooltip_EnhancedIrrigation_LiftsTwoStoreys",
}

local function exhausted(character)
    return character:getStats():get(CharacterStat.ENDURANCE) <= Pumps.EXHAUSTED
end

--- The level a pump lifts to for `into`, its outlet's tank or line tile: the tank's, or the floor
--- the line lies on.
function PumpJobs.levelOf(into)
    return Tanks.isTank(into) and Tanks.levelOf(into) or into:getZ()
end

--- What a pump lifting by `spec` (a row of Pumps.UNITS or Pumps.PARTS) would lift into, as this
--- side sees it: its outlet's tank, while that stands within its lift and has room, or its outlet's
--- line tile, while its line has no tap; and the source it draws from (Pumps.sourceOf, with the
--- hose's `intake`). Returns the tank or line tile and the source, or nil and the Tooltip key of
--- why it lifts nothing.
function PumpJobs.deliveryOf(pump, spec, intake)
    local outlet = Pumps.outletOf(EnhancedIrrigation.squareOf(pump))
    if not outlet then
        return nil, "Tooltip_EnhancedIrrigation_NoOutlet"
    end
    local b = outlet.b
    local into = Tanks.tankAt(b.x, b.y, b.z) or Lines.lineAt(b.x, b.y, b.z)
    if not into then
        return nil, "Tooltip_EnhancedIrrigation_OutletGone"
    end
    -- A barrel set on a stand at the far end since it was plumbed may stand out of its reach.
    if not Pumps.lifts(spec, PumpJobs.levelOf(into), pump:getZ()) then
        return nil, PumpJobs.LIFT_KEYS[spec.lift]
    end
    if Lines.isLine(into) then
        -- A wall knocked down since may have joined it to a tapped line. This pump feeds it too,
        -- so only a tap is another feed.
        if Pumps.feedOf(Lines.component(b.x, b.y, b.z)) == "tap" then
            return nil, Pumps.FEED_TAKEN.tap
        end
    elseif into:getFluidContainer():getFreeCapacity() < Pumps.LEAST_LITRES then
        return nil, "Tooltip_EnhancedIrrigation_OutletFull"
    end
    local source = Pumps.sourceOf(pump, intake, b)
    if not source or source.dry then
        return nil, "Tooltip_EnhancedIrrigation_NoWaterToDraw"
    end
    return into, source
end

--- What the hand pump `pump` would lift into, as this side sees it (PumpJobs.deliveryOf), unless
--- its body or seal is worn out. Returns the tank or line tile and the source, or nil and the
--- Tooltip key of why it lifts nothing.
function PumpJobs.flowOf(pump)
    local spec, summary = Pumps.specOf(pump), Pumps.currentSummary(pump)
    if not (spec and spec.kind == "hand" and summary) then
        return nil, Jobs.UNKNOWN
    end
    if summary.wornOut then
        return nil, "Tooltip_EnhancedIrrigation_PumpWornOut"
    end
    if summary.sealWorn then
        return nil, "Tooltip_EnhancedIrrigation_SealWornOut"
    end
    return PumpJobs.deliveryOf(pump, spec, summary.intake)
end

-- What a Pump House's next Repair Pump would restore its part to, from its `summary`: the ceiling,
-- lowered by a repair's loss.
local function repairRestores(summary)
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
            -- Someone else works the handle (PumpSystem.hold).
            local summary = Pumps.currentSummary(pump)
            if summary and summary.heldBy and summary.heldBy ~= character:getUsername() then
                return "Tooltip_EnhancedIrrigation_PumpInUse"
            end
            local into, refusal = PumpJobs.flowOf(pump)
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
            return not Pumps.powered(pump) and "IGUI_RadioRequiresPowerNearby" or nil
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
            local restores = repairRestores(summary)
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
