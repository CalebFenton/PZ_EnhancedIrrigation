-- The hands-on jobs at a treatment unit (Treatment.lua), done on the authority by
-- server/EnhancedIrrigation/Treatment/TreatmentSystem.lua: Pour In, from a carried container of
-- water into the unit's head; Clean Filter, on a clogged sand filter; Scrub Crock, on a clogged
-- Filter Crock; Take Down, lifting a crock out of its bucket; and Patch Drum, welding a patch on a
-- boiler's worn drum. Pour In's `with` is the container. A unit's inlet and outlet links are
-- LinkJobs'. A boiler's fire is vanilla's (ISBBQMenu).

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Treatment"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentJobs = {}
EnhancedIrrigation.TreatmentJobs = TreatmentJobs

local Treatment = EnhancedIrrigation.Treatment

TreatmentJobs.POUR_IN = "PourIn"
TreatmentJobs.CLEAN_FILTER = "CleanFilter"
TreatmentJobs.SCRUB_CROCK = "ScrubCrock"
TreatmentJobs.TAKE_DOWN_CROCK = "TakeDownCrock"
TreatmentJobs.PATCH_DRUM = "PatchDrum"

-- Minutes to scrub the clogged skin off a crock by hand, and to lift it out of its bucket.
TreatmentJobs.SCRUB_MINUTES = 15
TreatmentJobs.TAKE_DOWN_MINUTES = 2
-- Minutes to weld a patch on a boiler's drum.
TreatmentJobs.PATCH_MINUTES = 30

-- Minutes Clean Filter takes by hand, and with a tool that lifts the top of the sand: a shovel, a
-- garden trowel (both base:takedirt) or a mason's trowel.
TreatmentJobs.CLEAN_MINUTES = 60
TreatmentJobs.CLEAN_TOOL_MINUTES = 30
TreatmentJobs.CLEAN_TOOLS = { ItemTag.TAKE_DIRT, ItemTag.MASONS_TROWEL }

--- The tool `character` cleans a filter with, or nil to work by hand.
function TreatmentJobs.cleaningTool(character)
    local inventory = character:getInventory()
    for _, tag in ipairs(TreatmentJobs.CLEAN_TOOLS) do
        local tool = inventory:getFirstTagEvalRecurse(tag, EnhancedIrrigation.notBroken)
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

--- The litres Pour In moves from the carried `item` into `unit`: what it holds, as far as the head
--- has room. The container keeps the rest.
function TreatmentJobs.pourLitres(unit, item)
    local fluid = item and item:getFluidContainer()
    return fluid and math.min(fluid:getAmount(), headRoom(unit)) or 0
end

--- Whether `unit` is a Filter Crock standing in its bucket.
function TreatmentJobs.isCrock(unit)
    local spec = Treatment.specOf(unit)
    return spec ~= nil and spec.kind == "crock" and Treatment.isUnit(unit)
end

--- Whether `unit` is a boiler.
function TreatmentJobs.isBoiler(unit)
    local spec = Treatment.specOf(unit)
    return spec ~= nil and spec.kind == "boiler" and Treatment.isUnit(unit)
end

--- The welding torch with the most fuel `character` carries, or nil.
function TreatmentJobs.weldingTorch(character)
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
            return math.max(1, math.ceil(TreatmentJobs.pourLitres(unit, item) / Treatment.POUR_LITRES_PER_MINUTE))
        end,
        position = "Mid", sound = "PourWaterIntoObject",
        equip = function(character, unit, item) return item end,
        blocker = function(character, unit, item)
            if not Treatment.isUnit(unit) then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            local fluid = instanceof(item, "InventoryItem") and character:getInventory():containsRecursive(item)
                and item:getFluidContainer()
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
            return character and TreatmentJobs.cleaningTool(character) and TreatmentJobs.CLEAN_TOOL_MINUTES
                or TreatmentJobs.CLEAN_MINUTES
        end,
        position = "Mid", heavy = true, sound = "Shoveling",
        equip = function(character) return TreatmentJobs.cleaningTool(character) end,
        blocker = function(character, unit)
            local spec = Treatment.specOf(unit)
            if not (spec and spec.kind == "sand" and Treatment.isUnit(unit)) then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            local summary = Treatment.currentSummary(unit)
            return not (summary and summary.clogged) and "Tooltip_EnhancedIrrigation_NotClogged" or nil
        end,
    },
    [TreatmentJobs.SCRUB_CROCK] = {
        minutes = TreatmentJobs.SCRUB_MINUTES,
        position = "Low",
        blocker = function(character, unit)
            if not TreatmentJobs.isCrock(unit) then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
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
        minutes = TreatmentJobs.TAKE_DOWN_MINUTES,
        position = "Low",
        blocker = function(character, unit)
            return not TreatmentJobs.isCrock(unit) and "Tooltip_EnhancedIrrigation_UnknownJob" or nil
        end,
    },
    -- A small sheet welded over the worn steel, as vanilla mends metal: each patch restores less.
    [TreatmentJobs.PATCH_DRUM] = {
        minutes = TreatmentJobs.PATCH_MINUTES,
        anim = "BlowTorch", position = "Mid", sound = "BlowTorch",
        equip = function(character) return TreatmentJobs.weldingTorch(character) end,
        blocker = function(character, unit)
            if not TreatmentJobs.isBoiler(unit) then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            local summary = Treatment.currentSummary(unit)
            if not summary then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            local restores = summary.ceiling - Treatment.PATCH_LOSS
            if restores <= 0 then
                return "Tooltip_EnhancedIrrigation_DrumWornOut"
            end
            return summary.condition >= restores and "Tooltip_EnhancedIrrigation_DrumSound" or nil
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

EnhancedIrrigation.Jobs.define(TreatmentJobs)

return TreatmentJobs
