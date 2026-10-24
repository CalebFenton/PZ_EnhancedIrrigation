-- The right-click options of pumps (Pumps.lua): one submenu named for the pump, with a line saying
-- where it draws, how it stands and what it fills; then at a hand pump Pump and Replace Seal, with a
-- submenu of the seals carried; at a Pump House Fit Pump, with a submenu of the pump parts carried,
-- or Take Out Pump, Turn On or Turn Off, and Repair Pump, and Fit Timer, with a submenu of the
-- timers carried, or Set Timer, which opens the timer's panel (ValveUI), and Take Off Timer; then
-- Plumb Outlet, with a submenu of the tanks and garden lines in reach, and Unplumb. Each is greyed
-- out saying why when its job would be refused (PumpJobs, LinkJobs).

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/Lines/Valves"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/UI/LinkMenu"
require "EnhancedIrrigation/UI/ValveUI"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationPumpAction"
require "EnhancedIrrigation/UI/JobOptions"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpMenu = {}
EnhancedIrrigation.PumpMenu = PumpMenu

local Needs, Links, LinkJobs = EnhancedIrrigation.Needs, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Pumps, PumpJobs, LinkMenu = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs, EnhancedIrrigation.LinkMenu
local Valves, ValveUI = EnhancedIrrigation.Valves, EnhancedIrrigation.ValveUI
local JobOptions = EnhancedIrrigation.JobOptions

local function addJob(menu, playerNum, character, nameKey, job, pump, with)
    return JobOptions.add(menu, playerNum, character, "pump", getText(nameKey), job, pump, with)
end

-- The full type of each seal, in Pumps.SEALS' order.
local SEAL_TYPES = {}
for _, seal in ipairs(Pumps.SEALS) do
    table.insert(SEAL_TYPES, seal.type)
end

local function addReplaceSeal(menu, playerNum, character, pump)
    JobOptions.addEach(menu, playerNum, character, "pump", getText("ContextMenu_EnhancedIrrigation_ReplaceSeal"),
        PumpJobs.REPLACE_SEAL, pump, JobOptions.firstOfEach(character, SEAL_TYPES))
end

-- The pump parts in the inventory, bags included, each one, as each is as worn as it is.
local function partsCarried(character)
    local found = {}
    local inventory = character:getInventory()
    for part in pairs(Pumps.PARTS) do
        local items = inventory:getAllTypeRecurse(part)
        for i = 0, items:size() - 1 do
            table.insert(found, items:get(i))
        end
    end
    table.sort(found, function(a, b) return a:getCondition() > b:getCondition() end)
    return found
end

local function partName(item)
    return getText("IGUI_EnhancedIrrigation_PartCondition", item:getDisplayName(), item:getCondition())
end

local function addFitPump(menu, playerNum, character, pump)
    JobOptions.addEach(menu, playerNum, character, "pump", getText("ContextMenu_EnhancedIrrigation_FitPump"),
        PumpJobs.FIT_PUMP, pump, partsCarried(character), partName)
end

-- A hand pump's own options: Pump and Replace Seal.
local function addHandOptions(menu, playerNum, character, pump)
    local work = menu:addOption(getText("ContextMenu_EnhancedIrrigation_Pump"), playerNum, EnhancedIrrigationPumpAction.queue,
        pump)
    Needs.refuse(work, PumpJobs.refusal(character, PumpJobs.PUMP, pump))
    addReplaceSeal(menu, playerNum, character, pump)
end

-- Whether the Pump House `pump` still has a timer, for its panel.
local function hasTimer(pump)
    local summary = Pumps.currentSummary(pump)
    return summary ~= nil and summary.timer ~= nil
end

-- The panel of the Pump House `pump`'s timer as it stands now: its hour and knob; nil once the
-- timer is gone.
local function timerPanel(pump)
    local summary = Pumps.currentSummary(pump)
    local timer = summary and summary.timer
    if not timer then
        return nil
    end
    return {
        title = getItemNameFromFullType(timer.item),
        object = pump,
        feature = "pump",
        job = PumpJobs.SET_TIMER,
        okKey = "ContextMenu_EnhancedIrrigation_SetTimer",
        timer = true,
        start = timer.start,
        minutes = timer.minutes,
        blocker = function(who, object, with) return PumpJobs.blocker(who, PumpJobs.SET_TIMER, object, with) end,
        stillThere = hasTimer,
    }
end

--- Walks `character` to the Pump House `pump` and opens its timer's panel there (ValveUI).
function PumpMenu.openTimer(character, pump)
    ValveUI.walkAndOpen(character, pump, function() return timerPanel(pump) end)
end

-- A Pump House with a timer offers its panel and Take Off Timer; one without, Fit Timer with a
-- submenu of the timers carried, or greyed out saying it needs one.
local function addTimer(menu, playerNum, character, pump, summary)
    if summary and summary.timer then
        menu:addOption(getText("ContextMenu_EnhancedIrrigation_SetValveTimer"), character, PumpMenu.openTimer, pump)
        addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_TakeOffTimer", PumpJobs.TAKE_TIMER, pump)
        return
    end
    local carried = JobOptions.firstOfEach(character, Valves.ORDER, function(fullType)
        return Valves.ITEMS[fullType].house
    end)
    JobOptions.addEach(menu, playerNum, character, "pump", getText("ContextMenu_EnhancedIrrigation_FitTimer"),
        PumpJobs.FIT_TIMER, pump, carried)
end

-- A Pump House's own options: Fit Pump while it is empty, else Take Out Pump; its switch; Repair
-- Pump; its timer.
local function addHouseOptions(menu, playerNum, character, pump, summary)
    if summary and summary.part then
        addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_TakeOutPump", PumpJobs.TAKE_OUT_PUMP, pump)
    else
        addFitPump(menu, playerNum, character, pump)
    end
    if summary and summary.on then
        addJob(menu, playerNum, character, "ContextMenu_Turn_Off", PumpJobs.TURN_OFF, pump)
    else
        addJob(menu, playerNum, character, "ContextMenu_Turn_On", PumpJobs.TURN_ON, pump)
    end
    addJob(menu, playerNum, character, "ContextMenu_EnhancedIrrigation_RepairPump", PumpJobs.REPAIR_PUMP, pump)
    addTimer(menu, playerNum, character, pump, summary)
end

function PumpMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local pump = Needs.findClicked(worldobjects, Pumps.isPump)
    if not pump then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    local menu = Needs.addSubMenu(context, LinkMenu.objectName(pump))
    local summary = Pumps.currentSummary(pump)
    if summary then
        menu:addOption(Pumps.statusText(pump, summary)).notAvailable = true
    end
    if Pumps.isHouse(pump) then
        addHouseOptions(menu, playerNum, character, pump, summary)
    else
        addHandOptions(menu, playerNum, character, pump)
    end
    LinkMenu.addPlumbOptions(menu, playerNum, character, pump, {
        nameKey = "ContextMenu_EnhancedIrrigation_PlumbOutlet",
        job = LinkJobs.PLUMB_PUMP,
        skip = function() return false end,
        refusal = function(at) return (LinkJobs.pumpBlocker(pump, Links.encode(at))) end,
        noneKey = "ContextMenu_EnhancedIrrigation_NoOutletInReach",
        lines = true,
    })
    LinkMenu.addUnplumbOptions(menu, playerNum, character, pump)
end

Events.OnFillWorldObjectContextMenu.Add(PumpMenu.onFill)

return PumpMenu
