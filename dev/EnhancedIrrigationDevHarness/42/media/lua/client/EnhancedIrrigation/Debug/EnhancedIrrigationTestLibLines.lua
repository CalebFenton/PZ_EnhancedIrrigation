require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
local Squares = require "cf_commonlib/Squares"

-- Development only, not published. The line tile helpers of the mod's test library
-- (EnhancedIrrigationTestLib), for the tests that lay, read and run lines, and vanilla's
-- sledgehammer, which smashes line tiles and pumps alike.

local T = EnhancedIrrigationTest

local Lines = EnhancedIrrigation.Lines
local Sprites = EnhancedIrrigation.Sprites

--- This client's copy of the line tile at `handle`, or nil.
function T.lineObject(handle)
    return Lines.lineAt(handle.x, handle.y, handle.z)
end

--- The name of this client's sprite of the line tile at `handle`, or nil.
function T.lineSprite(handle)
    local line = T.lineObject(handle)
    return line and line:getSprite():getName() or nil
end

--- The saved fields of a tapped tile: { tap = true } with `extra`'s fields.
function T.tapped(extra)
    local fields = { tap = true }
    for key, value in pairs(extra or {}) do
        fields[key] = value
    end
    return fields
end

--- Queues a wait until this client has the line tile at every one of `handles` (line handles)
--- with its summary, and `check(summary, handle)`, if given, holds for each.
function T.waitForLines(self, handles, what, check)
    T.waitFor(self, function()
        for _, handle in ipairs(handles) do
            local summary = T.recordSummary(handle)
            if not summary or (check and not check(summary, handle)) then
                return false
            end
        end
        return true
    end, what)
end

--- Queues laying a line tile of `material` on each of `handles` as the authority lays one, each
--- with its handle's `fields` (saved fields) set, and a wait for this client's copies. The handles
--- become line handles.
function T.placeLine(self, handles, material, fields)
    local tiles = T.tiles(handles)
    for i, handle in ipairs(handles) do
        handle.kind = "line"
        tiles[i].material = handle.material or material
        tiles[i].fields = handle.fields or fields
    end
    T.server(self, "lines.place", { tiles = tiles })
    T.waitForLines(self, handles, "this client's copy of the placed line")
end

--- Queues laying a line tile of `material` on each of `handles`, holed unless its handle has
--- `fields` of its own (T.placeLine), and a dry crop on each.
function T.holedLine(self, handles, material)
    T.placeLine(self, handles, material, { holed = true })
    T.plant(self, handles, 0)
end

--- Queues the server's view of `handles` into self.reads[label].tiles: a list in the handles'
--- order, each { record, sprite, overlays, plant }.
function T.readLines(self, handles, label)
    T.read(self, "lines.read", { tiles = T.tiles(handles) }, label)
end

--- The reads of a line job (T.job's opts.reads): `handles`' tiles as T.readLines reads them, in
--- `before.state.tiles` and `after.state.tiles` of its answer.
function T.lineReads(handles)
    return { state = { name = "lines.read", args = { tiles = T.tiles(handles) } } }
end

--- Queues running the line tapped at `tap` for `hours` on the server as the tap runs it; the reply,
--- the litres `drawn` (nil when no tank fed it), why the water stops, `stopped`, if it does, and
--- `handles`' tiles, lands in self.reads[label].
function T.flow(self, tap, hours, handles, label)
    T.read(self, "lines.flow", T.at(tap, { hours = hours, tiles = T.tiles(handles) }), label)
end

--- The shape (Sprites.pipe) a pipe tile's name draws, or nil for any other name.
function T.shapeOf(spriteName)
    local material, _, shape = Sprites.pipeOf(spriteName)
    return material and shape or nil
end

--- The Lay Line cursor for `material`, started as its menu option starts it unless `started`, and
--- put away when the test ends. Called in a step.
function T.layCursor(self, material, started)
    local playerNum = T.player():getPlayerNum()
    if not started then
        EnhancedIrrigation.LineCursor.start(playerNum, material)
    end
    local cursor = getCell():getDrag(playerNum)
    T.defer(self, function() getCell():setDrag(nil, playerNum) end)
    return cursor
end

--- Queues T.useOption on this client's copy of the line tile at `handle` for the line job `job`.
function T.useLineJob(self, handle, job, label, choose)
    T.useOption(self, function() return T.lineObject(handle) end, label, T.findJob("line", job), choose)
end

--- Queues T.useOption on this client's copy of the tap tile at `handle` for Water from Tank.
function T.useWater(self, handle, label, choose)
    T.useOption(self, function() return T.lineObject(handle) end, label, T.running(EnhancedIrrigationWaterAction.queue),
        choose)
end

--- Queues giving the character a sledgehammer and smashing the object on `handle`'s square that
--- `isTarget(object)` picks, through vanilla's Destroy cursor and action, as a player does; then a
--- wait for this client to lose it. `what` names it in the waits.
function T.smash(self, handle, isTarget, what)
    T.give(self, "sledge", { { type = "Base.Sledgehammer" } })
    T.goNextTo(self, handle.square)
    local cursor
    -- The cursor lists what it can smash on the square it hovers, once the character sees it.
    T.waitFor(self, function()
        cursor = cursor or ISDestroyCursor:new(T.player(), false, self.items.sledge[1])
        cursor:isValid(handle.square)
        for i, object in ipairs(cursor:getObjectList()) do
            if isTarget(object) then
                cursor.objectIndex = i
                return true
            end
        end
        return false
    end, "the Destroy cursor offering " .. what)
    T.step(function() cursor:create(handle.x, handle.y, handle.z) end)
    T.waitFor(self, function()
        return Squares.findObjectOn(getSquare(handle.x, handle.y, handle.z), isTarget) == nil
    end, "this client to lose the smashed " .. what)
end

return T
