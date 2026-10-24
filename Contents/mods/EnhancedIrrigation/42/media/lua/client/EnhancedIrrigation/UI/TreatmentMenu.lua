-- The right-click options of treatment units (Treatment.lua): one submenu named for the unit, with
-- a line saying what its head holds and how it is, Pour In, with a submenu of the containers of
-- water carried, its kind's own jobs, and on a unit that takes pipe Plumb Inlet and Plumb Outlet,
-- with submenus of the tanks in reach, and Unplumb. Each is greyed out saying why when its job
-- would be refused (TreatmentJobs, LinkJobs). The basin is vanilla's: its fluid menu drinks,
-- fills and empties it, and offers no pour into it, as it is input-locked.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Links"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/Treatment"
require "EnhancedIrrigation/TreatmentJobs"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/UI/TankMenu"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local TreatmentMenu = {}
EnhancedIrrigation.TreatmentMenu = TreatmentMenu

local Needs, Links, LinkJobs = EnhancedIrrigation.Needs, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Treatment, TreatmentJobs, TankMenu = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentJobs,
    EnhancedIrrigation.TankMenu
local Action = EnhancedIrrigationAction

-- Each kind's own jobs, by their ContextMenu keys, in menu order.
local KIND_JOBS = {
    sand = { { job = TreatmentJobs.CLEAN_FILTER, nameKey = "ContextMenu_EnhancedIrrigation_CleanFilter" } },
    crock = {
        { job = TreatmentJobs.SCRUB_CROCK, nameKey = "ContextMenu_EnhancedIrrigation_ScrubCrock" },
        { job = TreatmentJobs.TAKE_DOWN_CROCK, nameKey = "ContextMenu_EnhancedIrrigation_TakeDownCrock" },
    },
}

-- Each end of a unit's pipe: the job and the option's ContextMenu key.
local PLUMB_ENDS = {
    { role = "inlet", job = LinkJobs.PLUMB_INLET, nameKey = "ContextMenu_EnhancedIrrigation_PlumbInlet" },
    { role = "outlet", job = LinkJobs.PLUMB_OUTLET, nameKey = "ContextMenu_EnhancedIrrigation_PlumbOutlet" },
}

local function showJob(option, character, job, unit, with)
    Needs.show(option, TreatmentJobs.needs(character, job, unit, with), TreatmentJobs.blocker(character, job, unit, with))
end

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
    local name = getText("ContextMenu_EnhancedIrrigation_PourIn")
    local carried = containersCarried(character)
    if #carried == 0 then
        Needs.refuse(menu:addOption(name), "Tooltip_EnhancedIrrigation_NoWaterCarried")
        return
    end
    local submenu = Needs.addSubMenu(menu, name)
    for _, item in ipairs(carried) do
        local option = submenu:addOption(item:getDisplayName(), playerNum, Action.queue, "treatment",
            TreatmentJobs.POUR_IN, unit, item)
        option.itemForTexture = item
        showJob(option, character, TreatmentJobs.POUR_IN, unit, item)
    end
end

local function addPlumbing(menu, playerNum, character, unit)
    for _, plumbEnd in ipairs(PLUMB_ENDS) do
        TankMenu.addPlumbOptions(menu, playerNum, character, unit, {
            nameKey = plumbEnd.nameKey,
            job = plumbEnd.job,
            skip = function() return false end,
            refusal = function(at) return (LinkJobs.unitBlocker(unit, Links.encode(at), plumbEnd.role)) end,
            noneKey = "ContextMenu_EnhancedIrrigation_NoTankForFixture",
        })
    end
    TankMenu.addUnplumbOptions(menu, playerNum, character, unit)
end

function TreatmentMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local unit = Needs.findClicked(worldobjects, Treatment.isUnit)
    if not unit then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    local spec = Treatment.specOf(unit)
    local menu = Needs.addSubMenu(context, TankMenu.objectName(unit))
    local summary = Treatment.currentSummary(unit)
    if summary then
        menu:addOption(Treatment.statusText(spec, summary)).notAvailable = true
    end
    addPourIn(menu, playerNum, character, unit)
    for _, entry in ipairs(KIND_JOBS[spec.kind] or {}) do
        local option = menu:addOption(getText(entry.nameKey), playerNum, Action.queue, "treatment", entry.job, unit)
        showJob(option, character, entry.job, unit)
    end
    if spec.plumbed then
        addPlumbing(menu, playerNum, character, unit)
    end
end

Events.OnFillWorldObjectContextMenu.Add(TreatmentMenu.onFill)

return TreatmentMenu
