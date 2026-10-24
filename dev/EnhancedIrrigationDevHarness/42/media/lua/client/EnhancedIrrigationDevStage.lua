-- Development only. What the --art and --promo modes and the Enhanced Irrigation QA scenario need
-- besides the harness's staging (PZHarness/Stage.lua): finding a lot near the character, clearing
-- it, building the mod's tiles and sowing crops on it.

require "PZHarness/Fixtures"
require "EnhancedIrrigation/Utilities"
local Harness = require "PZHarness/Stage"

local Stage = {}

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

--- Clears `lot`'s `w` by `h` squares, and `margin` more round it, of trees and ground cover, so
--- nothing stands in the way of what is set on it.
function Stage.clearLot(lot, w, h, margin)
    for x = -margin, w + margin - 1 do
        for y = -margin, h + margin - 1 do
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

--- The object of the tile `sprite` on `square` as the build menu builds one
--- (ISBuildIsoEntity:setInfo): a thumpable with the entity that owns the tile. Returns it, or nil
--- and what is missing.
function Stage.build(square, sprite)
    local script = EnhancedIrrigation.tileEntity(sprite)
    if not script then
        return nil, "the entity of the tile " .. sprite
    end
    local thumpable = IsoThumpable.new(getCell(), square, sprite, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(thumpable, script, true)
    square:AddSpecialObject(thumpable)
    return thumpable
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
