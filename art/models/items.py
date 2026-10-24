"""The parts every tile and icon is built from, in real metres (kit.py has the frame): garden pipe of
four materials, the tap, the Tank Stand and the rain barrels that sit on it, the sand filters, the
Filter Crock in its bucket, the boilers, the hand pumps and Pump Houses, the lawn sprinkler, the pump
parts, and the pamphlet.
"""
import math
import random

from mathutils import Matrix, Quaternion, Vector

from kit import beam, box, cylinder, group, lathe, material, profile_radius, stain, text, tube


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
        # The pumps: the pale grey of Plastic Pipe, the black of a Rubber Hose and an electric wire's
        # insulation, a leather seal, cast iron gone dark with rust in its creases, a Pump House's sheet
        # steel, lighter than a firebox's plate; the pump parts' white appliance plastic, cast
        # aluminium, a motor's copper winding and its core's laminated iron; a sprinkler's green cap.
        "pvc": lambda: material("EI_PVC", "#cbc9be", roughness=0.5, grime=0.15, scale=20),
        "rubber": lambda: material("EI_Rubber", "#262626", roughness=0.6, grime=0.15, scale=20),
        "insulation": lambda: material("EI_Insulation", "#1f1f21", roughness=0.55, grime=0.1),
        "leather": lambda: material("EI_Leather", "#5a3a24", roughness=0.8, grime=0.2),
        "castiron": lambda: material("EI_CastIron", "#30353a", roughness=0.65, metallic=0.45, grime=0.35, scale=20,
                                     streaks=("#6e4128", 0.3)),
        "sheet": lambda: material("EI_Sheet", "#80868a", roughness=0.55, metallic=0.5, grime=0.35, scale=20,
                                  streaks=("#7d4a2c", 0.3)),
        "appliance": lambda: material("EI_Appliance", "#dcd9cf", roughness=0.5, grime=0.1),
        "alloy": lambda: material("EI_Alloy", "#a6abae", roughness=0.45, metallic=0.6, grime=0.2, scale=30),
        "copper": lambda: material("EI_Copper", "#b4642e", roughness=0.4, metallic=0.7, grime=0.1),
        "lamination": lambda: material("EI_Lamination", "#585d61", roughness=0.5, metallic=0.6, grime=0.15),
        "green": lambda: material("EI_Green", "#3d7034", roughness=0.5, grime=0.1),
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
TAP_TOP = TAP_FOOT + 0.24  # the brass body's foot, on the riser
TAP_OUT = (0.7071, -0.7071)  # the spout's heading: toward the viewer (south-east)
TAP_SPOUT_END = (TAP_OUT[0] * 0.094, TAP_OUT[1] * 0.094, TAP_TOP - 0.03)  # where its hose thread starts


def tap(col):
    """The tap fitted at a line's head, drawn over whichever pipe tile it stands on: a galvanised
    tee over the pipe, a riser, a brass hose bib on top turned toward the viewer, its red
    handwheel uppermost. Its fittings are drawn a size up, as the pipes are, to read at the game's
    scale."""
    cylinder(col, "Tap_Tee", M("malleable"), 0.04, TAP_FOOT, segments=16)
    cylinder(col, "Tap_Riser", M("galvanised"), 0.019, 0.25, at=(0, 0, TAP_FOOT - 0.005), segments=12)
    top = TAP_TOP
    cylinder(col, "Tap_Body", M("brass"), 0.034, 0.07, at=(0, 0, top), segments=14)
    # The spout turned down, its hose thread at the end.
    out = TAP_OUT
    spout = [(0, 0, top + 0.035), (out[0] * 0.06, out[1] * 0.06, top + 0.035), (out[0] * 0.09, out[1] * 0.09, top + 0.01),
             TAP_SPOUT_END]
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
# The dark core between the staves, closed at its floor.
BARREL_CORE = ((0, 0.004), (0.315, 0.004), (0.335, 0.44), (0.315, BARREL_HEIGHT - 0.01))


def _barrel_shell(col):
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
    edge = profile_radius(BARREL_CORE, BARREL_SAND) - 0.002
    rng = random.Random(134)
    ripples = [rng.uniform(-1, 1) for _ in range(36)]
    lathe(col, "Filter_Sand", M("sand"), [(0, BARREL_SAND + 0.014), (edge * 0.5, BARREL_SAND + 0.01), (edge, BARREL_SAND)],
          segments=36, shape=lambda angle, row: (0.0, 0.003 * ripples[int(round(angle / 10)) % 36] * (row == 1)))
    angle, z = BARREL_OUTLET
    a = math.radians(angle)
    wall = profile_radius(BARREL_PROFILE, z) - 0.01
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
        tube(col, name, M("pail"), [(radius * math.cos(math.radians(a)), radius * math.sin(math.radians(a)), z)
                                    for a in range(0, 361, 10)], wire, sides=8)

    ring("Pail_Rim", top - 0.002, PAIL_TOP + 0.002, 0.007)
    for z in (0.075, 0.15):
        ring("Pail_Rib", z, profile_radius(PAIL_SIDE, z), 0.003)
    ring("Pail_Foot", 0.012, profile_radius(PAIL_SIDE, 0.012), 0.004)
    # The ears, plates riveted under the rim, and the bail: a half hoop between them, leaning back.
    ear_z = top - 0.035
    reach = profile_radius(PAIL_SIDE, ear_z) + 0.006
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


# The pumps -----------------------------------------------------------------------------------------
#
# The hand pumps are pitcher pumps about waist high, a little over the game's rain barrel, their
# spout out to the viewer's left (south-west) and their handle to the right (north-east): seen side
# on, which is how a pump reads. Each draws through a Rubber Hose that leaves its foot, sags to the
# ground and runs off to a strainer on its end, which lies in the well or barrel it draws from. A
# Pump House is a box about knee high round its electric pump, its hoses, switch and wire on the
# faces the camera sees.

LEFT = Vector((-math.sqrt(0.5), -math.sqrt(0.5), 0))  # the viewer's left, south-west
RIGHT = -LEFT
TOWARD = Vector((math.sqrt(0.5), -math.sqrt(0.5), 0))  # toward the viewer, south-east
UP = Vector((0, 0, 1))
HOSE_RADIUS = 0.017  # a Rubber Hose drawn a size up, as the pipes are, so it holds at game size
WIRE_RADIUS = 0.008
INTAKE_HEADING = -115  # degrees from east: off to the viewer's left and toward them, clear of the pump
WOOD_BOARD = 0.022  # a plank's thickness


def _spline(points, steps=6):
    """Points along a smooth curve through `points` (Catmull-Rom), for a hose's or a wire's run."""
    points = [Vector(p) for p in points]
    padded = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1:i + 3]
        for k in range(steps):
            t = k / steps
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(points[-1])
    return out


def _on_ground(points, radius):
    """`points` with none lower than `radius`, so a hose or wire the curve dips rests on the ground
    rather than through it, where a sprite has nothing to draw over."""
    return [Vector((p.x, p.y, max(p.z, radius))) for p in points]


def _board(col, name, mat, start, end, section, face, bevel=0.003):
    """A board from `start` to `end`, `section` = (width, thickness) across it, its broad side
    looking toward `face` (a direction)."""
    obj = beam(col, name, mat, start, end, section, bevel=bevel)
    run = (Vector(end) - Vector(start)).normalized()
    normal = Vector(face) - run * run.dot(Vector(face))
    normal.normalize()
    obj.rotation_quaternion = Matrix((normal.cross(run), normal, run)).transposed().to_quaternion()
    return obj


def _heading(degrees):
    return Vector((math.cos(math.radians(degrees)), math.sin(math.radians(degrees)), 0))


def _strainer(col, at, direction):
    """The brass strainer on an intake hose's end at `at`, along `direction`, its slots dark rings."""
    at, direction = Vector(at), Vector(direction).normalized()
    tube(col, "Strainer", M("brass"), [at - direction * 0.01, at + direction * 0.06], HOSE_RADIUS * 1.5, sides=12)
    for offset in (0.018, 0.032, 0.046):
        tube(col, "Strainer_Slot", M("soot"), [at + direction * offset, at + direction * (offset + 0.006)],
             HOSE_RADIUS * 1.55, sides=12)


def _intake(col, start, heading=INTAKE_HEADING, reach=0.32):
    """A pump's Rubber Hose intake from `start` (x, y, z) on its foot: out along `heading` (degrees
    from east), sagging to the ground and curving a little on it to the strainer on its end, `reach`
    metres out."""
    start = Vector(start)
    out = _heading(heading)
    side = UP.cross(out)
    foot = Vector((start.x, start.y, 0))
    stations = [(0, 0, start.z), (0.07, 0, max(HOSE_RADIUS, start.z * 0.6)), (0.16, 0.01, HOSE_RADIUS),
                (reach * 0.7, 0.05, HOSE_RADIUS), (reach, 0.03, HOSE_RADIUS)]
    points = _on_ground(_spline([foot + out * a + side * s + UP * z for a, s, z in stations]), HOSE_RADIUS)
    tube(col, "Hose", M("rubber"), points, HOSE_RADIUS, sides=10, up=(0, 0, 1))
    _strainer(col, points[-1], points[-1] - points[-2])


def _plank_box(col, name, width, depth, height, courses):
    """A box of planks nailed up, `width` east-west, `depth` north-south and `height` tall, its lid
    on top of that: the north and south sides' boards run its full width, nailed into the ends of
    the east and west sides', a finger's gap between courses, and the lid's boards run north to
    south over the sides, nailed down. Dark inside, which shows between the boards."""
    t = WOOD_BOARD
    course = height / courses
    box(col, name + "_Inside", M("barrelinside"), (width - 2 * t, depth - 2 * t, height - 0.004), at=(0, 0, 0.002))
    for k in range(courses):
        z = k * course + 0.003
        for sx, sy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            mat = M("planks" if (k + sx + 2 * sy) % 2 else "planksdark")
            if not sy:
                box(col, name + "_Board", mat, (t, depth - 2 * t, course - 0.006), at=(sx * (width - t) / 2, 0, z), bevel=0.003)
                continue
            box(col, name + "_Board", mat, (width, t, course - 0.006), at=(0, sy * (depth - t) / 2, z), bevel=0.003)
            for end in (-1, 1):
                box(col, name + "_Nail", M("nail"), (0.01, 0.004, 0.01),
                    at=(end * (width - t) / 2, sy * (depth / 2 + 0.001), z + course / 2 - 0.008))
    boards, gap = max(2, round(width / 0.15)), 0.008
    span = width + 0.04
    board = (span - (boards - 1) * gap) / boards
    for i in range(boards):
        x = -span / 2 + board / 2 + i * (board + gap)
        box(col, name + "_Lid", M("planks" if i % 2 else "planksdark"), (board, depth + 0.04, t), at=(x, 0, height), bevel=0.003)
        for sy in (-1, 1):
            box(col, name + "_Nail", M("nail"), (0.01, 0.01, 0.002), at=(x, sy * (depth - t) / 2, height + t))


PUMP_BOX = (0.34, 0.42)  # the wooden pump's box: its width both ways, its height
PVC_RADIUS = 0.05  # the wooden pump's barrel, a length of Plastic Pipe a size up
PVC_TOP = 0.86
SEAL = 0.014  # the seal's thickness: a band between a barrel and its cap, the part that wears
HANDLE_PITCH = 14  # degrees the wooden handle rises toward its end, at rest


def wooden_hand_pump(col):
    """A homemade pitcher pump: a length of Plastic Pipe for its barrel, strapped to a post on a
    nailed plank box, a wooden cap over the leather seal at its top, a pipe spout out of its side
    and a plank handle on a pivot at the post's top, the pump rod hung from it into the cap; its
    Rubber Hose intake out of the box's foot."""
    width, height = PUMP_BOX
    _plank_box(col, "WoodPump", width, width, height, 3)
    deck = height + WOOD_BOARD
    cylinder(col, "WoodPump_Barrel", M("pvc"), PVC_RADIUS, PVC_TOP - deck, at=(0, 0, deck), segments=20)
    cylinder(col, "WoodPump_Coupling", M("pvc"), PVC_RADIUS * 1.25, 0.045, at=(0, 0, deck), segments=20)
    cylinder(col, "WoodPump_Seal", M("leather"), PVC_RADIUS * 1.12, SEAL, at=(0, 0, PVC_TOP), segments=20)
    cap_top = PVC_TOP + SEAL + 0.045
    box(col, "WoodPump_Cap", M("planksdark"), (0.13, 0.13, 0.045), at=(0, 0, PVC_TOP + SEAL), bevel=0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(col, "WoodPump_Nail", M("nail"), (0.01, 0.01, 0.002), at=(sx * 0.045, sy * 0.045, cap_top))
    # The post on the handle's side of the barrel, the barrel strapped to it with wire.
    post_depth = 0.05
    post = RIGHT * (PVC_RADIUS + post_depth / 2)
    pivot = post + UP * 1.03
    handle = (0.055, 0.03)
    box(col, "WoodPump_Post", M("planks"), (post_depth, 0.1, pivot.z - handle[0] / 2 - 0.004 - deck),
        at=(post.x, post.y, deck), rotate=(0, 0, 45), bevel=0.004)
    for z in (0.58, 0.8):
        ring = [_heading(a) * (PVC_RADIUS + 0.004) + UP * z for a in range(-45, -226, -15)]
        reach = RIGHT * (PVC_RADIUS + post_depth)
        tube(col, "WoodPump_Strap", M("galvanised"), [ring[0] + reach] + ring + [ring[-1] + reach], 0.005, sides=6)
    # The handle between two cheeks nailed to the post's top, on a bolt through them.
    pitch = math.radians(HANDLE_PITCH)
    along = RIGHT * math.cos(pitch) + UP * math.sin(pitch)
    over_barrel = (PVC_RADIUS + post_depth / 2) / math.cos(pitch)
    _board(col, "WoodPump_Handle", M("planksdark"), pivot - along * (over_barrel + 0.06), pivot + along * 0.5, handle, TOWARD)
    for side in (1, -1):
        cheek = pivot + TOWARD * side * (handle[1] / 2 + 0.007)
        box(col, "WoodPump_Cheek", M("planks"), (0.06, 0.012, 0.12), at=(cheek.x, cheek.y, pivot.z - 0.075), rotate=(0, 0, 45),
            bevel=0.003)
    tube(col, "WoodPump_Bolt", M("nail"), [pivot - TOWARD * 0.035, pivot + TOWARD * 0.035], 0.008, sides=8)
    # The pump rod from the cap up to the handle over the barrel, bolted through it.
    rod = pivot - along * over_barrel
    cylinder(col, "WoodPump_Rod", M("galvanised"), 0.008, rod.z - cap_top, at=(0, 0, cap_top), segments=8)
    tube(col, "WoodPump_Bolt", M("nail"), [rod - TOWARD * 0.025, rod + TOWARD * 0.025], 0.006, sides=8)
    spout = [LEFT * (PVC_RADIUS - 0.01) + UP * 0.78, LEFT * 0.13 + UP * 0.785, LEFT * 0.16 + UP * 0.76, LEFT * 0.165 + UP * 0.71]
    tube(col, "WoodPump_Spout", M("pvc"), _spline(spout), 0.02, sides=12, up=tuple(TOWARD))
    _intake(col, (-0.05, -width / 2 + 0.01, 0.09))


IRON_PLATE = 0.4  # the base plate's width, both ways
IRON_COLUMN = 0.045  # the column's radius: an Iron Pipe a size up
# The cast body's outside from its foot flange up to its cap.
IRON_BODY = [(0, 0.5), (0.1, 0.5), (0.1, 0.525), (0.084, 0.535), (0.084, 0.82), (0.102, 0.828), (0.102, 0.852),
             (0.078, 0.866), (0.045, 0.886), (0, 0.892)]
IRON_PIVOT = 0.09  # the handle's pivot out from the body's axis, over its top flange


def iron_hand_pump(col):
    """A pitcher pump of cast iron: its body on an Iron Pipe column, which stands in a flange bolted
    to a sheet-steel base plate, a spout out of the body's side under its cap and a curved handle on
    a pivot ear at the cap's edge, the pump rod hung from it; its Rubber Hose intake on a nipple out
    of the column's foot."""
    plate = 0.008
    box(col, "IronPump_Plate", M("sheet"), (IRON_PLATE, IRON_PLATE, plate), bevel=0.002)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cylinder(col, "IronPump_Bolt", M("malleable"), 0.015, 0.012, at=(sx * 0.16, sy * 0.16, plate), segments=6)
    lathe(col, "IronPump_Foot", M("castiron"), [(0, plate), (0.095, plate), (0.095, plate + 0.02), (0.066, plate + 0.034),
                                                (IRON_COLUMN + 0.005, 0.075), (0, 0.075)], segments=24)
    for angle in (45, 135, 225, 315):
        at = _heading(angle) * 0.077
        cylinder(col, "IronPump_Bolt", M("malleable"), 0.011, 0.01, at=(at.x, at.y, plate + 0.02), segments=6)
    bottom = IRON_BODY[0][1]
    cylinder(col, "IronPump_Column", M("ironwork"), IRON_COLUMN, bottom - 0.06, at=(0, 0, 0.06), segments=16)
    cylinder(col, "IronPump_Coupling", M("malleable"), IRON_COLUMN * 1.3, 0.045, at=(0, 0, 0.28), segments=16)
    lathe(col, "IronPump_Body", M("castiron"), IRON_BODY, segments=28)
    cap = IRON_BODY[-1][1]
    spout = [LEFT * 0.07 + UP * 0.775, LEFT * 0.17 + UP * 0.78, LEFT * 0.215 + UP * 0.755, LEFT * 0.225 + UP * 0.71]
    tube(col, "IronPump_Spout", M("castiron"), _spline(spout), 0.026, sides=12, up=tuple(TOWARD))
    tube(col, "IronPump_SpoutRoot", M("castiron"), [spout[0], LEFT * 0.12 + UP * 0.777], 0.036, sides=12, up=tuple(TOWARD))
    tube(col, "IronPump_SpoutLip", M("castiron"), [spout[-1] + UP * 0.012, spout[-1] - UP * 0.004], 0.03, sides=12,
         up=tuple(RIGHT))
    # The handle on a bolt through the ear's two cheeks, curving up and over to its grip.
    pivot = RIGHT * IRON_PIVOT + UP * 0.99
    for side in (1, -1):
        ear = RIGHT * IRON_PIVOT + TOWARD * side * 0.025
        box(col, "IronPump_Ear", M("castiron"), (0.05, 0.014, pivot.z + 0.035 - 0.85), at=(ear.x, ear.y, 0.85),
            rotate=(0, 0, 45), bevel=0.003)
    tube(col, "IronPump_Pivot", M("malleable"), [pivot - TOWARD * 0.04, pivot + TOWARD * 0.04], 0.01, sides=8)
    curve = [RIGHT * t + UP * z for t, z in ((-0.05, 0.975), (IRON_PIVOT, 0.99), (0.22, 1.035), (0.37, 1.06), (0.5, 1.045),
                                             (0.57, 1.01))]
    handle = _spline(curve)
    tube(col, "IronPump_Handle", M("castiron"), handle, 0.019, sides=10, up=tuple(TOWARD))
    grip = (handle[-1] - handle[-2]).normalized()
    tube(col, "IronPump_Grip", M("castiron"), [handle[-1] - grip * 0.03, handle[-1] + grip * 0.012], 0.024, sides=10,
         up=tuple(TOWARD))
    rod_top = 0.98
    cylinder(col, "IronPump_Rod", M("galvanised"), 0.011, rod_top - cap, at=(0, 0, cap), segments=8)
    tube(col, "IronPump_RodPin", M("malleable"), [UP * rod_top - TOWARD * 0.025, UP * rod_top + TOWARD * 0.025], 0.006,
         sides=8)
    # The hose's nipple out of the column above the flange.
    out = _heading(INTAKE_HEADING)
    nipple = 0.1
    tube(col, "IronPump_Nipple", M("galvanised"), [out * (IRON_COLUMN - 0.004) + UP * nipple, out * 0.085 + UP * nipple], 0.013,
         sides=10, up=(0, 0, 1))
    _intake(col, out * 0.08 + UP * nipple)


HOUSE = (0.56, 0.48, 0.46)  # a Pump House's width (east-west), depth (north-south) and height
HOUSE_PLUG = (HOUSE[0] / 2 + 0.09, -HOUSE[1] / 2 + 0.08 - 0.2)  # where its switch's wire ends on the ground


def _plug(col, at, heading):
    """A two-pin plug lying on the ground at `at` on an electric wire's end, its pins along `heading`
    (degrees from east)."""
    out, side = _heading(heading), _heading(heading + 90)
    body = Vector(at) + out * 0.02
    box(col, "Plug", M("insulation"), (0.04, 0.03, 0.022), at=(body.x, body.y, 0), rotate=(0, 0, heading), bevel=0.003)
    for s in (-1, 1):
        pin = Vector(at) + out * 0.048 + side * s * 0.007
        box(col, "Plug_Pin", M("brass"), (0.018, 0.003, 0.008), at=(pin.x, pin.y, 0.007), rotate=(0, 0, heading))


def _house_fittings(col, width, depth):
    """What comes out of a Pump House's faces the camera sees: its Rubber Hose intake out of the
    south face's foot, its outlet hose out of the east face, curling on the ground to the coupling a
    Plumb takes on from, and its switch on the east face, its electric wire run from it down to a
    plug on the ground."""
    _intake(col, (-width / 2 + 0.12, -depth / 2 + 0.01, 0.1), heading=-140, reach=0.2)
    x = width / 2
    outlet = [(x - 0.01, 0.05, 0.2), (x + 0.06, 0.05, 0.15), (x + 0.1, 0.08, HOSE_RADIUS), (x + 0.12, 0.18, HOSE_RADIUS),
              (x + 0.09, 0.3, HOSE_RADIUS)]
    hose = _on_ground(_spline(outlet), HOSE_RADIUS)
    tube(col, "Hose", M("rubber"), hose, HOSE_RADIUS, sides=10, up=(0, 0, 1))
    tube(col, "Hose_Grommet", M("rubber"), [(x - 0.004, 0.05, 0.2), (x + 0.008, 0.05, 0.2)], HOSE_RADIUS * 1.5, sides=12,
         up=(0, 0, 1))
    end = (hose[-1] - hose[-2]).normalized()
    tube(col, "Hose_Coupling", M("brass"), [hose[-1] - end * 0.02, hose[-1] + end * 0.02], HOSE_RADIUS * 1.4, sides=12,
         up=(0, 0, 1))
    # The switch box, its toggle up, and the wire out of its foot.
    switch = Vector((x + 0.015, -depth / 2 + 0.08, 0.24))
    box(col, "House_Switch", M("drumdark"), (0.03, 0.06, 0.09), at=tuple(switch), bevel=0.003)
    tube(col, "House_Toggle", M("red"), [switch + Vector((0.015, 0, 0.055)), switch + Vector((0.04, 0, 0.075))], 0.006,
         sides=8, up=(0, 1, 0))
    wire = [switch + Vector((0.01, 0, 0.005)), switch + Vector((0.04, -0.01, -0.06)), switch + Vector((0.08, -0.03, -0.2)),
            Vector((x + 0.1, switch.y - 0.1, WIRE_RADIUS)), Vector((*HOUSE_PLUG, WIRE_RADIUS))]
    cable = _on_ground(_spline(wire), WIRE_RADIUS)
    tube(col, "House_Wire", M("insulation"), cable, WIRE_RADIUS, sides=8, up=(0, 0, 1))
    tail = cable[-1] - cable[-2]
    _plug(col, cable[-1], math.degrees(math.atan2(tail.y, tail.x)))


def pump_house_wood(col):
    """A Pump House of planks: a nailed plank box about knee high round its electric pump, its lid
    nailed on; its hoses, switch and wire out of the faces the camera sees."""
    width, depth, height = HOUSE
    _plank_box(col, "PumpHouse", width, depth, height, 3)
    _house_fittings(col, width, depth)


def pump_house_metal(col):
    """A Pump House of sheet steel: a box folded and screwed up its corners, a louvred vent in its
    south face and its lid lapping over its sides; its hoses, switch and wire as the wooden one's."""
    width, depth, height = HOUSE
    t = 0.004
    for sy in (-1, 1):
        box(col, "PumpHouse_Side", M("sheet"), (width, t, height), at=(0, sy * (depth - t) / 2, 0))
    for sx in (-1, 1):
        box(col, "PumpHouse_Side", M("sheet"), (t, depth - 2 * t, height), at=(sx * (width - t) / 2, 0, 0))
    # The lid: a sheet lapping the sides, its edges folded down over them.
    lap, skirt = 0.012, 0.035
    lid_w, lid_d = width + 2 * lap, depth + 2 * lap
    box(col, "PumpHouse_Lid", M("sheet"), (lid_w, lid_d, t), at=(0, 0, height), bevel=0.001)
    for sy in (-1, 1):
        box(col, "PumpHouse_LidEdge", M("sheet"), (lid_w, t, skirt), at=(0, sy * (lid_d - t) / 2, height + t - skirt))
    for sx in (-1, 1):
        box(col, "PumpHouse_LidEdge", M("sheet"), (t, lid_d, skirt), at=(sx * (lid_w - t) / 2, 0, height + t - skirt))
    # The sides' folded corners, a strip of each lapping the next, screwed through.
    fold = 0.03
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(col, "PumpHouse_Fold", M("sheet"), (fold, t, height - skirt), at=(sx * (width - fold) / 2, sy * (depth / 2 + t / 2), 0))
            box(col, "PumpHouse_Fold", M("sheet"), (t, fold, height - skirt), at=(sx * (width / 2 + t / 2), sy * (depth - fold) / 2, 0))
            for z in (0.06, 0.2, 0.34):
                box(col, "PumpHouse_Screw", M("malleable"), (0.012, 0.004, 0.012),
                    at=(sx * (width - fold) / 2, sy * (depth / 2 + t + 0.002), z))
                box(col, "PumpHouse_Screw", M("malleable"), (0.004, 0.012, 0.012),
                    at=(sx * (width / 2 + t + 0.002), sy * (depth - fold) / 2, z))
    # The vent: slots in the south face, each under a little hood.
    face = -(depth / 2 + t / 2)
    for k in range(4):
        z = 0.24 + k * 0.035
        box(col, "PumpHouse_VentSlot", M("soot"), (0.16, 0.002, 0.012), at=(0.08, face - 0.001, z))
        box(col, "PumpHouse_VentHood", M("sheet"), (0.16, 0.012, 0.004), at=(0.08, face - 0.006, z + 0.012))
    _house_fittings(col, width, depth)


# The lawn sprinkler --------------------------------------------------------------------------------

SPRINKLER_HEAD = 0.3  # the head's height on its riser: under the tap's, small beside it on a line


def _sprinkler_head(col, z):
    """A rotary sprinkler's head at height `z`: a brass bearing and hub under a green cap, and two
    arms out to the viewer's left and right, their tips bent round to throw the water that spins it."""
    cylinder(col, "Sprinkler_Bearing", M("brass"), 0.02, 0.025, at=(0, 0, z), segments=12)
    hub = z + 0.025
    cylinder(col, "Sprinkler_Hub", M("brass"), 0.032, 0.026, at=(0, 0, hub), segments=14)
    cylinder(col, "Sprinkler_Cap", M("green"), 0.027, 0.026, at=(0, 0, hub + 0.026), radius_top=0.015, segments=14)
    arm_z = hub + 0.013
    for side in (1, -1):
        out, round_ = RIGHT * side, TOWARD * side
        arm = _spline([UP * arm_z, out * 0.08 + UP * (arm_z + 0.014), out * 0.12 + round_ * 0.015 + UP * (arm_z + 0.026),
                       out * 0.125 + round_ * 0.045 + UP * (arm_z + 0.036)], steps=4)
        tube(col, "Sprinkler_Arm", M("galvanised"), arm, 0.011, sides=8, up=(0, 0, 1))
        tip = (arm[-1] - arm[-2]).normalized()
        tube(col, "Sprinkler_Nozzle", M("brass"), [arm[-1] - tip * 0.004, arm[-1] + tip * 0.016], 0.014, sides=8, up=(0, 0, 1))


def sprinkler(col):
    """The Lawn Sprinkler set on a line tile, drawn over whichever pipe tile it stands on, as the tap
    is: a collar clamped over the pipe at the tile's middle, a short galvanised riser and the head."""
    collar = 0.14  # over the widest pipe's top, clay's
    cylinder(col, "Sprinkler_Collar", M("malleable"), 0.034, collar, segments=14)
    cylinder(col, "Sprinkler_Riser", M("galvanised"), 0.013, SPRINKLER_HEAD - collar + 0.005, at=(0, 0, collar - 0.005),
             segments=10)
    _sprinkler_head(col, SPRINKLER_HEAD)


def lawn_sprinkler(col):
    """The Lawn Sprinkler on its own, as it's found: the head on a short riser over a spike, a step
    bar across the riser's foot to tread it into a lawn."""
    cylinder(col, "Sprinkler_Spike", M("galvanised"), 0.003, 0.12, at=(0, 0, -0.12), radius_top=0.013, segments=10)
    cylinder(col, "Sprinkler_Riser", M("galvanised"), 0.013, 0.2, segments=10)
    tube(col, "Sprinkler_Step", M("galvanised"), [LEFT * 0.05 + UP * 0.02, RIGHT * 0.05 + UP * 0.02], 0.008, sides=8,
         up=(0, 0, 1))
    _sprinkler_head(col, 0.2)


# The pump parts ------------------------------------------------------------------------------------
#
# Each is built along +X, its inlet's end, and turned for its icon so that runs to the viewer's
# right, seen side on.

def appliance_pump(col):
    """A washing machine's drain pump, as Salvage Pump takes it out: a white plastic pump body, its
    inlet straight out of the front and its outlet up off the top, on the laminated core of the
    small motor behind it, whose copper coil and two spade terminals sit on top."""
    z = 0.045  # the shaft's height
    level = (0, 0, 1)
    tube(col, "AppliancePump_Body", M("appliance"), [(0, 0, z), (0.04, 0, z)], 0.045, sides=24, up=level)
    tube(col, "AppliancePump_Seam", M("lamination"), [(0.038, 0, z), (0.043, 0, z)], 0.043, sides=24, up=level)
    tube(col, "AppliancePump_Cover", M("appliance"), [(0.043, 0, z), (0.053, 0, z)], 0.038, sides=24, up=level)
    tube(col, "AppliancePump_Inlet", M("appliance"), [(0.053, 0, z), (0.115, 0, z)], 0.017, sides=14, up=level)
    tube(col, "AppliancePump_InletRib", M("appliance"), [(0.095, 0, z), (0.103, 0, z)], 0.021, sides=14, up=level)
    outlet = (0.022, -0.02)
    tube(col, "AppliancePump_Outlet", M("appliance"), [(outlet[0], outlet[1], z + 0.03), (outlet[0], outlet[1], z + 0.1)], 0.012,
         sides=12, up=(1, 0, 0))
    tube(col, "AppliancePump_OutletRib", M("appliance"), [(outlet[0], outlet[1], z + 0.08), (outlet[0], outlet[1], z + 0.087)],
         0.015, sides=12, up=(1, 0, 0))
    # The ears it was screwed into the machine by.
    box(col, "AppliancePump_Ears", M("appliance"), (0.006, 0.12, 0.022), at=(-0.003, 0, z - 0.011), bevel=0.002)
    core = 0.07
    box(col, "AppliancePump_Core", M("lamination"), (0.05, 0.08, core), at=(-0.035, 0, z - core / 2), bevel=0.002)
    # The coil lies across the core's top, between the black flanges of its bobbin.
    coil_z = z + core / 2 + 0.02
    tube(col, "AppliancePump_Coil", M("copper"), [(-0.035, -0.03, coil_z), (-0.035, 0.03, coil_z)], 0.02, sides=16, up=level)
    for y in (-0.034, 0.03):
        box(col, "AppliancePump_Bobbin", M("insulation"), (0.05, 0.006, 0.046), at=(-0.035, y + 0.002, coil_z - 0.023),
            bevel=0.001)
    for dx in (-0.012, 0.012):
        box(col, "AppliancePump_Terminal", M("brass"), (0.004, 0.012, 0.016), at=(-0.035 + dx, -0.034, coil_z + 0.02))


def utility_pump(col):
    """A portable electric utility pump: a red motor on a steel base, its cast aluminium pump body on
    the front, a brass hose port straight out of it and another up off its top, a carry handle over
    the motor and the stub of its power cord out of the back."""
    z, r = 0.085, 0.06  # the shaft's height, the motor's radius
    level = (0, 0, 1)
    for sy in (-1, 1):
        box(col, "UtilityPump_Rail", M("ironwork"), (0.27, 0.025, 0.012), at=(-0.03, sy * 0.05, 0), bevel=0.002)
    for x in (-0.12, 0.0):
        box(col, "UtilityPump_Foot", M("ironwork"), (0.03, 0.13, 0.03), at=(x, 0, 0.01), bevel=0.002)
    tube(col, "UtilityPump_Motor", M("red"), [(-0.14, 0, z), (0.03, 0, z)], r, sides=24, up=level)
    for x in (-0.12, -0.09, -0.06, -0.03):
        tube(col, "UtilityPump_Fin", M("red"), [(x, 0, z), (x + 0.008, 0, z)], r + 0.004, sides=24, up=level)
    tube(col, "UtilityPump_EndBell", M("alloy"), [(-0.16, 0, z), (-0.14, 0, z)], r - 0.008, sides=24, up=level)
    tube(col, "UtilityPump_Body", M("alloy"), [(0.03, 0, z), (0.085, 0, z)], 0.07, sides=24, up=level)
    tube(col, "UtilityPump_Cover", M("alloy"), [(0.085, 0, z), (0.095, 0, z)], 0.062, sides=24, up=level)
    for angle in range(0, 360, 60):
        a = math.radians(angle + 30)
        box(col, "UtilityPump_Bolt", M("malleable"), (0.006, 0.01, 0.01), at=(0.097, 0.052 * math.cos(a), z + 0.052 * math.sin(a) - 0.005))
    tube(col, "UtilityPump_InletBoss", M("alloy"), [(0.095, 0, z), (0.115, 0, z)], 0.024, sides=16, up=level)
    tube(col, "UtilityPump_Inlet", M("brass"), [(0.115, 0, z), (0.145, 0, z)], 0.018, sides=16, up=level)
    outlet = (0.058, -0.035)
    tube(col, "UtilityPump_OutletBoss", M("alloy"), [(outlet[0], outlet[1], z + 0.05), (outlet[0], outlet[1], z + 0.088)], 0.022,
         sides=16, up=(1, 0, 0))
    tube(col, "UtilityPump_Outlet", M("brass"), [(outlet[0], outlet[1], z + 0.088), (outlet[0], outlet[1], z + 0.118)], 0.017,
         sides=16, up=(1, 0, 0))
    top = z + r - 0.005
    handle = _spline([(-0.12, 0, top), (-0.11, 0, top + 0.05), (-0.02, 0, top + 0.05), (-0.01, 0, top)], steps=6)
    tube(col, "UtilityPump_Handle", M("insulation"), handle, 0.011, sides=10, up=(0, 1, 0))
    cord = _spline([(-0.155, 0.02, z - 0.01), (-0.19, 0.025, z - 0.03), (-0.205, 0.01, z - 0.07)], steps=6)
    tube(col, "UtilityPump_Cord", M("insulation"), cord, WIRE_RADIUS, sides=8, up=(0, 1, 0))


# The valves ----------------------------------------------------------------------------------------
#
# Each faces the viewer (TOWARD), its dial square to the camera. Found, it is drawn on its own for
# its icon; fitted, it hangs off the tap's spout, which a hose-end timer screws onto, or sits by a
# Pump House's plug, which a plug-in timer goes between.

FACING = (90, 0, 45)  # turns an upright cylinder's axis, or a box's -Y face, toward the viewer
SQUARE = (0, 0, 45)  # turns a box's X along the viewer's right and its Y away from the viewer


def _dial(col, name, centre, radius, depth=0.004):
    """A white clock or timer face of `radius` whose back is at `centre`, facing the viewer, with
    two dark hands at ten to two and a red centre."""
    centre = Vector(centre)
    cylinder(col, name + "_Face", M("paper"), radius, depth, at=tuple(centre), rotate=FACING, segments=20)
    front = centre + TOWARD * (depth + 0.0008)
    for tilt, length in ((-50, 0.55), (60, 0.8)):
        box(col, name + "_Hand", M("ink"), (0.0035, 0.0012, radius * length), at=tuple(front), rotate=(0, tilt, 45))
    cylinder(col, name + "_Pin", M("red"), radius * 0.12, 0.002, at=tuple(front), rotate=FACING, segments=8)


def _barb(col, name, mat, start, direction, length, radius):
    """A barbed hose spigot from `start` along `direction`, two ribs on it."""
    start, direction = Vector(start), Vector(direction).normalized()
    tube(col, name, mat, [start, start + direction * length], radius, sides=12, up=(0, 0, 1))
    for at in (0.45, 0.8):
        rib = start + direction * length * at
        tube(col, name + "_Rib", mat, [rib, rib + direction * 0.005], radius * 1.25, sides=12, up=(0, 0, 1))


def water_valve(col, at=(0, 0, 0)):
    """A washing machine's water inlet valve, as Salvage Pump takes it out: a white plastic body
    with a barbed inlet out of the viewer's left and outlet out of the right, and the black coil
    that opens it on top, its two spade terminals up."""
    at = Vector(at)
    box(col, "WaterValve_Body", M("appliance"), (0.05, 0.034, 0.028), at=tuple(at), rotate=SQUARE, bevel=0.003)
    middle = at + UP * 0.014
    _barb(col, "WaterValve_Inlet", M("appliance"), middle + LEFT * 0.024, LEFT, 0.035, 0.008)
    _barb(col, "WaterValve_Outlet", M("appliance"), middle + RIGHT * 0.024, RIGHT, 0.035, 0.008)
    top = at + UP * 0.028
    cylinder(col, "WaterValve_Coil", M("insulation"), 0.015, 0.026, at=tuple(top), segments=16)
    for side in (-1, 1):
        box(col, "WaterValve_Terminal", M("brass"), (0.004, 0.0015, 0.012), at=tuple(top + UP * 0.026 + RIGHT * side * 0.006),
            rotate=SQUARE)


def wind_up_valve(col, at=(0, 0, 0)):
    """The Wind-up Valve: a white kitchen timer's housing, its dial to the viewer, pinching the
    length of Rubber Hose that runs through its foot, a brass coupling on each end."""
    at = Vector(at)
    box(col, "WindUp_Housing", M("appliance"), (0.07, 0.045, 0.065), at=tuple(at), rotate=SQUARE, bevel=0.006)
    _dial(col, "WindUp_Dial", at + UP * 0.036 + TOWARD * 0.0225, 0.025)
    # The knob it's wound by, on top.
    cylinder(col, "WindUp_Knob", M("red"), 0.009, 0.01, at=tuple(at + UP * 0.065), segments=12)
    hose = at + UP * 0.012
    tube(col, "WindUp_Hose", M("rubber"), [hose + LEFT * 0.065, hose + RIGHT * 0.065], HOSE_RADIUS * 0.8, sides=10,
         up=(0, 0, 1))
    for side in (LEFT, RIGHT):
        end = hose + side * 0.065
        tube(col, "WindUp_Coupling", M("brass"), [end - side * 0.012, end + side * 0.006], HOSE_RADIUS, sides=12, up=(0, 0, 1))


def _alarm_clock(col, centre):
    """A twin-bell alarm clock whose body's back is at `centre`: a red drum, its face to the
    viewer, two brass bells and a hammer between them, and two feet."""
    centre = Vector(centre)
    radius = 0.04
    back = centre - TOWARD * 0.012
    cylinder(col, "Clock_Body", M("red"), radius, 0.03, at=tuple(back), rotate=FACING, segments=24)
    _dial(col, "Clock_Dial", back + TOWARD * 0.03, radius * 0.85)
    middle = back + TOWARD * 0.015
    for side in (LEFT, RIGHT):
        bell = middle + side * 0.026 + UP * (radius + 0.002)
        cylinder(col, "Clock_Bell", M("brass"), 0.017, 0.014, at=tuple(bell), radius_top=0.006, segments=14)
        foot = middle + side * 0.025 - UP * (radius + 0.006)
        cylinder(col, "Clock_Foot", M("brass"), 0.005, 0.01, at=tuple(foot), segments=8)
    cylinder(col, "Clock_Hammer", M("brass"), 0.003, 0.02, at=tuple(middle + UP * radius), segments=6)


def timer_valve(col, at=(0, 0, 0), clock=None):
    """The Timer Valve: an alarm clock standing on a salvaged Water Valve, or at `clock` beside it,
    two electric wires looped from the clock's back to the valve's coil."""
    at = Vector(at)
    water_valve(col, at)
    clock = Vector(clock) if clock else at + UP * 0.1
    _alarm_clock(col, clock)
    for side in (-1, 1):
        start = at + UP * 0.054 + RIGHT * side * 0.006
        end = clock - TOWARD * 0.02 + RIGHT * side * 0.012
        wire = _spline([start, start + UP * 0.012 - TOWARD * 0.03, (start + end) / 2 - TOWARD * 0.035, end], steps=6)
        tube(col, "TimerValve_Wire", M("red" if side > 0 else "insulation"), wire, 0.0025, sides=6, up=(0, 0, 1))


def sprinkler_timer(col, at=(0, 0, 0)):
    """The Sprinkler Timer, a garden store's plug-in hose timer: a green box with a dial on its face,
    a brass hose thread into its top and out of its foot, and its power cord out of the side."""
    at = Vector(at)
    box(col, "SprinklerTimer_Box", M("green"), (0.065, 0.04, 0.085), at=tuple(at), rotate=SQUARE, bevel=0.006)
    _dial(col, "SprinklerTimer_Dial", at + UP * 0.05 + TOWARD * 0.02, 0.022)
    cylinder(col, "SprinklerTimer_In", M("brass"), 0.012, 0.018, at=tuple(at + UP * 0.085), segments=12)
    cylinder(col, "SprinklerTimer_Out", M("brass"), 0.011, 0.016, at=tuple(at - UP * 0.016), segments=12)
    side = at + RIGHT * 0.032 + UP * 0.02
    cord = _spline([side, side + RIGHT * 0.02 - UP * 0.005, side + RIGHT * 0.03 - UP * 0.03 + TOWARD * 0.01], steps=5)
    tube(col, "SprinklerTimer_Cord", M("insulation"), cord, WIRE_RADIUS * 0.7, sides=6, up=(0, 0, 1))


# Where a hose-end valve hangs on the tap: below the spout's thread, to a tenth of a millimetre.
TAP_VALVE_AT = (round(TAP_SPOUT_END[0], 4), round(TAP_SPOUT_END[1], 4), TAP_SPOUT_END[2] - 0.1)


def tap_wind_up_valve(col):
    """The Wind-up Valve as fitted, overlaid on the tap: hung off its spout, its dial to the viewer."""
    wind_up_valve(col, TAP_VALVE_AT)


def tap_timer_valve(col):
    """The Timer Valve as fitted, overlaid on the tap: its valve hung off the spout, the clock
    strapped to the riser's other side, to the viewer's right."""
    valve = (TAP_VALVE_AT[0], TAP_VALVE_AT[1], TAP_VALVE_AT[2] + 0.01)
    timer_valve(col, valve, clock=Vector(valve) + RIGHT * 0.085 + UP * 0.005)


def tap_sprinkler_timer(col):
    """The Sprinkler Timer as fitted, overlaid on the tap: screwed to its spout."""
    sprinkler_timer(col, (TAP_VALVE_AT[0], TAP_VALVE_AT[1], TAP_VALVE_AT[2] - 0.03))


def house_timer(col):
    """A timer fitted to a Pump House, overlaid on either: a plug-in timer on the ground by the end of
    its wire, which the pump's plug goes into."""
    sprinkler_timer(col, (HOUSE_PLUG[0] + 0.01, HOUSE_PLUG[1] - 0.01, 0.016))


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
    "AppliancePump": {"model": appliance_pump, "icon_elevation": 35, "icon_turn": 45},
    "UtilityPump": {"model": utility_pump, "icon_turn": 45},
    "LawnSprinkler": {"model": lawn_sprinkler},
    "WaterValve": {"model": water_valve},
    "WindUpValve": {"model": wind_up_valve},
    "TimerValve": {"model": timer_valve},
    "SprinklerTimer": {"model": sprinkler_timer},
}
