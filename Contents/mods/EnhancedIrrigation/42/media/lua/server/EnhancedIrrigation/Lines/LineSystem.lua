-- The authority's side of garden lines: their Global Object System, laying and taking up tiles
-- (which reshapes the neighbours), the jobs of LineJobs done for real, and which lines a pump runs.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
local Materials = require "cf_commonlib/Materials"
local Items = require "cf_commonlib/Items"
local LibObjectSystem = require "cf_commonlib/ObjectSystem"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/LineJobs"
require "EnhancedIrrigation/Parts"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/ObjectSystem"
require "EnhancedIrrigation/Lines/LineObject"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/Lines/ValveSystem"

EnhancedIrrigation = EnhancedIrrigation or {}
local LineSystem = {}
EnhancedIrrigation.LineSystem = LineSystem

local Sprites = EnhancedIrrigation.Sprites
local Lines = EnhancedIrrigation.Lines
local LineJobs = EnhancedIrrigation.LineJobs
local Pipes = EnhancedIrrigation.Pipes
local Parts, Sprinklers = EnhancedIrrigation.Parts, EnhancedIrrigation.Sprinklers
local Valves, ValveSystem = EnhancedIrrigation.Valves, EnhancedIrrigation.ValveSystem

LineSystem.System = EnhancedIrrigation.ObjectSystem.define({
    name = "Line",
    sprites = Sprites.pipeNames(),
    owner = Lines,
    Object = EnhancedIrrigation.LineObject,
    isObject = Lines.isLine,
})

-- The name a line tile's object carries; nothing shows it, and the server has no translations.
local OBJECT_NAME = "EnhancedIrrigationLine"

-- Shows the tile at x, y, z and its four neighbours as their records say, after a tile came or
-- went between them.
local function reshapeAround(x, y, z)
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

--- Marks every tile of the line through x, y, z as run by its pump now, or not (`running`), and
--- tells their clients: a pumped line is held while its pump runs, as a tap is while someone holds
--- it. The pump says so again on each pass, so a tile laid on since, or a line split, is right by
--- the next one.
function LineSystem.setRunning(x, y, z, running)
    for _, tile in ipairs(Lines.component(x, y, z)) do
        tile.state.running = running or nil
        tile.state:sendSummary()
    end
end

-- A line split by a tile taken away is no longer known to run, each part until its pump says so.
local function forgetRunningAround(x, y, z)
    for _, step in ipairs(Lines.STEPS) do
        LineSystem.setRunning(x + step.dx, y + step.dy, z, false)
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
    reshapeAround(square:getX(), square:getY(), square:getZ())
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
    reshapeAround(x, y, z)
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
        reshapeAround(isoObject:getX(), isoObject:getY(), isoObject:getZ())
        forgetRunningAround(isoObject:getX(), isoObject:getY(), isoObject:getZ())
    end
end

-- Takes the sprinkler off the tile of `record`. Returns it as an item, as it went on.
local function takeSprinkler(record)
    local item = instanceItem(Sprinklers.ITEM)
    item:setCondition(record.sprinkler.condition)
    Parts.setCeiling(item, record.sprinkler.ceiling)
    record.sprinkler = nil
    return item
end

-- What each job does: Lay at the floor, with no record yet; every other at a line tile, on its
-- record brought up to now (ObjectSystem.jobSite).
local DO = {
    [LineJobs.LAY] = function(character, record, row, floor, kind, materials)
        LineSystem.place(floor:getSquare(), kind, { conditions = Materials.conditions(character, materials) })
        return true
    end,
    [LineJobs.DRILL] = function(character, record)
        record.holed = true
        if LineJobs.mayCrack(LineJobs.holeTool(character, record.material), record.material)
                and ZombRandFloat(0, 1) < Lines.PUNCH_CRACK_CHANCE then
            record.cracked = true
        end
        return true
    end,
    [LineJobs.TAP] = function(character, record, row, object, with, materials)
        record.tap = true
        record.tapMaterial = record.material
        record.tapConditions = Materials.conditions(character, materials)
        return true
    end,
    [LineJobs.PATCH] = function(character, record)
        record.cracked = false
        return true
    end,
    -- The water runs out over the ground where the line is opened, wetting it, not into a bed's
    -- roots, so it adds no soak.
    [LineJobs.DRAIN] = function(character, record)
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
        return true
    end,
    -- Each item comes back as it went in. A length still cracked is scrap. The tap's length, its
    -- valve and the sprinkler come back with their tile.
    [LineJobs.TAKE_UP] = function(character, record, row, object)
        if not record.cracked then
            Pipes.giveBack(character, record.material, 1, record.conditions)
        end
        if record.tap and record.tapMaterial then
            Pipes.giveBack(character, record.tapMaterial, 1, record.tapConditions)
        end
        if record.valve then
            Items.giveItems(character, ValveSystem.takeOff(record))
        end
        if record.sprinkler then
            Items.giveItems(character, takeSprinkler(record))
        end
        LineSystem.remove(object)
        return true
    end,
    -- The sprinkler carried goes on as it is: its condition and the ceiling its item carries.
    [LineJobs.SET_SPRINKLER] = function(character, record, row, object, item)
        Items.takeItem(character, item)
        record.sprinkler = { condition = item:getCondition(), ceiling = Parts.ceilingOf(item) }
        return true
    end,
    [LineJobs.TAKE_SPRINKLER] = function(character, record)
        Items.giveItems(character, takeSprinkler(record))
        return true
    end,
    [LineJobs.FIT_VALVE] = function(character, record, row, object, item)
        Items.takeItem(character, item)
        ValveSystem.fit(record, item)
        return true
    end,
    [LineJobs.TAKE_OFF_VALVE] = function(character, record)
        Items.giveItems(character, ValveSystem.takeOff(record))
        return true
    end,
    [LineJobs.WIND_VALVE] = function(character, record, row, object, with)
        ValveSystem.wind(record, Valves.decodeWind(with))
        return true
    end,
    [LineJobs.SET_TIMER] = function(character, record, row, object, with)
        ValveSystem.setTimer(record, Valves.decodeTimer(with))
        return true
    end,
}

local tileSite = LibObjectSystem.jobSite(Lines, DO)

--- The authority's side of the line jobs (a site of Jobs.perform): Lay works at the floor, where no
--- record is yet, and makes the tile's; every other job works on the record of the tile.
LineSystem.site = {
    open = tileSite.open,
    act = function(character, job, record, row, object, with, materials)
        if job == LineJobs.LAY then
            return DO[job](character, nil, row, object, with, materials)
        end
        return tileSite.act(character, job, record, row, object, with, materials)
    end,
    tell = tileSite.tell,
}

return LineSystem
