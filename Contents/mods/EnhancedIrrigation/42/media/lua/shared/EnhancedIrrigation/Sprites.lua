-- The mod's tiles, named here only. Their numbers must stay in step with art/models/tiles.py, which
-- draws them, and tools/make_tiles.py, which gives them their properties.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Sprites = {}
EnhancedIrrigation.Sprites = Sprites

local TILESET = "enhanced_irrigation_01"

local function tile(index)
    return TILESET .. "_" .. index
end

-- Garden pipe: one tile for each material, dry or wet, and which of its four neighbours it joins,
-- so a line draws itself from its pieces. The material's place in this list is its block of tiles.
Sprites.PIPE_MATERIALS = { "plastic", "iron", "lead", "clay" }
local MATERIAL_BLOCK = {}
for i, material in ipairs(Sprites.PIPE_MATERIALS) do
    MATERIAL_BLOCK[material] = i - 1
end

-- A neighbour's bit in a pipe's shape: north is y - 1, east x + 1, south y + 1, west x - 1.
Sprites.NORTH, Sprites.EAST, Sprites.SOUTH, Sprites.WEST = 1, 2, 4, 8

--- The pipe tile of `material` ("plastic"...), `wet` or dry, joining the neighbours in `shape`
--- (the sum of their bits; 0 is a lone piece).
function Sprites.pipe(material, wet, shape)
    return tile(MATERIAL_BLOCK[material] * 32 + (wet and 16 or 0) + shape)
end

local PIPE_LAST = #Sprites.PIPE_MATERIALS * 32 - 1

--- The material, wetness and shape of a pipe tile's name, or nil for any other name.
function Sprites.pipeOf(spriteName)
    local index = spriteName and spriteName:match("^" .. TILESET .. "_(%d+)$")
    index = index and tonumber(index)
    if not index or index > PIPE_LAST then
        return nil
    end
    local material = Sprites.PIPE_MATERIALS[math.floor(index / 32) + 1]
    return material, index % 32 >= 16, index % 16
end

--- Every pipe tile's name, for load hooks.
function Sprites.pipeNames()
    local names = {}
    for index = 0, PIPE_LAST do
        table.insert(names, tile(index))
    end
    return names
end

-- The tap riser, drawn over the pipe tile at a line's head.
Sprites.TAP = tile(128)

-- The Tank Stand, empty, and with a rain barrel on it: open, lidded, and the tarp barrel open and
-- lidded. The lidded ones' entities are named as the open ones' plus "Closed", which is how
-- vanilla's lid action (ISOpenCloseLid) finds the other.
Sprites.STAND = tile(129)
Sprites.RAISED_BARREL = tile(130)
Sprites.RAISED_BARREL_CLOSED = tile(131)
Sprites.RAISED_TARP_BARREL = tile(132)
Sprites.RAISED_TARP_BARREL_CLOSED = tile(133)

-- The priority every loader of the mod's tiles passes to MapObjects.OnLoadWithSprite. MapObjects
-- keeps one function per sprite and priority, a later one silently replacing an earlier
-- (MapObjects.java), so a second loader of the same tiles on one side needs a priority of its own.
Sprites.LOAD_PRIORITY = 6

return Sprites
