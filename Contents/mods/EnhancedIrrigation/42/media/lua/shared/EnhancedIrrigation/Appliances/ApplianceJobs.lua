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

local Appliances = EnhancedIrrigation.Appliances

ApplianceJobs.SALVAGE_PUMP = "SalvagePump"

-- The knowledge Salvage Pump needs (Recipes.txt), which Electricity teaches.
ApplianceJobs.RECIPE = "EnhancedIrrigation_SalvagePump"

-- Minutes to open the appliance's back panel, unhook its pump and cut it free of its hoses.
ApplianceJobs.SALVAGE_MINUTES = 30

-- The condition an Appliance Pump comes out at, at random between these: a used part.
ApplianceJobs.SALVAGED_CONDITION = { 60, 100 }

-- The screwdriver Salvage Pump holds.
local function screwdriver(character)
    return character:getInventory():getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, EnhancedIrrigation.Materials.notBroken)
end

ApplianceJobs.JOBS = {
    [ApplianceJobs.SALVAGE_PUMP] = {
        minutes = ApplianceJobs.SALVAGE_MINUTES, position = "Low", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, appliance)
            if not Appliances.hasPumpTile(appliance) then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            return Appliances.isStripped(appliance) and "Tooltip_EnhancedIrrigation_PumpSalvaged" or nil
        end,
        materials = {
            { recipe = ApplianceJobs.RECIPE },
            { skill = "Electricity", level = 2 },
            { tool = "SCREWDRIVER", item = "Base.Screwdriver" },
            { tool = "PLIERS", item = "Base.Pliers" },
        },
    },
}

EnhancedIrrigation.Jobs.define(ApplianceJobs)

return ApplianceJobs
