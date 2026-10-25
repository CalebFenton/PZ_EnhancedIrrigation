-- The authority's side of Salvage Pump, which takes out an appliance's drain pump and the water
-- inlet valve beside it.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
local Items = require "cf_commonlib/Items"
local Jobs = require "cf_commonlib/Jobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Appliances/Appliances"
require "EnhancedIrrigation/Appliances/ApplianceJobs"
require "EnhancedIrrigation/Valves"

EnhancedIrrigation = EnhancedIrrigation or {}
local ApplianceSystem = {}
EnhancedIrrigation.ApplianceSystem = ApplianceSystem

local Appliances, ApplianceJobs = EnhancedIrrigation.Appliances, EnhancedIrrigation.ApplianceJobs

-- What each job does at `appliance`.
local DO = {
    [ApplianceJobs.SALVAGE_PUMP] = function(character, record, row, appliance)
        local pump = instanceItem(EnhancedIrrigation.Pumps.APPLIANCE_PUMP)
        local least, most = ApplianceJobs.SALVAGED_CONDITION[1], ApplianceJobs.SALVAGED_CONDITION[2]
        pump:setCondition(ZombRand(least, most + 1))
        Appliances.strip(appliance)
        Items.giveItems(character, pump)
        Items.giveItems(character, EnhancedIrrigation.Valves.WATER_VALVE)
        return true
    end,
}

--- The authority's side of the appliance jobs (a site of Jobs.perform).
ApplianceSystem.site = Jobs.targetSite(DO)

return ApplianceSystem
