-- Development only. What the --art mode and the Enhanced Irrigation QA scenario need besides the
-- harness: finding a lot near the character, clearing its trees and ground cover, building the
-- mod's tiles and sowing crops on it, and the steps that walk the character to a shot and frame it
-- (run by PZHarness/Capture.lua). Taken from Renewable Energy's RenewableEnergyDevStage.lua,
-- keeping only what this mod's stages use.

require "PZHarness/Fixtures"
require "EnhancedIrrigation/Utilities"

local Stage = {}

-- How far around the character a place is looked for, in squares.
Stage.SEARCH_RADIUS = 40
-- How far from a place the trees go: near a building, a tree out of the character's sight draws
-- as a black silhouette full of holes (IsoTree.render).
local TREE_RADIUS = 30
-- The character faces the camera last.
local LOOK_AROUND = { IsoDirections.N, IsoDirections.E, IsoDirections.S, IsoDirections.W, IsoDirections.SE }
-- Lighting passes a facing is held for: the main thread hands the facing to the lighting thread on
-- its next update, the thread's next pass sees with it, and the pass after that one is back.
local LOOK_PASSES = 3
-- The lighting thread shows a change of facing within about a tenth of a second, so lighting this
-- long unchanged has settled.
local SETTLE_MS = 300
local SETTLE_RADIUS = 15
-- Steps to scroll in to reach the closest zoom.
local STEPS_TO_CLOSEST = 8

-- How many squares around the character it has seen, and the sum of their light levels: together
-- they change when a square is newly seen or its light changes.
local function lightingState(player)
    local here = player:getCurrentSquare()
    if not here then
        return nil, nil
    end
    local cell, x, y, z = getCell(), here:getX(), here:getY(), here:getZ()
    local playerNum = player:getPlayerNum()
    local seen, light = 0, 0
    for dx = -SETTLE_RADIUS, SETTLE_RADIUS do
        for dy = -SETTLE_RADIUS, SETTLE_RADIUS do
            local square = cell:getGridSquare(x + dx, y + dy, z)
            if square then
                seen = seen + (square:isSeen(playerNum) and 1 or 0)
                light = light + math.floor(square:getLightLevel(playerNum) * 100)
            end
        end
    end
    return seen, light
end

--- A runSteps wait until the lighting around the character has settled: no square newly seen and
--- no light level changed for SETTLE_MS.
function Stage.lightingSettled(player)
    -- The lighting changes only once per pass of its thread, so the area is scanned once a pass
    -- rather than every one of the hundreds of frames a second an uncapped run draws.
    local interval = 1000 / getPerformance():getLightingFPS()
    local lastSeen, lastLight, since, sampled
    return function()
        local now = getTimestampMs()
        if sampled and now - sampled < interval then
            return false
        end
        sampled = now
        local seen, light = lightingState(player)
        if seen ~= lastSeen or light ~= lastLight or not since then
            lastSeen, lastLight, since = seen, light, now
            return false
        end
        return now - since >= SETTLE_MS
    end
end

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

--- Removes every tree within TREE_RADIUS of x, y on level z.
function Stage.removeTrees(x, y, z)
    local cell = getCell()
    for dx = -TREE_RADIUS, TREE_RADIUS do
        for dy = -TREE_RADIUS, TREE_RADIUS do
            local square = cell:getGridSquare(x + dx, y + dy, z)
            local tree = square and square:getTree()
            if tree then
                square:RemoveTileObject(tree)
            end
        end
    end
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

--- A crop sown on `square` as the line tests sow one (lines.plant), then grown to `stage` at full
--- health and `water` water points, its tile set as the farming system's growth sets it. Returns
--- what is missing, or nil. Single player only: SFarmingSystem is the authority's.
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

--- Adds the steps that put the character on `square` and have it look around, since squares it
--- never saw are drawn dark. Its sight sweeps round with each turn, so only the last waits for the
--- lighting to settle.
function Stage.addLookAround(steps, player, square)
    table.insert(steps, function()
        -- To the middle: teleportTo alone leaves it on the north-west corner, inside the footprint
        -- of whatever stands diagonally behind it.
        PZHarness.Fixtures.teleportToMiddle(player, square:getX(), square:getY(), square:getZ())
        return function()
            return player:getCurrentSquare() == square
        end
    end)
    for _, direction in ipairs(LOOK_AROUND) do
        local target = direction:ToVector()
        local length = math.sqrt(target:getX() ^ 2 + target:getY() ^ 2)
        local targetX, targetY = target:getX() / length, target:getY() / length
        -- Turned at once, body and animation, rather than over the half second a turn takes.
        table.insert(steps, function()
            player:setTargetAndCurrentDirection(targetX, targetY)
            local untilMs = getTimestampMs() + LOOK_PASSES * 1000 / getPerformance():getLightingFPS()
            return function()
                return getTimestampMs() >= untilMs
            end
        end)
    end
    table.insert(steps, function()
        return Stage.lightingSettled(player)
    end)
end

--- Sets the zoom `stepsOut` steps out from the closest.
function Stage.zoomOut(stepsOut)
    for _ = 1, STEPS_TO_CLOSEST do
        getCore():doZoomScroll(0, -1)
    end
    for _ = 1, stepsOut do
        getCore():doZoomScroll(0, 1)
    end
end

return Stage
