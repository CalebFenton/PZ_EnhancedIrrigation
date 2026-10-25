-- The right-click options of Tank Stands: Set Barrel on Stand on an empty stand and Take Barrel
-- Down on a raised barrel, each greyed out saying why when StandJobs would refuse it.

require "EnhancedIrrigation/UI/JobOptions"
require "EnhancedIrrigation/Stands/Stands"
require "EnhancedIrrigation/Stands/StandJobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local StandMenu = {}
EnhancedIrrigation.StandMenu = StandMenu

local Stands, StandJobs = EnhancedIrrigation.Stands, EnhancedIrrigation.StandJobs
local JobOptions = EnhancedIrrigation.JobOptions

local function isStandOrRaised(object)
    return Stands.isStand(object) or Stands.isRaised(object)
end

JobOptions.onWorldMenu(isStandOrRaised, function(context, playerNum, character, object)
    if Stands.isStand(object) then
        local barrels = {}
        for _, entry in ipairs(Stands.barrelsCarried(character)) do
            table.insert(barrels, entry.item)
        end
        JobOptions.addEach(context, playerNum, character, "stand", getText("ContextMenu_EnhancedIrrigation_SetBarrel"),
            StandJobs.SET_BARREL, object, barrels)
    else
        JobOptions.add(context, playerNum, character, "stand", getText("ContextMenu_EnhancedIrrigation_TakeBarrelDown"),
            StandJobs.TAKE_DOWN, object)
    end
end)

return StandMenu
