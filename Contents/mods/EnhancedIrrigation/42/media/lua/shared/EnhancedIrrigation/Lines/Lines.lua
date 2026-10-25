-- Garden lines: pipe laid on the ground, one tile a square, joined to its same-floor neighbours
-- where no wall stands between, holed over the beds and tapped at a tank or fed by a pump's
-- outlet. The authority keeps a record of every tile in a Global Object System, saved with the
-- world and run loaded or not; every client gets each tile's summary, whose fields carry the
-- record's names, so the menu and the authority read a line the same way (Lines.stateAt).

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
local GlobalObjects = require "cf_commonlib/GlobalObjects"
local Squares = require "cf_commonlib/Squares"
require "EnhancedIrrigation/Links/Links"

EnhancedIrrigation = EnhancedIrrigation or {}
local Lines = {}
EnhancedIrrigation.Lines = Lines

local Sprites, Links = EnhancedIrrigation.Sprites, EnhancedIrrigation.Links

Lines.SYSTEM_NAME = "enhanced_irrigation_line"

-- Flow ---------------------------------------------------------------------------------------------

-- Litres an hour out of a hole under one storey of head: a few minutes at the tap a day keeps a
-- holed tile's plant watered. A higher tank pushes harder, by the square root of its head
-- (Torricelli).
Lines.HOLE_RATE = 1
-- Litres an hour out of a crack under one storey of head, while the tap runs: a split runs freer
-- than a drilled hole, and its water spills along the outside of the pipe, wetting the tile but
-- reaching no roots.
Lines.CRACK_RATE = 3
-- Vanilla's watering: one use of 200 mL adds 10 water points (SPlantGlobalObject.water).
Lines.POINTS_PER_LITRE = 50
-- The most water vanilla lets a plant hold (SPlantGlobalObject).
Lines.PLANT_FULL = 100
-- How long after the water stops the soil under an outlet, or where a line was drained, still
-- shows wet.
Lines.WET_HOURS = 4

-- Soak and root rot --------------------------------------------------------------------------------

-- The most soak a tile holds: the water an outlet gives past what its plant takes, in plant points.
Lines.SOAK_MAX = 100
-- Thresholds of the plant info's soil line: damp, soaked, and waterlogged (strictly above), where
-- the roots rot.
Lines.DAMP = 1
Lines.SOAKED = 15
Lines.WATERLOGGED = 30
-- Soak lost a day: sun and wind dry a bed outdoors faster than one under a roof.
Lines.SOAK_DRY_OUT = 10
Lines.SOAK_DRY_IN = 5
-- Health a plant loses an hour while its soil stays waterlogged, so drowned roots weigh on it as
-- drought does. Vanilla's health pass, every second hour (SFarmingSystem.changeHealth), takes the
-- first figure from a plant far short of water and gives the second to one watered enough, which a
-- waterlogged plant also is to vanilla: rot takes both, leaving it where a parched plant stands.
Lines.ROOT_ROT_PER_HOUR = (0.5 + 0.4) / 2

-- Holes ---------------------------------------------------------------------------------------------

-- A punched hole may split brittle pipe as it's made (Pipes.MATERIALS punchCracks).
Lines.PUNCH_CRACK_CHANCE = 0.2

-- The four same-floor neighbours of a tile, each with its bit in a pipe's shape. The edge between
-- a tile and a neighbour is the north or west edge of whichever of the two squares lies south or
-- east, where the game keeps a wall's flags.
Lines.STEPS = {
    { dx = 0, dy = -1, bit = Sprites.NORTH, edgeDx = 0, edgeDy = 0 },
    { dx = 1, dy = 0, bit = Sprites.EAST, edgeDx = 1, edgeDy = 0 },
    { dx = 0, dy = 1, bit = Sprites.SOUTH, edgeDx = 0, edgeDy = 1 },
    { dx = -1, dy = 0, bit = Sprites.WEST, edgeDx = 0, edgeDy = 0 },
}

-- A wall on the north (or west) edge of `square`: a solid wall, or a window in one. A square's
-- collideN (W) comes from walls, window frames, glazed or not, garage doors and fences; a door
-- frame and a door add none, so a line runs through a doorway. The square drops HoppableN (W)
-- when anything on that edge can't be hopped (IsoGridSquare.RecalcProperties), so a hoppable edge
-- holds only fences and low walls, which a pipe is laid over. Vanilla's isWallTo would block
-- those and pass a glazed window.
function Lines.wallOn(square, north)
    local props = square:getProperties()
    if north then
        return props:has(IsoFlagType.collideN) and not props:has(IsoFlagType.HoppableN)
            and not props:has(IsoFlagType.TallHoppableN)
    end
    return props:has(IsoFlagType.collideW) and not props:has(IsoFlagType.HoppableW)
        and not props:has(IsoFlagType.TallHoppableW)
end

--- Whether line on x, y, z and on its neighbour one `step` (of Lines.STEPS) away join: no wall
--- stands between their squares. An edge on a square this side hasn't loaded, such as a long
--- line's far end, joins: its walls can't be read there, and every edge a player works at is
--- loaded.
function Lines.joins(x, y, z, step)
    local square = getCell():getGridSquare(x + step.edgeDx, y + step.edgeDy, z)
    return square == nil or not Lines.wallOn(square, step.dy ~= 0)
end

function Lines.isLine(isoObject)
    local sprite = isoObject and isoObject:getSprite()
    return sprite ~= nil and Sprites.pipeOf(sprite:getName()) ~= nil
end

--- The line tile on `square`, or nil. Takes a nil square.
function Lines.lineOn(square)
    return Squares.findObjectOn(square, Lines.isLine)
end

function Lines.lineAt(x, y, z)
    return Lines.lineOn(getCell():getGridSquare(x, y, z))
end

function Lines.canTakeLine(square)
    if not square or not square:isFree(false) or square:getFloor() == nil then
        return false
    end
    if square:getFloor():getProperties():has(IsoFlagType.water) then
        return false
    end
    return Lines.lineOn(square) == nil
end

-- Summaries are the system's own tables; nothing here changes them. Only a multiplayer client
-- reads them: single player's client keeps its copy of a tile whose record just went until it
-- reads the removal packet, so the authority asks its records alone.
local function receivedAt(x, y, z)
    local system = isClient() and Lines.clientSystem
    local globalObject = system and system.system:getObjectAt(x, y, z)
    return globalObject and globalObject:getModData().summary or nil
end

--- The tile at x, y, z as this side knows it: on the authority its record, loaded or not, which
--- the line's own modules may change; on a multiplayer client the summary it has, read only. Nil
--- where there is no line tile.
function Lines.stateAt(x, y, z)
    return Lines.recordAt(x, y, z) or receivedAt(x, y, z)
end

function Lines.stateOf(isoObject)
    return Lines.stateAt(isoObject:getX(), isoObject:getY(), isoObject:getZ())
end

--- The summary of the tile at x, y, z as this side knows it: on the authority built from its
--- record, as currentSummary builds it; on a multiplayer client the one it has. Nil where there is
--- no line tile. Read only.
function Lines.currentSummaryAt(x, y, z)
    local record = Lines.recordAt(x, y, z)
    if record then
        return record:buildSummary()
    end
    return receivedAt(x, y, z)
end

--- The tiles of the line through x, y, z, the start first and the rest in the order water reaches
--- them from it: a list of { x, y, z, state }, `state` as Lines.stateAt gives it. Empty when x, y,
--- z holds no line tile.
function Lines.component(x, y, z)
    local list, seen = {}, {}
    local start = Lines.stateAt(x, y, z)
    if not start then
        return list
    end
    local squareKey = EnhancedIrrigation.squareKey
    seen[squareKey(x, y, z)] = true
    table.insert(list, { x = x, y = y, z = z, state = start })
    local i = 1
    while i <= #list do
        local tile = list[i]
        for _, step in ipairs(Lines.STEPS) do
            local nx, ny = tile.x + step.dx, tile.y + step.dy
            local key = squareKey(nx, ny, z)
            -- Marked only once reached: the tile behind a wall may join from another side.
            if not seen[key] and Lines.joins(tile.x, tile.y, z, step) then
                seen[key] = true
                local state = Lines.stateAt(nx, ny, z)
                if state then
                    table.insert(list, { x = nx, y = ny, z = z, state = state })
                end
            end
        end
        i = i + 1
    end
    return list
end

--- The tile of `tiles` (Lines.component) that holds the tap, or nil.
function Lines.tapIn(tiles)
    for _, tile in ipairs(tiles) do
        if tile.state.tap then
            return tile
        end
    end
    return nil
end

--- The outlet link of a pump that feeds the line of `tiles` (Lines.component), or nil.
function Lines.pumpFeeding(tiles)
    for _, link in ipairs(Links.all()) do
        if link.pump then
            local _, into = Links.ends(link)
            for _, tile in ipairs(tiles) do
                if EnhancedIrrigation.sameSquare(into, tile) then
                    return link
                end
            end
        end
    end
    return nil
end

-- A line takes one tap or one pump: two would each run every outlet on it, and a pump would push
-- against a tank. The Tooltip key refusing another feed to a line each kind feeds.
Lines.FEED_TAKEN = {
    tap = "Tooltip_EnhancedIrrigation_LineHasTap",
    pump = "Tooltip_EnhancedIrrigation_LinePumped",
}

--- What feeds the line of `tiles` (Lines.component): "tap" while a tap is on it, else "pump" while
--- a pump's outlet is plumbed to it, else nil.
function Lines.feedOf(tiles)
    if Lines.tapIn(tiles) then
        return "tap"
    end
    return Lines.pumpFeeding(tiles) and "pump" or nil
end

--- The shape (Sprites.pipe) of a tile at x, y, z: the bits of the neighbours `isLineAt(x, y, z)`
--- says hold line and no wall parts from it.
function Lines.shapeAt(x, y, z, isLineAt)
    local shape = 0
    for _, step in ipairs(Lines.STEPS) do
        if isLineAt(x + step.dx, y + step.dy, z) and Lines.joins(x, y, z, step) then
            shape = shape + step.bit
        end
    end
    return shape
end

--- The IG_UI key of the plant info's soil word for `soak`, or nil when the soil is dry.
function Lines.soilKey(soak)
    if not soak or soak < Lines.DAMP then
        return nil
    elseif soak > Lines.WATERLOGGED then
        return "IGUI_EnhancedIrrigation_Waterlogged"
    elseif soak >= Lines.SOAKED then
        return "IGUI_EnhancedIrrigation_Soaked"
    end
    return "IGUI_EnhancedIrrigation_Damp"
end

local SOIL_RANK = {
    IGUI_EnhancedIrrigation_Damp = 1, IGUI_EnhancedIrrigation_Soaked = 2, IGUI_EnhancedIrrigation_Waterlogged = 3,
}

--- The wetter of two soil words (Lines.soilKey), either of which may be nil for dry soil.
function Lines.wetterKey(a, b)
    if not a or (b and SOIL_RANK[b] > SOIL_RANK[a]) then
        return b
    end
    return a
end

-- A line tile has no containers, so a summary needs nothing added on read.
GlobalObjects.addAccessors(Lines, function() end)

return Lines
