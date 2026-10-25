-- The authority's side of Water from Tank and of the valves: running the line from the tank that
-- feeds its tap.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Taps"
require "EnhancedIrrigation/Lines/Flow"

EnhancedIrrigation = EnhancedIrrigation or {}
local TapSystem = {}
EnhancedIrrigation.TapSystem = TapSystem

local Lines = EnhancedIrrigation.Lines
local Taps = EnhancedIrrigation.Taps
local Flow = EnhancedIrrigation.Flow

--- Runs the line tapped at the tile `tap` for `hours` from the tank that feeds it. Returns the
--- Tooltip key of why the water stops, or nil while it runs.
function TapSystem.run(tap, hours)
    local tank, refusal = Taps.tankFor(tap)
    if not tank then
        return refusal
    end
    Flow.run(Lines.recordOf(tap), Flow.fromTank(tank, tap:getZ()), hours)
    local _, stopped = Taps.tankFor(tap)
    return stopped
end

return TapSystem
