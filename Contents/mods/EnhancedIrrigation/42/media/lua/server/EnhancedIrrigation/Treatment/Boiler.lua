-- What time and Patch Drum do to a boiler's record (TreatmentObject.KINDS.boiler): its fire, the
-- drum's heat and wear, burning through and the patch. A boiler's fire is vanilla's fireplace, which
-- the record reads, never runs.

if isClient() then return end

require "EnhancedIrrigation/Parts"
require "EnhancedIrrigation/Treatment/Treatment"
require "EnhancedIrrigation/Treatment/TreatmentObject"

local Treatment, TreatmentObject = EnhancedIrrigation.Treatment, EnhancedIrrigation.TreatmentObject

--- Whether a boiler's drum has burnt through: a hole that holds nothing.
function TreatmentObject:isBurntThrough()
    return self.condition ~= nil and self.condition <= 0
end

-- A drum this close to HOT_HOURS counts as hot: heat added up in ten-minute passes falls short of a
-- whole hour by a rounding.
local HOT_SLACK = 1e-6

--- Whether a boiler's drum is hot enough to make its water safe.
function TreatmentObject:isHot()
    return (self.hotHours or 0) >= Treatment.HOT_HOURS - HOT_SLACK
end

-- How much of `lit` hours of fire then `unlit` hours without a drum of heat `hotHours` spends hot,
-- and its heat after: the fire warms it an hour of heat an hour up to HEAT_MAX_HOURS, and it cools
-- COOLING times as fast. Worked through within the step, so ten-minute passes and an hour's
-- catch-up pass the same water.
local function heat(hotHours, lit, unlit)
    local hot = math.max(0, lit - math.max(0, Treatment.HOT_HOURS - hotHours))
    hotHours = math.min(Treatment.HEAT_MAX_HOURS, hotHours + lit)
    hot = hot + math.min(unlit, math.max(0, (hotHours - Treatment.HOT_HOURS) / Treatment.COOLING))
    return hot, math.max(0, hotHours - Treatment.COOLING * unlit)
end

-- The longest a fire lit since the last pass can have burned: the ten-minute pass's span, as a
-- player can light one only while the boiler is loaded, where the passes run.
local PASS_HOURS = 10 / 60

-- Vanilla burns the fireplace's fuel down while its square is loaded, and after a reload catches it
-- up and may put it out before or after the record catches up. So the record notes the fire after
-- every pass and burns that note down: a fire noted lit burned from the gap's start for as long as
-- its noted fuel lasted, whichever runs first. A fire burning now that wasn't noted, or was
-- refuelled since, burned at least PASS_HOURS.
TreatmentObject.KINDS.boiler = {
    init = function(record)
        record.hotHours = 0
        record.condition = Treatment.DRUM_CONDITION
        record.ceiling = Treatment.DRUM_CONDITION
        record.fireLit = false
        record.fuel = 0
    end,
    begin = function(record, unit, hours)
        local noted = record.fireLit and record.fuel / 60 or 0
        record.burnLeft = math.min(hours, unit:isLit() and math.max(noted, PASS_HOURS) or noted)
    end,
    step = function(record, unit, spec, hours)
        local lit = math.min(hours, record.burnLeft)
        record.burnLeft = record.burnLeft - lit
        if record:isBurntThrough() then
            -- A holed drum still warms and cools with the fire under it, so a patch finds it only as
            -- hot as a fire has kept it since.
            local _
            _, record.hotHours = heat(record.hotHours, lit, hours - lit)
            return
        end
        local wear = record.head > 0 and Treatment.WEAR_WET or Treatment.WEAR_DRY
        record.condition = math.max(0, record.condition - wear * lit)
        local hot
        hot, record.hotHours = heat(record.hotHours, lit, hours - lit)
        if record:isBurntThrough() then
            record:spill()
            return
        end
        record:pass(unit, spec.rate * hot, FluidType.Water)
    end,
    finish = function(record, unit)
        record.fireLit, record.fuel, record.burnLeft = unit:isLit(), unit:getFuelAmount(), nil
    end,
}

--- Patch Drum: the patch restores the drum to a little less than the last one did.
function TreatmentObject:patch()
    self.ceiling = EnhancedIrrigation.Parts.restores(self.ceiling, Treatment.PATCH_LOSS)
    self.condition = self.ceiling
end

return TreatmentObject.KINDS.boiler
