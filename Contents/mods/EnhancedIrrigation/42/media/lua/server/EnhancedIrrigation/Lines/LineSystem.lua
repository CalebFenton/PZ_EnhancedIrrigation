-- The authority's side of garden lines: their Global Object System, laying and taking up tiles
-- (which reshapes the neighbours), the jobs of LineJobs done for real, and which lines a pump runs.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Materials"
require "EnhancedIrrigation/Jobs"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Lines/LineObject"
require "EnhancedIrrigation/Lines/ValveSystem"

EnhancedIrrigation = EnhancedIrrigation or {}
local LineSystem = {}
EnhancedIrrigation.LineSystem = LineSystem

local Sprites = EnhancedIrrigation.Sprites
local Lines = EnhancedIrrigation.Lines
local LineJobs = EnhancedIrrigation.LineJobs
local Materials = EnhancedIrrigation.Materials
local Pipes = EnhancedIrrigation.Pipes
local Pumps, Sprinklers = EnhancedIrrigation.Pumps, EnhancedIrrigation.Sprinklers

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

--- Marks every tile of the line through x, y, z as run by its pump now, or not (`running`), for the
--- menus: a pumped line is held while its pump runs, as a tap is while someone holds it
--- (LineJobs' Drain Line). Tells the clients of each tile that changed. The pump says so again as
--- it runs (PumpObject.afterChange), so a tile laid on since, or a line split, is right by its
--- next pass.
function LineSystem.showRunning(x, y, z, running)
    for _, tile in ipairs(Lines.component(x, y, z)) do
        -- Single player's client copy of a tile whose record just went is in the line too.
        local record = Lines.recordAt(tile.x, tile.y, tile.z)
        if record then
            record.running = running or nil
            record:sendSummary()
        end
    end
end

-- A line split by a tile taken away is no longer known to run, each part until its pump says so.
local function forgetRunningAround(x, y, z)
    for _, step in ipairs(Lines.STEPS) do
        if Lines.recordAt(x + step.dx, y + step.dy, z) then
            LineSystem.showRunning(x + step.dx, y + step.dy, z, false)
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
    forgetRunningAround(x, y, z)
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
        forgetRunningAround(isoObject:getX(), isoObject:getY(), isoObject:getZ())
    end
end

-- What each job does at `object`: the floor for Lay, else a line tile, whose record
-- LineSystem.perform brought up to now.
local DO = {
    [LineJobs.LAY] = function(character, floor, kind, materials)
        LineSystem.place(floor:getSquare(), kind, { conditions = Materials.conditions(character, materials) })
    end,
    [LineJobs.DRILL] = function(character, object)
        local record = Lines.recordOf(object)
        record.holed = true
        if LineJobs.mayCrack(LineJobs.holeTool(character, record.material), record.material)
                and ZombRandFloat(0, 1) < Lines.PUNCH_CRACK_CHANCE then
            record.cracked = true
        end
    end,
    [LineJobs.TAP] = function(character, object, with, materials)
        local record = Lines.recordOf(object)
        record.tap = true
        record.tapMaterial = record.material
        record.tapConditions = Materials.conditions(character, materials)
    end,
    [LineJobs.PATCH] = function(character, object)
        Lines.recordOf(object).cracked = false
    end,
    -- The water runs out over the ground where the line is opened, wetting it, not into a bed's
    -- roots, so it adds no soak.
    [LineJobs.DRAIN] = function(character, object)
        local record = Lines.recordOf(object)
        for _, tile in ipairs(Lines.component(record.x, record.y, record.z)) do
            local other = tile.state
            if other ~= record then
                other:catchUp()
                other.full = false
                other:afterChange()
            end
        end
        record.full = false
        record.wetUntil = EnhancedIrrigation.now() + Lines.WET_HOURS
    end,
    -- Each item comes back as it went in. A length still cracked is scrap. The tap's length, its
    -- valve and the sprinkler come back with their tile.
    [LineJobs.TAKE_UP] = function(character, object)
        local record = Lines.recordOf(object)
        if not record.cracked then
            Pipes.giveBack(character, record.material, 1, record.conditions)
        end
        if record.tap and record.tapMaterial then
            Pipes.giveBack(character, record.tapMaterial, 1, record.tapConditions)
        end
        if record.valve then
            EnhancedIrrigation.Materials.giveItems(character, EnhancedIrrigation.ValveSystem.takeOff(record))
        end
        if record.sprinkler then
            EnhancedIrrigation.Materials.giveItems(character, LineSystem.takeSprinkler(record))
        end
        LineSystem.remove(object)
    end,
    -- The sprinkler carried goes on as it is: its condition and the ceiling its item carries.
    [LineJobs.SET_SPRINKLER] = function(character, object, item)
        EnhancedIrrigation.Materials.takeItem(character, item)
        Lines.recordOf(object).sprinkler = { condition = item:getCondition(), ceiling = Pumps.ceilingOf(item) }
    end,
    [LineJobs.TAKE_SPRINKLER] = function(character, object)
        EnhancedIrrigation.Materials.giveItems(character, LineSystem.takeSprinkler(Lines.recordOf(object)))
    end,
    [LineJobs.FIT_VALVE] = function(character, object, item)
        EnhancedIrrigation.Materials.takeItem(character, item)
        EnhancedIrrigation.ValveSystem.fit(Lines.recordOf(object), item)
    end,
    [LineJobs.TAKE_VALVE] = function(character, object)
        EnhancedIrrigation.Materials.giveItems(character, EnhancedIrrigation.ValveSystem.takeOff(Lines.recordOf(object)))
    end,
    [LineJobs.WIND_VALVE] = function(character, object, with)
        EnhancedIrrigation.ValveSystem.wind(Lines.recordOf(object), EnhancedIrrigation.Valves.decodeWind(with))
    end,
    [LineJobs.SET_VALVE_TIMER] = function(character, object, with)
        EnhancedIrrigation.ValveSystem.setTimer(Lines.recordOf(object), EnhancedIrrigation.Valves.decodeTimer(with))
    end,
}

--- Takes the sprinkler off the tile of `record`. Returns it as an item, as it went on.
function LineSystem.takeSprinkler(record)
    local item = instanceItem(Sprinklers.ITEM)
    item:setCondition(record.sprinkler.condition)
    Pumps.setCeiling(item, record.sprinkler.ceiling)
    record.sprinkler = nil
    return item
end

--- Does `job` at `object` with `with` for `character` on the authority (Jobs.perform), on the
--- tile as time has left it, then shows and tells what changed. Returns whether it was done.
function LineSystem.perform(character, job, object, with)
    local record = job ~= LineJobs.LAY and Lines.recordOf(object) or nil
    -- Kept here: removing a record (Take Up) clears its x, y, z.
    local x, y, z = object:getX(), object:getY(), object:getZ()
    if record then
        record:catchUp()
    end
    local done = EnhancedIrrigation.Jobs.perform(LineJobs, DO, character, job, object, with)
    -- Unless Take Up took the record with the tile.
    if record and Lines.recordAt(x, y, z) == record then
        record:afterChange()
    end
    return done
end

return LineSystem
