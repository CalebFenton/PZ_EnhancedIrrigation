"""Renders review sheets of everything make.sh produced, read back from the files the game loads:

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

Writes to PREVIEWS (default $TMPDIR/enhanced-irrigation-previews) and prints the folder. PZ_MEDIA
overrides where the game's media folder is.
"""
import os
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, "dev", "harness", "check"))
import items  # noqa: E402
import kit  # noqa: E402
import tiles  # noqa: E402
from packs import read_index  # noqa: E402

OUT = os.environ.get("PREVIEWS", os.path.join(tempfile.gettempdir(), "enhanced-irrigation-previews"))
PZ_MEDIA = os.environ.get("PZ_MEDIA", os.path.expanduser(
    "~/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/media"))
TILE_PATH = os.path.join(REPO, "tools/tiles/enhanced_irrigation_01_%d.png")
BACKGROUND = np.array([0.3, 0.3, 0.3, 1.0], dtype=np.float32)
GRASS = np.array([0.36, 0.42, 0.22, 1.0], dtype=np.float32)


def over(sheet, pixels, x, y):
    """Alpha-composites `pixels` onto `sheet` with its top left at (x, y)."""
    height, width, _ = pixels.shape
    region = sheet[y:y + height, x:x + width]
    alpha = pixels[..., 3:4]
    region[..., :3] = pixels[..., :3] * alpha + region[..., :3] * (1 - alpha)
    region[..., 3:] = alpha + region[..., 3:] * (1 - alpha)


def grid(cells, columns, cell_w, cell_h):
    rows = (len(cells) + columns - 1) // columns
    sheet = np.tile(BACKGROUND, (rows * cell_h, columns * cell_w, 1))
    for i, pixels in enumerate(cells):
        over(sheet, pixels, (i % columns) * cell_w, (i // columns) * cell_h)
    return sheet


def enlarge(pixels, factor):
    return pixels.repeat(factor, axis=0).repeat(factor, axis=1)


def floor_diamond(width=128, height=256, fill=None):
    """A tile's floor: its outline, or filled with `fill`, so a sprite's placement on its square
    shows."""
    cell = np.zeros((height, width, 4), dtype=np.float32)
    for x in range(width):
        dy = round(abs(x - width / 2 + 0.5) / 2)
        top, bottom = height - 64 + dy, height - 1 - dy
        if fill is not None:
            cell[top:bottom + 1, x] = fill
        else:
            for y in (top, bottom):
                cell[min(y, height - 1), x] = (0.5, 0.5, 0.5, 1)
    return cell


def tile(index):
    return kit.load_pixels(TILE_PATH % index)


def tile_sheet():
    cells = []
    for index in sorted(tiles.TILES):
        cell = floor_diamond()
        over(cell, tile(index), 0, 0)
        cells.append(enlarge(cell, 2))
    kit.save_pixels(os.path.join(OUT, "tiles.png"), grid(cells, 8, 256, 512))


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
        place(x, y, tile(tiles.pipe_index(material, wet, shape)))
        if (x, y) == TAP_AT:
            place(x, y, tile(tiles.TAP))
    return sheet


def lines_sheets():
    for material in tiles.PIPE_MATERIALS:
        dry, wet = garden(material, False), garden(material, True)
        sheet = np.concatenate([dry, wet], axis=1)
        kit.save_pixels(os.path.join(OUT, "lines_%s.png" % material), enlarge(sheet, 2))


def vanilla_sprite(name):
    """A sprite of the game's Tiles2x.pack as its full cell, or None without the game."""
    path = os.path.join(PZ_MEDIA, "texturepacks", "Tiles2x.pack")
    if not os.path.exists(path):
        return None
    for page in read_index(path):
        for sprite in page.sprites:
            if sprite.name != name:
                continue
            with open(path, "rb") as f:
                f.seek(page.image_start)
                data = f.read(page.image_length)
            scratch = os.path.join(tempfile.gettempdir(), "enhanced-irrigation-page.png")
            with open(scratch, "wb") as f:
                f.write(data)
            pixels = kit.load_pixels(scratch)
            cell = np.zeros((sprite.cell_height, sprite.cell_width, 4), dtype=np.float32)
            cell[sprite.offset_y:sprite.offset_y + sprite.height, sprite.offset_x:sprite.offset_x + sprite.width] = \
                pixels[sprite.y:sprite.y + sprite.height, sprite.x:sprite.x + sprite.width]
            return cell
    return None


def stands_sheet():
    cells = []

    def add(*sprites):
        cell = floor_diamond(fill=GRASS)
        for pixels in sprites:
            over(cell, pixels, 0, 0)
        cells.append(cell)

    barrel = vanilla_sprite("carpentry_02_122")
    if barrel is not None:
        add(barrel)
    add(tile(tiles.pipe_index("plastic", False, 10)), tile(tiles.TAP))
    for material in ("plastic", "clay"):
        add(tile(tiles.pipe_index(material, False, 10)), tile(tiles.SPRINKLER))
    for index in list(range(tiles.STAND, tiles.STAND + 5)) + [tiles.BARREL_FILTER, tiles.BRICK_FILTER, tiles.FILTER_CROCK,
                                                              tiles.BOILER_STONE, tiles.BOILER_WELDED]:
        add(tile(index))
    well = vanilla_sprite("camping_01_16")
    if well is not None:
        add(well)
    for index in (tiles.WOODEN_HAND_PUMP, tiles.IRON_HAND_PUMP, tiles.PUMP_HOUSE_WOOD, tiles.PUMP_HOUSE_METAL):
        add(tile(index))
    if barrel is not None:
        add(barrel)
    kit.save_pixels(os.path.join(OUT, "stands.png"), enlarge(grid(cells, len(cells), 128, 256), 3))


def icon_sheet():
    cells = [enlarge(kit.load_pixels(os.path.join(REPO, "tools/textures/Item_EnhancedIrrigation_%s.png" % name)), 4)
             for name in items.ITEMS]
    cells += [enlarge(kit.load_pixels(os.path.join(REPO, "tools/textures/EnhancedIrrigation_Build_%s.png" % name)), 4)
              for name in tiles.BUILD_ICONS]
    kit.save_pixels(os.path.join(OUT, "icons.png"), grid(cells, len(cells), 200, 200))


def main():
    os.makedirs(OUT, exist_ok=True)
    tile_sheet()
    lines_sheets()
    stands_sheet()
    icon_sheet()
    print("previews:", OUT)


main()
