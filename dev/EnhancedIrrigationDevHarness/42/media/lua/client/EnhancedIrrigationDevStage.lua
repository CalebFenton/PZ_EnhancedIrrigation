-- Development only. What the --art and --promo modes and the Enhanced Irrigation QA scenario need
-- besides the harness's staging (PZHarness/Stage.lua): finding a lot near the character, clearing
-- it, sowing crops on it, and the values they share. The mod's tiles are built through
-- EnhancedIrrigationDebugBuild.lua.

require "PZHarness/Fixtures"
local Harness = require "PZHarness/Stage"

local Stage = {}

Stage.VANILLA_WELL = "camping_01_16"
-- Water points of a crop just watered.
Stage.WATERED = 100
-- Fuel enough that a fire burns at its full light radius through every shot: the clock's jump to
-- a night shot burns the hours it skips (IsoFireplace.update counts world hours).
Stage.BOILER_FUEL = 48 * 60

--- A new sprinkler's record fields, as Set Sprinkler fits one.
function Stage.newSprinkler()
    return { condition = 100, ceiling = 100 }
end

local isGroundCover, clearGroundCover = Harness.isGroundCover, Harness.clearGroundCover

local function isNaturalFloor(square)
    local floor = square:getFloor()
    local name = floor and floor:getSprite() and floor:getSprite():getName()
    return name ~= nil and luautils.stringStarts(name, "blends_natural")
end

-- Open: outdoors, nothing on it the stage can't clear, and with `natural`, soil or grass, which
-- the wet patches show on and a furrow is dug in.
local function isOpen(square, natural)
    if square == nil or not square:isOutside() or not square:isSolidFloor() or square:getRoom() ~= nil
        or square:getWall(true) ~= nil or square:getWall(false) ~= nil or square:getVehicleContainer() ~= nil
        or (natural and not isNaturalFloor(square)) then
        return false
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if not object:isFloor() and object:getType() ~= IsoObjectType.tree and not isGroundCover(object) then
            return false
        end
    end
    return true
end

local function lotFits(cornerX, cornerY, z, w, h, natural)
    local cell = getCell()
    for x = cornerX, cornerX + w - 1 do
        for y = cornerY, cornerY + h - 1 do
            if not isOpen(cell:getGridSquare(x, y, z), natural) then
                return false
            end
        end
    end
    return true
end

-- Whether a lot `w` by `h` at x, y keeps `gap` squares from each of `others`.
local function isApart(x, y, w, h, others, gap)
    for _, other in ipairs(others) do
        if x < other.x + other.w + gap and other.x < x + w + gap and y < other.y + other.h + gap
            and other.y < y + h + gap then
            return false
        end
    end
    return true
end

--- The north-west corner of the closest lot `w` by `h` squares whose every square is open (only
--- trees and ground cover on it), on soil or grass with `natural`, or nil. With `others` (lots this
--- returned), it keeps `gap` squares from each of them; with `clearance`, the squares that far
--- round it are open too, of any floor, so that no building or fence stands at its edge. Returns
--- { x, y, z, w, h }.
function Stage.findLot(player, w, h, natural, others, gap, clearance)
    local c = clearance or 0
    local corner = Harness.closestSquare(player, function(square)
        local x, y, z = square:getX(), square:getY(), square:getZ()
        return isApart(x, y, w, h, others or {}, gap or 0) and lotFits(x, y, z, w, h, natural)
            and (c == 0 or lotFits(x - c, y - c, z, w + 2 * c, h + 2 * c, false))
    end)
    return corner and { x = corner:getX(), y = corner:getY(), z = corner:getZ(), w = w, h = h } or nil
end

--- The square `x`, `y` squares east and south of `lot`'s corner, `up` floors above it.
function Stage.lotSquare(lot, x, y, up)
    return getCell():getGridSquare(lot.x + x, lot.y + y, lot.z + (up or 0))
end

--- Clears `lot`'s squares, and `margin` more round it, of trees and ground cover, so nothing
--- stands in the way of what is set on it.
function Stage.clearLot(lot, margin)
    for x = -margin, lot.w + margin - 1 do
        for y = -margin, lot.h + margin - 1 do
            local square = Stage.lotSquare(lot, x, y)
            local tree = square and square:getTree()
            if tree then
                square:RemoveTileObject(tree)
            end
            if square then
                clearGroundCover(square)
            end
        end
    end
end

--- Stage.clearLot for shots, which also takes the trees further round (Harness.removeTrees), as
--- they draw black where the character can't see them.
function Stage.clearForShots(lot, margin)
    Harness.removeTrees(lot.x, lot.y, lot.z)
    Stage.clearLot(lot, margin)
end

--- Recalculates `lot`'s squares and those beside it, once what was set on them is in place, so
--- that they draw it.
function Stage.recalcLot(lot)
    for x = -1, lot.w do
        for y = -1, lot.h do
            local square = Stage.lotSquare(lot, x, y)
            if square then
                square:RecalcAllWithNeighbours(true)
            end
        end
    end
end

--- A crop sown on `square`, then grown to `stage` at full health and `water` water points, its tile
--- set as the farming system's growth sets it. Returns what is missing, or nil. Single player
--- only: SFarmingSystem is the authority's.
function Stage.plant(square, seed, stage, water)
    local farming = SFarmingSystem.instance
    farming:plow(square)
    local crop = farming:getLuaObjectOnSquare(square)
    if not crop then
        return "the plowed furrow's record at " .. square:getX() .. "," .. square:getY()
    end
    crop:seed(seed)
    crop.nbOfGrow = stage
    crop.health = 100
    crop.waterLvl = water
    crop.mildewLvl = 0
    crop:setSpriteName(farming_vegetableconf.getSpriteName(crop))
    crop:saveData()
end

return Stage
