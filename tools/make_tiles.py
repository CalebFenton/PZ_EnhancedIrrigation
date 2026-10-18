"""Write enhanced_irrigation.tiles, the properties of every tile in enhanced_irrigation_01, and
tileGeometry.txt.

    python3 tools/make_tiles.py

Tile numbers match art/models/tiles.py, which renders them, and
media/lua/shared/EnhancedIrrigation/Sprites.lua, which names them for Lua. Property names and
values follow the vanilla tile definitions (newtiledefinitions.tiles).

- Pipe tiles and the tap overlay have none. Nothing that blocks (solid, solidtrans), since a line
  runs under plants and feet. Never canBeRemoved, vegitation or canBeCut: plowing a square deletes
  objects so marked, and the game counts them as weeds. Not IsMoveAble: the mod takes a pipe up
  with its own action, which gives the pipe back and reshapes the neighbours.
- The Tank Stand and the stand with a barrel block movement and building as the game's own rain
  barrel (carpentry_02_122) does. That barrel is also IsMoveAble and IsWaterCollector, which only
  the pick-up and disassemble cursors read; a barrel on the stand comes down by the mod's own
  action, so the raised barrels carry neither, nor CanScrap. The bare stand is scrapped as vanilla
  scraps wooden furniture (ISMoveableDefinitions' Wood material: planks and nails back), which
  needs no IsMoveAble.

The game loads a mod's depth maps (media/depthmaps/DEPTH_<tileset>.png, which art/models/render.py
renders) only when the mod's common/media has a tileGeometry.txt (TileDepthTextureManager.init),
so this writes one without geometry. Without the depth map every tile would be drawn as if it
filled its square up to the ceiling, and a pipe would hide whoever walks over it.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "dev", "harness", "check"))
import tiledefs  # noqa: E402

MEDIA = os.path.join(HERE, "..", "Contents", "mods", "EnhancedIrrigation", "common", "media")
TILES_FILE = os.path.join(MEDIA, "enhanced_irrigation.tiles")
GEOMETRY_FILE = os.path.join(MEDIA, "tileGeometry.txt")
TILESET = "enhanced_irrigation_01"
COLUMNS, ROWS = 8, 17

STAND = 129
RAISED_BARRELS = (130, 131, 132, 133)


def stand_like(name, **props):
    return {"CustomName": name, "Material": "Wood", "BlocksPlacement": "", "solidtrans": "", **props}


TILES = {STAND: stand_like("Tank Stand", CanScrap="")}
for index in RAISED_BARRELS:
    TILES[index] = stand_like("Raised Rain Barrel")


def main():
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
