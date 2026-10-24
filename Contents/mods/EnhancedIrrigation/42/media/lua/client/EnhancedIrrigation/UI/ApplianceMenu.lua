-- The right-click options of washers, washer-dryers and dishwashers (Appliances.lua): Salvage Pump,
-- greyed out saying why when it would be refused (ApplianceJobs); and on a stripped one, vanilla's
-- Turn On greyed out saying its pump is gone, wherever vanilla's menu put it.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Appliances"
require "EnhancedIrrigation/ApplianceJobs"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local ApplianceMenu = {}
EnhancedIrrigation.ApplianceMenu = ApplianceMenu

local Needs, Appliances, ApplianceJobs = EnhancedIrrigation.Needs, EnhancedIrrigation.Appliances, EnhancedIrrigation.ApplianceJobs

-- Whether `option` is one of vanilla's washer switches. A get-up option carries its handler as its
-- first parameter.
local function isSwitch(option)
    local handler = option.onSelect == ISContextMenu.onGetUpAndThen and option.param1 or option.onSelect
    return handler == ISWorldObjectContextMenu.onToggleClothingWasher
        or handler == ISWorldObjectContextMenu.onToggleComboWasherDryer
end

-- Greys out every washer switch in `menu` and its submenus (vanilla's sits in the washer's own).
local function refuseSwitches(context, menu)
    for _, option in ipairs(menu.options) do
        if isSwitch(option) then
            Needs.refuse(option, "Tooltip_EnhancedIrrigation_PumpSalvaged")
        end
        local sub = option.subOption and context:getSubMenu(option.subOption)
        if sub then
            refuseSwitches(context, sub)
        end
    end
end

function ApplianceMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local appliance = Needs.findClicked(worldobjects, Appliances.hasPumpTile)
    if not appliance then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    if Appliances.refusesSwitchOn(appliance) then
        refuseSwitches(context, context)
    end
    local job = ApplianceJobs.SALVAGE_PUMP
    local option = context:addOption(getText("ContextMenu_EnhancedIrrigation_SalvagePump"), playerNum,
        EnhancedIrrigationAction.queue, "appliance", job, appliance)
    Needs.show(option, ApplianceJobs.needs(character, job, appliance), ApplianceJobs.blocker(character, job, appliance))
end

Events.OnFillWorldObjectContextMenu.Add(ApplianceMenu.onFill)

return ApplianceMenu
