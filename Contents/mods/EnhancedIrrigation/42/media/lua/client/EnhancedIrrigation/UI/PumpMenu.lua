-- The right-click options of pumps (Pumps.lua): one submenu named for the pump, with a line saying
-- where it draws, how it stands and what it fills; then at a hand pump Pump and Replace Seal, with a
-- submenu of the seals carried; at a Pump House Fit Pump, with a submenu of the pump parts carried,
-- or Take Out Pump, Turn On or Turn Off, and Repair Pump; then Plumb Outlet, with a submenu of the
-- tanks in reach, and Unplumb. Each is greyed out saying why when its job would be refused
-- (PumpJobs, LinkJobs).

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Links"
require "EnhancedIrrigation/LinkJobs"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/PumpJobs"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/UI/TankMenu"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationPumpAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpMenu = {}
EnhancedIrrigation.PumpMenu = PumpMenu

local Needs, Links, LinkJobs = EnhancedIrrigation.Needs, EnhancedIrrigation.Links, EnhancedIrrigation.LinkJobs
local Pumps, PumpJobs, TankMenu = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs, EnhancedIrrigation.TankMenu
local Action = EnhancedIrrigationAction

-- The seals in the inventory, bags included, one of each kind, in Pumps.SEALS' order.
local function sealsCarried(character)
    local found = {}
    local inventory = character:getInventory()
    for _, seal in ipairs(Pumps.SEALS) do
        local item = inventory:getFirstTypeRecurse(seal.type)
        if item then
            table.insert(found, item)
        end
    end
    return found
end

local function addReplaceSeal(menu, playerNum, character, pump)
    local name = getText("ContextMenu_EnhancedIrrigation_ReplaceSeal")
    local carried = sealsCarried(character)
    if #carried == 0 then
        Needs.refuse(menu:addOption(name), "Tooltip_EnhancedIrrigation_NoSeal")
        return
    end
    local submenu = Needs.addSubMenu(menu, name)
    for _, item in ipairs(carried) do
        local option = submenu:addOption(item:getDisplayName(), playerNum, Action.queue, "pump", PumpJobs.REPLACE_SEAL,
            pump, item)
        option.itemForTexture = item
        Needs.show(option, PumpJobs.needs(character, PumpJobs.REPLACE_SEAL, pump, item),
            PumpJobs.blocker(character, PumpJobs.REPLACE_SEAL, pump, item))
    end
end

-- Adds the option of `job` named by `nameKey`, greyed out saying why when it would be refused.
local function addJob(menu, playerNum, character, pump, job, nameKey, with)
    local option = menu:addOption(getText(nameKey), playerNum, Action.queue, "pump", job, pump, with)
    Needs.show(option, PumpJobs.needs(character, job, pump, with), PumpJobs.blocker(character, job, pump, with))
    return option
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

local function addFitPump(menu, playerNum, character, pump)
    local name = getText("ContextMenu_EnhancedIrrigation_FitPump")
    local carried = partsCarried(character)
    if #carried == 0 then
        Needs.refuse(menu:addOption(name), "Tooltip_EnhancedIrrigation_NoPumpPart")
        return
    end
    local submenu = Needs.addSubMenu(menu, name)
    for _, item in ipairs(carried) do
        local option = submenu:addOption(getText("IGUI_EnhancedIrrigation_PartCondition", item:getDisplayName(),
            item:getCondition()), playerNum, Action.queue, "pump", PumpJobs.FIT_PUMP, pump, item)
        option.itemForTexture = item
        Needs.show(option, PumpJobs.needs(character, PumpJobs.FIT_PUMP, pump, item),
            PumpJobs.blocker(character, PumpJobs.FIT_PUMP, pump, item))
    end
end

-- A hand pump's own options: Pump and Replace Seal.
local function addHandOptions(menu, playerNum, character, pump)
    local work = menu:addOption(getText("ContextMenu_EnhancedIrrigation_Pump"), playerNum, EnhancedIrrigationPumpAction.queue,
        pump)
    Needs.refuse(work, PumpJobs.refusal(character, PumpJobs.PUMP, pump))
    addReplaceSeal(menu, playerNum, character, pump)
end

-- A Pump House's own options: Fit Pump while it is empty, else Take Out Pump; its switch; Repair Pump.
local function addHouseOptions(menu, playerNum, character, pump, summary)
    if summary and summary.part then
        addJob(menu, playerNum, character, pump, PumpJobs.TAKE_OUT_PUMP, "ContextMenu_EnhancedIrrigation_TakeOutPump")
    else
        addFitPump(menu, playerNum, character, pump)
    end
    if summary and summary.on then
        addJob(menu, playerNum, character, pump, PumpJobs.TURN_OFF, "ContextMenu_Turn_Off")
    else
        addJob(menu, playerNum, character, pump, PumpJobs.TURN_ON, "ContextMenu_Turn_On")
    end
    addJob(menu, playerNum, character, pump, PumpJobs.REPAIR_PUMP, "ContextMenu_EnhancedIrrigation_RepairPump")
end

function PumpMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local pump = Needs.findClicked(worldobjects, Pumps.isPump)
    if not pump then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    local menu = Needs.addSubMenu(context, TankMenu.objectName(pump))
    local summary = Pumps.currentSummary(pump)
    if summary then
        menu:addOption(Pumps.statusText(pump, summary)).notAvailable = true
    end
    if Pumps.isHouse(pump) then
        addHouseOptions(menu, playerNum, character, pump, summary)
    else
        addHandOptions(menu, playerNum, character, pump)
    end
    TankMenu.addPlumbOptions(menu, playerNum, character, pump, {
        nameKey = "ContextMenu_EnhancedIrrigation_PlumbOutlet",
        job = LinkJobs.PLUMB_PUMP,
        skip = function() return false end,
        refusal = function(at) return (LinkJobs.pumpBlocker(pump, Links.encode(at))) end,
        noneKey = "ContextMenu_EnhancedIrrigation_NoTankForFixture",
    })
    TankMenu.addUnplumbOptions(menu, playerNum, character, pump)
end

Events.OnFillWorldObjectContextMenu.Add(PumpMenu.onFill)

return PumpMenu
