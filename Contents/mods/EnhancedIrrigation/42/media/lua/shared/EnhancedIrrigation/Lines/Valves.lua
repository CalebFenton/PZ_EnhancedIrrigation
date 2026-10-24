-- The valves that run a tap with nobody holding it, and the timers that run a Pump House
-- (docs/design.md, Automation): what each item is, the minutes its knob offers and how a menu
-- words it.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Timers"

local Timers = EnhancedIrrigation.Timers

EnhancedIrrigation = EnhancedIrrigation or {}
local Valves = {}
EnhancedIrrigation.Valves = Valves

Valves.WIND_UP = "EnhancedIrrigation.WindUpValve"
Valves.TIMER = "EnhancedIrrigation.TimerValve"
Valves.SPRINKLER_TIMER = "EnhancedIrrigation.SprinklerTimer"
-- The part a Timer Valve is made around, from a washer or dishwasher (Salvage Pump) or plumbing
-- supplies.
Valves.WATER_VALVE = "EnhancedIrrigation.WaterValve"

-- Each valve by full type: `kind`, "windup" (wound by hand, runs down) or "timer" (opens daily
-- while powered); `house`, whether it also fits a Pump House, which only an electric timer
-- switches. A Sprinkler Timer is a bought Timer Valve.
Valves.ITEMS = {
    [Valves.WIND_UP] = { kind = "windup" },
    [Valves.TIMER] = { kind = "timer", house = true },
    [Valves.SPRINKLER_TIMER] = { kind = "timer", house = true },
}
-- The order the menus list them in.
Valves.ORDER = { Valves.WIND_UP, Valves.TIMER, Valves.SPRINKLER_TIMER }

-- The minutes the oven's timer knob stops at (ISOvenUI.addKnobValues), which both knobs offer, so
-- a run is picked from a few steps the player can tell apart, never seven minutes against eight.
Valves.KNOB_MINUTES = { 0, 1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 60, 90, 120 }

--- The kind of the valve of full type `fullType`, "windup" or "timer", or nil if it is none.
function Valves.kindOf(fullType)
    local spec = fullType and Valves.ITEMS[fullType]
    return spec and spec.kind
end

--- Whether `minutes` is one of the knob's stops.
function Valves.isKnobMinutes(minutes)
    for _, stop in ipairs(Valves.KNOB_MINUTES) do
        if stop == minutes then
            return true
        end
    end
    return false
end

-- Jobs carry their setting as a string (EnhancedIrrigationAction's `with`).

--- A Set Timer job's setting: the start hour and the minutes, as "hour:minutes".
function Valves.encodeTimer(start, minutes)
    return start .. ":" .. minutes
end

--- The start hour and minutes of a Set Timer setting, or nil when it isn't one a timer takes.
function Valves.decodeTimer(with)
    local start, minutes = string.match(tostring(with), "^(%d+):(%d+)$")
    start, minutes = tonumber(start), tonumber(minutes)
    if not (Timers.isStartHour(start) and Valves.isKnobMinutes(minutes)) then
        return nil
    end
    return start, minutes
end

--- The minutes of a Wind Valve setting, or nil when it isn't one of the knob's stops.
function Valves.decodeWind(with)
    local minutes = tonumber(string.match(tostring(with), "^(%d+)$"))
    return Valves.isKnobMinutes(minutes) and minutes or nil
end

--- The minutes left on the wound valve of `valve` (a summary's), rounded up; 0 when run down.
function Valves.minutesLeft(valve)
    local left = (valve.untilHour or 0) - EnhancedIrrigation.now()
    return left > 0 and math.ceil(left * 60 - 0.001) or 0
end

--- What the valve or timer of `valve` (a summary's: item, start, minutes, untilHour) is and how it
--- is set: a wind-up's minutes left or run down, a timer's hour and minutes or not set.
function Valves.describe(valve)
    local name = getItemNameFromFullType(valve.item)
    if Valves.kindOf(valve.item) == "windup" then
        local left = Valves.minutesLeft(valve)
        if left > 0 then
            return getText("IGUI_EnhancedIrrigation_ValveMinutesLeft", name, left)
        end
        return getText("IGUI_EnhancedIrrigation_ValveRunDown", name)
    end
    if (valve.minutes or 0) > 0 then
        return getText("IGUI_EnhancedIrrigation_TimerSet", name, Timers.hourText(valve.start), valve.minutes)
    end
    return getText("IGUI_EnhancedIrrigation_TimerNotSet", name)
end

return Valves
