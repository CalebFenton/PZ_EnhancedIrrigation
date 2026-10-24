-- The right-click options of treatment units (Treatment.lua): one submenu named for the unit, with
-- a line saying what its head holds and how it is, Pour In, with a submenu of the containers of
-- water carried, its kind's own jobs, and on a unit that takes pipe Plumb Inlet and Plumb Outlet,
-- with submenus of the tanks in reach, and Unplumb. Each is greyed out saying why when its job
-- would be refused (TreatmentJobs, LinkJobs). The basin is vanilla's: its fluid menu drinks,
-- fills and empties it, and offers no pour into it, as it is input-locked. A boiler's options go in
-- the submenu vanilla's fire menu (ISBBQMenu) has already made for it, under its fuel and fire.

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

-- Each kind's own jobs, by their ContextMenu keys, in menu order.
local KIND_JOBS = {
    sand = { { job = TreatmentJobs.CLEAN_FILTER, nameKey = "ContextMenu_EnhancedIrrigation_CleanFilter" } },
    crock = {
        { job = TreatmentJobs.SCRUB_CROCK, nameKey = "ContextMenu_EnhancedIrrigation_ScrubCrock" },
        { job = TreatmentJobs.TAKE_DOWN_CROCK, nameKey = "ContextMenu_EnhancedIrrigation_TakeDownCrock" },
    },
    boiler = { { job = TreatmentJobs.PATCH_DRUM, nameKey = "ContextMenu_EnhancedIrrigation_PatchDrum" } },
}

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
            skip = function() return false end,
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

function TreatmentMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local unit = Needs.findClicked(worldobjects, Treatment.isUnit)
    if not unit then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    local spec = Treatment.specOf(unit)
    local menu = unitMenu(context, unit)
    local summary = Treatment.currentSummary(unit)
    if summary then
        menu:addOption(Treatment.statusText(unit, spec, summary)).notAvailable = true
    end
    addPourIn(menu, playerNum, character, unit)
    for _, entry in ipairs(KIND_JOBS[spec.kind] or {}) do
        JobOptions.add(menu, playerNum, character, "treatment", getText(entry.nameKey), entry.job, unit)
    end
    if spec.plumbed then
        addPlumbing(menu, playerNum, character, unit)
    end
end

Events.OnFillWorldObjectContextMenu.Add(TreatmentMenu.onFill)

return TreatmentMenu
