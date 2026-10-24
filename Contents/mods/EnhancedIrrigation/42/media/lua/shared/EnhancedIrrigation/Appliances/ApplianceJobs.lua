-- The hands-on job at a washer, washer-dryer or dishwasher (Appliances.lua), done on the authority
-- by server/EnhancedIrrigation/Appliances/ApplianceSystem.lua: Salvage Pump, which takes the
-- appliance's drain pump out as an Appliance Pump and leaves the appliance where it stands, stripped.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Appliances/Appliances"

EnhancedIrrigation = EnhancedIrrigation or {}
local ApplianceJobs = {}
EnhancedIrrigation.ApplianceJobs = ApplianceJobs

local Jobs, Materials = EnhancedIrrigation.Jobs, EnhancedIrrigation.Materials
local Appliances = EnhancedIrrigation.Appliances

ApplianceJobs.SALVAGE_PUMP = "SalvagePump"

-- The knowledge Salvage Pump needs (Recipes.txt), which Electricity teaches.
ApplianceJobs.RECIPE = "EnhancedIrrigation_SalvagePump"

-- Minutes to open the appliance's back panel, unhook its pump and cut it free of its hoses.
ApplianceJobs.SALVAGE_MINUTES = 30

-- The condition an Appliance Pump comes out at, at random between these: a used part.
ApplianceJobs.SALVAGED_CONDITION = { 60, 100 }

ApplianceJobs.JOBS = {
    [ApplianceJobs.SALVAGE_PUMP] = {
        minutes = ApplianceJobs.SALVAGE_MINUTES, position = "Low", sound = "Screwdriver",
        equip = Materials.holds(Materials.SCREWDRIVER),
        blocker = function(character, appliance)
            if not Appliances.hasPumpTile(appliance) then
                return Jobs.UNKNOWN
            end
            return Appliances.isStripped(appliance) and "Tooltip_EnhancedIrrigation_PumpSalvaged" or nil
        end,
        materials = {
            { recipe = ApplianceJobs.RECIPE },
            { skill = "Electricity", level = 2 },
            Materials.SCREWDRIVER,
            { tool = "PLIERS", item = "Base.Pliers" },
        },
    },
}

Jobs.define(ApplianceJobs)

return ApplianceJobs
