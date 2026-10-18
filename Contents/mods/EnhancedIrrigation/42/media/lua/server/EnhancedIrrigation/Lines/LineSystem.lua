-- The authority's side of garden lines: their Global Object System, laying and taking up tiles
-- (which reshapes the neighbours), and the jobs of LineJobs done for real.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationWaterAction"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Lines/LineObject"
require "EnhancedIrrigation/Lines/Flow"

EnhancedIrrigation = EnhancedIrrigation or {}
local LineSystem = {}
EnhancedIrrigation.LineSystem = LineSystem

local Sprites = EnhancedIrrigation.Sprites
local Lines = EnhancedIrrigation.Lines
local LineJobs = EnhancedIrrigation.LineJobs
local Materials = EnhancedIrrigation.Materials
local Pipes = EnhancedIrrigation.Pipes
local Flow = EnhancedIrrigation.Flow

LineSystem.System = EnhancedIrrigation.ObjectSystem.define({
    name = "Line",
    sprites = Sprites.pipeNames(),
    owner = Lines,
    Object = EnhancedIrrigation.LineObject,
    isObject = Lines.isLine,
})

-- The name a line tile's object carries; nothing shows it, and the server has no translations.
local OBJECT_NAME = "EnhancedIrrigationLine"

--- Shows the tile at x, y, z and its four neighbours as their records say, after a tile came or
--- went between them.
function LineSystem.reshapeAround(x, y, z)
    local record = Lines.recordAt(x, y, z)
    if record then
        record:show()
    end
    for _, step in ipairs(Lines.STEPS) do
        local neighbour = Lines.recordAt(x + step.dx, y + step.dy, z)
        if neighbour then
            neighbour:show()
        end
    end
end

--- Lays a `material` line tile on `square`, sends it to the clients and gives it a record, with
--- `fields` (saved fields) set on it. Returns the record. Authority only.
function LineSystem.place(square, material, fields)
    local isoObject = IsoObject.new(square, Sprites.pipe(material, false, 0), OBJECT_NAME)
    square:transmitAddObjectToSquare(isoObject, -1)
    LineSystem.System.instance:loadIsoObject(isoObject)
    local record = Lines.recordOf(isoObject)
    for key, value in pairs(fields or {}) do
        record[key] = value
    end
    record:sendSummary()
    LineSystem.reshapeAround(square:getX(), square:getY(), square:getZ())
    return record
end

--- Takes the line tile `isoObject` off its square with its record, tap and all, and reshapes the
--- neighbours. Authority only.
function LineSystem.remove(isoObject)
    local square = isoObject:getSquare()
    local x, y, z = isoObject:getX(), isoObject:getY(), isoObject:getZ()
    local record = Lines.recordOf(isoObject)
    if record then
        LineSystem.System.instance:removeLuaObject(record)
    end
    square:transmitRemoveItemFromSquare(isoObject)
    LineSystem.reshapeAround(x, y, z)
end

-- A tile removed any other way (a sledgehammer, a mod's RemoveTileObject) loses its record, tap and
-- all, as vanilla's handler does, and its neighbours reshape. The tile is still on its square
-- during the event, but the shapes come from the records, so they reshape at once. Take Up's
-- LineSystem.remove takes the record first and reshapes itself.
function LineSystem.System:OnObjectAboutToBeRemoved(isoObject)
    local record = self:isValidIsoObject(isoObject) and Lines.recordOf(isoObject)
    SGlobalObjectSystem.OnObjectAboutToBeRemoved(self, isoObject)
    if record then
        LineSystem.reshapeAround(isoObject:getX(), isoObject:getY(), isoObject:getZ())
    end
end

-- What each job does at `object`: the floor for Lay, else a line tile, whose record
-- LineSystem.perform brought up to now. Returns whether it was done.
local DO = {
    [LineJobs.LAY] = function(character, floor, kind, materials)
        LineSystem.place(floor:getSquare(), kind, { conditions = Materials.conditions(character, materials) })
        return true
    end,
    [LineJobs.DRILL] = function(character, object)
        local record = Lines.recordOf(object)
        record.holed = true
        if LineJobs.mayCrack(LineJobs.holeTool(character, record.material), record.material)
                and ZombRandFloat(0, 1) < Lines.PUNCH_CRACK_CHANCE then
            record.cracked = true
        end
        return true
    end,
    [LineJobs.TAP] = function(character, object, with, materials)
        local record = Lines.recordOf(object)
        record.tap = true
        record.tapMaterial = record.material
        record.tapConditions = Materials.conditions(character, materials)
        return true
    end,
    [LineJobs.PATCH] = function(character, object)
        Lines.recordOf(object).cracked = false
        return true
    end,
    -- The water runs out over the ground where the line is opened, wetting it, not into a bed's
    -- roots, so it adds no soak.
    [LineJobs.DRAIN] = function(character, object)
        local record = Lines.recordOf(object)
        for _, tile in ipairs(Lines.component(record.x, record.y, record.z)) do
            local other = tile.state
            if other ~= record then
                other:advance(other:elapsedHours())
                other.full = false
                other:afterChange()
            end
        end
        record.full = false
        record.wetUntil = EnhancedIrrigation.now() + Lines.WET_HOURS
        return true
    end,
    -- Each item comes back as it went in. A length still cracked is scrap. The tap's length comes
    -- back with its tile.
    [LineJobs.TAKE_UP] = function(character, object)
        local record = Lines.recordOf(object)
        if not record.cracked then
            Pipes.giveBack(character, record.material, 1, record.conditions)
        end
        if record.tap and record.tapMaterial then
            Pipes.giveBack(character, record.tapMaterial, 1, record.tapConditions)
        end
        LineSystem.remove(object)
        return true
    end,
}

--- Does `job` at `object` with `with` for `character` on the authority (Jobs.perform), on the
--- tile as time has left it, then shows and tells what changed. Returns whether it was done.
function LineSystem.perform(character, job, object, with)
    local record = job ~= LineJobs.LAY and Lines.recordOf(object) or nil
    -- Kept here: removing a record (Take Up) clears its x, y, z.
    local x, y, z = object:getX(), object:getY(), object:getZ()
    if record then
        record:advance(record:elapsedHours())
    end
    local done = EnhancedIrrigation.Jobs.perform(LineJobs, DO, character, job, object, with)
    -- Unless Take Up took the record with the tile.
    if record and Lines.recordAt(x, y, z) == record then
        record:afterChange()
    end
    return done
end

--- Runs the line tapped at the tile `tapObject` for the `hours` since the Water from Tank action
--- last ran it. Returns the Tooltip key of why the water stops, or nil while it runs. Authority
--- only.
function LineSystem.runTap(tapObject, hours)
    local tank, refusal = LineJobs.tapTank(tapObject)
    if not tank then
        return refusal
    end
    Flow.run(Lines.recordOf(tapObject), tank, hours)
    local _, stopped = LineJobs.tapTank(tapObject)
    return stopped
end

-- Holding a tap ----------------------------------------------------------------------------------

-- One Water from Tank runs a tap at a time: the action holding it is the record's `holder`, its
-- character's name `heldBy`, which the summary carries so every menu can say so, and `heldMs`
-- when it last ran the tap. None of them is saved: a loaded world has no action running.

-- How long, in real milliseconds, a tap stays held after its action last ran it. A multiplayer
-- server drops the action of a client that disconnects mid-run without stopping it
-- (ActionManager.disconnectPlayer), so a hold its action no longer renews lets go by itself. Single
-- player has no such end, and runs its tap by game minutes, which a long day draws out.
LineSystem.HOLD_LAPSE_MS = 5 * EnhancedIrrigationWaterAction.RUN_MS

-- The records of the taps held now.
local held = {}

local function lapsed(record)
    return isServer() and getTimestampMs() - record.heldMs > LineSystem.HOLD_LAPSE_MS
end

local function letGo(record)
    record.holder, record.heldBy, record.heldMs = nil, nil, nil
    held[record] = nil
    -- Unless the tile went while held, taking its record.
    if record.x and Lines.recordAt(record.x, record.y, record.z) == record then
        record:sendSummary()
    end
end

--- Holds the tap at the tile `tapObject` for the Water from Tank `action`, unless another action
--- holds it. Returns whether `action` holds it now. Authority only.
function LineSystem.holdTap(tapObject, action)
    local record = Lines.recordOf(tapObject)
    if not record or (record.holder and record.holder ~= action and not lapsed(record)) then
        return false
    end
    record.holder, record.heldBy, record.heldMs = action, action.character:getUsername(), getTimestampMs()
    held[record] = true
    record:sendSummary()
    return true
end

--- Notes that `action` ran the tap it holds just now. Authority only.
function LineSystem.renewTap(action)
    for record in pairs(held) do
        if record.holder == action then
            record.heldMs = getTimestampMs()
        end
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

--- Lets go of the tap `action` holds, if any. Authority only.
function LineSystem.releaseTap(action)
    letGoWhere(function(record) return record.holder == action end)
end

-- A hold whose action went silent lets go, so the menus offer the tap again.
Events.EveryOneMinute.Add(function() letGoWhere(lapsed) end)

return LineSystem
