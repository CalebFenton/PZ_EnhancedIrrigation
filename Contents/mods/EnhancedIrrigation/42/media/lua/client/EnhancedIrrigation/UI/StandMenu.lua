-- The right-click options of Tank Stands: Set Barrel on Stand on an empty stand and Take Barrel
-- Down on a raised barrel, each greyed out saying why when StandJobs would refuse it.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/UI/JobOptions"
require "EnhancedIrrigation/Stands/Stands"
require "EnhancedIrrigation/Stands/StandJobs"

EnhancedIrrigation = EnhancedIrrigation or {}
local StandMenu = {}
EnhancedIrrigation.StandMenu = StandMenu

local Needs, Stands, StandJobs = EnhancedIrrigation.Needs, EnhancedIrrigation.Stands, EnhancedIrrigation.StandJobs
local JobOptions = EnhancedIrrigation.JobOptions

local function addStandOptions(context, playerNum, character, object)
    if Stands.isStand(object) then
        local carried = Stands.barrelsCarried(character)
        local name = getText("ContextMenu_EnhancedIrrigation_SetBarrel")
        if #carried > 1 then
            local submenu = Needs.addSubMenu(context, name)
            for _, entry in ipairs(carried) do
                JobOptions.add(submenu, playerNum, character, "stand", entry.item:getDisplayName(), StandJobs.SET_BARREL,
                    object, entry.item)
            end
        else
            JobOptions.add(context, playerNum, character, "stand", name, StandJobs.SET_BARREL, object,
                carried[1] and carried[1].item)
        end
    elseif Stands.isRaised(object) then
        JobOptions.add(context, playerNum, character, "stand", getText("ContextMenu_EnhancedIrrigation_TakeBarrelDown"),
            StandJobs.TAKE_DOWN, object)
    end
end

function StandMenu.onFill(playerNum, context, worldobjects, test)
    local character = getSpecificPlayer(playerNum)
    if not character or character:getVehicle() then return end
    local stand = Needs.findClicked(worldobjects, function(object)
        return Stands.isStand(object) or Stands.isRaised(object)
    end)
    if not stand then return end
    if test then return ISWorldObjectContextMenu.setTest() end
    addStandOptions(context, playerNum, character, stand)
end

Events.OnFillWorldObjectContextMenu.Add(StandMenu.onFill)

return StandMenu
