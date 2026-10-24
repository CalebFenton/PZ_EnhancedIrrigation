-- The hands-on jobs at a pump (Pumps.lua), done on the authority by
-- server/EnhancedIrrigation/Pumps/PumpSystem.lua: Pump, which runs for as long as the character
-- works the handle (TimedActions/EnhancedIrrigationPumpAction.lua), and Replace Seal, whose `with`
-- is the seal carried. A pump's outlet is LinkJobs' Plumb Pump.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Pumps"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpJobs = {}
EnhancedIrrigation.PumpJobs = PumpJobs

local Pumps, Tanks = EnhancedIrrigation.Pumps, EnhancedIrrigation.Tanks

PumpJobs.PUMP = "Pump"
PumpJobs.REPLACE_SEAL = "ReplaceSeal"

-- Minutes to take a hand pump's cap off, swap the cup on its plunger and screw it back.
PumpJobs.SEAL_MINUTES = 10

-- The Tooltip key saying how high a pump of each lift fills a tank.
PumpJobs.LIFT_KEYS = {
    [1] = "Tooltip_EnhancedIrrigation_LiftsOneStorey",
    [2] = "Tooltip_EnhancedIrrigation_LiftsTwoStoreys",
}

--- Whether `character` is too tired to work a pump.
function PumpJobs.exhausted(character)
    return character:getStats():get(CharacterStat.ENDURANCE) <= Pumps.EXHAUSTED
end

--- What the pump `pump` would lift into, as this side sees it: its outlet's tank, while that stands
--- within its lift and has room, and the source it draws from (Pumps.sourceOf). Returns the tank
--- and the source, or nil and the Tooltip key of why it lifts nothing.
function PumpJobs.flowOf(pump)
    local spec, summary = Pumps.specOf(pump), Pumps.currentSummary(pump)
    if not (spec and summary) then
        return nil, "Tooltip_EnhancedIrrigation_UnknownJob"
    end
    if summary.wornOut then
        return nil, "Tooltip_EnhancedIrrigation_PumpWornOut"
    end
    if summary.sealWorn then
        return nil, "Tooltip_EnhancedIrrigation_SealWornOut"
    end
    local outlet = Pumps.outletOf(EnhancedIrrigation.squareOf(pump))
    if not outlet then
        return nil, "Tooltip_EnhancedIrrigation_NoOutlet"
    end
    local tank = Tanks.tankAt(outlet.b.x, outlet.b.y, outlet.b.z)
    if not tank then
        return nil, "Tooltip_EnhancedIrrigation_TankGone"
    end
    -- A barrel set on a stand at the far end since it was plumbed may stand out of its reach.
    if not Pumps.lifts(spec, Tanks.levelOf(tank), pump:getZ()) then
        return nil, PumpJobs.LIFT_KEYS[spec.lift]
    end
    if tank:getFluidContainer():getFreeCapacity() < Pumps.LEAST_LITRES then
        return nil, "Tooltip_EnhancedIrrigation_OutletFull"
    end
    local source = Pumps.sourceOf(pump, summary.intake, outlet.b)
    if not source or source.dry then
        return nil, "Tooltip_EnhancedIrrigation_NoWaterToDraw"
    end
    return tank, source
end

-- The screwdriver Replace Seal holds.
local function screwdriver(character)
    return character:getInventory():getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, EnhancedIrrigation.notBroken)
end

local SCREWDRIVER = { tool = "SCREWDRIVER", item = "Base.Screwdriver" }

PumpJobs.JOBS = {
    -- Worked for as long as the character keeps at it, so it has no minutes of its own.
    [PumpJobs.PUMP] = {
        blocker = function(character, pump)
            -- Someone else works the handle (PumpSystem.hold).
            local summary = Pumps.currentSummary(pump)
            if summary and summary.heldBy and summary.heldBy ~= character:getUsername() then
                return "Tooltip_EnhancedIrrigation_PumpInUse"
            end
            local tank, refusal = PumpJobs.flowOf(pump)
            if not tank then
                return refusal
            end
            return PumpJobs.exhausted(character) and "Tooltip_EnhancedIrrigation_Exhausted" or nil
        end,
    },
    -- The old seal is worn to nothing, so it doesn't come back.
    [PumpJobs.REPLACE_SEAL] = {
        minutes = PumpJobs.SEAL_MINUTES, position = "Mid", sound = "Screwdriver", equip = screwdriver,
        blocker = function(character, pump, item)
            if not Pumps.isPump(pump) then
                return "Tooltip_EnhancedIrrigation_UnknownJob"
            end
            if not (instanceof(item, "InventoryItem") and Pumps.sealLitres(item:getFullType())
                    and character:getInventory():containsRecursive(item)) then
                return "Tooltip_EnhancedIrrigation_NoSeal"
            end
            local summary = Pumps.currentSummary(pump)
            return summary and summary.wornOut and "Tooltip_EnhancedIrrigation_PumpWornOut" or nil
        end,
        materials = function(character, pump, item)
            local list = { SCREWDRIVER }
            if instanceof(item, "InventoryItem") then
                table.insert(list, { item = item:getFullType(), need = 1 })
            end
            return list
        end,
    },
}

EnhancedIrrigation.Jobs.define(PumpJobs)

return PumpJobs
