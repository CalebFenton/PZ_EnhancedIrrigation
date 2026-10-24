-- The authority's record of one garden line tile: its pipe, holes, wear, sprinkler and water. Time
-- dries its soak and the soak its sprinkler left off the line, rots the roots of a plant in
-- waterlogged soil there and freezes it when full; the flow (Flow.lua) fills and wets it; the jobs
-- (LineSystem.lua) change the rest.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Frost"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Sprinklers"
require "EnhancedIrrigation/ObjectSystem"

EnhancedIrrigation = EnhancedIrrigation or {}

local Sprites = EnhancedIrrigation.Sprites
local Pipes = EnhancedIrrigation.Pipes
local Frost = EnhancedIrrigation.Frost
local Lines = EnhancedIrrigation.Lines
local Sprinklers = EnhancedIrrigation.Sprinklers

local LineObject = EnhancedIrrigation.ObjectSystem.Object:derive("EnhancedIrrigation_Line")
EnhancedIrrigation.LineObject = LineObject

-- The world's save format: renaming one loses it from saves. material: the pipe's kind; holed;
-- cracked; conditions: the condition of each item of pipe it was laid with, in order (none listed:
-- as new); full: water stands in it; soak: plant points of water in the soil under it; tap,
-- tapMaterial and tapConditions (the pipe it took); wetUntil: the hour its soil stops showing wet;
-- exterior: whether it lies outdoors, as last seen loaded; lastHour: when time last reached it;
-- sprinkler: { condition, ceiling } of the Lawn Sprinkler set on it, as its item had them, nil for
-- none; sprinklerSoak: the soak of squares with no line tile that its sprinkler soaked, by
-- Sprinklers.offsetKey from it, nil for none, a square's on one record only, the first sprinkler's
-- to soak it (addSprinklerSoak); valve: the valve on its tap, nil for none (ValveSystem.lua).
-- Unsaved, `running`: its pump runs the line now (LineSystem.showRunning), which a loaded world's
-- pumps say again; and `valveOpen`: its valve runs the line now, which the valve says again.
LineObject.SAVED_FIELDS = {
    "material", "holed", "cracked", "conditions", "full", "soak", "tap", "tapMaterial", "tapConditions",
    "wetUntil", "exterior", "lastHour", "sprinkler", "sprinklerSoak", "valve",
}

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

--- The live, sown plant on the square x, y, z (its SFarmingSystem record, loaded or not), or nil.
function LineObject.plantAt(x, y, z)
    local farming = SFarmingSystem and SFarmingSystem.instance
    local plant = farming and farming:getLuaObjectAt(x, y, z)
    if plant and plant:isAlive() and plant.state ~= "plow" then
        return plant
    end
    return nil
end

function LineObject:addSoak(points)
    self.soak = math.min(Lines.SOAK_MAX, self.soak + points)
end

-- The line record within a sprinkler's reach of the square x, y, z that keeps its soak, and the
-- square's key there; nil when none does.
local function soakHolder(x, y, z)
    for dx = -Sprinklers.ALONG, Sprinklers.ALONG do
        for dy = -Sprinklers.ALONG, Sprinklers.ALONG do
            local record = Lines.recordAt(x - dx, y - dy, z)
            local key = Sprinklers.offsetKey(dx, dy)
            if record and record.sprinklerSoak and record.sprinklerSoak[key] then
                return record, key
            end
        end
    end
    return nil
end

--- Adds `points` the tile's sprinkler threw to the soak of the square x, y off the line: on the
--- record already keeping it, so overlapping sprinklers share one soak there that rots and dries
--- once, else on this one. Returns the record it went on.
function LineObject:addSprinklerSoak(x, y, points)
    local holder, key = soakHolder(x, y, self.z)
    if not holder then
        holder, key = self, Sprinklers.offsetKey(x - self.x, y - self.y)
        self.sprinklerSoak = self.sprinklerSoak or {}
    end
    holder.sprinklerSoak[key] = math.min(Lines.SOAK_MAX, (holder.sprinklerSoak[key] or 0) + points)
    return holder
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

-- Dries `soak` for `hours` at `perHour`; the plant at x, y, z, if any, loses health to root rot for
-- as long as the soil stays waterlogged, down to none, where vanilla's own check kills it
-- (SPlantGlobalObject.checkStat). The plant's record keeps the change when its chunk is unloaded
-- (saveData then writes nothing, and loading the chunk puts the record on the plant,
-- SPlantGlobalObject.stateToIsoObject). Returns the soak left.
local function dryAndRotAt(soak, perHour, hours, x, y, z)
    local rotting = hoursAbove(soak, Lines.WATERLOGGED, perHour, hours)
    local plant = rotting > 0 and LineObject.plantAt(x, y, z)
    if plant then
        plant.health = math.max(0, plant.health - Lines.ROOT_ROT_PER_HOUR * rotting)
        plant:saveData()
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

-- Read by Treatment until it reads Frost.
function LineObject.temperatureAt(record)
    return Frost.celsiusAt(record)
end

-- Water standing in the pipe may split it in a hard freeze.
function LineObject:freeze(hours)
    if not self.full or self.cracked or not Frost.isHard(self) then
        return
    end
    local perHour = Pipes.KINDS[self.material].frostPerHour
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

-- The overlays a tile may carry.
local OVERLAYS = { [Sprites.TAP] = true, [Sprites.SPRINKLER] = true }
for _, sprite in pairs(Sprites.TAP_VALVES) do
    OVERLAYS[sprite] = true
end

local function isOverlay(name)
    return OVERLAYS[name] == true
end

--- Shows the tile as its record says: the pipe joined to its neighbours, wet or dry, with the tap's
--- riser and its valve or the sprinkler over it if it has one. Does nothing while its chunk is
--- unloaded.
function LineObject:show()
    local isoObject = self:getIsoObject()
    if not isoObject then
        return
    end
    local shape = Lines.shapeAt(self.x, self.y, self.z, Lines.recordAt)
    EnhancedIrrigation.ObjectSystem.showSprite(isoObject, Sprites.pipe(self.material, self:isWet(), shape))
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
    EnhancedIrrigation.ObjectSystem.showOverlays(isoObject, isOverlay, overlays)
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
