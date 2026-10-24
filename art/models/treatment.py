"""The treatment units: the sand filters, the Filter Crock in its bucket and the boilers."""
import math
import random

from mathutils import Vector

from kit import box, circle, cylinder, group, heading, lathe, parts, profile_radius, tube
from palette import M
from stands import BARREL_CORE, BARREL_HEIGHT, BARREL_PROFILE, barrel_shell


# The sand filters ----------------------------------------------------------------------------------
#
# Each is filled with sand nearly to its top, which is what tells it from a barrel of water at a
# glance, and has an outlet pipe near its foot on a face the camera sees (east, toward the viewer),
# turned down as a spout.

OUTLET_RADIUS = 0.022  # drawn fatter than a real nipple, as the pipes are, so it holds at game size


def _sleeve(col, name, start, out):
    """The malleable sleeve round a nipple where it leaves a wall at `start`, heading `out`."""
    tube(col, name, M("malleable"), [start - out * 0.01, start + out * 0.03], OUTLET_RADIUS * 1.35, sides=10, up=(0, 0, 1))


def _outlet(col, start, angle, length, drop):
    """A galvanised nipple out of a wall at `start` (x, y, z), heading `angle` degrees from east,
    `length` long to its elbow, then turning down `drop` to its mouth: a sleeve where it leaves the
    wall and a lip round the mouth. Returns the mouth."""
    out = heading(angle)
    down = Vector((0, 0, -1))
    start = Vector(start)
    bend = start + out * length
    radius = OUTLET_RADIUS * 1.5  # the elbow's: no tighter than the pipe, or its inside pinches
    centre = bend + down * radius
    elbow = [centre - down * (radius * math.cos(t)) + out * (radius * math.sin(t))
             for t in (math.radians(d) for d in range(0, 91, 15))]
    mouth = elbow[-1] + down * (drop - radius)
    tube(col, "Outlet_Pipe", M("galvanised"), [start] + elbow + [mouth], OUTLET_RADIUS, sides=10, up=(0, 0, 1))
    _sleeve(col, "Outlet_Sleeve", start, out)
    tube(col, "Outlet_Lip", M("malleable"), [mouth - down * 0.018, mouth + down * 0.004], OUTLET_RADIUS * 1.3, sides=10,
         up=tuple(out))
    return mouth


BARREL_SAND = BARREL_HEIGHT - 0.07  # the sand's top, below the rim so the barrel's inside shows over it
BARREL_OUTLET = (-20, 0.15)  # the outlet's heading (degrees from east) and height


def barrel_filter(col):
    """The game's rain barrel without its liner, open, filled with sand to a hand below its rim; a
    nipple out of a stave between the bottom hoops turns down over a clay dish on the ground."""
    barrel_shell(col)
    # The staves' cut ends round the rim, and the sand's surface, heaped a little in the middle.
    rim = BARREL_HEIGHT
    lathe(col, "Filter_Rim", M("stave"), [(0.313, rim - 0.012), (0.317, rim), (0.337, rim)], segments=36, smooth=False)
    edge = profile_radius(BARREL_CORE, BARREL_SAND) - 0.002
    rng = random.Random(134)
    ripples = [rng.uniform(-1, 1) for _ in range(36)]
    lathe(col, "Filter_Sand", M("sand"), [(0, BARREL_SAND + 0.014), (edge * 0.5, BARREL_SAND + 0.01), (edge, BARREL_SAND)],
          segments=36, shape=lambda angle, row: (0.0, 0.003 * ripples[int(round(angle / 10)) % 36] * (row == 1)))
    angle, z = BARREL_OUTLET
    wall = heading(angle) * (profile_radius(BARREL_PROFILE, z) - 0.01)
    mouth = _outlet(col, (wall.x, wall.y, z), angle, 0.06, 0.06)
    lathe(col, "Filter_Dish", M("clay"), [(0, 0.004), (0.06, 0.004), (0.085, 0.045), (0.079, 0.047), (0.058, 0.012), (0, 0.012)],
          segments=24, at=(mouth.x, mouth.y, 0))


BRICK_TANK = 0.84  # the brick filter's outside width, both ways: four bricks, and room for its outlet
BRICK_WALL = 0.11  # a stretcher's width: the walls are one brick thick
BRICK_COURSE = 0.075  # a brick's height and its mortar bed
BRICK_COURSES = 11
BRICK_LENGTH = 0.21  # a brick's length and its joint
BRICK_JOINT = 0.01


def _brick_walls(col, name, rng, width, courses, mouth=None):
    """Four walls of red bricks one brick thick, `width` outside both ways and `courses` high, in
    stretcher bond, the corners lapped course by course, mortar showing in every joint. `mouth` =
    (west, east, sill, head) leaves an opening in the south wall, the bricks beside it cut square to
    its sides and those round it sooted."""
    half = width / 2
    height = courses * BRICK_COURSE
    # The mortar behind each wall's bricks, set in from every face further than a joint sets a brick's
    # end back, so it shows only in the joints and no face of it lies in a brick's, where the render
    # draws black.
    for sx, sy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        length, thickness = width - 0.03, BRICK_WALL - 0.016
        y = sy * (half - BRICK_WALL / 2)
        if mouth and sy == -1:
            # Round the mouth, set back from its sides as from the walls' ends.
            west, east, sill, head = mouth
            for a, b, bottom, top in ((-length / 2, west - 0.008, 0, height - 0.006),
                                      (east + 0.008, length / 2, 0, height - 0.006),
                                      (west - 0.008, east + 0.008, 0, sill - 0.008),
                                      (west - 0.008, east + 0.008, head + BRICK_JOINT, height - 0.006)):
                box(col, name + "_Mortar", M("mortar"), (b - a, thickness, top - bottom), at=((a + b) / 2, y, bottom))
            continue
        size = (length, thickness, height - 0.006) if sy else (thickness, length, height - 0.006)
        box(col, name + "_Mortar", M("mortar"), size, at=(sx * (half - BRICK_WALL / 2), y, 0))
    for course in range(courses):
        z = course * BRICK_COURSE
        cut = mouth is not None and mouth[2] <= z < mouth[3]
        over = mouth is not None and mouth[3] <= z < mouth[3] + 2 * BRICK_COURSE
        # The north and south walls run to the corners on even courses, the east and west walls on
        # odd ones, so each corner laps; a wall a brick's width shorter at both ends puts its joints
        # about half a brick along from the course below's, which is the bond.
        for sx, sy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            long_wall = (sy != 0) == (course % 2 == 0)
            length = width if long_wall else width - 2 * BRICK_WALL
            count = max(1, round(length / BRICK_LENGTH))
            module = length / count
            for i in range(count):
                along = -length / 2 + (i + 0.5) * module
                mat = M("brick" if rng.random() < 0.6 else "brickdark")
                size = (module - BRICK_JOINT, BRICK_WALL, BRICK_COURSE - BRICK_JOINT)
                at = (along, sy * (half - BRICK_WALL / 2), z + BRICK_JOINT)
                if sx:
                    size, at = (size[1], size[0], size[2]), (sx * (half - BRICK_WALL / 2), along, z + BRICK_JOINT)
                if sy != -1 or not (cut or over):
                    box(col, name + "_Brick", mat, size, at=at, bevel=0.004)
                    continue
                west, east = mouth[0], mouth[1]
                start, end = along - size[0] / 2, along + size[0] / 2
                if over:
                    # The fire's smoke blackens the bricks over the mouth's head.
                    sooted = end > west - 0.03 and start < east + 0.03
                    box(col, name + "_Brick", M("brickscorch") if sooted else mat, size, at=at, bevel=0.004)
                    continue
                for a, b in ((start, min(end, west)), (max(start, east), end)):
                    if b - a > 0.03:
                        sooted = b == west or a == east
                        box(col, name + "_Brick", M("brickscorch") if sooted else mat, (b - a, size[1], size[2]),
                            at=((a + b) / 2, at[1], at[2]), bevel=0.004)


def brick_filter(col):
    """A square tank of red bricks in stretcher bond, the corners lapped course by course, mortar
    showing in every joint, filled with sand to a course below its top; a nipple out of the east
    wall near its south corner turns down over the ground."""
    half = BRICK_TANK / 2
    height = BRICK_COURSES * BRICK_COURSE
    _brick_walls(col, "BrickFilter", random.Random(135), BRICK_TANK, BRICK_COURSES)
    inside = BRICK_TANK - 2 * BRICK_WALL
    sand = height - BRICK_COURSE
    box(col, "BrickFilter_Sand", M("sand"), (inside - 0.004, inside - 0.004, sand), at=(0, 0, 0))
    _outlet(col, (half - 0.01, -half + 0.2, 2 * BRICK_COURSE), 0, 0.045, 0.07)


# The Filter Crock ----------------------------------------------------------------------------------
#
# A wide-bellied pot of about 8 litres standing in the game's 10-litre metal bucket (Base.Bucket):
# its belly sits down in the bucket and its shoulder, neck and rim stand clear above the bucket's
# rim, so the pot reads as a pot and the bucket as a bucket.

# The crock's outside from its foot up, then its inside back down to its floor, one wall thick.
CROCK_PROFILE = [(0, 0), (0.07, 0), (0.078, 0.006), (0.095, 0.03), (0.11, 0.07), (0.119, 0.11), (0.121, 0.14),
                 (0.118, 0.17), (0.108, 0.2), (0.093, 0.23), (0.08, 0.252), (0.075, 0.266), (0.078, 0.278),
                 (0.088, 0.29), (0.094, 0.298), (0.094, 0.306), (0.088, 0.31), (0.077, 0.308), (0.066, 0.292),
                 (0.064, 0.27), (0.07, 0.25), (0.085, 0.225), (0.1, 0.195), (0.108, 0.16), (0.109, 0.13),
                 (0.104, 0.09), (0.09, 0.05), (0.06, 0.022), (0, 0.018)]


def filter_crock(col, fired=True):
    """The Filter Crock standing on z = 0: a round-bellied pot on a narrow foot, its shoulder drawn in
    to a short neck and a rolled rim, terracotta once `fired`, raw clay before."""
    lathe(col, "Crock", M("terracotta" if fired else "rawclay"), CROCK_PROFILE, segments=36)


def crock_icon(col, fired=True):
    """The Filter Crock tipped onto its side towards the viewer's right, its mouth up and out, as the
    game draws its clay jars' icons."""
    group(col, "Crock_Tipped", parts(col, filter_crock, fired), rotate=(0, 40, 0))


PAIL_HEIGHT = 0.23
PAIL_BOTTOM, PAIL_TOP = 0.108, 0.145  # its outside radius at the foot and at the rim
PAIL_WALL = 0.003
PAIL_FLOOR = 0.01  # the inside floor's height, which the crock stands on
PAIL_WIRE = 0.007  # the bail, drawn fatter than life, as the pipes are, so it holds at game size
PAIL_EARS = 45  # the bail's pivots, on the north-east and south-west sides: square to the camera
PAIL_LEAN = 15  # how far the bail leans back from upright, away from the camera: its top shows over the crock's rim
PAIL_SIDE = ((PAIL_BOTTOM, 0), (PAIL_TOP, PAIL_HEIGHT))  # its outside from foot to rim, as a lathe profile


def crock_in_bucket(col):
    """The fired Filter Crock standing in the game's galvanised bucket: a tapered pail with a rolled
    rim, two pressed ribs and a foot ring, its wire bail hooked through an ear on either side and
    leaning back over the rim behind the crock."""
    top, inner = PAIL_HEIGHT, PAIL_TOP - PAIL_WALL
    lathe(col, "Pail", M("pail"), [(0, 0.002), (PAIL_BOTTOM - 0.004, 0.002), (PAIL_BOTTOM, 0.008), (PAIL_TOP, top),
                                   (inner, top), (PAIL_BOTTOM - PAIL_WALL, PAIL_FLOOR + 0.004),
                                   (PAIL_BOTTOM - PAIL_WALL - 0.004, PAIL_FLOOR), (0, PAIL_FLOOR)], segments=36)

    def ring(name, z, radius, wire):
        tube(col, name, M("pail"), circle(radius, z), wire, sides=8)

    ring("Pail_Rim", top - 0.002, PAIL_TOP + 0.002, 0.007)
    for z in (0.075, 0.15):
        ring("Pail_Rib", z, profile_radius(PAIL_SIDE, z), 0.003)
    ring("Pail_Foot", 0.012, profile_radius(PAIL_SIDE, 0.012), 0.004)
    # The ears, plates riveted under the rim, and the bail: a half hoop between them, leaning back.
    ear_z = top - 0.035
    reach = profile_radius(PAIL_SIDE, ear_z) + 0.006
    pivot = heading(PAIL_EARS)
    back = Vector((-pivot.y, pivot.x, 0))
    lean = math.radians(PAIL_LEAN)
    rise = Vector((0, 0, math.cos(lean))) + back * math.sin(lean)
    for side in (1, -1):
        at = pivot * side * (reach - 0.004)
        box(col, "Pail_Ear", M("malleable"), (0.006, 0.026, 0.04), at=(at.x, at.y, ear_z - 0.02),
            rotate=(0, 0, PAIL_EARS))
    centre = Vector((0, 0, ear_z))
    hoop = reach + 0.004
    bail = [centre + pivot * (reach - 0.008)]
    bail += [centre + pivot * (hoop * math.cos(t)) + rise * (hoop * math.sin(t))
             for t in (math.radians(d) for d in range(0, 181, 10))]
    bail.append(centre - pivot * (reach - 0.008))
    tube(col, "Pail_Bail", M("galvanised"), bail, PAIL_WIRE, sides=8)
    group(col, "Pail_Crock", parts(col, filter_crock), at=(0, 0, PAIL_FLOOR))


# The boilers ---------------------------------------------------------------------------------------
#
# The game's Metal Drum (crafted_01_32) standing on a firebox. A lit boiler is a vanilla fireplace,
# and its CustomName, Metal Drum, has the game draw its barrel fire's flames (IsoFireplace's
# updateFireSprite) at a fixed place on the tile: their foot where a barrel fire's front rim is, a
# drum's height over the tile's middle seen from the camera. So the firebox stands about that high,
# its top open at the corners under the drum's round foot, and the flames rise out of the front
# corner and up the drum's side, as a fire under a pot licks up it. Below the flames they would hide
# nothing they could seem to burn: the fire mouth is in the south wall, the tap on the east side.

DRUM_RADIUS = 0.355  # measured off crafted_01_32, as the game draws it: wider than a real drum
DRUM_HEIGHT = 0.87
DRUM_SEAM = 0.4  # the rolled seam round it, below the middle as on the game's drum
DRUM_WELD = -8  # the welded seam up its side (degrees from east), where the game's drum has it
FIREBOX = BRICK_TANK  # outside width, both ways
FIREBOX_COURSES = 12
FIREBOX_HEIGHT = FIREBOX_COURSES * BRICK_COURSE
FIREBOX_INSIDE = FIREBOX - 2 * BRICK_WALL  # its top's opening: narrower than the drum, which rests on its walls
BRICK_MOUTH = (-0.13, 0.15, BRICK_COURSE, 4 * BRICK_COURSE)  # the fire mouth: west and east sides, sill, head
PLATE = 0.006  # the welded firebox's sheet steel
PLATE_MOUTH = (-0.06, 0.2, 0.12, 0.36)
DRUM_INLET = (-110, DRUM_HEIGHT - 0.12)  # heading (degrees from east) and height on the drum
DRUM_TAP = (15, 0.09)


def metal_drum(col):
    """The game's Metal Drum standing on z = 0: grey steel, its lid's chime rolled over, a rolled seam
    round it studded with rivets, a welded seam up its side, two bungs in its lid, its foot sooted by
    the fire under it."""
    r, h = DRUM_RADIUS, DRUM_HEIGHT
    lathe(col, "Drum_Shell", M("drum"), [(0, 0.004), (r - 0.012, 0.004), (r - 0.003, 0), (r, 0.012), (r, h - 0.014),
                                         (r + 0.004, h - 0.006), (r - 0.002, h), (r - 0.014, h - 0.004),
                                         (r - 0.018, h - 0.014)], segments=48)
    cylinder(col, "Drum_Lid", M("drumlid"), r - 0.016, 0.002, at=(0, 0, h - 0.016), segments=48)
    for x, y, radius in ((-0.2, 0.03, 0.03), (0.17, 0.15, 0.018)):
        cylinder(col, "Drum_Bung", M("drumdark"), radius, 0.006, at=(x, y, h - 0.016), segments=12)
    lathe(col, "Drum_Seam", M("drum"), [(r, DRUM_SEAM - 0.012), (r + 0.006, DRUM_SEAM), (r, DRUM_SEAM + 0.012)], segments=48)
    for angle in range(-150, 61, 30):
        at = heading(angle) * r
        cylinder(col, "Drum_Rivet", M("drumdark"), 0.009, 0.01, at=(at.x, at.y, DRUM_SEAM - 0.02), rotate=(90, 0, angle + 90),
                 segments=6)
    at = heading(DRUM_WELD) * r
    box(col, "Drum_Weld", M("drumdark"), (0.006, 0.03, h - 0.05), at=(at.x, at.y, 0.025), rotate=(0, 0, DRUM_WELD))


def _stub(col, start, angle, length):
    """A galvanised nipple out of a wall at `start` (x, y, z), heading `angle` degrees from east,
    `length` long, a sleeve where it leaves the wall and a coupling on its end for the pipe that
    feeds it."""
    out = heading(angle)
    start = Vector(start)
    end = start + out * length
    tube(col, "Stub_Pipe", M("galvanised"), [start, end], OUTLET_RADIUS, sides=10, up=(0, 0, 1))
    _sleeve(col, "Stub_Sleeve", start, out)
    tube(col, "Stub_Coupling", M("malleable"), [end - out * 0.035, end], OUTLET_RADIUS * 1.4, sides=10, up=(0, 0, 1))


def _boiler_drum(col):
    """The Metal Drum resting on the firebox's walls, an inlet stub near its top and a tap near its
    foot, its spout hanging past the firebox's east side."""
    group(col, "Boiler_Drum", parts(col, metal_drum), at=(0, 0, FIREBOX_HEIGHT))
    wall = DRUM_RADIUS - 0.01
    angle, z = DRUM_INLET
    _stub(col, heading(angle) * wall + Vector((0, 0, FIREBOX_HEIGHT + z)), angle, 0.06)
    angle, z = DRUM_TAP
    start = heading(angle) * wall + Vector((0, 0, FIREBOX_HEIGHT + z))
    _outlet(col, start, angle, 0.09, 0.05)
    # A brass globe valve on the run, its red handwheel uppermost, as on the tap at a line's head.
    valve = start + heading(angle) * 0.05
    cylinder(col, "Boiler_Valve", M("brass"), 0.026, 0.05, at=(valve.x, valve.y, valve.z - 0.025), segments=12)
    cylinder(col, "Boiler_ValveStem", M("brass"), 0.007, 0.035, at=(valve.x, valve.y, valve.z + 0.025), segments=8)
    cylinder(col, "Boiler_ValveWheel", M("red"), 0.035, 0.01, at=(valve.x, valve.y, valve.z + 0.055), segments=16)


def _firebox_inside(col, half, mouth):
    """A firebox's inside, `half` its inside half-width: its walls sooted black, a bed of ash up to
    the mouth's sill and two charred logs on it, seen through the mouth and down the gaps round the
    drum's foot."""
    west, east, sill, head = mouth
    t = 0.004
    edge = half - 0.002 - t / 2
    top = FIREBOX_HEIGHT - 0.01
    for sx, sy in ((-1, 0), (1, 0), (0, 1)):
        size = (t, 2 * edge, top) if sx else (2 * edge, t, top)
        box(col, "Firebox_Soot", M("soot"), size, at=(sx * edge, sy * edge, 0.005))
    for a, b, bottom, upper in ((-edge, west, 0.005, top), (east, edge, 0.005, top), (west, east, 0.005, sill), (west, east, head, top)):
        box(col, "Firebox_Soot", M("soot"), (b - a, t, upper - bottom), at=((a + b) / 2, -edge, bottom))
    box(col, "Firebox_Ash", M("ash"), (2 * edge - t, 2 * edge - t, sill - 0.005), at=(0, 0, 0))
    for at, turn in (((-0.2, -0.06, sill - 0.01), 12), ((-0.05, -0.2, sill + 0.02), 70)):
        cylinder(col, "Firebox_Log", M("charcoal"), 0.035, 0.36, at=at, rotate=(0, 90, turn), segments=8)


def boiler_stone(col):
    """A Metal Drum on a firebox of red brick, the brick filter's walls, open at the top under the
    drum, a fire mouth in its south wall under an iron bar, the bricks round it sooted."""
    _brick_walls(col, "Boiler", random.Random(137), FIREBOX, FIREBOX_COURSES, mouth=BRICK_MOUTH)
    west, east, sill, head = BRICK_MOUTH
    # The bar the bricks over the mouth rest on, in the bed joint over its head.
    box(col, "Boiler_Lintel", M("ironwork"), (east - west + 0.12, BRICK_WALL + 0.004, BRICK_JOINT),
        at=((west + east) / 2, -(FIREBOX - BRICK_WALL) / 2, head))
    _firebox_inside(col, FIREBOX_INSIDE / 2, BRICK_MOUTH)
    _boiler_drum(col)


def boiler_welded(col):
    """A Metal Drum on a box of sheet steel welded up, angle iron riveted up its corners, a strap
    round it and a plate over its top round the drum's foot; in its south side a fire door shut over
    the mouth, framed in flat bar, hung on two hinges, a spring handle on its latch side, and a
    spinner draught vent under it."""
    half = FIREBOX / 2
    side = FIREBOX_HEIGHT - PLATE
    west, east, sill, head = PLATE_MOUTH
    box(col, "Firebox_Plate", M("plate"), (FIREBOX, PLATE, side), at=(0, half - PLATE / 2, 0))
    for sx in (-1, 1):
        box(col, "Firebox_Plate", M("plate"), (PLATE, FIREBOX - 2 * PLATE, side), at=(sx * (half - PLATE / 2), 0, 0))
    for a, b, bottom, top in ((-half, west, 0, side), (east, half, 0, side), (west, east, 0, sill), (west, east, head, side)):
        box(col, "Firebox_Plate", M("plate"), (b - a, PLATE, top - bottom), at=((a + b) / 2, -(half - PLATE / 2), bottom))
    # The top, round an opening as wide as the brick firebox's.
    rim = (FIREBOX - FIREBOX_INSIDE) / 2
    for sy in (-1, 1):
        box(col, "Firebox_Top", M("plate"), (FIREBOX, rim, PLATE), at=(0, sy * (half - rim / 2), side))
    for sx in (-1, 1):
        box(col, "Firebox_Top", M("plate"), (rim, FIREBOX_INSIDE, PLATE), at=(sx * (half - rim / 2), 0, side))
    flange, thick = 0.045, 0.005
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(col, "Firebox_Angle", M("ironwork"), (flange, thick, FIREBOX_HEIGHT),
                at=(sx * (half - flange / 2), sy * (half + thick / 2), 0))
            box(col, "Firebox_Angle", M("ironwork"), (thick, flange, FIREBOX_HEIGHT),
                at=(sx * (half + thick / 2), sy * (half - flange / 2), 0))
            for z in (0.08, 0.3, 0.52, 0.74):
                box(col, "Firebox_Rivet", M("malleable"), (0.012, 0.004, 0.012), at=(sx * (half - flange / 2), sy * (half + thick + 0.002), z))
                box(col, "Firebox_Rivet", M("malleable"), (0.004, 0.012, 0.012), at=(sx * (half + thick + 0.002), sy * (half - flange / 2), z))
    # The strap welded round it above the mouth, which keeps the hot plates from bowing.
    strap = 0.6
    for sy in (-1, 1):
        box(col, "Firebox_Strap", M("ironwork"), (FIREBOX + 2 * thick, 0.004, 0.04), at=(0, sy * (half + thick + 0.002), strap))
    for sx in (-1, 1):
        box(col, "Firebox_Strap", M("ironwork"), (0.004, FIREBOX + 2 * thick, 0.04), at=(sx * (half + thick + 0.002), 0, strap))
    face = -(half + 0.002)
    lap, bar = 0.015, 0.015
    left, right, bottom, top = west - lap, east + lap, sill - lap, head + lap
    middle = (sill + head) / 2
    box(col, "Firebox_Door", M("plate"), (right - left, 0.008, top - bottom), at=((left + right) / 2, face - 0.004, bottom))
    for a, b, z, height in ((left, right, bottom, bar), (left, right, top - bar, bar),
                            (left, left + bar, bottom, top - bottom), (right - bar, right, bottom, top - bottom)):
        box(col, "Firebox_DoorFrame", M("ironwork"), (b - a, 0.004, height), at=((a + b) / 2, face - 0.01, z))
    for z in (bottom + 0.03, top - 0.07):
        cylinder(col, "Firebox_Hinge", M("ironwork"), 0.009, 0.04, at=(left - 0.006, face - 0.008, z), segments=8)
    handle = right - 0.03
    tube(col, "Firebox_Handle", M("galvanised"), [(handle, face - 0.01, middle - 0.05), (handle, face - 0.035, middle - 0.04),
                                                  (handle, face - 0.035, middle + 0.04), (handle, face - 0.01, middle + 0.05)],
         0.007, sides=8)
    # The draught vent: a disc turned over a row of slots to let air in under the fire.
    vent = ((west + east) / 2, bottom / 2)
    cylinder(col, "Firebox_Vent", M("ironwork"), 0.04, 0.006, at=(vent[0], face, vent[1]), rotate=(90, 0, 0), segments=16)
    for dx in (-0.02, 0, 0.02):
        box(col, "Firebox_VentSlot", M("soot"), (0.009, 0.002, 0.04), at=(vent[0] + dx, face - 0.0075, vent[1] - 0.02))
    _firebox_inside(col, half - PLATE, PLATE_MOUTH)
    _boiler_drum(col)
