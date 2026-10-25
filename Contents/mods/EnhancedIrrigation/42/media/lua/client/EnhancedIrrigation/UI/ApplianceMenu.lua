-- The right-click options of washers, washer-dryers and dishwashers: Salvage Pump, and on a
-- stripped one vanilla's switch greyed out saying its pump is gone, wherever vanilla's menu put it.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Appliances/Appliances"
require "EnhancedIrrigation/Appliances/ApplianceJobs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"
local Needs = require "cf_commonlib/Needs"
local JobOptions = require "cf_commonlib/JobOptions"

EnhancedIrrigation = EnhancedIrrigation or {}
local ApplianceMenu = {}
EnhancedIrrigation.ApplianceMenu = ApplianceMenu

local Appliances, ApplianceJobs = EnhancedIrrigation.Appliances, EnhancedIrrigation.ApplianceJobs

-- Whether `option` is one of vanilla's washer switches.
local function isSwitch(option)
    local handler = JobOptions.handlerOf(option)
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

JobOptions.onWorldMenu(Appliances.hasPumpTile, function(context, playerNum, character, appliance)
    if Appliances.refusesSwitchOn(appliance) then
        refuseSwitches(context, context)
    end
    JobOptions.add(context, playerNum, EnhancedIrrigationAction, "appliance", ApplianceJobs.SALVAGE_PUMP, appliance,
        nil, getText("ContextMenu_EnhancedIrrigation_SalvagePump"))
end)

return ApplianceMenu
