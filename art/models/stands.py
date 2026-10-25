"""The Tank Stand and the game's rain barrels that sit on it."""
import math
import random

from mathutils import Quaternion

from art.kit import beam, box, circle, cylinder, group, lathe, parts, profile_radius, tube
from palette import M


# The Tank Stand and its barrels --------------------------------------------------------------------
#
# A barrel on the stand stands a storey up in play (Tanks.levelOf), but a tile's sprite ends 224
# pixels above its floor's centre, and a barrel on a deck a storey up would rise past that. So the
# deck is drawn at chest height, which leaves the barrel at the game's own barrel's size and every
# part of the stand inside the sprite.

DECK_TOP = 1.6
DECK_BOARD = 0.025
LEG_AT = 0.36  # each leg's distance from the middle, east-west and north-south
LEG_RADIUS = 0.065
JOIST = (0.04, 0.12)  # thickness, depth
BRACE = (0.1, 0.02)  # width, thickness


def tank_stand(col, barrel=None, tarp=False):
    """A one-tile tower of four log legs, a plank cross-braced up each side, two joists nailed to the
    legs' tops and a deck of planks across them; with `barrel` ("open" or "closed") the game's rain
    barrel on it, lined with a bag or, with `tarp`, a tarp."""
    top = DECK_TOP - DECK_BOARD
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = cylinder(col, "Stand_Leg", M("bark"), LEG_RADIUS, top, at=(sx * LEG_AT, sy * LEG_AT, 0), segments=10)
            leg.rotation_euler.z = math.radians(17 * (sx + 2 * sy))
            cylinder(col, "Stand_LegEnd", M("logend"), LEG_RADIUS - 0.004, 0.002, at=(sx * LEG_AT, sy * LEG_AT, top), segments=10)
    for sy in (-1, 1):
        y = sy * (LEG_AT + LEG_RADIUS + JOIST[0] / 2)
        box(col, "Stand_Joist", M("planksdark"), (2 * LEG_AT + 0.2, JOIST[0], JOIST[1]), at=(0, y, top - JOIST[1]), bevel=0.004)
        for sx in (-1, 1):
            box(col, "Stand_Nail", M("nail"), (0.012, 0.004, 0.012), at=(sx * LEG_AT, y - sy * (JOIST[0] / 2 + 0.002), top - 0.06))
    # Cross braces up each side, from near the foot of one leg to near the top of the other.
    low, high = 0.18, top - JOIST[1] - 0.06
    out = LEG_AT + LEG_RADIUS + BRACE[1] / 2
    for side in range(4):
        for k, (a, b) in enumerate(((-1, 1), (1, -1))):
            start, end = (a * LEG_AT, low), (b * LEG_AT, high)
            offset = out + (BRACE[1] if k else 0)
            if side == 0:  # south
                p0, p1 = (start[0], -offset, start[1]), (end[0], -offset, end[1])
            elif side == 1:  # east
                p0, p1 = (offset, start[0], start[1]), (offset, end[0], end[1])
            elif side == 2:  # north
                p0, p1 = (start[0], offset, start[1]), (end[0], offset, end[1])
            else:  # west
                p0, p1 = (-offset, start[0], start[1]), (-offset, end[0], end[1])
            brace = beam(col, "Stand_Brace", M("planks" if (side + k) % 2 else "planksdark"), p0, p1, (BRACE[0], BRACE[1]),
                         bevel=0.003)
            # A beam keeps its width on X; a brace on an east or west side lies in the YZ plane, so
            # its width turns onto Y, flat against the legs.
            if side in (1, 3):
                brace.rotation_quaternion = brace.rotation_quaternion @ _quarter_turn()
    boards, gap = 6, 0.012
    width = (2 * (LEG_AT + LEG_RADIUS) + 0.06 - (boards - 1) * gap) / boards
    span = boards * width + (boards - 1) * gap
    for i in range(boards):
        x = -span / 2 + width / 2 + i * (width + gap)
        box(col, "Stand_Deck", M("planks" if i % 2 else "planksdark"), (width, 2 * (LEG_AT + LEG_RADIUS) + 0.1, DECK_BOARD),
            at=(x, 0, top), bevel=0.003)
        for sy in (-1, 1):
            box(col, "Stand_Nail", M("nail"), (0.01, 0.01, 0.002),
                at=(x, sy * (LEG_AT + LEG_RADIUS + JOIST[0] / 2), DECK_TOP))
    if barrel:
        group(col, "Stand_Barrel", parts(col, rain_barrel, closed=barrel == "closed", tarp=tarp), at=(0, 0, DECK_TOP))


def _quarter_turn():
    return Quaternion((0, 0, 1), math.radians(90))


# The game's rain barrel, measured off carpentry_02_122: about 0.72 m across its belly and 0.8 m
# tall, staves of oak, two dark iron hoops showing below the liner's skirt.
BARREL_HEIGHT = 0.8
BARREL_PROFILE = ((0.335, 0.0), (0.353, 0.18), (0.362, 0.4), (0.353, 0.62), (0.335, BARREL_HEIGHT))
BARREL_STAVES = 18
BARREL_HOOPS = (0.27, 0.53)
# The dark core between the staves, closed at its floor.
BARREL_CORE = ((0, 0.004), (0.315, 0.004), (0.335, 0.44), (0.315, BARREL_HEIGHT - 0.01))


def barrel_shell(col):
    """The rain barrel's staves and hoops standing on z = 0, and the dark core between the staves."""
    lathe(col, "Barrel_Core", M("barrelinside"), BARREL_CORE, segments=24)
    step = 360 / BARREL_STAVES
    for i in range(BARREL_STAVES):
        lathe(col, "Barrel_Stave", M("stavedark" if i % 3 == 1 else "stave"), BARREL_PROFILE, segments=3,
              arc=(i * step + 0.3, (i + 1) * step - 0.3))
    for z in BARREL_HOOPS + (0.035,):
        r = profile_radius(BARREL_PROFILE, z) + 0.004
        lathe(col, "Barrel_Hoop", M("hoop"), [(r, z - 0.022), (r + 0.004, z), (r, z + 0.022)], segments=36)


def rain_barrel(col, closed=False, tarp=False):
    """The game's rain barrel standing on z = 0: staves, hoops and a dark core showing between the
    staves; a garbage bag (or, with `tarp`, a tarp) lining it, gathered over the rim in folds and
    tied round under it, the cord's ends sticking out; `closed` puts a lid of boards over the liner."""
    barrel_shell(col)
    liner = M("tarp" if tarp else "bag")
    rng = random.Random(124 if tarp else 122)
    folds = [rng.uniform(0, 2 * math.pi) for _ in range(3)]
    segments = 72
    hem = [rng.uniform(-0.04, 0.025) for _ in range(segments)]
    rim = BARREL_HEIGHT
    tie = rim - 0.08
    # The liner over the rim, gathered under the cord, and its skirt hanging below that; how deep
    # each row folds: crumpled over the rim, pulled tight under the cord, loose at the hem.
    skirt = [(0.34, rim - 0.01, 0.6), (0.362, rim + 0.035, 1.0), (0.386, rim + 0.028, 1.0), (0.395, rim - 0.03, 0.8),
             (0.388, tie, 0.15), (0.4, rim - 0.12, 1.0), (0.406, rim - 0.17, 1.3)]
    bowl = [] if closed else [(0.0, rim - 0.32, 0.5), (0.18, rim - 0.3, 0.6), (0.27, rim - 0.2, 0.8), (0.315, rim - 0.09, 0.8)]
    profile = bowl + skirt
    # Small creases on top of the big folds, as a bag pulled over a rim crumples.
    creases = [[rng.uniform(-1, 1) for _ in range(segments)] for _ in profile]

    def crumple(angle, row):
        a = math.radians(angle)
        k = int(round(angle / (360 / segments))) % segments
        fold = (0.6 * math.sin(9 * a + folds[0]) + 0.3 * math.sin(14 * a + folds[1]) + 0.25 * math.sin(23 * a + folds[2])
                + 0.35 * creases[row][k])
        depth = profile[row][2]
        drop = hem[k] if row == len(profile) - 1 else 0.006 * fold * depth
        return 0.016 * fold * depth, drop
    lathe(col, "Barrel_Liner", liner, [(r, z) for r, z, _ in profile], segments=segments, shape=crumple)
    # The cord tied round the skirt, its two ends sticking out at the sides.
    tube(col, "Barrel_Cord", M("cord"), circle(0.395, tie), 0.006, sides=6)
    for angle in (155, 340):
        a = math.radians(angle)
        tube(col, "Barrel_CordEnd", M("cord"), [(0.392 * math.cos(a), 0.392 * math.sin(a), tie),
                                                (0.45 * math.cos(a + 0.08), 0.45 * math.sin(a + 0.08), tie + 0.012)], 0.007, sides=6)
    if closed:
        lid_z = rim + 0.025
        cylinder(col, "Barrel_Lid", M("lid"), 0.35, 0.03, at=(0, 0, lid_z), segments=36)
        # The gaps between its boards, which run north to south as the game's lid's do.
        for offset in (-0.18, -0.06, 0.06, 0.18):
            half = math.sqrt(max(0.0, 0.345 ** 2 - offset ** 2))
            box(col, "Barrel_LidSeam", M("barrelinside"), (0.012, 2 * half - 0.01, 0.001), at=(offset, 0, lid_z + 0.03))
