-- The authority's record of one garden line tile: its pipe, holes, wear and water. Time dries its
-- soak, rots a waterlogged plant above it and freezes it when full; the flow (Flow.lua) fills and
-- wets it; the jobs (LineSystem.lua) change the rest.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/ObjectSystem"

EnhancedIrrigation = EnhancedIrrigation or {}

local Sprites = EnhancedIrrigation.Sprites
local Pipes = EnhancedIrrigation.Pipes
local Lines = EnhancedIrrigation.Lines

local LineObject = EnhancedIrrigation.ObjectSystem.Object:derive("EnhancedIrrigation_Line")
EnhancedIrrigation.LineObject = LineObject

-- The world's save format: renaming one loses it from saves. material: the pipe's kind; holed;
-- cracked, patches; conditions: the condition of each item of pipe it was laid with, in order (none
-- listed: as new); full: water stands in it; soak: plant points of water in the soil under it; tap,
-- tapMaterial and tapConditions (the pipe it took), tapX, tapY, tapZ (its tank's square); wetUntil:
-- the hour its soil stops showing wet; exterior: whether it lies outdoors, as last seen loaded;
-- lastHour: when time last reached it.
LineObject.SAVED_FIELDS = {
    "material", "holed", "cracked", "patches", "conditions", "full", "soak",
    "tap", "tapMaterial", "tapConditions", "tapX", "tapY", "tapZ", "wetUntil", "exterior", "lastHour",
}

function LineObject:initNew()
    self.material = "plastic"
    self.holed = false
    self.cracked = false
    self.patches = 0
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

--- Whether the soil under the tile shows wet.
function LineObject:isWet()
    return self.soak >= Lines.DAMP or EnhancedIrrigation.now() < (self.wetUntil or 0)
end

--- The live, sown plant on the tile's square (its SFarmingSystem record, loaded or not), or nil.
function LineObject:plant()
    local farming = SFarmingSystem and SFarmingSystem.instance
    local plant = farming and farming:getLuaObjectAt(self.x, self.y, self.z)
    if plant and plant:isAlive() and plant.state ~= "plow" then
        return plant
    end
    return nil
end

function LineObject:addSoak(points)
    self.soak = math.min(Lines.SOAK_MAX, self.soak + points)
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

-- Soak dries; a plant standing in waterlogged soil mildews for as long as it stays so. The plant's
-- record keeps the change when its chunk is unloaded (saveData then writes nothing, and loading the
-- chunk puts the record on the plant, SPlantGlobalObject.stateToIsoObject).
function LineObject:dryAndRot(hours)
    local square = self:getSquare()
    if square then
        self.exterior = square:isOutside()
    end
    local perHour = (self.exterior and Lines.SOAK_DRY_OUT or Lines.SOAK_DRY_IN) / 24
    local rotting = hoursAbove(self.soak, Lines.WATERLOGGED, perHour, hours)
    self.soak = math.max(0, self.soak - perHour * hours)
    local plant = rotting > 0 and self:plant()
    if plant then
        plant.mildewLvl = math.min(Lines.PLANT_FULL, (plant.mildewLvl or 0) + Lines.MILDEW_PER_HOUR * rotting)
        plant:saveData()
    end
end

--- The air temperature, in Celsius, at the tile of `record`: its square's when loaded, which a room
--- warms, else the world's. A field so a test can freeze the garden.
function LineObject.temperatureAt(record)
    local square = record:getSquare()
    if square then
        return getClimateManager():getAirTemperatureForSquare(square)
    end
    return getClimateManager():getTemperature()
end

-- Water standing in the pipe may split it in a hard freeze.
function LineObject:freeze(hours)
    if not self.full or self.cracked then
        return
    end
    if LineObject.temperatureAt(self) > Lines.HARD_FREEZE_CELSIUS then
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

local function isTap(name)
    return name == Sprites.TAP
end

--- Shows the tile as its record says: the pipe joined to its neighbours, wet or dry, with the tap's
--- riser over it if it has one. Does nothing while its chunk is unloaded.
function LineObject:show()
    local isoObject = self:getIsoObject()
    if not isoObject then
        return
    end
    local shape = Lines.shapeAt(self.x, self.y, self.z, Lines.recordAt)
    EnhancedIrrigation.showSprite(isoObject, Sprites.pipe(self.material, self:isWet(), shape))
    EnhancedIrrigation.showOverlay(isoObject, isTap, self.tap and Sprites.TAP or nil)
end

function LineObject:afterChange()
    self:show()
    self:sendSummary()
end

-- What every client keeps: the fields the shared refusals read, under the record's names
-- (Lines.stateAt), rounded so a little drying sends nothing.
function LineObject:buildSummary()
    return {
        material = self.material,
        holed = self.holed,
        cracked = self.cracked,
        patches = self.patches,
        full = self.full,
        soak = EnhancedIrrigation.round(self.soak),
        tap = self.tap,
        tapX = self.tap and self.tapX or nil,
        tapY = self.tap and self.tapY or nil,
        tapZ = self.tap and self.tapZ or nil,
    }
end

return LineObject
