-- The authority's side of the job at an appliance (shared/EnhancedIrrigation/ApplianceJobs.lua):
-- Salvage Pump done for real, which takes out the drain pump and the water inlet valve beside it.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/Appliances"
require "EnhancedIrrigation/ApplianceJobs"
require "EnhancedIrrigation/Valves"

EnhancedIrrigation = EnhancedIrrigation or {}
local ApplianceSystem = {}
EnhancedIrrigation.ApplianceSystem = ApplianceSystem

local Appliances, ApplianceJobs = EnhancedIrrigation.Appliances, EnhancedIrrigation.ApplianceJobs

-- What each job does at `appliance`. Returns whether it was done.
local DO = {
    [ApplianceJobs.SALVAGE_PUMP] = function(character, appliance)
        local pump = instanceItem(EnhancedIrrigation.Pumps.APPLIANCE_PUMP)
        local least, most = ApplianceJobs.SALVAGED_CONDITION[1], ApplianceJobs.SALVAGED_CONDITION[2]
        pump:setCondition(ZombRand(least, most + 1))
        Appliances.strip(appliance)
        EnhancedIrrigation.giveItems(character, pump)
        EnhancedIrrigation.giveItems(character, EnhancedIrrigation.Valves.WATER_VALVE)
        return true
    end,
}

--- Does `job` at `appliance` for `character` on the authority (Jobs.perform). Returns whether it was
--- done.
function ApplianceSystem.perform(character, job, appliance, with)
    return EnhancedIrrigation.Jobs.perform(ApplianceJobs, DO, character, job, appliance, with)
end

return ApplianceSystem
