"""What each tile of enhanced_irrigation_01 shows, built from the builders in items.py.

The index of each entry is the tile's number, which Lua reads through
media/lua/shared/EnhancedIrrigation/Sprites.lua and tools/make_tiles.py gives properties; keep the
three in step. A tile is a list of layers. A layer marked `holdout` is drawn invisible: an overlay
tile renders the object it sits on that way, so it keeps only the pixels the object doesn't hide.

Tile coordinates are a square one metre wide centred on the origin: its north edge is y = +0.5 and
its west edge x = -0.5 (see kit.py).
"""
import items


def layer(build, holdout=False, at=(0, 0, 0), turn=0, scale=1, **options):
    return {"build": build, "options": options, "at": at, "turn": turn, "scale": scale, "holdout": holdout}


# Pipe tiles: a block of 32 per material in Sprites.PIPE_MATERIALS' order, the dry shapes then the
# wet ones, each numbered by its shape (the bits of the neighbours it joins).
PIPE_MATERIALS = ("plastic", "iron", "lead", "clay")
SHAPES = 16


def pipe_index(material, wet, shape):
    return PIPE_MATERIALS.index(material) * 32 + (SHAPES if wet else 0) + shape


TILES = {}
for material in PIPE_MATERIALS:
    for wet in (False, True):
        for shape in range(SHAPES):
            TILES[pipe_index(material, wet, shape)] = [layer(items.pipe, material=material, shape=shape, wet=wet)]

# The tap: an overlay on any pipe tile, so it has no base of its own to hold out; it stands on the
# tile's middle, where every shape but a lone piece has pipe.
TAP = 128
TILES[TAP] = [layer(items.tap)]

# The Tank Stand, then with the game's rain barrels on it: open, lidded, the tarp barrel open and
# lidded (carpentry_02_122, _126, _124 and _127).
STAND = 129
TILES[STAND] = [layer(items.tank_stand)]
for index, barrel, tarp in ((130, "open", False), (131, "closed", False), (132, "open", True), (133, "closed", True)):
    TILES[index] = [layer(items.tank_stand, barrel=barrel, tarp=tarp)]

# The sand filters.
BARREL_FILTER = 134
BRICK_FILTER = 135
TILES[BARREL_FILTER] = [layer(items.barrel_filter)]
TILES[BRICK_FILTER] = [layer(items.brick_filter)]

# The Filter Crock in its bucket.
FILTER_CROCK = 136
TILES[FILTER_CROCK] = [layer(items.crock_in_bucket)]

# Build-menu icons by the name after EnhancedIrrigation_Build_: each thing as it stands built.
BUILD_ICONS = {
    "TankStand": [layer(items.tank_stand)],
    "BarrelFilter": [layer(items.barrel_filter)],
    "BrickFilter": [layer(items.brick_filter)],
    "FilterCrock": [layer(items.crock_in_bucket)],
}
