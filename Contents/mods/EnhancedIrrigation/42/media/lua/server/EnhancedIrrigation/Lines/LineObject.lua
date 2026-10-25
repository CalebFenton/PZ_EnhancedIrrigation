-- The authority's record of one garden line tile: its pipe, holes, wear, sprinkler and water. Time
-- dries its soak and the soak its sprinkler left off the line, rots the roots of a plant in
-- waterlogged soil there and freezes it when full; the flow fills and wets it; the jobs change the
-- rest.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Frost"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/Lines/Plants"
require "EnhancedIrrigation/ObjectSystem"
local Tiles = require "cf_commonlib/Tiles"

EnhancedIrrigation = EnhancedIrrigation or {}

local Sprites = EnhancedIrrigation.Sprites
local Pipes = EnhancedIrrigation.Pipes
local Frost = EnhancedIrrigation.Frost
local Lines = EnhancedIrrigation.Lines
local Sprinklers = EnhancedIrrigation.Sprinklers
local Plants = EnhancedIrrigation.Plants

local LineObject = EnhancedIrrigation.ObjectSystem.Object:derive("EnhancedIrrigation_Line")
EnhancedIrrigation.LineObject = LineObject

-- The world's save format: renaming a field loses it from saves.
LineObject.SAVED_FIELDS = {
    "material", -- the pipe's kind
    "holed",
    "cracked",
    "conditions", -- the condition of each item of pipe it was laid with, in order; none listed: as new
    "full", -- water stands in it
    "soak", -- plant points of water in the soil under it
    "tap",
    "tapMaterial", -- the kind of the pipe the tap took
    "tapConditions", -- that pipe's, as `conditions`
    "wetUntil", -- the hour its soil stops showing wet
    "exterior", -- whether it lies outdoors, as last seen loaded
    "lastHour", -- when time last reached it
    "sprinkler", -- { condition, ceiling } of the Lawn Sprinkler set on it, as its item had them
    -- The soak of squares with no line tile that its sprinkler soaked, by Sprinklers.offsetKey from
    -- it; a square's on one record only (addSprinklerSoak).
    "sprinklerSoak",
    "valve", -- the valve on its tap, as ValveSystem keeps it
}
-- Unsaved: `running`, its pump runs the line now, and `valveOpen`, its valve does; each says so
-- again as it next runs after a load.

function LineObject:initNew()
    self.material = "plastic"
    self.holed = false
    self.cracked = false
    self.full = false
    self.soak = 0
    self.tap = false
    self.wetUntil = 0
    self.exterior = true
    self.lastHour = EnhancedIrrigation.now()
end

-- A tile without a record: a fresh one, or one whose record was lost with the system's save file.
function LineObject:stateFromIsoObject(isoObject)
    self:initNew()
    local sprite = isoObject:getSprite()
    self.material = Sprites.pipeOf(sprite and sprite:getName()) or self.material
    self.exterior = isoObject:getSquare():isOutside()
    self.summary = self:buildSummary()
end

-- The chunk loaded again: show what time did to the tile while it was away.
function LineObject:stateToIsoObject(isoObject)
    self.exterior = isoObject:getSquare():isOutside()
    self:show()
end

function LineObject:isWet()
    return self.soak >= Lines.DAMP or EnhancedIrrigation.now() < (self.wetUntil or 0)
end

function LineObject:addSoak(points)
    self.soak = math.min(Lines.SOAK_MAX, self.soak + points)
end

--- Adds `points` the tile's sprinkler threw to the soak of the square x, y off the line: on the
--- record already keeping it, so overlapping sprinklers share one soak there that rots and dries
--- once, else on this one. Returns the record it went on.
function LineObject:addSprinklerSoak(x, y, points)
    local keeper, key = Sprinklers.keeperOf(x, y, self.z, Lines.recordAt, "sprinklerSoak")
    if not keeper then
        keeper, key = self, Sprinklers.offsetKey(x - self.x, y - self.y)
        self.sprinklerSoak = self.sprinklerSoak or {}
    end
    keeper.sprinklerSoak[key] = math.min(Lines.SOAK_MAX, (keeper.sprinklerSoak[key] or 0) + points)
    return keeper
end

-- The hours of `hours` the soak stays above `level` while it dries at `perHour` from `soak`.
local function hoursAbove(soak, level, perHour, hours)
    if soak <= level then
        return 0
    end
    if perHour <= 0 then
        return hours
    end
    return math.min(hours, (soak - level) / perHour)
end

-- Dries `soak` for `hours` at `perHour`, rotting the roots of the plant at x, y, z for as long as
-- the soil stays waterlogged. Returns the soak left.
local function dryAndRotAt(soak, perHour, hours, x, y, z)
    local rotting = hoursAbove(soak, Lines.WATERLOGGED, perHour, hours)
    if rotting > 0 then
        Plants.rot(x, y, z, rotting)
    end
    return math.max(0, soak - perHour * hours)
end

-- Soak dries, under the tile and where its sprinkler soaked the soil, and rots the roots of a plant
-- left waterlogged; a square dried out is forgotten.
function LineObject:dryAndRot(hours)
    local square = self:getSquare()
    if square then
        self.exterior = square:isOutside()
    end
    local perHour = (self.exterior and Lines.SOAK_DRY_OUT or Lines.SOAK_DRY_IN) / 24
    self.soak = dryAndRotAt(self.soak, perHour, hours, self.x, self.y, self.z)
    if not self.sprinklerSoak then
        return
    end
    local left = nil
    for key, soak in pairs(self.sprinklerSoak) do
        local dx, dy = key:match("^(-?%d+),(-?%d+)$")
        soak = dryAndRotAt(soak, perHour, hours, self.x + tonumber(dx), self.y + tonumber(dy), self.z)
        if soak > 0 then
            left = left or {}
            left[key] = soak
        end
    end
    self.sprinklerSoak = left
end

-- Water standing in the pipe may split it in a hard freeze.
function LineObject:freeze(hours)
    if not self.full or self.cracked or not Frost.isHard(self) then
        return
    end
    local perHour = Pipes.MATERIALS[self.material].frostPerHour
    local chance = 1 - (1 - perHour) ^ hours
    if ZombRandFloat(0, 1) < chance then
        self.cracked = true
    end
end

function LineObject:advance(hours)
    if hours <= 0 then
        return
    end
    self:dryAndRot(hours)
    self:freeze(hours)
end

local OVERLAYS = { [Sprites.TAP] = true, [Sprites.SPRINKLER] = true }
for _, sprite in pairs(Sprites.TAP_VALVES) do
    OVERLAYS[sprite] = true
end

local function isOverlay(name)
    return OVERLAYS[name] == true
end

--- Shows the tile as its record says, joined to its neighbours. Does nothing while its chunk is
--- unloaded.
function LineObject:show()
    local isoObject = self:getIsoObject()
    if not isoObject then
        return
    end
    local shape = Lines.shapeAt(self.x, self.y, self.z, Lines.recordAt)
    Tiles.showTile(isoObject, Sprites.pipe(self.material, self:isWet(), shape))
    local overlays = {}
    if self.tap then
        table.insert(overlays, Sprites.TAP)
    end
    if self.valve then
        table.insert(overlays, Sprites.TAP_VALVES[self.valve.item])
    end
    if self.sprinkler then
        table.insert(overlays, Sprites.SPRINKLER)
    end
    Tiles.showOverlays(isoObject, isOverlay, overlays)
end

function LineObject:afterChange()
    self:show()
    self:sendSummary()
end

-- What every client keeps: the fields the shared refusals read, under the record's names
-- (Lines.stateAt), and the soil's words for the plant info, decided from the soak itself, as the
-- rot reads it, so a word never disagrees with the roots and a little drying sends nothing: under
-- the tile, and where its sprinkler soaked squares off the line, by Sprinklers.offsetKey. Of its
-- valve, what the menu says of it, not its clock.
function LineObject:buildSummary()
    local sprinklerSoil = nil
    for key, soak in pairs(self.sprinklerSoak or {}) do
        local word = Lines.soilKey(soak)
        if word then
            sprinklerSoil = sprinklerSoil or {}
            sprinklerSoil[key] = word
        end
    end
    local valve = self.valve
    return {
        material = self.material,
        holed = self.holed,
        cracked = self.cracked,
        full = self.full,
        soil = Lines.soilKey(self.soak),
        tap = self.tap,
        heldBy = self.heldBy,
        sprinkler = self.sprinkler ~= nil,
        sprinklerSoil = sprinklerSoil,
        running = self.running == true,
        valve = valve and { item = valve.item, start = valve.start, minutes = valve.minutes, untilHour = valve.untilHour },
        valveOpen = self.valveOpen == true,
    }
end

return LineObject
