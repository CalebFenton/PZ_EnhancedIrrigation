#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==12.3.0"]
# ///
"""Draws the mod list icon, 42/enhanced_irrigation_icon.png: the game's oak rain barrel, water
showing at its open top, up on a log Tank Stand, a drop falling from the tap at its foot.

    art/models/mod_icon.py

The mod list shows the icon at about 22 pixels, so it is one object in a few large blocks of
colour with a dark outline, drawn pixel by pixel like the item icons and saved by the harness's
lib/promo.py (save_mod_icon says at what size, and why). The colours are palette.py's materials,
lit flat. It is drawn from the shapes below rather than kept as an edited image, so a rerun
writes the same file.
"""
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "dev" / "harness" / "lib"))
import promo  # noqa: E402
from palette import PALETTE  # noqa: E402

ICON = REPO / "Contents" / "mods" / "EnhancedIrrigation" / "42" / "enhanced_irrigation_icon.png"
SIZE = promo.MOD_ICON


def paint(name):
    """PALETTE's sRGB colour `name` as the icon draws it, lit flat."""
    value = PALETTE[name]["color"]
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


# Darker than the item icons' outline, which sits on the lighter inventory: the mod list is dark.
# The shades are picked by hand; the base colours are the tiles'.
OUTLINE = (22, 24, 28)
STAVE, STAVE_LIGHT, STAVE_DARK, STAVE_SEAM = paint("stave"), (176, 112, 60), (112, 64, 30), (100, 56, 26)
HOOP, HOOP_LIGHT = paint("hoop"), (150, 152, 160)
RIM = paint("stavedark")
WATER, WATER_LIGHT, WATER_DARK = (58, 140, 214), (170, 216, 255), (36, 92, 160)
BOARD, BOARD_LIGHT = paint("planks"), (176, 138, 92)
BARK, BARK_LIGHT = paint("bark"), (124, 98, 72)
BRASS, BRASS_LIGHT = paint("brass"), (226, 196, 120)
HANDLE = paint("red")

# The barrel's rows, inclusive: the rim, two rows of the water inside it, seen a little from above,
# and the front lip, then the staves, which bulge between BULGE's rows, under two iron hoops.
BARREL_TOP, BARREL_BOTTOM = 1, 17
BULGE = (7, 13)
HOOPS = (6, 15)
STAND_TOP = 18
LEGS = ((5, 7), (19, 21))
# The drop under the tap, a row at a time from its tip: the first and last pixel of each.
DROP = [(26, 27), (26, 27), (25, 28), (25, 28), (24, 29), (24, 29), (24, 29), (25, 28)]
DROP_TOP = 20


def barrel_span(y):
    return (5, 22) if BULGE[0] <= y <= BULGE[1] else (6, 21)


def draw(put):
    left, right = barrel_span(BARREL_TOP)
    for x in range(left + 1, right):
        put(x, BARREL_TOP, RIM)
        put(x, BARREL_TOP + 3, RIM)
    for y in (BARREL_TOP + 1, BARREL_TOP + 2):
        put(left, y, RIM)
        put(right, y, RIM)
        for x in range(left + 1, right):
            put(x, y, WATER)
    for x in range(left + 2, left + 7):
        put(x, BARREL_TOP + 1, WATER_LIGHT)
    for x in range(right - 6, right):
        put(x, BARREL_TOP + 2, WATER_DARK)
    # The staves, lit from the left, a seam every fourth pixel.
    for y in range(BARREL_TOP + 4, BARREL_BOTTOM + 1):
        left, right = barrel_span(y)
        for x in range(left, right + 1):
            colour = STAVE
            if x - left < 3:
                colour = STAVE_LIGHT
            elif right - x < 3:
                colour = STAVE_DARK
            if (x - 5) % 4 == 3:
                colour = STAVE_SEAM
            if y in HOOPS:
                colour = HOOP_LIGHT if x - left < 4 else HOOP
            put(x, y, colour)
    # The stand's top board, wider than the barrel, its front edge catching the light.
    for x in range(3, 24):
        put(x, STAND_TOP, BOARD_LIGHT)
        put(x, STAND_TOP + 1, BOARD)
    # Two log legs down to the ground, and a rail between them.
    for x0, x1 in LEGS:
        for y in range(STAND_TOP + 2, SIZE - 1):
            for x in range(x0, x1 + 1):
                put(x, y, BARK_LIGHT if x == x0 else BARK)
    for x in range(LEGS[0][1] + 1, LEGS[1][0]):
        put(x, 25, BARK)
    # The tap at the barrel's foot: a brass spout out to the right, turning down, under a red
    # handle.
    for x in range(22, 28):
        put(x, 13, BRASS_LIGHT)
        put(x, 14, BRASS)
    for y in (15, 16):
        put(26, y, BRASS)
        put(27, y, BRASS)
    for x, y in [(23, 12), (24, 12), (23, 11), (24, 11)]:
        put(x, y, HANDLE)
    for y, (x0, x1) in enumerate(DROP, start=DROP_TOP):
        for x in range(x0, x1 + 1):
            put(x, y, WATER)
    for x, y in [(25, 23), (25, 24), (26, 22)]:
        put(x, y, WATER_LIGHT)
    for x, y in [(29, 25), (28, 26), (27, 27), (28, 27)]:
        put(x, y, WATER_DARK)


def main():
    colours = {}
    draw(lambda x, y, colour: colours.__setitem__((x, y), colour))
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pixels = image.load()
    # A one-pixel outline round every shape, on the pixels beside it that nothing covers.
    for x, y in colours:
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if 0 <= nx < SIZE and 0 <= ny < SIZE and (nx, ny) not in colours:
                pixels[nx, ny] = OUTLINE + (255,)
    for (x, y), colour in colours.items():
        pixels[x, y] = colour + (255,)
    promo.save_mod_icon(image, ICON)


if __name__ == "__main__":
    main()
