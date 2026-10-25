-- The right-click options of Tank Stands: Set Barrel on Stand on an empty stand and Take Barrel
-- Down on a raised barrel, each greyed out saying why when StandJobs would refuse it.

local JobOptions = require "cf_commonlib/JobOptions"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"
require "EnhancedIrrigation/Stands/Stands"
require "EnhancedIrrigation/Stands/StandJobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local StandMenu = {}
EnhancedIrrigation.StandMenu = StandMenu

local Stands, StandJobs = EnhancedIrrigation.Stands, EnhancedIrrigation.StandJobs

local function isStandOrRaised(object)
    return Stands.isStand(object) or Stands.isRaised(object)
end

JobOptions.onWorldMenu(isStandOrRaised, function(context, playerNum, character, object)
    if Stands.isStand(object) then
        local barrels = {}
        for _, entry in ipairs(Stands.barrelsCarried(character)) do
            table.insert(barrels, entry.item)
        end
        JobOptions.addEach(context, playerNum, EnhancedIrrigationAction, "stand", StandJobs.SET_BARREL, object, barrels,
            getText("ContextMenu_EnhancedIrrigation_SetBarrel"))
    else
        JobOptions.add(context, playerNum, EnhancedIrrigationAction, "stand", StandJobs.TAKE_DOWN, object, nil,
            getText("ContextMenu_EnhancedIrrigation_TakeBarrelDown"))
    end
end)

return StandMenu
