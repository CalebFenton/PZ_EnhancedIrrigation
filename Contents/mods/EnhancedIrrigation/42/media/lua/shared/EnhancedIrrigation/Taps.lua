-- Water from Tank: a garden line's tap runs while a character holds it open
-- (EnhancedIrrigationWaterAction). What the menu and the authority both read: which tank feeds a
-- tap, and why water can't run. Holding and running a tap is the authority's
-- (server/EnhancedIrrigation/Lines/TapSystem.lua); what the water does in the line is Flow.lua's.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines"

EnhancedIrrigation = EnhancedIrrigation or {}
local Taps = {}
EnhancedIrrigation.Taps = Taps

local Lines = EnhancedIrrigation.Lines
local Tanks = EnhancedIrrigation.Tanks

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

--- Why `character` can't run water from the tap tile `tap`, a Tooltip key, or nil: someone else
--- holds it (TapSystem.hold), its valve runs it (ValveSystem.lua), or no tank can feed it.
function Taps.blocker(tap, character)
    local state = Lines.stateOf(tap)
    if state and state.heldBy and state.heldBy ~= character:getUsername() then
        return "Tooltip_EnhancedIrrigation_TapInUse"
    end
    if state and state.valveOpen then
        return "Tooltip_EnhancedIrrigation_ValveRunning"
    end
    local _, refusal = Taps.tankFor(tap)
    return refusal
end

return Taps
