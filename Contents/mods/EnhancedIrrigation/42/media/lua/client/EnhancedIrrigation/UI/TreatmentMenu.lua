-- The right-click options of treatment units: one submenu named for the unit, with a line saying
-- what its head holds and how it is, then its jobs and its plumbing. The basin is vanilla's: its
-- fluid menu drinks, fills and empties it, and offers no pour into it, as it is input-locked.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/UI/JobOptions"
require "EnhancedIrrigation/UI/LinkMenu"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentMenu = {}
EnhancedIrrigation.TreatmentMenu = TreatmentMenu

local Needs, Links, LinkJobs = EnhancedIrrigation.Needs, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Treatment, TreatmentJobs, LinkMenu = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs,
    EnhancedIrrigation.LinkMenu
local JobOptions = EnhancedIrrigation.JobOptions

-- Each kind's words for its state, from its summary and the unit, as a list of texts.
local KIND_WORDS = {
    sand = function(summary)
        local words = {}
        if summary.clogged then
            table.insert(words, getText("IGUI_EnhancedIrrigation_Clogged"))
        end
        if summary.ripeHours >= Treatment.RIPE_HOURS then
            table.insert(words, getText("IGUI_EnhancedIrrigation_Ripe"))
        else
            table.insert(words, getText("IGUI_EnhancedIrrigation_Ripening",
                math.ceil(Treatment.RIPE_HOURS - summary.ripeHours)))
        end
        if summary.head <= 0 and summary.dryHours >= 1 then
            table.insert(words, getText("IGUI_EnhancedIrrigation_DryFor", math.floor(summary.dryHours)))
        end
        return words
    end,
    -- Fired clay with charcoal pores passes only clean water, so its state is whether it still can.
    crock = function(summary)
        if summary.cracked then
            return { getText("IGUI_EnhancedIrrigation_Cracked") }
        end
        return summary.clogged and { getText("IGUI_EnhancedIrrigation_Clogged") } or {}
    end,
    -- Whether the drum is hot from the record, which counts the hours of fire; whether it is
    -- heating from the fire as vanilla shows it on this side.
    boiler = function(summary, unit)
        if summary.burntThrough then
            return { getText("IGUI_EnhancedIrrigation_BurntThrough") }
        end
        local heat = summary.hot and "IGUI_EnhancedIrrigation_Hot"
            or unit:isLit() and "IGUI_EnhancedIrrigation_Heating" or "IGUI_EnhancedIrrigation_Cold"
        return { getText(heat), getText("IGUI_EnhancedIrrigation_Drum", summary.condition) }
    end,
}

--- The menu's line for `unit` of `spec` with `summary`: the raw water waiting, then its state.
function TreatmentMenu.describe(unit, spec, summary)
    local text = getText("IGUI_EnhancedIrrigation_Head", math.floor(summary.head + 0.5), spec.head)
    local words = KIND_WORDS[spec.kind](summary, unit)
    return #words > 0 and text .. ", " .. table.concat(words, ", ") or text
end

-- Each end of a unit's pipe: the job and the option's ContextMenu key.
local PLUMB_ENDS = {
    { role = "inlet", job = LinkJobs.PLUMB_INLET, nameKey = "ContextMenu_EnhancedIrrigation_PlumbInlet" },
    { role = "outlet", job = LinkJobs.PLUMB_OUTLET, nameKey = "ContextMenu_EnhancedIrrigation_PlumbOutlet" },
}

-- The containers in the main inventory holding any fluid, which Pour In lists as vanilla's pour
-- does (ISWorldObjectContextMenuLogic.addFluidFromItem); greyed out are those that aren't water.
local function containersCarried(character)
    local found = {}
    local items = character:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fluid = item:getFluidContainer()
        if fluid and not fluid:isEmpty() then
            table.insert(found, item)
        end
    end
    return found
end

local function addPourIn(menu, playerNum, character, unit)
    JobOptions.addEach(menu, playerNum, character, "treatment", getText("ContextMenu_EnhancedIrrigation_PourIn"),
        TreatmentJobs.POUR_IN, unit, containersCarried(character))
end

local function addPlumbing(menu, playerNum, character, unit)
    for _, plumbEnd in ipairs(PLUMB_ENDS) do
        LinkMenu.addPlumbOptions(menu, playerNum, character, unit, {
            nameKey = plumbEnd.nameKey,
            job = plumbEnd.job,
            refusal = function(at) return (LinkJobs.unitBlocker(unit, Links.encode(at), plumbEnd.role)) end,
            noneKey = "ContextMenu_EnhancedIrrigation_NoTankForFixture",
        })
    end
    LinkMenu.addUnplumbOptions(menu, playerNum, character, unit)
end

-- The submenu for `unit`: for a fireplace, the one vanilla's fire menu, which the game fills before
-- this event, made under the name it gives the fireplace (ISBBQMenu, getTileName); else a new one.
local function unitMenu(context, unit)
    local option = unit:isFireInteractionObject() and context:getOptionFromName(unit:getTileName())
    local submenu = option and option.subOption and context:getSubMenu(option.subOption)
    return submenu or Needs.addSubMenu(context, LinkMenu.objectName(unit))
end

JobOptions.onWorldMenu(Treatment.isUnit, function(context, playerNum, character, unit)
    local spec = Treatment.specOf(unit)
    local menu = unitMenu(context, unit)
    local summary = Treatment.currentSummary(unit)
    if summary then
        menu:addOption(TreatmentMenu.describe(unit, spec, summary)).notAvailable = true
    end
    addPourIn(menu, playerNum, character, unit)
    for _, entry in ipairs(TreatmentJobs.KIND_JOBS[spec.kind]) do
        JobOptions.add(menu, playerNum, character, "treatment", getText(entry.nameKey), entry.job, unit)
    end
    if spec.plumbed then
        addPlumbing(menu, playerNum, character, unit)
    end
end)

return TreatmentMenu
