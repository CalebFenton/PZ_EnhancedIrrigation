local JobAction = require "cf_commonlib/JobAction"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Stands/Stands"
require "EnhancedIrrigation/Stands/StandJobs"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Fixtures/Fixtures"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentJobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/Appliances/Appliances"
require "EnhancedIrrigation/Appliances/ApplianceJobs"

-- Every hands-on job of fixed length at one of the mod's objects, or at an appliance. A global,
-- as the server finds the class by its Type (NetTimedAction.parse).
EnhancedIrrigationAction = EnhancedIrrigationAction or JobAction:derive("EnhancedIrrigationAction")

local Action = EnhancedIrrigationAction
local Stands, LineJobs, Treatment = EnhancedIrrigation.Stands, EnhancedIrrigation.LineJobs, EnhancedIrrigation.Treatment
local Pumps = EnhancedIrrigation.Pumps

--- Whether `object` is its square's floor: what a job on the ground works at, such as laying a
--- line tile or taking up buried pipe whose tank is gone.
local function isFloor(object)
    local square = object and object:getSquare()
    return square ~= nil and square:getFloor() == object
end

-- Each feature's job module; each system's server file serves its site (Action.serve).
local FEATURES = {
    stand = {
        isTarget = function(object) return Stands.isStand(object) or Stands.isRaised(object) end,
        jobs = EnhancedIrrigation.StandJobs,
    },
    -- Plumbing works at a tank, a fixture, a treatment unit or a pump; Unplumb also at the floor of
    -- an end whose tank, fixture, unit or pump is gone.
    link = {
        isTarget = function(object)
            return EnhancedIrrigation.Tanks.isTank(object) or EnhancedIrrigation.Fixtures.isFixture(object)
                or Treatment.isUnit(object) or Pumps.isPump(object) or isFloor(object)
        end,
        jobs = EnhancedIrrigation.LinkJobs,
    },
    line = {
        isTarget = function(object) return EnhancedIrrigation.Lines.isLine(object) or isFloor(object) end,
        jobs = LineJobs,
    },
    treatment = { isTarget = Treatment.isUnit, jobs = EnhancedIrrigation.TreatmentJobs },
    pump = { isTarget = Pumps.isPump, jobs = EnhancedIrrigation.PumpJobs },
    appliance = { isTarget = EnhancedIrrigation.Appliances.hasPumpTile, jobs = EnhancedIrrigation.ApplianceJobs },
}

-- How far from the middle of the object's square, on each axis in squares, the character may work
-- at it: what luautils.walkAdj counts as there, and a little for drift and a client's lag.
Action.REACH = 2.6

JobAction.forFeatures(Action, FEATURES)

--- The translation key of `job`'s name in a menu, where its row has no `label`.
function Action.labelKey(job)
    return "ContextMenu_EnhancedIrrigation_" .. job
end

return Action
