-- The right-click options of pumps: one submenu named for the pump, with a line saying where it
-- draws, how it stands and what it fills, then its own jobs and its outlet's plumbing.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpWater"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/Valves"
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
local Tanks, Lines, PumpWater = EnhancedIrrigation.Tanks, EnhancedIrrigation.Lines, EnhancedIrrigation.PumpWater

-- The menu's name for `source` (PumpWater.sourceOf): the well, the tank's container ("Rain
-- Barrel"), the trough or the river; or that there is nothing to draw when it is nil or dry.
local function sourceName(source)
    if not source or source.dry then
        return getText("IGUI_EnhancedIrrigation_NoWaterToDraw")
    elseif source.kind == "tank" then
        return source.object:getFluidContainer():getTranslatedContainerName()
    end
    return getText(source.kind == "well" and "IGUI_EnhancedIrrigation_SourceWell"
        or source.kind == "trough" and "IGUI_EnhancedIrrigation_SourceTrough" or "IGUI_EnhancedIrrigation_SourceRiver")
end

-- The words of a hand pump's `summary`: its seal, then its body.
local function handWords(words, summary)
    if not summary.seal then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoSeal"))
    elseif summary.sealWorn then
        table.insert(words, getText("IGUI_EnhancedIrrigation_SealWornOut"))
    else
        table.insert(words, getText("IGUI_EnhancedIrrigation_Seal", summary.sealLeft))
    end
    table.insert(words, summary.wornOut and getText("IGUI_EnhancedIrrigation_PumpWornOut")
        or getText("IGUI_EnhancedIrrigation_PumpCondition", summary.condition))
end

-- The words of a Pump House's `summary`: its part and how worn, then whether it runs, is off or is
-- switched on with no power, then its timer and how it is set.
local function houseWords(words, summary)
    if not summary.part then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoPumpFitted"))
    else
        local name = getItemNameFromFullType(summary.part)
        table.insert(words, summary.burntOut and getText("IGUI_EnhancedIrrigation_PartBurntOut", name)
            or getText("IGUI_EnhancedIrrigation_PartCondition", name, summary.partCondition))
        table.insert(words, getText(summary.running and "IGUI_EnhancedIrrigation_Running"
            or summary.on and "IGUI_EnhancedIrrigation_NoPower" or "IGUI_EnhancedIrrigation_SwitchedOff"))
    end
    if summary.timer then
        table.insert(words, Valves.describe(summary.timer))
    end
end

--- The menu's line for `pump` with `summary`: where it draws; a hand pump's seal and body, or a Pump
--- House's part and switch; the tank it fills or the line it feeds.
function PumpMenu.describe(pump, summary)
    local into = Links.farEnd(EnhancedIrrigation.squareOf(pump), "pump")
    local words = { sourceName(PumpWater.sourceOf(pump, summary.intake, into)) }
    if Pumps.isHouse(pump) then
        houseWords(words, summary)
    else
        handWords(words, summary)
    end
    local tank = into and Tanks.tankAt(into.x, into.y, into.z)
    if not into then
        table.insert(words, getText("IGUI_EnhancedIrrigation_NoOutlet"))
    elseif tank then
        table.insert(words, getText("IGUI_EnhancedIrrigation_OutletTo", tank:getFluidContainer():getTranslatedContainerName()))
    elseif Lines.lineAt(into.x, into.y, into.z) then
        table.insert(words, getText("IGUI_EnhancedIrrigation_OutletToLine"))
    end
    return table.concat(words, ", ")
end

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

local function addHandOptions(menu, playerNum, character, pump)
    local work = menu:addOption(getText("ContextMenu_EnhancedIrrigation_Pump"), playerNum, EnhancedIrrigationPumpAction.queue,
        pump)
    Needs.refuse(work, PumpJobs.refusal(character, PumpJobs.PUMP, pump))
    addReplaceSeal(menu, playerNum, character, pump)
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
    }
end

--- Walks `character` to the Pump House `pump` and opens its timer's panel there (ValveUI).
function PumpMenu.openTimer(character, pump)
    ValveUI.walkAndOpen(character, pump, function() return timerPanel(pump) end)
end

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
        menu:addOption(PumpMenu.describe(pump, summary)).notAvailable = true
    end
    if Pumps.isHouse(pump) then
        addHouseOptions(menu, playerNum, character, pump, summary)
    else
        addHandOptions(menu, playerNum, character, pump)
    end
    LinkMenu.addPlumbOptions(menu, playerNum, character, pump, {
        nameKey = "ContextMenu_EnhancedIrrigation_PlumbOutlet",
        job = LinkJobs.PLUMB_PUMP,
        refusal = function(at) return (LinkJobs.pumpBlocker(pump, Links.encode(at))) end,
        noneKey = "ContextMenu_EnhancedIrrigation_NoOutletInReach",
        lines = true,
    })
    LinkMenu.addUnplumbOptions(menu, playerNum, character, pump)
end

Events.OnFillWorldObjectContextMenu.Add(PumpMenu.onFill)

return PumpMenu
