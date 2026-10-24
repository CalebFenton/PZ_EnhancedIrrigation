-- The hands-on jobs at a treatment unit, done on the authority by TreatmentSystem. Pour In's `with`
-- is the container carried. A unit's inlet and outlet are plumbed by LinkJobs, and a boiler's fire
-- is vanilla's (ISBBQMenu).

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Parts"
require "EnhancedIrrigation/Treatment/Treatment"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentJobs = {}
EnhancedIrrigation.TreatmentJobs = TreatmentJobs

local Jobs = EnhancedIrrigation.Jobs
local Treatment = EnhancedIrrigation.Treatment

TreatmentJobs.POUR_IN = "PourIn"
TreatmentJobs.CLEAN_FILTER = "CleanFilter"
TreatmentJobs.SCRUB_CROCK = "ScrubCrock"
TreatmentJobs.TAKE_DOWN_CROCK = "TakeDownCrock"
TreatmentJobs.PATCH_DRUM = "PatchDrum"

-- Minutes to scrub the clogged skin off a crock by hand, and to lift it out of its bucket.
local SCRUB_MINUTES = 15
local TAKE_DOWN_MINUTES = 2
local PATCH_MINUTES = 30
-- Litres a minute poured from a carried container, about vanilla's pour.
local POUR_LITRES_PER_MINUTE = 4

-- Minutes Clean Filter takes by hand, and with a tool that lifts the top of the sand: a shovel or a
-- garden trowel, or a mason's trowel.
local CLEAN_MINUTES = 60
local CLEAN_TOOL_MINUTES = 30
local CLEAN_TOOLS = { ItemTag.TAKE_DIRT, ItemTag.MASONS_TROWEL }

-- The tool `character` cleans a filter with, or nil to work by hand.
local function cleaningTool(character)
    for _, tag in ipairs(CLEAN_TOOLS) do
        local tool = EnhancedIrrigation.Materials.workingTool(character, tag)
        if tool then
            return tool
        end
    end
    return nil
end

-- The litres of raw water `unit`'s head has room for, as this side last heard; none before its
-- summary arrives.
local function headRoom(unit)
    local summary = Treatment.currentSummary(unit)
    return summary and math.max(0, Treatment.specOf(unit).head - summary.head) or 0
end

-- The litres Pour In moves from the carried `item` into `unit`: what it holds, as far as the head
-- has room. The container keeps the rest.
local function pourLitres(unit, item)
    local fluid = item and item:getFluidContainer()
    return fluid and math.min(fluid:getAmount(), headRoom(unit)) or 0
end

--- Each kind's own jobs, with the ContextMenu key naming each, in menu order.
TreatmentJobs.KIND_JOBS = {
    sand = { { job = TreatmentJobs.CLEAN_FILTER, nameKey = "ContextMenu_EnhancedIrrigation_CleanFilter" } },
    crock = {
        { job = TreatmentJobs.SCRUB_CROCK, nameKey = "ContextMenu_EnhancedIrrigation_ScrubCrock" },
        { job = TreatmentJobs.TAKE_DOWN_CROCK, nameKey = "ContextMenu_EnhancedIrrigation_TakeDownCrock" },
    },
    boiler = { { job = TreatmentJobs.PATCH_DRUM, nameKey = "ContextMenu_EnhancedIrrigation_PatchDrum" } },
}

local KIND_OF_JOB = {}
for kind, entries in pairs(TreatmentJobs.KIND_JOBS) do
    for _, entry in ipairs(entries) do
        KIND_OF_JOB[entry.job] = kind
    end
end

-- Why a job of KIND_JOBS is refused before anything else: `unit` is no unit of the job's kind. A
-- crock counts while it stands in its bucket.
local function kindBlocker(unit, job)
    local spec = Treatment.specOf(unit)
    return not (spec and spec.kind == KIND_OF_JOB[job] and Treatment.isUnit(unit)) and Jobs.UNKNOWN or nil
end

-- The welding torch with the most fuel `character` carries, or nil.
local function weldingTorch(character)
    local best = nil
    local torches = character:getInventory():getAllTypeRecurse("Base.BlowTorch")
    for i = 0, torches:size() - 1 do
        local torch = torches:get(i)
        if not best or torch:getCurrentUses() > best:getCurrentUses() then
            best = torch
        end
    end
    return best
end

TreatmentJobs.JOBS = {
    [TreatmentJobs.POUR_IN] = {
        minutes = function(unit, item)
            return math.max(1, math.ceil(pourLitres(unit, item) / POUR_LITRES_PER_MINUTE))
        end,
        position = "Mid", sound = "PourWaterIntoObject",
        equip = function(character, unit, item) return item end,
        blocker = function(character, unit, item)
            if not Treatment.isUnit(unit) then
                return Jobs.UNKNOWN
            end
            local fluid = Jobs.carries(character, item) and item:getFluidContainer()
            if not fluid or fluid:isEmpty() then
                return "Tooltip_EnhancedIrrigation_NoWaterCarried"
            end
            if not Treatment.isWater(fluid) then
                return "Tooltip_EnhancedIrrigation_OnlyWater"
            end
            local summary = Treatment.currentSummary(unit)
            if summary and summary.cracked then
                return "Tooltip_EnhancedIrrigation_CrockCracked"
            end
            if summary and summary.burntThrough then
                return "Tooltip_EnhancedIrrigation_BurntThrough"
            end
            if headRoom(unit) <= 0 then
                return "Tooltip_EnhancedIrrigation_HeadFull"
            end
            return nil
        end,
    },
    [TreatmentJobs.CLEAN_FILTER] = {
        minutes = function(unit, with, character)
            return character and cleaningTool(character) and CLEAN_TOOL_MINUTES
                or CLEAN_MINUTES
        end,
        position = "Mid", heavy = true, sound = "Shoveling",
        equip = function(character) return cleaningTool(character) end,
        blocker = function(character, unit)
            local refusal = kindBlocker(unit, TreatmentJobs.CLEAN_FILTER)
            if refusal then
                return refusal
            end
            local summary = Treatment.currentSummary(unit)
            return not (summary and summary.clogged) and "Tooltip_EnhancedIrrigation_NotClogged" or nil
        end,
    },
    [TreatmentJobs.SCRUB_CROCK] = {
        minutes = SCRUB_MINUTES,
        position = "Low",
        blocker = function(character, unit)
            local refusal = kindBlocker(unit, TreatmentJobs.SCRUB_CROCK)
            if refusal then
                return refusal
            end
            local summary = Treatment.currentSummary(unit)
            if summary and summary.cracked then
                return "Tooltip_EnhancedIrrigation_CrockCracked"
            end
            return not (summary and summary.clogged) and "Tooltip_EnhancedIrrigation_NotClogged" or nil
        end,
    },
    -- Whatever is still waiting in the crock spills as it comes out; the bucket keeps its water.
    [TreatmentJobs.TAKE_DOWN_CROCK] = {
        minutes = TAKE_DOWN_MINUTES,
        position = "Low",
        blocker = function(character, unit)
            return kindBlocker(unit, TreatmentJobs.TAKE_DOWN_CROCK)
        end,
    },
    -- A small sheet welded over the worn steel, as vanilla mends metal: each patch restores less.
    [TreatmentJobs.PATCH_DRUM] = {
        minutes = PATCH_MINUTES,
        anim = "BlowTorch", position = "Mid", sound = "BlowTorch",
        equip = function(character) return weldingTorch(character) end,
        blocker = function(character, unit)
            local refusal = kindBlocker(unit, TreatmentJobs.PATCH_DRUM)
            if refusal then
                return refusal
            end
            local summary = Treatment.currentSummary(unit)
            if not summary then
                return Jobs.UNKNOWN
            end
            return EnhancedIrrigation.Parts.mendRefusal(summary.condition, summary.ceiling, Treatment.PATCH_LOSS,
                "Tooltip_EnhancedIrrigation_DrumWornOut", "Tooltip_EnhancedIrrigation_DrumSound")
        end,
        materials = {
            { skill = "MetalWelding", level = 2 },
            { tool = "WELDING_MASK", item = "Base.WeldingMask" },
            { item = "Base.SmallSheetMetal", need = 1 },
            { types = { "Base.BlowTorch" }, uses = 2, labelKey = "IGUI_EnhancedIrrigation_WeldingTorch" },
            { types = { "Base.WeldingRods" }, uses = 1, labelKey = "IGUI_EnhancedIrrigation_WeldingRods" },
        },
    },
}

Jobs.define(TreatmentJobs)

return TreatmentJobs
