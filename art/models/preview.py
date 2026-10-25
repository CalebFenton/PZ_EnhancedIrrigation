"""Renders review sheets of everything make.sh produced, read back from the sprites and icons
render.py wrote, not from the pack the game loads:

    blender -b --factory-startup -P art/models/preview.py

- tiles.png: every tile at twice its size on a floor diamond.
- lines_<material>.png: a garden of that material's pipe laid out as the game draws neighbouring
  tiles, its shapes chosen from its neighbours by Sprites.lua's rule (north is y - 1), dry on the
  left and wet on the right, the tap on the west arm's end: the pieces have to meet as one pipe.
- stands.png: the game's own rain barrel (carpentry_02_122, read from its Tiles2x.pack when the
  game is installed), the tap on a pipe, the sprinkler on a plastic and on a clay pipe, the stand,
  the stand with each barrel, the sand filters, the Filter Crock, the boilers, then the hand pumps
  and Pump Houses between the game's well (camping_01_16) and its rain barrel again, at three times
  their size, so they can be held against the game's.
- icons.png: every icon at four times its size.

Writes to PREVIEWS (default $TMPDIR/enhanced-irrigation-previews) and prints the folder. PZ_APP
overrides the game's Contents folder, where the game's sprites are read.
"""
import os
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(os.path.dirname(os.path.dirname(HERE)), "dev", "harness", "lib")]
import render  # noqa: E402
import sprites  # noqa: E402
import tiles  # noqa: E402
from art import kit  # noqa: E402
from art.preview import BACKGROUND, enlarge, floor_diamond, grid, over, vanilla_sprite  # noqa: E402
from art.render import TILE_H, TILE_W  # noqa: E402
from art.tilefile import COLUMNS  # noqa: E402

OUT = os.environ.get("PREVIEWS", os.path.join(tempfile.gettempdir(), "enhanced-irrigation-previews"))
ART = render.ART
GRASS = np.array([0.36, 0.42, 0.22, 1.0], dtype=np.float32)


def tile(index):
    return kit.load_pixels(ART.tile_file(sprites.TILESET, index))


def tile_sheet():
    cells = []
    for index in sorted(tiles.TILES):
        cell = floor_diamond()
        over(cell, tile(index), 0, 0)
        cells.append(enlarge(cell, 2))
    kit.save_pixels(os.path.join(OUT, "tiles.png"), grid(cells, COLUMNS, 2 * TILE_W, 2 * TILE_H))


# A 5 x 5 frame of pipe with a cross through it, a stub off each side and a lone piece in a corner:
# every straight, corner, tee and end, and the cross.
GARDEN = ["...#...",
          ".#####.",
          ".#.#.#.",
          "#######",
          ".#.#.#.",
          ".#####.",
          "...#..#"]
TAP_AT = (0, 3)


def garden(material, wet):
    cells = {(x, y) for y, row in enumerate(GARDEN) for x, c in enumerate(row) if c == "#"}
    size = len(GARDEN)
    sheet = np.tile(BACKGROUND, (size * 64 + 192, size * 128, 1))
    origin_x = (size - 1) * 64

    def place(x, y, pixels):
        over(sheet, pixels, origin_x + (x - y) * 64, (x + y) * 32)

    shade = floor_diamond(fill=GRASS)
    dark = floor_diamond(fill=GRASS * np.array([0.9, 0.9, 0.9, 1], dtype=np.float32))
    order = sorted(((x, y) for y in range(size) for x in range(size)), key=lambda c: (c[0] + c[1], c[0]))
    for x, y in order:
        place(x, y, shade if (x + y) % 2 else dark)
    for x, y in order:
        if (x, y) not in cells:
            continue
        shape = sum(bit for bit, (dx, dy) in ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0)))
                    if (x + dx, y + dy) in cells)
        place(x, y, tile(sprites.pipe_index(material, wet, shape)))
        if (x, y) == TAP_AT:
            place(x, y, tile(sprites.TAP))
    return sheet


def lines_sheets():
    for material in sprites.PIPE_MATERIALS:
        dry, wet = garden(material, False), garden(material, True)
        sheet = np.concatenate([dry, wet], axis=1)
        kit.save_pixels(os.path.join(OUT, "lines_%s.png" % material), enlarge(sheet, 2))


def stands_sheet():
    cells = []

    def add(*layers):
        cell = floor_diamond(fill=GRASS)
        for pixels in layers:
            over(cell, pixels, 0, 0)
        cells.append(cell)

    barrel = vanilla_sprite("carpentry_02_122", ART.scratch)
    if barrel is not None:
        add(barrel)
    add(tile(sprites.pipe_index("plastic", False, 10)), tile(sprites.TAP))
    for material in ("plastic", "clay"):
        add(tile(sprites.pipe_index(material, False, 10)), tile(sprites.SPRINKLER))
    for index in [sprites.STAND, *sprites.RAISED_BARRELS, sprites.BARREL_FILTER, sprites.BRICK_FILTER,
                  sprites.FILTER_CROCK, sprites.BOILER_STONE, sprites.BOILER_WELDED]:
        add(tile(index))
    well = vanilla_sprite("camping_01_16", ART.scratch)
    if well is not None:
        add(well)
    for index in (sprites.WOODEN_HAND_PUMP, sprites.IRON_HAND_PUMP, sprites.PUMP_HOUSE_WOOD, sprites.PUMP_HOUSE_METAL):
        add(tile(index))
    if barrel is not None:
        add(barrel)
    kit.save_pixels(os.path.join(OUT, "stands.png"), enlarge(grid(cells, len(cells), TILE_W, TILE_H), 3))


def icon_sheet():
    cells = [enlarge(kit.load_pixels(ART.icon_file(name)), 4) for name in ART.items]
    cells += [enlarge(kit.load_pixels(ART.build_icon_file(name)), 4) for name in ART.build_icons]
    kit.save_pixels(os.path.join(OUT, "icons.png"), grid(cells, len(cells), 200, 200))


def main():
    os.makedirs(OUT, exist_ok=True)
    tile_sheet()
    lines_sheets()
    stands_sheet()
    icon_sheet()
    print("previews:", OUT)


if __name__ == "__main__":
    main()
