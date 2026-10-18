"""The parts every tile and icon is built from, in real metres (kit.py has the frame): garden pipe of
four materials, the tap, the Tank Stand and the rain barrels that sit on it, and the pamphlet.
"""
import math
import random

from mathutils import Quaternion, Vector

from kit import beam, box, cylinder, group, lathe, material, stain, text, tube


def M(name):
    """The shared materials, made on first use. Pipe materials have no grime: its blotches follow
    each part's own coordinates, so two tiles' halves of one pipe would not match where they meet."""
    return {
        # Black polyethylene drip line and its barbed fittings, dull enough that the sky's
        # reflection doesn't turn a line this thin grey.
        "poly": lambda: material("EI_Poly", "#1e1e20", roughness=0.7, grime=0.0),
        "galvanised": lambda: material("EI_Galvanised", "#858b8f", roughness=0.55, metallic=0.5, grime=0.0),
        "malleable": lambda: material("EI_Malleable", "#6f7478", roughness=0.6, metallic=0.4, grime=0.0),
        # Old lead goes dull grey-blue, its wiped joints' solder a shade darker.
        "lead": lambda: material("EI_Lead", "#5f6875", roughness=0.75, metallic=0.25, grime=0.0),
        "solder": lambda: material("EI_Solder", "#4c535c", roughness=0.6, metallic=0.35, grime=0.0),
        "clay": lambda: material("EI_Clay", "#a85d38", roughness=0.85, grime=0.0),
        "brass": lambda: material("EI_Brass", "#b08d45", roughness=0.4, metallic=0.7, grime=0.1),
        "red": lambda: material("EI_Red", "#b3261e", roughness=0.5, grime=0.1),
        # Logs with their bark on, and planks nailed up outdoors in two shades so boards read apart.
        "bark": lambda: material("EI_Bark", "#5b4633", roughness=0.9, grime=0.35, scale=14, grain="weathered"),
        "logend": lambda: material("EI_LogEnd", "#b08a5c", roughness=0.85, grime=0.3),
        "planks": lambda: material("EI_Planks", "#8a6442", roughness=0.85, grime=0.3, scale=10, grain="weathered"),
        "planksdark": lambda: material("EI_PlanksDark", "#6d4e33", roughness=0.85, grime=0.3, scale=10, grain="weathered"),
        "nail": lambda: material("EI_Nail", "#3b3936", roughness=0.6, metallic=0.5, grime=0.2),
        # The game's rain barrel (carpentry_02_122 and its kin): oak staves, iron hoops, lined with a
        # green garbage bag or an orange tarp tied round under the rim.
        "stave": lambda: material("EI_Stave", "#93582a", roughness=0.75, grime=0.25, scale=10, grain="board"),
        "stavedark": lambda: material("EI_StaveDark", "#7c4720", roughness=0.75, grime=0.25, scale=10, grain="board"),
        "barrelinside": lambda: material("EI_BarrelInside", "#3a2412", roughness=0.9, grime=0.2),
        "hoop": lambda: material("EI_Hoop", "#5c5d63", roughness=0.6, metallic=0.4, grime=0.2),
        "bag": lambda: material("EI_Bag", "#44593b", roughness=0.65, grime=0.35, scale=30),
        "tarp": lambda: material("EI_Tarp", "#d27449", roughness=0.7, grime=0.25, scale=30),
        "cord": lambda: material("EI_Cord", "#2b241f", roughness=0.8, grime=0.1),
        "lid": lambda: material("EI_Lid", "#8d5a2b", roughness=0.8, grime=0.25, scale=10, grain="board"),
        # The pamphlet: cream stock, green ink for the band, brown for the drawing and the type.
        "paper": lambda: material("EI_Paper", "#efe5c6", roughness=0.9, grime=0.05),
        "paperback": lambda: material("EI_PaperBack", "#ddd0ab", roughness=0.9, grime=0.05),
        "inkgreen": lambda: material("EI_InkGreen", "#3d5b36", roughness=0.8, grime=0.05),
        "ink": lambda: material("EI_Ink", "#3a2a1c", roughness=0.8, grime=0.05),
    }[name]()


# Garden pipe ---------------------------------------------------------------------------------------
#
# A pipe tile shows the pipe from the tile's middle to the edge of each neighbour it joins
# (Sprites.lua: north is the game's y - 1, Blender's +Y). Its pieces end exactly on the edges and are
# round about the same axis there, so two tiles' halves meet as one pipe. Joints sit halfway along
# each arm, never on an edge, where a fitting would be cut in two between the tiles: along a straight
# run they fall every half metre, the length of a clay segment, as Pipes.lua takes two segments to a
# tile.

NORTH, EAST, SOUTH, WEST = 1, 2, 4, 8
DIRECTIONS = {NORTH: (0, 1), EAST: (1, 0), SOUTH: (0, -1), WEST: (-1, 0)}
PIPE_SIDES = 16

# For each material: its radius, its material, the
# joint along each arm ("coupling" a threaded sleeve, "wiped" a lead joint's bulb, "bell" a clay
# socket, or none), the fitting at the middle of a tee or cross and of an elbow that can't bend
# ("hub"), and the radius a pipe that bends is bent round. Each is drawn a little fatter than life,
# drip line 3 cm across, iron and lead 4 cm, clay 10 cm: at the game's scale a centimetre is under a
# pixel, and a line two pixels wide comes and goes as the camera moves.
PIPES = {
    "plastic": {"radius": 0.015, "mat": "poly", "joint": None, "hub": "poly", "bend": 0.12},
    "iron": {"radius": 0.02, "mat": "galvanised", "joint": "coupling", "hub": "malleable", "bend": None},
    "lead": {"radius": 0.02, "mat": "lead", "joint": "wiped", "hub": "solder", "bend": 0.16},
    "clay": {"radius": 0.05, "mat": "clay", "joint": "bell", "hub": "clay", "bend": None},
}
LONE_HALF = 0.2  # a lone piece's half length
FITTING = 1.5  # the widest fitting's radius over its pipe's: a wiped joint's bulb


def _axis(spec):
    """The height of a pipe's axis: its fittings rest on the ground, which holds the pipe up a few
    millimetres, so nothing reaches below the floor, where a sprite has nothing to draw over."""
    return spec["radius"] * FITTING


def _towards(start, end, radius_start, radius_end, col, name, mat):
    """A cone from `start` to `end` (points), its radius going from one to the other."""
    start, end = [tuple(p) for p in (start, end)]
    run = [b - a for a, b in zip(start, end)]
    length = math.sqrt(sum(c * c for c in run))
    obj = cylinder(col, name, mat, radius_start, length, radius_top=radius_end, segments=PIPE_SIDES)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(run))
    obj.location = start
    return obj


def _run(col, name, mat, points, radius):
    return tube(col, name, mat, points, radius, sides=PIPE_SIDES, up=(0, 0, 1))


def _joint(col, spec, at, direction):
    """The joint of `spec`'s kind centred at `at` on a pipe along `direction`. Bells and wiped joints
    taper the one way along a run (east or north) whichever arm they are on, so a run reads as
    laid one way."""
    kind, radius, z = spec["joint"], spec["radius"], _axis(spec)
    dx, dy = (abs(direction[0]), abs(direction[1]))
    x, y = at

    def point(offset):
        return (x + dx * offset, y + dy * offset, z)

    if kind == "coupling":
        _run(col, "Pipe_Coupling", M("malleable"), [point(-0.022), point(0.022)], radius * 1.35)
    elif kind == "wiped":
        _towards(point(-0.04), point(0), radius * 1.05, radius * FITTING, col, "Pipe_Wipe", M("solder"))
        _towards(point(0), point(0.04), radius * FITTING, radius * 1.05, col, "Pipe_Wipe", M("solder"))
    elif kind == "bell":
        _run(col, "Pipe_Bell", M("clay"), [point(-0.045), point(0.015)], radius * 1.32)
        _towards(point(0.015), point(0.04), radius * 1.32, radius * 1.02, col, "Pipe_BellShoulder", M("clay"))


def _hub(col, spec, arms):
    """The fitting at the tile's middle where two or more `arms` meet: a sleeve up each arm and a
    round body where they join, filling an elbow's corner."""
    radius, z = spec["radius"], _axis(spec)
    mat = M(spec["hub"])
    sleeve = {"bell": 1.32, "wiped": FITTING}.get(spec["joint"], 1.3) * radius
    length = max(0.035, radius * 1.6)
    for bit in arms:
        dx, dy = DIRECTIONS[bit]
        _run(col, "Pipe_Hub", mat, [(0, 0, z), (dx * length, dy * length, z)], sleeve)
    steps = 8
    lathe(col, "Pipe_HubBody", mat, [(sleeve * math.sin(math.pi * k / steps), z - sleeve * math.cos(math.pi * k / steps))
                                     for k in range(steps + 1)], segments=PIPE_SIDES)


def _cap(col, spec, at, direction):
    """A pipe's closed end at `at`, facing away along `direction`: a plug, or a folded-over drip
    line's end."""
    radius, z = spec["radius"], _axis(spec)
    x, y = at
    dx, dy = direction
    if spec["mat"] == "poly":
        _run(col, "Pipe_Cap", M("poly"), [(x, y, z), (x + dx * 0.012, y + dy * 0.012, z)], radius * 1.25)
    else:
        _run(col, "Pipe_Cap", M(spec["hub"]), [(x - dx * 0.025, y - dy * 0.025, z), (x + dx * 0.012, y + dy * 0.012, z)],
             radius * 1.3)


def _bend(a, b, bend, steps=8):
    """Points from the edge of arm `a` round a curve of radius `bend` to the edge of arm `b`."""
    ax, ay = DIRECTIONS[a]
    bx, by = DIRECTIONS[b]
    cx, cy = (ax + bx) * bend, (ay + by) * bend
    points = [(ax * 0.5, ay * 0.5)]
    for k in range(steps + 1):
        t = k / steps * math.pi / 2
        # From the point `bend` along a to the point `bend` along b, round the corner's centre.
        px = cx - bx * bend * math.cos(t) - ax * bend * math.sin(t)
        py = cy - by * bend * math.cos(t) - ay * bend * math.sin(t)
        points.append((px, py))
    points.append((bx * 0.5, by * 0.5))
    return points


# The wet patch's plane overhangs its tile by this much each side. The render softens a sprite's
# edge over a pixel or two, and two such edges laid side by side let the grass through as a line
# across a wet run; overlapping, the opaque middles of the bands hide it.
WET_OVERHANG = 0.02


def _wet_soil(material, arms):
    """The wet patch under a pipe tile: soil darkened by water, darkest round the middle, where an
    outlet drips, and in a band along each arm that runs into the next wet tile's. Its edge noise
    differs from tile to tile but for a strip along each edge, which every tile shares, so wet
    neighbours join without a seam (kit.stain). Opaque inside, where neighbours overlap (see
    WET_OVERHANG), so its colour has a little of the grass's in it, which no longer shows through."""
    variant = 1 + list(PIPES).index(material) * 16 + sum(arms)
    return stain("EI_WetSoil_%s_%d" % (material, sum(arms)), "#3e321d", [DIRECTIONS[bit] for bit in arms],
                 centre=0.64, near=0.24, far=0.2, softness=0.12, ragged=0.14, opacity=1.0, variant=variant)


def pipe(col, material="plastic", shape=0, wet=False):
    """The pipe tile of `material` joining the neighbours in `shape` (bits NORTH, EAST, SOUTH, WEST).
    `wet` lays it on a patch of wet soil."""
    spec = PIPES[material]
    radius, mat = spec["radius"], M(spec["mat"])
    z = _axis(spec)
    arms = [bit for bit in (NORTH, EAST, SOUTH, WEST) if shape & bit]
    if wet:
        side = 1 + 2 * WET_OVERHANG
        box(col, "Pipe_WetSoil", _wet_soil(material, arms), (side, side, 0.001))
    if not arms:
        _run(col, "Pipe", mat, [(-LONE_HALF, 0, z), (LONE_HALF, 0, z)], radius)
        _cap(col, spec, (-LONE_HALF, 0), (-1, 0))
        _cap(col, spec, (LONE_HALF, 0), (1, 0))
        if spec["joint"]:
            _joint(col, spec, (0, 0), (1, 0))
        return
    straight = shape in (NORTH | SOUTH, EAST | WEST)
    corner = len(arms) == 2 and not straight
    if straight:
        a, b = arms
        _run(col, "Pipe", mat, [(dx * 0.5, dy * 0.5, z) for dx, dy in (DIRECTIONS[a], DIRECTIONS[b])], radius)
    elif corner and spec["bend"]:
        _run(col, "Pipe", mat, [(x, y, z) for x, y in _bend(arms[0], arms[1], spec["bend"])], radius)
    else:
        for bit in arms:
            dx, dy = DIRECTIONS[bit]
            _run(col, "Pipe", mat, [(0, 0, z), (dx * 0.5, dy * 0.5, z)], radius)
        if len(arms) == 1:
            _cap(col, spec, (0, 0), tuple(-c for c in DIRECTIONS[arms[0]]))
        else:
            _hub(col, spec, arms)
    if spec["joint"]:
        for bit in arms:
            dx, dy = DIRECTIONS[bit]
            _joint(col, spec, (dx * 0.25, dy * 0.25), (dx, dy))


# The tap -------------------------------------------------------------------------------------------

TAP_FOOT = 0.15  # the tee's height at the foot of the riser: over the widest pipe's fittings, clay's


def tap(col):
    """The tap fitted at a line's head, drawn over whichever pipe tile it stands on: a galvanised
    tee over the pipe, a riser, a brass hose bib on top turned toward the viewer, its red
    handwheel uppermost. Its fittings are drawn a size up, as the pipes are, to read at the game's
    scale."""
    cylinder(col, "Tap_Tee", M("malleable"), 0.04, TAP_FOOT, segments=16)
    cylinder(col, "Tap_Riser", M("galvanised"), 0.019, 0.25, at=(0, 0, TAP_FOOT - 0.005), segments=12)
    top = TAP_FOOT + 0.24
    cylinder(col, "Tap_Body", M("brass"), 0.034, 0.07, at=(0, 0, top), segments=14)
    # The spout toward the viewer (south-east), turned down, its hose thread at the end.
    out = (0.7071, -0.7071)
    spout = [(0, 0, top + 0.035), (out[0] * 0.06, out[1] * 0.06, top + 0.035), (out[0] * 0.09, out[1] * 0.09, top + 0.01),
             (out[0] * 0.094, out[1] * 0.094, top - 0.03)]
    tube(col, "Tap_Spout", M("brass"), spout, 0.016, sides=10)
    tube(col, "Tap_Thread", M("brass"), [spout[-1], (spout[-1][0], spout[-1][1], spout[-1][2] - 0.025)], 0.02, sides=10)
    cylinder(col, "Tap_Stem", M("brass"), 0.009, 0.04, at=(0, 0, top + 0.07), segments=8)
    wheel_z = top + 0.1
    cylinder(col, "Tap_Wheel", M("red"), 0.05, 0.014, at=(0, 0, wheel_z), segments=20)
    cylinder(col, "Tap_Nut", M("brass"), 0.013, 0.014, at=(0, 0, wheel_z + 0.01), segments=8)


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
    joist_top = top
    leg_top = joist_top
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = cylinder(col, "Stand_Leg", M("bark"), LEG_RADIUS, leg_top, at=(sx * LEG_AT, sy * LEG_AT, 0), segments=10)
            leg.rotation_euler.z = math.radians(17 * (sx + 2 * sy))
            cylinder(col, "Stand_LegEnd", M("logend"), LEG_RADIUS - 0.004, 0.002, at=(sx * LEG_AT, sy * LEG_AT, leg_top), segments=10)
    # Joists along the north and south rows of legs, nailed to their outer faces.
    for sy in (-1, 1):
        y = sy * (LEG_AT + LEG_RADIUS + JOIST[0] / 2)
        box(col, "Stand_Joist", M("planksdark"), (2 * LEG_AT + 0.2, JOIST[0], JOIST[1]), at=(0, y, joist_top - JOIST[1]), bevel=0.004)
        for sx in (-1, 1):
            box(col, "Stand_Nail", M("nail"), (0.012, 0.004, 0.012), at=(sx * LEG_AT, y - sy * (JOIST[0] / 2 + 0.002), joist_top - 0.06))
    # Cross braces up each side, from near the foot of one leg to near the top of the other.
    low, high = 0.18, joist_top - JOIST[1] - 0.06
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
    # The deck: boards north to south across the joists, a finger's gap between them.
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
        parts = rain_barrel(col, closed=barrel == "closed", tarp=tarp)
        group(col, "Stand_Barrel", parts, at=(0, 0, DECK_TOP))


def _quarter_turn():
    return Quaternion((0, 0, 1), math.radians(90))


# The game's rain barrel, measured off carpentry_02_122: about 0.72 m across its belly and 0.8 m
# tall, staves of oak, two dark iron hoops showing below the liner's skirt.
BARREL_HEIGHT = 0.8
BARREL_PROFILE = ((0.335, 0.0), (0.353, 0.18), (0.362, 0.4), (0.353, 0.62), (0.335, BARREL_HEIGHT))
BARREL_STAVES = 18
BARREL_HOOPS = (0.27, 0.53)


def _barrel_radius(z):
    for (r0, z0), (r1, z1) in zip(BARREL_PROFILE, BARREL_PROFILE[1:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return BARREL_PROFILE[-1][0]


def rain_barrel(col, closed=False, tarp=False):
    """The game's rain barrel standing on z = 0: staves, hoops and a dark core showing between the
    staves; a garbage bag (or, with `tarp`, a tarp) lining it, gathered over the rim in folds and
    tied round under it, the cord's ends sticking out; `closed` puts a lid of boards over the liner.
    Returns its parts, to be moved as one."""
    before = set(col.objects)
    lathe(col, "Barrel_Core", M("barrelinside"), [(0, 0.004), (0.315, 0.004), (0.335, 0.44), (0.315, BARREL_HEIGHT - 0.01)],
          segments=24)
    step = 360 / BARREL_STAVES
    for i in range(BARREL_STAVES):
        lathe(col, "Barrel_Stave", M("stavedark" if i % 3 == 1 else "stave"), BARREL_PROFILE, segments=3,
              arc=(i * step + 0.3, (i + 1) * step - 0.3))
    for z in BARREL_HOOPS + (0.035,):
        r = _barrel_radius(z) + 0.004
        lathe(col, "Barrel_Hoop", M("hoop"), [(r, z - 0.022), (r + 0.004, z), (r, z + 0.022)], segments=36)
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
    tube(col, "Barrel_Cord", M("cord"), [(0.395 * math.cos(math.radians(a)), 0.395 * math.sin(math.radians(a)), tie)
                                         for a in range(0, 361, 10)], 0.006, sides=6)
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
    return [obj for obj in col.objects if obj not in before and obj.parent is None]


# The pamphlet --------------------------------------------------------------------------------------

LEAFLET = (0.1, 0.22, 0.0015)  # one panel of a tri-fold: width, height, thickness


def pamphlet(col):
    """Cisterns for Kentucky, an extension service leaflet folded in three, lying cover up: cream
    stock, a green band with its title, a drawing of a barrel on a stand in brown ink, and its inner
    panels showing along the open edge."""
    width, depth, thick = LEAFLET
    box(col, "Leaflet_Back", M("paperback"), (width, depth, thick), at=(0.012, -0.004, 0))
    box(col, "Leaflet_Middle", M("paperback"), (width, depth, thick), at=(0.006, -0.002, thick))
    box(col, "Leaflet_Cover", M("paper"), (width, depth, thick), at=(0, 0, 2 * thick))
    top = 3 * thick
    flat = (0, 0, 0)
    box(col, "Leaflet_Band", M("inkgreen"), (width, 0.045, 0.0004), at=(0, depth / 2 - 0.0305, top))
    text(col, "Leaflet_Title", M("paper"), "CISTERNS", 0.016, at=(0, depth / 2 - 0.031, top + 0.0004), rotate=flat)
    # A barrel on a splayed stand, inked solid, bellied, its hoops left in paper: at an icon's size a
    # barrel drawn in outline reads as a ladder.
    ink = 0.0004
    base = -0.098
    legs_top = base + 0.032
    for x, lean in ((-0.03, -14), (0.03, 14)):
        box(col, "Leaflet_Leg", M("ink"), (0.007, 0.034, ink), at=(x, base + 0.016, top), rotate=(0, 0, lean))
    box(col, "Leaflet_Deck", M("ink"), (0.078, 0.008, ink), at=(0, legs_top, top))
    barrel_bottom, barrel_top = legs_top + 0.004, legs_top + 0.078
    middle = (barrel_top + barrel_bottom) / 2
    box(col, "Leaflet_Barrel", M("ink"), (0.058, barrel_top - barrel_bottom, ink), at=(0, middle, top))
    box(col, "Leaflet_Belly", M("ink"), (0.07, 0.05, ink), at=(0, middle, top))
    for y in (barrel_bottom + 0.018, barrel_top - 0.018):
        box(col, "Leaflet_Hoop", M("paper"), (0.072, 0.005, ink), at=(0, y, top + ink))
    # Lines of type under the band.
    for i, length in enumerate((0.07, 0.06)):
        box(col, "Leaflet_Type", M("ink"), (length, 0.004, 0.0004), at=(0, depth / 2 - 0.068 - i * 0.012, top))


# Inventory icons by item name (Item_EnhancedIrrigation_<name>), each drawn from `model` at
# `icon_elevation` degrees above the horizon, turned `icon_turn` degrees about the vertical: the
# leaflet's head turned away from the viewer, so it stands upright in the icon and fills it.
ITEMS = {
    "CisternsForKentucky": {"model": pamphlet, "icon_elevation": 65, "icon_turn": 45},
}
