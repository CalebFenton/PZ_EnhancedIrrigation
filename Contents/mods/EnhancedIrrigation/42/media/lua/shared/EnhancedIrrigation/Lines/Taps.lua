-- Water from Tank: a garden line's tap runs while a character holds it open. What the menu and
-- the authority both read: which tank feeds a tap.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines/Lines"

EnhancedIrrigation = EnhancedIrrigation or {}
local Taps = {}
EnhancedIrrigation.Taps = Taps

local Lines = EnhancedIrrigation.Lines
local Tanks = EnhancedIrrigation.Tanks

-- The sound of water running out of a line: from a tap held open, or a line drained.
Taps.SOUND = "WaterCrops"

--- The tank the water runs from at the tap tile `tap`, asked each time it runs: of the tanks high
--- enough to push water out of it (Tanks.pushingAt), the highest holding water, then the fullest.
--- Or nil and why none, a Tooltip key.
function Taps.tankFor(tap)
    local state = Lines.stateOf(tap)
    if not (state and state.tap) then
        return nil, "Tooltip_EnhancedIrrigation_NoTap"
    end
    local tanks = Tanks.pushingAt(tap:getX(), tap:getY(), tap:getZ())
    if #tanks == 0 then
        return nil, "Tooltip_EnhancedIrrigation_NoPressure"
    end
    local best
    for _, tank in ipairs(tanks) do
        if Tanks.litres(tank) > 0 and (not best or Tanks.levelOf(tank) > Tanks.levelOf(best)
                or (Tanks.levelOf(tank) == Tanks.levelOf(best) and Tanks.litres(tank) > Tanks.litres(best))) then
            best = tank
        end
    end
    if not best then
        return nil, "Tooltip_EnhancedIrrigation_TankEmpty"
    end
    return best
end

return Taps
