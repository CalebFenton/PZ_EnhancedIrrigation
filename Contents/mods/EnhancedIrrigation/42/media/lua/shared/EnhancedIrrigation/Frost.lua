-- Hard frost: the air in which water left standing in a pipe, a sand filter's head or a crock
-- freezes solid and may split what holds it. Vanilla water never freezes, so the mod decides when.

EnhancedIrrigation = EnhancedIrrigation or {}
local Frost = {}
EnhancedIrrigation.Frost = Frost

-- Water supercools, and a pipe splits from the pressure an ice plug builds against a closed end,
-- not where the ice forms, so a light frost does nothing: in the University of Illinois Building
-- Research Council's tests for the ICC, unsheltered pipe began to freeze only when the air fell to
-- about 20 F, and plumbers saw bursts start in the teens
-- (iccsafe.org/wp-content/uploads/DIS-FreezeBurstPipe.pdf).
Frost.HARD_FREEZE_CELSIUS = -7

--- The air temperature, in Celsius, at the authority's record `record`: its square's while loaded,
--- which a room warms, else the world's.
function Frost.celsiusAt(record)
    local square = record:getSquare()
    if square then
        return getClimateManager():getAirTemperatureForSquare(square)
    end
    return getClimateManager():getTemperature()
end

--- Whether the air at the authority's record `record` is in a hard freeze.
function Frost.isHard(record)
    return Frost.celsiusAt(record) <= Frost.HARD_FREEZE_CELSIUS
end

return Frost
