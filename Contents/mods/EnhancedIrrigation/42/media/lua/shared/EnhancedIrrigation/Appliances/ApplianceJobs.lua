-- The hands-on job at a washer, washer-dryer or dishwasher, done on the authority by
-- ApplianceSystem: Salvage Pump, which takes out the appliance's drain pump as an Appliance Pump and
-- the water inlet valve beside it, and leaves the appliance where it stands, stripped.

require "EnhancedIrrigation/Utilities"
local Materials = require "cf_commonlib/Materials"
local Jobs = require "cf_commonlib/Jobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Appliances/Appliances"

EnhancedIrrigation = EnhancedIrrigation or {}
local ApplianceJobs = {}
EnhancedIrrigation.ApplianceJobs = ApplianceJobs

local Appliances, Pumps = EnhancedIrrigation.Appliances, EnhancedIrrigation.Pumps

ApplianceJobs.SALVAGE_PUMP = "SalvagePump"

-- The knowledge Salvage Pump needs (Recipes.txt), which Electricity teaches.
ApplianceJobs.RECIPE = "EnhancedIrrigation_SalvagePump"

-- Minutes to open the appliance's back panel, unhook its pump and cut it free of its hoses.
local SALVAGE_MINUTES = 30

-- The condition an Appliance Pump comes out at, at random between these: a used part.
ApplianceJobs.SALVAGED_CONDITION = { 60, 100 }

ApplianceJobs.JOBS = {
    [ApplianceJobs.SALVAGE_PUMP] = {
        minutes = SALVAGE_MINUTES, position = "Low", sound = "Screwdriver",
        equip = Materials.holds(Pumps.SCREWDRIVER),
        blocker = function(character, appliance)
            if not Appliances.hasPumpTile(appliance) then
                return EnhancedIrrigation.JOB_REFUSALS.unknown
            end
            return Appliances.isStripped(appliance) and "Tooltip_EnhancedIrrigation_PumpSalvaged" or nil
        end,
        materials = {
            { recipe = ApplianceJobs.RECIPE },
            { perk = "Electricity", need = 2 },
            Pumps.SCREWDRIVER,
            { tool = "PLIERS", item = "Base.Pliers" },
        },
    },
}

Jobs.define(ApplianceJobs, EnhancedIrrigation.JOB_REFUSALS)

return ApplianceJobs
