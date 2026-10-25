-- The daily window a timer opens, on a tap's valve or a Pump House: when it falls and how the
-- menus write its hour.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Timers = {}
EnhancedIrrigation.Timers = Timers

--- Whether `hour` is an hour of the day a timer may start at.
function Timers.isStartHour(hour)
    return type(hour) == "number" and hour >= 0 and hour <= 23 and hour == math.floor(hour)
end

-- The hour of the day, 0 up to 24, at the world hour `worldHour` (EnhancedIrrigation.now). The
-- world's age doesn't start at midnight, so it is read off the clock now.
local function hourOfDay(worldHour)
    local back = EnhancedIrrigation.now() - worldHour
    return (getGameTime():getTimeOfDay() - back) % 24
end

--- The stretches, as { from, to } world hours in order, of [from, to] that a daily window opening
--- at the hour `start` for `minutes` covers. None for 0 minutes.
function Timers.openHours(from, to, start, minutes)
    local found = {}
    if not (minutes and minutes > 0 and start and to > from) then
        return found
    end
    local length = minutes / 60
    -- The last opening at or before `from`, which may still be open then.
    local opens = from - (hourOfDay(from) - start) % 24
    while opens < to do
        local a, b = math.max(from, opens), math.min(to, opens + length)
        if b > a then
            table.insert(found, { from = a, to = b })
        end
        opens = opens + 24
    end
    return found
end

--- Whether the daily window of `start` and `minutes` is open at the world hour `hour`.
function Timers.isOpenAt(hour, start, minutes)
    if not (minutes and minutes > 0 and start) then
        return false
    end
    return (hourOfDay(hour) - start) % 24 < minutes / 60
end

--- The hour of the day `hour` as the panel and the menus show it.
function Timers.hourText(hour)
    return string.format("%02d:00", hour)
end

return Timers
