-- The jobs at a Tank Stand: setting a barrel on it and taking it down again, done on the authority
-- by StandSystem. Set Barrel's `with` is the barrel moveable set on it.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Stands/Stands"

EnhancedIrrigation = EnhancedIrrigation or {}
local StandJobs = {}
EnhancedIrrigation.StandJobs = StandJobs

local Jobs = EnhancedIrrigation.Jobs
local Stands = EnhancedIrrigation.Stands

StandJobs.SET_BARREL = "SetBarrel"
StandJobs.TAKE_DOWN = "TakeBarrelDown"

-- A full barrel weighs as much as a man, and an empty one is still a heave up a storey's height
-- of stand, so both jobs are heavy work at chest height.
StandJobs.JOBS = {
    [StandJobs.SET_BARREL] = {
        minutes = 5, position = "Mid", heavy = true,
        blocker = function(character, object, barrel)
            if not Stands.isStand(object) then
                return "Tooltip_EnhancedIrrigation_NotAStand"
            end
            if not Jobs.carries(character, barrel, Stands.barrelSpec) then
                return "Tooltip_EnhancedIrrigation_NoBarrel"
            end
            return not Stands.isEmptyBarrel(barrel) and "Tooltip_EnhancedIrrigation_BarrelNotEmpty" or nil
        end,
    },
    [StandJobs.TAKE_DOWN] = {
        minutes = 5, position = "Mid", heavy = true,
        blocker = function(character, object)
            if not Stands.isRaised(object) then
                return "Tooltip_EnhancedIrrigation_NoBarrelOnStand"
            end
            -- As vanilla refuses to pick up a rain barrel holding anything.
            return not object:getFluidContainer():isEmpty() and "Tooltip_EnhancedIrrigation_EmptyBarrelFirst" or nil
        end,
    },
}

Jobs.define(StandJobs)

return StandJobs
