-- Lawn Sprinklers: set on a garden line tile (LineJobs' Set Sprinkler), a sprinkler throws its
-- water over a rectangle of squares around it while a pump drives the line; a tank's gravity is
-- too weak to work one (docs/design.md, Garden lines). Its tile's record keeps it and the soak of
-- the squares it waters off the line (server/EnhancedIrrigation/Lines/LineObject.lua); the flow
-- sprays it (Flow.lua). What both sides read: which squares a sprinkler waters, and the soil word
-- at a square, from its own line tile and every sprinkler watering it.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/Pumps"

EnhancedIrrigation = EnhancedIrrigation or {}
local Sprinklers = {}
EnhancedIrrigation.Sprinklers = Sprinklers

local Sprites, Lines, Pumps = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.Pumps

Sprinklers.ITEM = "EnhancedIrrigation.LawnSprinkler"

-- Litres an hour a sprinkler asks of a pumped line, and the share of it lost to the air and the
-- paths between the beds: fast and wasteful, so ten minutes soaks a bed and an hour empties a rain
-- barrel (design, Starting numbers).
Sprinklers.RATE = 600
Sprinklers.LOST = 0.5
-- Squares the rectangle reaches from the sprinkler along the line and across it: five by three.
Sprinklers.ALONG = 2
Sprinklers.ACROSS = 1

-- The ceiling a sprinkler made from pipe comes out at, as a home-made part falls short of a bought
-- one (Pumps.MADE_CEILING).
Sprinklers.MADE_CEILING = 80

-- The shapes (Sprites.pipe) of a tile the line runs through north to south: straight, or its end.
local NORTH_SOUTH = {
    [Sprites.NORTH] = true, [Sprites.SOUTH] = true, [Sprites.NORTH + Sprites.SOUTH] = true,
}

--- The key of the square `dx`, `dy` from a sprinkler in its record's soak.
function Sprinklers.offsetKey(dx, dy)
    return dx .. "," .. dy
end

--- The squares the sprinkler on the line tile at x, y, z waters: the rectangle centred on it, its
--- long side along the line there, east to west where the line turns, branches or stands alone.
--- `isLineAt(x, y, z)` says where line lies (Lines.shapeAt). A list of { x, y, dx, dy }.
function Sprinklers.squaresOf(x, y, z, isLineAt)
    local reachX, reachY = Sprinklers.ALONG, Sprinklers.ACROSS
    if NORTH_SOUTH[Lines.shapeAt(x, y, z, isLineAt)] then
        reachX, reachY = reachY, reachX
    end
    local squares = {}
    for dx = -reachX, reachX do
        for dy = -reachY, reachY do
            table.insert(squares, { x = x + dx, y = y + dy, dx = dx, dy = dy })
        end
    end
    return squares
end

-- Whether the sprinkler on the line tile at x, y, z waters the square `dx`, `dy` from it.
local function waters(x, y, z, dx, dy)
    for _, square in ipairs(Sprinklers.squaresOf(x, y, z, Lines.stateAt)) do
        if square.dx == dx and square.dy == dy then
            return true
        end
    end
    return false
end

--- The IG_UI key of the soil word at x, y, z as this side knows it, or nil when the soil is dry:
--- the wettest of the line tile's on that square and of every sprinkler's that waters it.
function Sprinklers.soilKeyAt(x, y, z)
    local own = Lines.summaryAt(x, y, z)
    local key = own and own.soil
    for dx = -Sprinklers.ALONG, Sprinklers.ALONG do
        for dy = -Sprinklers.ALONG, Sprinklers.ALONG do
            local sx, sy = x - dx, y - dy
            local state = (dx ~= 0 or dy ~= 0) and Lines.stateAt(sx, sy, z)
            if state and state.sprinkler and waters(sx, sy, z, dx, dy) then
                local summary = Lines.summaryAt(sx, sy, z)
                local soil = summary and summary.sprinklerSoil
                key = Lines.wetterKey(key, soil and soil[Sprinklers.offsetKey(dx, dy)])
            end
        end
    end
    return key
end

--- OnCreate of Make Pipe Sprinkler (Recipes.txt): the sprinkler comes out at its lower ceiling,
--- which travels with it as a pump part's does (Pumps.setCeiling).
function Sprinklers.onMade(craftRecipeData, character)
    local sprinkler = craftRecipeData:getFirstCreatedItem()
    Pumps.setCeiling(sprinkler, Sprinklers.MADE_CEILING)
    sprinkler:setCondition(Sprinklers.MADE_CEILING)
    sprinkler:syncItemFields()
end

return Sprinklers
