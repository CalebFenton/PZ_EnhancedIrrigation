-- The hands-on jobs at a treatment unit (Treatment.lua), done on the authority by
-- server/EnhancedIrrigation/Treatment/TreatmentSystem.lua: Pour In, from a carried container of
-- water into the unit's head, and Clean Filter, on a clogged sand filter. Pour In's `with` is the
-- container. A unit's inlet and outlet links are LinkJobs'.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Treatment"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentJobs = {}
EnhancedIrrigation.TreatmentJobs = TreatmentJobs

local Treatment = EnhancedIrrigation.Treatment

TreatmentJobs.POUR_IN = "PourIn"
TreatmentJobs.CLEAN_FILTER = "CleanFilter"

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
}

EnhancedIrrigation.Jobs.define(TreatmentJobs)

return TreatmentJobs
