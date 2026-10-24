"""What each tile of enhanced_irrigation_01 shows, by its number in sprites.py, built from the
builders in items.py. A tile is a list of layers.

Tile coordinates are a square one metre wide centred on the origin: its north edge is y = +0.5 and
its west edge x = -0.5 (see kit.py).
"""
import items
from sprites import (BARREL_FILTER, BOILER_STONE, BOILER_WELDED, BRICK_FILTER, COLUMNS, FILTER_CROCK, HOUSE_TIMER,
                     IRON_HAND_PUMP, PIPE_MATERIALS, PUMP_HOUSE_METAL, PUMP_HOUSE_WOOD, RAISED_BARRELS, ROWS, SHAPES,
                     SPRINKLER, STAND, TAP, TAP_SPRINKLER_TIMER, TAP_TIMER_VALVE, TAP_WIND_UP, WOODEN_HAND_PUMP,
                     pipe_index)


def layer(build, turn=0, **options):
    return {"build": build, "options": options, "turn": turn}


TILES = {}
for material in PIPE_MATERIALS:
    for wet in (False, True):
        for shape in range(SHAPES):
            TILES[pipe_index(material, wet, shape)] = [layer(items.pipe, material=material, shape=shape, wet=wet)]

# The tap: an overlay on any pipe tile, standing on the tile's middle, where every shape but a lone
# piece has pipe.
TILES[TAP] = [layer(items.tap)]

# The game's rain barrels on the stand: carpentry_02_122, _126, _124 and _127.
TILES[STAND] = [layer(items.tank_stand)]
for index, (barrel, tarp) in zip(RAISED_BARRELS, (("open", False), ("closed", False), ("open", True), ("closed", True))):
    TILES[index] = [layer(items.tank_stand, barrel=barrel, tarp=tarp)]
TILES[BARREL_FILTER] = [layer(items.barrel_filter)]
TILES[BRICK_FILTER] = [layer(items.brick_filter)]
TILES[FILTER_CROCK] = [layer(items.crock_in_bucket)]
TILES[BOILER_STONE] = [layer(items.boiler_stone)]
TILES[BOILER_WELDED] = [layer(items.boiler_welded)]
TILES[WOODEN_HAND_PUMP] = [layer(items.wooden_hand_pump)]
TILES[IRON_HAND_PUMP] = [layer(items.iron_hand_pump)]
TILES[PUMP_HOUSE_WOOD] = [layer(items.pump_house_wood)]
TILES[PUMP_HOUSE_METAL] = [layer(items.pump_house_metal)]
# The lawn sprinkler: an overlay on a line tile, as the tap is, standing on the tile's middle.
TILES[SPRINKLER] = [layer(items.sprinkler)]
# Overlays drawn with the tap's, hung off its spout, then one on either Pump House by its plug.
TILES[TAP_WIND_UP] = [layer(items.tap_wind_up_valve)]
TILES[TAP_TIMER_VALVE] = [layer(items.tap_timer_valve)]
TILES[TAP_SPRINKLER_TIMER] = [layer(items.tap_sprinkler_timer)]
TILES[HOUSE_TIMER] = [layer(items.house_timer)]
assert max(TILES) < COLUMNS * ROWS, "a tile past sprites.ROWS: raise it to the last tile's"

# Build-menu icons by the name after EnhancedIrrigation_Build_: each thing as it stands built.
BUILD_ICONS = {
    "TankStand": [layer(items.tank_stand)],
    "BarrelFilter": [layer(items.barrel_filter)],
    "BrickFilter": [layer(items.brick_filter)],
    "FilterCrock": [layer(items.crock_in_bucket)],
    "BoilerStone": [layer(items.boiler_stone)],
    "BoilerWelded": [layer(items.boiler_welded)],
    "WoodenHandPump": [layer(items.wooden_hand_pump)],
    "IronHandPump": [layer(items.iron_hand_pump)],
    "PumpHouseWood": [layer(items.pump_house_wood)],
    "PumpHouseMetal": [layer(items.pump_house_metal)],
}
