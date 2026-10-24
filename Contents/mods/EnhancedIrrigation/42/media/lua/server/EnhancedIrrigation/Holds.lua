-- Who holds each tap and hand pump: one open-ended action at a time works one, the record's
-- `holder`, its character's name `heldBy`, which the summary carries so every menu can say so, and
-- `heldMs` when it last ran it. None of them is saved: a loaded world has no action running.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationHeldAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local Holds = {}
EnhancedIrrigation.Holds = Holds

-- How long, in real milliseconds, a record stays held after its action last ran it. A multiplayer
-- server drops the action of a client that disconnects mid-run without stopping it
-- (ActionManager.disconnectPlayer), so a hold its action no longer renews lets go by itself. Single
-- player has no such end, and runs its actions by game minutes, which a long day draws out.
Holds.LAPSE_MS = 5 * EnhancedIrrigationHeldAction.RUN_MS

-- The records held now.
local held = {}

local function lapsed(record)
    return isServer() and getTimestampMs() - record.heldMs > Holds.LAPSE_MS
end

-- The record tells what changed through its afterChange: a pump's hold runs its outlet's line.
local function letGo(record)
    record.holder, record.heldBy, record.heldMs = nil, nil, nil
    held[record] = nil
    -- Unless the object went while held, taking its record.
    if record.x and record.luaSystem:getLuaObjectAt(record.x, record.y, record.z) == record then
        record:afterChange()
    end
end

-- Lets go of every record held for which `matches(record)` holds.
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

--- Holds `record` for `action`, unless another action holds it. Returns whether `action` holds it
--- now.
function Holds.hold(record, action)
    if record.holder and record.holder ~= action and not lapsed(record) then
        return false
    end
    record.holder, record.heldBy, record.heldMs = action, action.character:getUsername(), getTimestampMs()
    held[record] = true
    record:afterChange()
    return true
end

--- Notes that `action` ran the record it holds just now.
function Holds.renew(action)
    for record in pairs(held) do
        if record.holder == action then
            record.heldMs = getTimestampMs()
        end
    end
end

--- Lets go of the record `action` holds, if any.
function Holds.release(action)
    letGoWhere(function(record) return record.holder == action end)
end

-- A hold whose action went silent lets go, so the menus offer it again.
Events.EveryOneMinute.Add(function() letGoWhere(lapsed) end)

return Holds
