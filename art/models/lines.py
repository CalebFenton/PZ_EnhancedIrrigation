"""A line's parts: garden pipe of four materials, the tap at its head and the lawn sprinkler."""
import math

from mathutils import Vector

from kit import LEFT, RIGHT, TOWARD, UP, box, cylinder, lathe, spline, stain, tube
from palette import M
from sprites import PIPE_MATERIALS, SHAPES


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

# For each material: its radius, its material, the joint along each arm ("coupling" a threaded
# sleeve, "wiped" a lead joint's bulb, "bell" a clay socket, or none), the fitting at the middle of a
# tee or cross and of an elbow that can't bend ("hub"), and the radius a pipe that bends is bent
# round. Each is drawn a little fatter than life: at the game's scale a centimetre is under a pixel,
# and a line two pixels wide comes and goes as the camera moves.
PIPES = {
    "plastic": {"radius": 0.015, "mat": "poly", "joint": None, "hub": "poly", "bend": 0.12},
    "iron": {"radius": 0.02, "mat": "galvanised", "joint": "coupling", "hub": "malleable", "bend": None},
    "lead": {"radius": 0.02, "mat": "lead", "joint": "wiped", "hub": "solder", "bend": 0.16},
    "clay": {"radius": 0.05, "mat": "clay", "joint": "bell", "hub": "clay", "bend": None},
}
LONE_HALF = 0.2
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
    WET_OVERHANG), so its colour carries a little of the grass's, which can't show through there."""
    variant = 1 + PIPE_MATERIALS.index(material) * SHAPES + sum(arms)
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
    out = TAP_OUT
    spout = [(0, 0, top + 0.035), (out[0] * 0.06, out[1] * 0.06, top + 0.035), (out[0] * 0.09, out[1] * 0.09, top + 0.01),
             TAP_SPOUT_END]
    tube(col, "Tap_Spout", M("brass"), spout, 0.016, sides=10)
    tube(col, "Tap_Thread", M("brass"), [spout[-1], (spout[-1][0], spout[-1][1], spout[-1][2] - 0.025)], 0.02, sides=10)
    cylinder(col, "Tap_Stem", M("brass"), 0.009, 0.04, at=(0, 0, top + 0.07), segments=8)
    wheel_z = top + 0.1
    cylinder(col, "Tap_Wheel", M("red"), 0.05, 0.014, at=(0, 0, wheel_z), segments=20)
    cylinder(col, "Tap_Nut", M("brass"), 0.013, 0.014, at=(0, 0, wheel_z + 0.01), segments=8)


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
        arm = spline([UP * arm_z, out * 0.08 + UP * (arm_z + 0.014), out * 0.12 + round_ * 0.015 + UP * (arm_z + 0.026),
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
