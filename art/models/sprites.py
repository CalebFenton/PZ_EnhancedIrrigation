"""The tile numbers of enhanced_irrigation_01, which Lua reads through Sprites.lua: keep the two in
step. Free of Blender, so tools/make_tiles.py reads them as the renders do.
"""
from art.tilefile import COLUMNS

TILESET = "enhanced_irrigation_01"

# Pipe tiles: a block per material in Sprites.PIPE_MATERIALS' order, the dry shapes then the wet
# ones, each numbered by its shape (the bits of the neighbours it joins).
PIPE_MATERIALS = ("plastic", "iron", "lead", "clay")
SHAPES = 16


def pipe_index(material, wet, shape):
    return PIPE_MATERIALS.index(material) * 2 * SHAPES + (SHAPES if wet else 0) + shape


TAP = 128
# The Tank Stand, then with the game's rain barrels on it: open, lidded, the tarp barrel open and
# lidded.
STAND = 129
RAISED_BARRELS = (130, 131, 132, 133)
BARREL_FILTER = 134
BRICK_FILTER = 135
FILTER_CROCK = 136
# The boilers: a Metal Drum on a brick firebox, then on a welded one.
BOILER_STONE = 137
BOILER_WELDED = 138
WOODEN_HAND_PUMP = 139
IRON_HAND_PUMP = 140
PUMP_HOUSE_WOOD = 141
PUMP_HOUSE_METAL = 142
SPRINKLER = 143
# The valves fitted to a tap, then a timer fitted to a Pump House.
TAP_WIND_UP = 144
TAP_TIMER_VALVE = 145
TAP_SPRINKLER_TIMER = 146
HOUSE_TIMER = 147

ROWS = HOUSE_TIMER // COLUMNS + 1  # the rows the last tile needs
