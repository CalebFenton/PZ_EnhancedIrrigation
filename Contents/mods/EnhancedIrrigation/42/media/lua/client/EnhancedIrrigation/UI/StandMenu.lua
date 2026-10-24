-- The right-click options of Tank Stands: Set Barrel on Stand on an empty stand and Take Barrel
-- Down on a raised barrel, each greyed out saying why when StandJobs would refuse it.

require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/UI/Needs"
require "EnhancedIrrigation/Stands/Stands"
require "EnhancedIrrigation/Stands/StandJobs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local StandMenu = {}
EnhancedIrrigation.StandMenu = StandMenu

local Needs, Stands, StandJobs = EnhancedIrrigation.Needs, EnhancedIrrigation.Stands, EnhancedIrrigation.StandJobs
local Action = EnhancedIrrigationAction

local function addStandOptions(context, playerNum, character, object)
    if Stands.isStand(object) then
        local carried = Stands.barrelsCarried(character)
        local name = getText("ContextMenu_EnhancedIrrigation_SetBarrel")
        if #carried > 1 then
            local submenu = Needs.addSubMenu(context, name)
            for _, entry in ipairs(carried) do
                local option = submenu:addOption(entry.item:getDisplayName(), playerNum, Action.queue, "stand",
                    StandJobs.SET_BARREL, object, entry.item)
                Needs.refuse(option, StandJobs.refusal(character, StandJobs.SET_BARREL, object, entry.item))
            end
        else
            local barrel = carried[1] and carried[1].item
            local option = context:addOption(name, playerNum, Action.queue, "stand", StandJobs.SET_BARREL, object, barrel)
            Needs.refuse(option, StandJobs.refusal(character, StandJobs.SET_BARREL, object, barrel))
        end
    elseif Stands.isRaised(object) then
        local option = context:addOption(getText("ContextMenu_EnhancedIrrigation_TakeBarrelDown"), playerNum, Action.queue,
            "stand", StandJobs.TAKE_DOWN, object)
        Needs.refuse(option, StandJobs.refusal(character, StandJobs.TAKE_DOWN, object))
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
