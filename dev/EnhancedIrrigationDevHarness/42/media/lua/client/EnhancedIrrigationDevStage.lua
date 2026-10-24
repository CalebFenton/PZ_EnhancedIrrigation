-- Development only. What the --art mode and the Enhanced Irrigation QA scenario need besides the
-- harness: finding a lot near the character, clearing its trees and ground cover, building the
-- mod's tiles and sowing crops on it. Taken from Renewable Energy's RenewableEnergyDevStage.lua,
-- keeping only what this mod's stages use.

require "PZHarness/Fixtures"
require "EnhancedIrrigation/Utilities"

local Stage = {}

-- How far around the character a place is looked for, in squares.
Stage.SEARCH_RADIUS = 40

--- The loaded square closest to the character, within SEARCH_RADIUS on its level, for which
--- `accepts(square)` holds, or nil. Of squares as close, the one furthest west, then north.
function Stage.closestSquare(player, accepts)
    local here = player:getCurrentSquare()
    local x, y, z = here:getX(), here:getY(), here:getZ()
    local best, bestDistance, bestDx, bestDy
    -- Ring by ring outwards, until no square of the next ring can be as close as the best.
    for radius = 0, Stage.SEARCH_RADIUS do
        if bestDistance and radius * radius > bestDistance then
            break
        end
        for sx, sy in PZHarness.Fixtures.ring(x, y, radius) do
            local dx, dy = sx - x, sy - y
            local distance = dx * dx + dy * dy
            if not bestDistance or distance < bestDistance
                or (distance == bestDistance and (dx < bestDx or (dx == bestDx and dy < bestDy))) then
                local square = getCell():getGridSquare(sx, sy, z)
                if square and accepts(square) then
                    best, bestDistance, bestDx, bestDy = square, distance, dx, dy
                end
            end
        end
    end
    return best
end

-- The tileset of the litter the world's generation strews on open ground: twigs, small stumps and
-- fallen branches (tiledefinitions_erosion, WorldGen's generic_plant), only some of which vanilla
-- flags as removable.
local LITTER = "d_generic_1_"

--- Grass, weeds and bushes a character could pull up (as vanilla's remove-grass and building code
--- tell them from other objects), and litter.
function Stage.isGroundCover(object)
    local props = object:getProperties()
    local sprite = object:getSprite() and object:getSprite():getName()
    return (props ~= nil and (props:has(IsoFlagType.canBeRemoved)
        or (props:has(IsoFlagType.vegitation) and object:getType() ~= IsoObjectType.tree)))
        or (sprite ~= nil and luautils.stringStarts(sprite, LITTER))
end

--- Clears the ground cover off `square`, so what is set on it shows.
function Stage.clearGroundCover(square)
    local objects = square:getObjects()
    for i = objects:size() - 1, 0, -1 do
        if Stage.isGroundCover(objects:get(i)) then
            square:RemoveTileObject(objects:get(i))
        end
    end
end

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
        if not object:isFloor() and object:getType() ~= IsoObjectType.tree and not Stage.isGroundCover(object) then
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

--- The north-west corner of the closest lot `w` by `h` squares whose every square is open (only
--- trees and ground cover on it), on soil or grass with `natural`, or nil. Returns { x, y, z }.
function Stage.findLot(player, w, h, natural)
    local corner = Stage.closestSquare(player, function(square)
        return lotFits(square:getX(), square:getY(), square:getZ(), w, h, natural)
    end)
    return corner and { x = corner:getX(), y = corner:getY(), z = corner:getZ() } or nil
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
                Stage.clearGroundCover(square)
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
