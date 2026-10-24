"""The parts every tile and icon is built from, in real metres (kit.py has the frame): garden pipe of
four materials, the tap, the Tank Stand and the rain barrels that sit on it, the sand filters, the
Filter Crock in its bucket, the boilers, and the pamphlet.
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
        # The sand filters: washed sand, red clay bricks in two shades, and the lime mortar between them,
        # the colours of Renewable Energy's.
        "sand": lambda: material("EI_Sand", "#c9b48a", roughness=0.95, grime=0.2, scale=60, speckle=("#a48f64", 0.4)),
        "brick": lambda: material("EI_Brick", "#a5503a", roughness=0.85, grime=0.2, scale=30),
        "brickdark": lambda: material("EI_BrickDark", "#86412d", roughness=0.85, grime=0.2, scale=30),
        "mortar": lambda: material("EI_Mortar", "#b0aa9c", roughness=0.95, grime=0.2, scale=30),
        # The Filter Crock: unglazed terracotta with the charcoal mixed into its clay showing as faint
        # dark specks, paler and greyer before it is fired; and the game's galvanised pail it stands in.
        "terracotta": lambda: material("EI_Terracotta", "#935b45", roughness=0.9, grime=0.15, scale=50,
                                       speckle=("#654536", 0.35)),
        "rawclay": lambda: material("EI_RawClay", "#978676", roughness=0.95, grime=0.15, scale=50, speckle=("#76695d", 0.35)),
        "pail": lambda: material("EI_Pail", "#a3a8ab", roughness=0.65, metallic=0.4, grime=0.15, scale=20),
        # The boilers: the game's grey steel Metal Drum, its lid a shade bluer, sooted round its foot
        # by the fire under it; the firebox's soot, ash and charred wood, the bricks blackened over its
        # mouth, and the welded box's sheet steel, rust running down it, and its darker angle iron.
        "drum": lambda: material("EI_Drum", "#808283", roughness=0.55, metallic=0.45, grime=0.35, scale=20,
                                 scorch=("#2a2624", "#6e5a45", 0.09)),
        "drumlid": lambda: material("EI_DrumLid", "#7c878b", roughness=0.55, metallic=0.4, grime=0.25, scale=20),
        "drumdark": lambda: material("EI_DrumDark", "#4a4c4e", roughness=0.6, metallic=0.4, grime=0.15),
        "soot": lambda: material("EI_Soot", "#1e1b1a", roughness=0.95, grime=0.2, scale=30),
        "ash": lambda: material("EI_Ash", "#6d6964", roughness=0.95, grime=0.3, scale=60, speckle=("#3a3633", 0.4)),
        "charcoal": lambda: material("EI_Charcoal", "#2a2420", roughness=0.9, grime=0.3, scale=40, speckle=("#4a3a30", 0.3)),
        "brickscorch": lambda: material("EI_BrickScorch", "#4d3229", roughness=0.9, grime=0.3, scale=30),
        "plate": lambda: material("EI_Plate", "#4f5356", roughness=0.6, metallic=0.5, grime=0.35, scale=20,
                                  streaks=("#7d4a2c", 0.45)),
        "ironwork": lambda: material("EI_Ironwork", "#3a3d40", roughness=0.6, metallic=0.5, grime=0.3, scale=20),
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


def _barrel_shell(col):
    """The rain barrel's staves and hoops standing on z = 0, and the dark core between the staves."""
    lathe(col, "Barrel_Core", M("barrelinside"), [(0, 0.004), (0.315, 0.004), (0.335, 0.44), (0.315, BARREL_HEIGHT - 0.01)],
          segments=24)
    step = 360 / BARREL_STAVES
    for i in range(BARREL_STAVES):
        lathe(col, "Barrel_Stave", M("stavedark" if i % 3 == 1 else "stave"), BARREL_PROFILE, segments=3,
              arc=(i * step + 0.3, (i + 1) * step - 0.3))
    for z in BARREL_HOOPS + (0.035,):
        r = _barrel_radius(z) + 0.004
        lathe(col, "Barrel_Hoop", M("hoop"), [(r, z - 0.022), (r + 0.004, z), (r, z + 0.022)], segments=36)


def rain_barrel(col, closed=False, tarp=False):
    """The game's rain barrel standing on z = 0: staves, hoops and a dark core showing between the
    staves; a garbage bag (or, with `tarp`, a tarp) lining it, gathered over the rim in folds and
    tied round under it, the cord's ends sticking out; `closed` puts a lid of boards over the liner.
    Returns its parts, to be moved as one."""
    before = set(col.objects)
    _barrel_shell(col)
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


# The sand filters ----------------------------------------------------------------------------------
#
# Each is filled with sand nearly to its top, which is what tells it from a barrel of water at a
# glance, and has an outlet pipe near its foot on a face the camera sees (east, toward the viewer),
# turned down as a spout.

OUTLET_RADIUS = 0.022  # drawn fatter than a real nipple, as the pipes are, so it holds at game size


def _outlet(col, start, angle, length, drop):
    """A galvanised nipple out of a wall at `start` (x, y, z), heading `angle` degrees from east,
    `length` long to its elbow, then turning down `drop` to its mouth: a sleeve where it leaves the
    wall and a lip round the mouth. Returns the mouth."""
    out = Vector((math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0))
    down = Vector((0, 0, -1))
    start = Vector(start)
    bend = start + out * length
    radius = OUTLET_RADIUS * 1.5  # the elbow's: no tighter than the pipe, or its inside pinches
    centre = bend + down * radius
    elbow = [centre - down * (radius * math.cos(t)) + out * (radius * math.sin(t))
             for t in (math.radians(d) for d in range(0, 91, 15))]
    mouth = elbow[-1] + down * (drop - radius)
    tube(col, "Outlet_Pipe", M("galvanised"), [start] + elbow + [mouth], OUTLET_RADIUS, sides=10, up=(0, 0, 1))
    tube(col, "Outlet_Sleeve", M("malleable"), [start - out * 0.01, start + out * 0.03], OUTLET_RADIUS * 1.35, sides=10,
         up=(0, 0, 1))
    tube(col, "Outlet_Lip", M("malleable"), [mouth - down * 0.018, mouth + down * 0.004], OUTLET_RADIUS * 1.3, sides=10,
         up=tuple(out))
    return mouth


BARREL_SAND = BARREL_HEIGHT - 0.07  # the sand's top, below the rim so the barrel's inside shows over it
BARREL_OUTLET = (-20, 0.15)  # the outlet's heading (degrees from east) and height


def barrel_filter(col):
    """The game's rain barrel without its liner, open, filled with sand to a hand below its rim; a
    nipple out of a stave between the bottom hoops turns down over a clay dish on the ground."""
    _barrel_shell(col)
    # The staves' cut ends round the rim, and the sand's surface, heaped a little in the middle.
    rim = BARREL_HEIGHT
    lathe(col, "Filter_Rim", M("stave"), [(0.313, rim - 0.012), (0.317, rim), (0.337, rim)], segments=36, smooth=False)
    edge = 0.335 + (0.315 - 0.335) * (BARREL_SAND - 0.44) / (rim - 0.01 - 0.44) - 0.002
    rng = random.Random(134)
    ripples = [rng.uniform(-1, 1) for _ in range(36)]
    lathe(col, "Filter_Sand", M("sand"), [(0, BARREL_SAND + 0.014), (edge * 0.5, BARREL_SAND + 0.01), (edge, BARREL_SAND)],
          segments=36, shape=lambda angle, row: (0.0, 0.003 * ripples[int(round(angle / 10)) % 36] * (row == 1)))
    angle, z = BARREL_OUTLET
    a = math.radians(angle)
    wall = _barrel_radius(z) - 0.01
    mouth = _outlet(col, (wall * math.cos(a), wall * math.sin(a), z), angle, 0.06, 0.06)
    # The dish under the spout, its rim a few fingers below the mouth.
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
    to a short neck and a rolled rim, terracotta once `fired`, raw clay before. Returns its parts, to
    be moved as one."""
    before = set(col.objects)
    lathe(col, "Crock", M("terracotta" if fired else "rawclay"), CROCK_PROFILE, segments=36)
    return [obj for obj in col.objects if obj not in before and obj.parent is None]


def crock_icon(col, fired=True):
    """The Filter Crock tipped onto its side towards the viewer's right, its mouth up and out, as the
    game draws its clay jars' icons."""
    group(col, "Crock_Tipped", filter_crock(col, fired), rotate=(0, 40, 0))


PAIL_HEIGHT = 0.23
PAIL_BOTTOM, PAIL_TOP = 0.108, 0.145  # its outside radius at the foot and at the rim
PAIL_WALL = 0.003
PAIL_FLOOR = 0.01  # the inside floor's height, which the crock stands on
PAIL_WIRE = 0.007  # the bail, drawn fatter than life, as the pipes are, so it holds at game size
PAIL_EARS = 45  # the bail's pivots, on the north-east and south-west sides: square to the camera
PAIL_LEAN = 15  # how far the bail leans back from upright, away from the camera: its top shows over the crock's rim


def _pail_radius(z):
    return PAIL_BOTTOM + (PAIL_TOP - PAIL_BOTTOM) * z / PAIL_HEIGHT


def crock_in_bucket(col):
    """The fired Filter Crock standing in the game's galvanised bucket: a tapered pail with a rolled
    rim, two pressed ribs and a foot ring, its wire bail hooked through an ear on either side and
    leaning back over the rim behind the crock."""
    top, inner = PAIL_HEIGHT, PAIL_TOP - PAIL_WALL
    lathe(col, "Pail", M("pail"), [(0, 0.002), (PAIL_BOTTOM - 0.004, 0.002), (PAIL_BOTTOM, 0.008), (PAIL_TOP, top),
                                   (inner, top), (PAIL_BOTTOM - PAIL_WALL, PAIL_FLOOR + 0.004),
                                   (PAIL_BOTTOM - PAIL_WALL - 0.004, PAIL_FLOOR), (0, PAIL_FLOOR)], segments=36)

    def ring(name, z, radius, wire):
        tube(col, name, M("pail"), [(radius * math.cos(math.radians(a)), radius * math.sin(math.radians(a)), z)
                                    for a in range(0, 361, 10)], wire, sides=8)

    ring("Pail_Rim", top - 0.002, PAIL_TOP + 0.002, 0.007)
    for z in (0.075, 0.15):
        ring("Pail_Rib", z, _pail_radius(z), 0.003)
    ring("Pail_Foot", 0.012, _pail_radius(0.012), 0.004)
    # The ears, plates riveted under the rim, and the bail: a half hoop between them, leaning back.
    ear_z = top - 0.035
    reach = _pail_radius(ear_z) + 0.006
    pivot = Vector((math.cos(math.radians(PAIL_EARS)), math.sin(math.radians(PAIL_EARS)), 0))
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
    group(col, "Pail_Crock", filter_crock(col), at=(0, 0, PAIL_FLOOR))


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
    the fire under it. Returns its parts, to be moved as one."""
    before = set(col.objects)
    r, h = DRUM_RADIUS, DRUM_HEIGHT
    lathe(col, "Drum_Shell", M("drum"), [(0, 0.004), (r - 0.012, 0.004), (r - 0.003, 0), (r, 0.012), (r, h - 0.014),
                                         (r + 0.004, h - 0.006), (r - 0.002, h), (r - 0.014, h - 0.004),
                                         (r - 0.018, h - 0.014)], segments=48)
    cylinder(col, "Drum_Lid", M("drumlid"), r - 0.016, 0.002, at=(0, 0, h - 0.016), segments=48)
    for x, y, radius in ((-0.2, 0.03, 0.03), (0.17, 0.15, 0.018)):
        cylinder(col, "Drum_Bung", M("drumdark"), radius, 0.006, at=(x, y, h - 0.016), segments=12)
    lathe(col, "Drum_Seam", M("drum"), [(r, DRUM_SEAM - 0.012), (r + 0.006, DRUM_SEAM), (r, DRUM_SEAM + 0.012)], segments=48)
    for angle in range(-150, 61, 30):
        a = math.radians(angle)
        cylinder(col, "Drum_Rivet", M("drumdark"), 0.009, 0.01, at=(r * math.cos(a), r * math.sin(a), DRUM_SEAM - 0.02),
                 rotate=(90, 0, angle + 90), segments=6)
    a = math.radians(DRUM_WELD)
    box(col, "Drum_Weld", M("drumdark"), (0.006, 0.03, h - 0.05), at=(r * math.cos(a), r * math.sin(a), 0.025), rotate=(0, 0, DRUM_WELD))
    return [obj for obj in col.objects if obj not in before and obj.parent is None]


def _stub(col, start, angle, length):
    """A galvanised nipple out of a wall at `start` (x, y, z), heading `angle` degrees from east,
    `length` long, a sleeve where it leaves the wall and a coupling on its end for the pipe that
    feeds it."""
    out = Vector((math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0))
    start = Vector(start)
    end = start + out * length
    tube(col, "Stub_Pipe", M("galvanised"), [start, end], OUTLET_RADIUS, sides=10, up=(0, 0, 1))
    tube(col, "Stub_Sleeve", M("malleable"), [start - out * 0.01, start + out * 0.03], OUTLET_RADIUS * 1.35, sides=10, up=(0, 0, 1))
    tube(col, "Stub_Coupling", M("malleable"), [end - out * 0.035, end], OUTLET_RADIUS * 1.4, sides=10, up=(0, 0, 1))


def _boiler_drum(col):
    """The Metal Drum resting on the firebox's walls, an inlet stub near its top and a tap near its
    foot, its spout hanging past the firebox's east side."""
    group(col, "Boiler_Drum", metal_drum(col), at=(0, 0, FIREBOX_HEIGHT))
    wall = DRUM_RADIUS - 0.01
    angle, z = DRUM_INLET
    a = math.radians(angle)
    _stub(col, (wall * math.cos(a), wall * math.sin(a), FIREBOX_HEIGHT + z), angle, 0.06)
    angle, z = DRUM_TAP
    a = math.radians(angle)
    start = Vector((wall * math.cos(a), wall * math.sin(a), FIREBOX_HEIGHT + z))
    _outlet(col, start, angle, 0.09, 0.05)
    # A brass globe valve on the run, its red handwheel uppermost, as on the tap at a line's head.
    valve = start + Vector((math.cos(a), math.sin(a), 0)) * 0.05
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
    # Angle iron up each corner, a flange on each face, riveted through the plates.
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
    # The door over the mouth, lapping its sides, its edges framed in flat bar.
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
    "FilterCrock": {"model": crock_icon},
    "FilterCrockUnfired": {"model": lambda col: crock_icon(col, fired=False)},
}
