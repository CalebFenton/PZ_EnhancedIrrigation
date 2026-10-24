-- The authority's side of Water from Tank (shared/EnhancedIrrigation/Lines/Taps.lua): holding a
-- tap, and running the line from the tank that feeds it.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Taps"
require "EnhancedIrrigation/Lines/Flow"
require "EnhancedIrrigation/Holds"

EnhancedIrrigation = EnhancedIrrigation or {}
local TapSystem = {}
EnhancedIrrigation.TapSystem = TapSystem

local Lines = EnhancedIrrigation.Lines
local Taps = EnhancedIrrigation.Taps
local Flow = EnhancedIrrigation.Flow

--- Holds the tap at the tile `tap` for the Water from Tank `action`, unless another action holds
--- it or its valve runs it (ValveSystem.lua). Returns whether `action` holds it now.
function TapSystem.hold(tap, action)
    local record = Lines.recordOf(tap)
    return record ~= nil and not record.valveOpen and EnhancedIrrigation.Holds.hold(record, action)
end

--- Runs the line tapped at the tile `tap` for the `hours` since the Water from Tank action last ran
--- it. Returns the Tooltip key of why the water stops, or nil while it runs.
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
