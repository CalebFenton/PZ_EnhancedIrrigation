-- The authority's side of Water from Tank (shared/EnhancedIrrigation/Taps.lua): who holds each tap,
-- and running the line from the tank that feeds it.
--
-- One Water from Tank runs a tap at a time: the action holding it is the record's `holder`, its
-- character's name `heldBy`, which the summary carries so every menu can say so, and `heldMs`
-- when it last ran the tap. None of them is saved: a loaded world has no action running.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/Taps"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationWaterAction"
require "EnhancedIrrigation/Lines/Flow"

EnhancedIrrigation = EnhancedIrrigation or {}
local TapSystem = {}
EnhancedIrrigation.TapSystem = TapSystem

local Lines = EnhancedIrrigation.Lines
local Taps = EnhancedIrrigation.Taps
local Flow = EnhancedIrrigation.Flow

-- How long, in real milliseconds, a tap stays held after its action last ran it. A multiplayer
-- server drops the action of a client that disconnects mid-run without stopping it
-- (ActionManager.disconnectPlayer), so a hold its action no longer renews lets go by itself. Single
-- player has no such end, and runs its tap by game minutes, which a long day draws out.
TapSystem.HOLD_LAPSE_MS = 5 * EnhancedIrrigationWaterAction.RUN_MS

-- The records of the taps held now.
local held = {}

local function lapsed(record)
    return isServer() and getTimestampMs() - record.heldMs > TapSystem.HOLD_LAPSE_MS
end

local function letGo(record)
    record.holder, record.heldBy, record.heldMs = nil, nil, nil
    held[record] = nil
    -- Unless the tile went while held, taking its record.
    if record.x and Lines.recordAt(record.x, record.y, record.z) == record then
        record:sendSummary()
    end
end

-- Lets go of every tap held for which `matches(record)` holds.
local function letGoWhere(matches)
    local found = {}
    for record in pairs(held) do
        if matches(record) then
            table.insert(found, record)
        end
    end
    for _, record in ipairs(found) do
        letGo(record)
    end
end

--- Holds the tap at the tile `tap` for the Water from Tank `action`, unless another action holds
--- it. Returns whether `action` holds it now.
function TapSystem.hold(tap, action)
    local record = Lines.recordOf(tap)
    if not record or (record.holder and record.holder ~= action and not lapsed(record)) then
        return false
    end
    record.holder, record.heldBy, record.heldMs = action, action.character:getUsername(), getTimestampMs()
    held[record] = true
    record:sendSummary()
    return true
end

--- Notes that `action` ran the tap it holds just now.
function TapSystem.renew(action)
    for record in pairs(held) do
        if record.holder == action then
            record.heldMs = getTimestampMs()
        end
    end
end

--- Lets go of the tap `action` holds, if any.
function TapSystem.release(action)
    letGoWhere(function(record) return record.holder == action end)
end

--- Runs the line tapped at the tile `tap` for the `hours` since the Water from Tank action last ran
--- it. Returns the Tooltip key of why the water stops, or nil while it runs.
function TapSystem.run(tap, hours)
    local tank, refusal = Taps.tankFor(tap)
    if not tank then
        return refusal
    end
    Flow.run(Lines.recordOf(tap), tank, hours)
    local _, stopped = Taps.tankFor(tap)
    return stopped
end

-- A hold whose action went silent lets go, so the menus offer the tap again.
Events.EveryOneMinute.Add(function() letGoWhere(lapsed) end)

return TapSystem
