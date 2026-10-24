-- The authority's side of the job at an appliance (shared/EnhancedIrrigation/Appliances/ApplianceJobs.lua):
-- Salvage Pump done for real, which takes out the drain pump and the water inlet valve beside it.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Appliances/Appliances"
require "EnhancedIrrigation/Appliances/ApplianceJobs"
require "EnhancedIrrigation/Lines/Valves"

EnhancedIrrigation = EnhancedIrrigation or {}
local ApplianceSystem = {}
EnhancedIrrigation.ApplianceSystem = ApplianceSystem

local Appliances, ApplianceJobs = EnhancedIrrigation.Appliances, EnhancedIrrigation.ApplianceJobs

-- What each job does at `appliance`.
local DO = {
    [ApplianceJobs.SALVAGE_PUMP] = function(character, appliance)
        local pump = instanceItem(EnhancedIrrigation.Pumps.APPLIANCE_PUMP)
        local least, most = ApplianceJobs.SALVAGED_CONDITION[1], ApplianceJobs.SALVAGED_CONDITION[2]
        pump:setCondition(ZombRand(least, most + 1))
        Appliances.strip(appliance)
        EnhancedIrrigation.Materials.giveItems(character, pump)
        EnhancedIrrigation.Materials.giveItems(character, EnhancedIrrigation.Valves.WATER_VALVE)
    end,
}

--- Does `job` at `appliance` for `character` on the authority (Jobs.perform). Returns whether it was
--- done.
function ApplianceSystem.perform(character, job, appliance, with)
    return EnhancedIrrigation.Jobs.perform(ApplianceJobs, DO, character, job, appliance, with)
end

return ApplianceSystem
