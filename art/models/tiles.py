"""What each tile of enhanced_irrigation_01 shows, by its number in sprites.py, built from the
builders of lines, stands, treatment, pumps and valves. A tile is a list of layers.

Tile coordinates are a square one metre wide centred on the origin: its north edge is y = +0.5 and
its west edge x = -0.5 (see kit.py).
"""
import lines
import pumps
import stands
import treatment
import valves
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
            TILES[pipe_index(material, wet, shape)] = [layer(lines.pipe, material=material, shape=shape, wet=wet)]

# The tap: an overlay on any pipe tile, standing on the tile's middle, where every shape but a lone
# piece has pipe.
TILES[TAP] = [layer(lines.tap)]

# The game's rain barrels on the stand: carpentry_02_122, _126, _124 and _127.
TILES[STAND] = [layer(stands.tank_stand)]
for index, (barrel, tarp) in zip(RAISED_BARRELS, (("open", False), ("closed", False), ("open", True), ("closed", True))):
    TILES[index] = [layer(stands.tank_stand, barrel=barrel, tarp=tarp)]
TILES[BARREL_FILTER] = [layer(treatment.barrel_filter)]
TILES[BRICK_FILTER] = [layer(treatment.brick_filter)]
TILES[FILTER_CROCK] = [layer(treatment.crock_in_bucket)]
TILES[BOILER_STONE] = [layer(treatment.boiler_stone)]
TILES[BOILER_WELDED] = [layer(treatment.boiler_welded)]
TILES[WOODEN_HAND_PUMP] = [layer(pumps.wooden_hand_pump)]
TILES[IRON_HAND_PUMP] = [layer(pumps.iron_hand_pump)]
TILES[PUMP_HOUSE_WOOD] = [layer(pumps.pump_house_wood)]
TILES[PUMP_HOUSE_METAL] = [layer(pumps.pump_house_metal)]
# The lawn sprinkler: an overlay on a line tile, as the tap is, standing on the tile's middle.
TILES[SPRINKLER] = [layer(lines.sprinkler)]
# Overlays drawn with the tap's, hung off its spout, then one on either Pump House by its plug.
TILES[TAP_WIND_UP] = [layer(valves.tap_wind_up_valve)]
TILES[TAP_TIMER_VALVE] = [layer(valves.tap_timer_valve)]
TILES[TAP_SPRINKLER_TIMER] = [layer(valves.tap_sprinkler_timer)]
TILES[HOUSE_TIMER] = [layer(valves.house_timer)]
assert max(TILES) < COLUMNS * ROWS, "a tile past sprites.ROWS: raise it to the last tile's"

# Build-menu icons by the name after EnhancedIrrigation_Build_: each thing as it stands built.
BUILD_ICONS = {
    "TankStand": [layer(stands.tank_stand)],
    "BarrelFilter": [layer(treatment.barrel_filter)],
    "BrickFilter": [layer(treatment.brick_filter)],
    "FilterCrock": [layer(treatment.crock_in_bucket)],
    "BoilerStone": [layer(treatment.boiler_stone)],
    "BoilerWelded": [layer(treatment.boiler_welded)],
    "WoodenHandPump": [layer(pumps.wooden_hand_pump)],
    "IronHandPump": [layer(pumps.iron_hand_pump)],
    "PumpHouseWood": [layer(pumps.pump_house_wood)],
    "PumpHouseMetal": [layer(pumps.pump_house_metal)],
}
