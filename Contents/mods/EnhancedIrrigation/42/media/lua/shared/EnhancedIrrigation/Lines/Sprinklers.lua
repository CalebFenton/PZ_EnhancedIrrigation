-- Lawn Sprinklers: set on a garden line tile, a sprinkler throws its water over a rectangle of
-- squares around it while a pump drives the line; a tank's gravity is too weak to work one. Its
-- tile's record keeps it and the soak of the squares it waters off the line. What both sides read:
-- which squares a sprinkler waters, and the soil word at a square, from its own line tile and the
-- soak any sprinkler left on it.

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Parts"

EnhancedIrrigation = EnhancedIrrigation or {}
local Sprinklers = {}
EnhancedIrrigation.Sprinklers = Sprinklers

local Sprites, Lines, Parts = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.Parts

Sprinklers.ITEM = "EnhancedIrrigation.LawnSprinkler"

-- Litres an hour a sprinkler asks of a pumped line, and the share of it lost to the air and the
-- paths between the beds. Each square it waters gets about what a pumped hole gives its own, so a
-- daily run set by watching a held tap suits both (design, Starting numbers); faster, no daily run
-- would lie between a dry bed and a drowned one.
Sprinklers.RATE = 54
Sprinklers.LOST = 0.5
-- Squares the rectangle reaches each way from the sprinkler, along the line and across it.
Sprinklers.ALONG = 2
Sprinklers.ACROSS = 1

-- The ceiling a sprinkler made from pipe comes out at.
Sprinklers.MADE_CEILING = 80

-- The shapes (Sprites.pipe) of a tile the line runs through north to south: straight, or its end.
local NORTH_SOUTH = {
    [Sprites.NORTH] = true, [Sprites.SOUTH] = true, [Sprites.NORTH + Sprites.SOUTH] = true,
}

--- The key of the square `dx`, `dy` from the line tile whose record keeps its soak.
function Sprinklers.offsetKey(dx, dy)
    return dx .. "," .. dy
end

--- The squares the sprinkler on the line tile at x, y, z waters: the rectangle centred on it, its
--- long side along the line there, east to west where the line turns, branches or stands alone.
--- `isLineAt(x, y, z)` says where line lies (Lines.shapeAt). A list of { x, y }.
function Sprinklers.squaresOf(x, y, z, isLineAt)
    local reachX, reachY = Sprinklers.ALONG, Sprinklers.ACROSS
    if NORTH_SOUTH[Lines.shapeAt(x, y, z, isLineAt)] then
        reachX, reachY = reachY, reachX
    end
    local squares = {}
    for dx = -reachX, reachX do
        for dy = -reachY, reachY do
            table.insert(squares, { x = x + dx, y = y + dy })
        end
    end
    return squares
end

--- The state of those `stateAt(x, y, z)` gives that keeps what sprinklers left on the square x, y,
--- z off the line, and the square's key in its `field` (a record's sprinklerSoak, a summary's
--- sprinklerSoil); nil when none does. A square has one keeper (LineObject:addSprinklerSoak),
--- sought as far along either axis, as a sprinkler's rectangle may lie either way.
function Sprinklers.keeperOf(x, y, z, stateAt, field)
    for dx = -Sprinklers.ALONG, Sprinklers.ALONG do
        for dy = -Sprinklers.ALONG, Sprinklers.ALONG do
            local state = (dx ~= 0 or dy ~= 0) and stateAt(x - dx, y - dy, z)
            local kept = state and state[field]
            local key = Sprinklers.offsetKey(dx, dy)
            if kept and kept[key] then
                return state, key
            end
        end
    end
    return nil
end

--- The IG_UI key of the soil word at x, y, z as this side knows it, or nil when the soil is dry:
--- the wetter of the line tile's on that square and of the soak a sprinkler left on it, which
--- rots the roots for as long as it lasts, whether or not a sprinkler waters the square now.
function Sprinklers.soilKeyAt(x, y, z)
    local own = Lines.currentSummaryAt(x, y, z)
    local keeper, key = Sprinklers.keeperOf(x, y, z, Lines.currentSummaryAt, "sprinklerSoil")
    return Lines.wetterKey(own and own.soil, keeper and keeper.sprinklerSoil[key])
end

--- OnCreate of Make Pipe Sprinkler (Recipes.txt).
function Sprinklers.onMade(craftRecipeData)
    Parts.made(craftRecipeData, Sprinklers.MADE_CEILING)
end

return Sprinklers
