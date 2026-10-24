-- The right-click options of pumps (Pumps.lua): one submenu named for the pump, with a line saying
-- where it draws, how its seal and body are and what it fills, then Pump, Replace Seal, with a
-- submenu of the seals carried, Plumb Outlet, with a submenu of the tanks in reach, and Unplumb.
-- Each is greyed out saying why when its job would be refused (PumpJobs, LinkJobs).

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
    local work = menu:addOption(getText("ContextMenu_EnhancedIrrigation_Pump"), playerNum, EnhancedIrrigationPumpAction.queue,
        pump)
    Needs.refuse(work, PumpJobs.refusal(character, PumpJobs.PUMP, pump))
    addReplaceSeal(menu, playerNum, character, pump)
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
