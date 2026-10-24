"""Write enhanced_irrigation.tiles, the properties of every tile in enhanced_irrigation_01, and
tileGeometry.txt.

    python3 tools/make_tiles.py

Tile numbers come from art/models/sprites.py. Property names and values follow the vanilla tile
definitions (newtiledefinitions.tiles).

- Pipe tiles and the tap, sprinkler, valve and Pump House timer overlays have none. Nothing that
  blocks (solid, solidtrans), since a line runs under plants and feet. Never canBeRemoved,
  vegitation or canBeCut: plowing a square deletes objects so marked, and the game counts them as
  weeds. Not IsMoveAble: the mod takes a pipe up with its own action, which gives the pipe back and
  reshapes the neighbours.
- The Tank Stand and the stand with a barrel block movement and building as the game's own rain
  barrel (carpentry_02_122) does. That barrel is also IsMoveAble and IsWaterCollector, which only
  the pick-up and disassemble cursors read; a barrel on the stand comes down by the mod's own
  action, so the raised barrels carry neither, nor CanScrap. The bare stand is scrapped as vanilla
  scraps wooden furniture (ISMoveableDefinitions' Wood material: planks and nails back), which
  needs no IsMoveAble.
- The sand filters block as the barrel does too. They hold sand and water the mod keeps track of,
  so the scrap cursor, which would drop all that, can't take them (no CanScrap). The brick filter's
  Material is Brick, as the game's brick fireplaces' is.
- The Filter Crock, a pot in a bucket, is as small as the game's potted floor plants (Snake Plant,
  vegetation_indoor_01_10), so it takes their BlocksPlacement and IsLow and, like them, no
  solidtrans: it doesn't stop a character. Nothing reads Material without CanScrap or IsMoveAble,
  which it lacks for the filters' reason, so it has none.
- The boilers block as the filters do, and keep water the mod tracks, so no CanScrap either. Each is
  a vanilla fireplace once built (the entity's OnCreate makes it one, as vanilla's Barrel Oven), and
  IsoFireplace draws its flames only on its own sprites, on walls (collideN or collideW, which
  would wall the square off from the mod's pipe lines) or on a CustomName of exactly "Metal Drum",
  which the boilers take for the barrel fire's flames. The game names a moveable by GroupName and
  CustomName, so GroupName "Boiler" makes it "Boiler Metal Drum", which Moveables.json calls the
  Boiler. No container, which would make the fireplace an oven with an inventory. Material as the
  filters': Brick for the brick firebox, Metal for the welded one.
- The hand pumps and Pump Houses block as the filters do. Each carries a record the mod keeps (a
  pump's seal and wear, a house's pump part), which the scrap cursor would drop, so no CanScrap.
  Material as they are built: Wood for the wooden pump and the plank house, Metal for the iron pump
  and the sheet-steel house.

The game loads a mod's depth maps (media/depthmaps/DEPTH_<tileset>.png, which art/models/render.py
renders) only when the mod's common/media has a tileGeometry.txt (TileDepthTextureManager.init),
so this writes one without geometry. Without the depth map every tile would be drawn as if it
filled its square up to the ceiling, and a pipe would hide whoever walks over it.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "dev", "harness", "check"))
sys.path.insert(0, os.path.join(HERE, "..", "art", "models"))
import tiledefs  # noqa: E402
from sprites import (BARREL_FILTER, BOILER_STONE, BOILER_WELDED, BRICK_FILTER, COLUMNS, FILTER_CROCK,  # noqa: E402
                     IRON_HAND_PUMP, PUMP_HOUSE_METAL, PUMP_HOUSE_WOOD, RAISED_BARRELS, ROWS, STAND, TILESET,
                     WOODEN_HAND_PUMP)

MEDIA = os.path.join(HERE, "..", "Contents", "mods", "EnhancedIrrigation", "common", "media")
TILES_FILE = os.path.join(MEDIA, "enhanced_irrigation.tiles")
GEOMETRY_FILE = os.path.join(MEDIA, "tileGeometry.txt")


def stand_like(name, **props):
    return {"CustomName": name, "Material": "Wood", "BlocksPlacement": "", "solidtrans": "", **props}


TILES = {STAND: stand_like("Tank Stand", CanScrap="")}
for index in RAISED_BARRELS:
    TILES[index] = stand_like("Raised Rain Barrel")
TILES[BARREL_FILTER] = stand_like("Barrel Filter")
TILES[BRICK_FILTER] = stand_like("Brick Filter", Material="Brick")
TILES[FILTER_CROCK] = {"CustomName": "Filter Crock", "BlocksPlacement": "", "IsLow": ""}
TILES[BOILER_STONE] = stand_like("Metal Drum", GroupName="Boiler", Material="Brick")
TILES[BOILER_WELDED] = stand_like("Metal Drum", GroupName="Boiler", Material="Metal")
TILES[WOODEN_HAND_PUMP] = stand_like("Wooden Hand Pump")
TILES[IRON_HAND_PUMP] = stand_like("Iron Hand Pump", Material="Metal")
TILES[PUMP_HOUSE_WOOD] = stand_like("Pump House")
TILES[PUMP_HOUSE_METAL] = stand_like("Pump House", Material="Metal")


def main():
    assert max(TILES) < COLUMNS * ROWS, "a tile past sprites.ROWS: raise it to the last tile's"
    tiles = [sorted(TILES.get(index, {}).items(), key=lambda prop: prop[0].lower())
             for index in range(COLUMNS * ROWS)]
    # The only tileset in the file, so number 1.
    tileset = tiledefs.Tileset(TILESET, TILESET + ".png", COLUMNS, ROWS, 1, tiles)
    data = tiledefs.dumps([tileset])
    assert tiledefs.loads(data) == [tileset], "the tiles would not read back as written"
    os.makedirs(MEDIA, exist_ok=True)
    with open(TILES_FILE, "wb") as f:
        f.write(data)
    print("%s: %d tiles with properties" % (os.path.basename(TILES_FILE), len(TILES)))
    with open(GEOMETRY_FILE, "w") as f:
        f.write("tileGeometry\n{\n    VERSION = 2,\n}\n")


if __name__ == "__main__":
    main()
