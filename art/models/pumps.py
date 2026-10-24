"""The hand pumps, the Pump Houses and the pump parts they are built from."""
import math

from mathutils import Vector

from kit import LEFT, RIGHT, TOWARD, UP, board, box, cylinder, heading, lathe, on_ground, spline, tube
from palette import M


# The pumps -----------------------------------------------------------------------------------------
#
# The hand pumps are pitcher pumps about waist high, a little over the game's rain barrel, their
# spout out to the viewer's left (south-west) and their handle to the right (north-east): seen side
# on, which is how a pump reads. Each draws through a Rubber Hose that leaves its foot, sags to the
# ground and runs off to a strainer on its end, which lies in the well or barrel it draws from. A
# Pump House is a box about knee high round its electric pump, its hoses, switch and wire on the
# faces the camera sees.
HOSE_RADIUS = 0.017  # a Rubber Hose drawn a size up, as the pipes are, so it holds at game size
WIRE_RADIUS = 0.008
INTAKE_HEADING = -115  # degrees from east: off to the viewer's left and toward them, clear of the pump
WOOD_BOARD = 0.022  # a plank's thickness


def _strainer(col, at, direction):
    """The brass strainer on an intake hose's end at `at`, along `direction`, its slots dark rings."""
    at, direction = Vector(at), Vector(direction).normalized()
    tube(col, "Strainer", M("brass"), [at - direction * 0.01, at + direction * 0.06], HOSE_RADIUS * 1.5, sides=12)
    for offset in (0.018, 0.032, 0.046):
        tube(col, "Strainer_Slot", M("soot"), [at + direction * offset, at + direction * (offset + 0.006)],
             HOSE_RADIUS * 1.55, sides=12)


def _intake(col, start, angle=INTAKE_HEADING, reach=0.32):
    """A pump's Rubber Hose intake from `start` (x, y, z) on its foot: out along `angle` (degrees
    from east), sagging to the ground and curving a little on it to the strainer on its end, `reach`
    metres out."""
    start = Vector(start)
    out = heading(angle)
    side = UP.cross(out)
    foot = Vector((start.x, start.y, 0))
    stations = [(0, 0, start.z), (0.07, 0, max(HOSE_RADIUS, start.z * 0.6)), (0.16, 0.01, HOSE_RADIUS),
                (reach * 0.7, 0.05, HOSE_RADIUS), (reach, 0.03, HOSE_RADIUS)]
    points = on_ground(spline([foot + out * a + side * s + UP * z for a, s, z in stations]), HOSE_RADIUS)
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
        ring = [heading(a) * (PVC_RADIUS + 0.004) + UP * z for a in range(-45, -226, -15)]
        reach = RIGHT * (PVC_RADIUS + post_depth)
        tube(col, "WoodPump_Strap", M("galvanised"), [ring[0] + reach] + ring + [ring[-1] + reach], 0.005, sides=6)
    # The handle between two cheeks nailed to the post's top, on a bolt through them.
    pitch = math.radians(HANDLE_PITCH)
    along = RIGHT * math.cos(pitch) + UP * math.sin(pitch)
    over_barrel = (PVC_RADIUS + post_depth / 2) / math.cos(pitch)
    board(col, "WoodPump_Handle", M("planksdark"), pivot - along * (over_barrel + 0.06), pivot + along * 0.5, handle, TOWARD)
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
    tube(col, "WoodPump_Spout", M("pvc"), spline(spout), 0.02, sides=12, up=tuple(TOWARD))
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
        at = heading(angle) * 0.077
        cylinder(col, "IronPump_Bolt", M("malleable"), 0.011, 0.01, at=(at.x, at.y, plate + 0.02), segments=6)
    bottom = IRON_BODY[0][1]
    cylinder(col, "IronPump_Column", M("ironwork"), IRON_COLUMN, bottom - 0.06, at=(0, 0, 0.06), segments=16)
    cylinder(col, "IronPump_Coupling", M("malleable"), IRON_COLUMN * 1.3, 0.045, at=(0, 0, 0.28), segments=16)
    lathe(col, "IronPump_Body", M("castiron"), IRON_BODY, segments=28)
    cap = IRON_BODY[-1][1]
    spout = [LEFT * 0.07 + UP * 0.775, LEFT * 0.17 + UP * 0.78, LEFT * 0.215 + UP * 0.755, LEFT * 0.225 + UP * 0.71]
    tube(col, "IronPump_Spout", M("castiron"), spline(spout), 0.026, sides=12, up=tuple(TOWARD))
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
    handle = spline(curve)
    tube(col, "IronPump_Handle", M("castiron"), handle, 0.019, sides=10, up=tuple(TOWARD))
    grip = (handle[-1] - handle[-2]).normalized()
    tube(col, "IronPump_Grip", M("castiron"), [handle[-1] - grip * 0.03, handle[-1] + grip * 0.012], 0.024, sides=10,
         up=tuple(TOWARD))
    rod_top = 0.98
    cylinder(col, "IronPump_Rod", M("galvanised"), 0.011, rod_top - cap, at=(0, 0, cap), segments=8)
    tube(col, "IronPump_RodPin", M("malleable"), [UP * rod_top - TOWARD * 0.025, UP * rod_top + TOWARD * 0.025], 0.006,
         sides=8)
    # The hose's nipple out of the column above the flange.
    out = heading(INTAKE_HEADING)
    nipple = 0.1
    tube(col, "IronPump_Nipple", M("galvanised"), [out * (IRON_COLUMN - 0.004) + UP * nipple, out * 0.085 + UP * nipple], 0.013,
         sides=10, up=(0, 0, 1))
    _intake(col, out * 0.08 + UP * nipple)


HOUSE = (0.56, 0.48, 0.46)  # a Pump House's width (east-west), depth (north-south) and height
HOUSE_PLUG = (HOUSE[0] / 2 + 0.09, -HOUSE[1] / 2 + 0.08 - 0.2)  # where its switch's wire ends on the ground


def _plug(col, at, angle):
    """A two-pin plug lying on the ground at `at` on an electric wire's end, its pins along `angle`
    (degrees from east)."""
    out, side = heading(angle), heading(angle + 90)
    body = Vector(at) + out * 0.02
    box(col, "Plug", M("insulation"), (0.04, 0.03, 0.022), at=(body.x, body.y, 0), rotate=(0, 0, angle), bevel=0.003)
    for s in (-1, 1):
        pin = Vector(at) + out * 0.048 + side * s * 0.007
        box(col, "Plug_Pin", M("brass"), (0.018, 0.003, 0.008), at=(pin.x, pin.y, 0.007), rotate=(0, 0, angle))


def _house_fittings(col, width, depth):
    """What comes out of a Pump House's faces the camera sees: its Rubber Hose intake out of the
    south face's foot, its outlet hose out of the east face, curling on the ground to the coupling a
    Plumb takes on from, and its switch on the east face, its electric wire run from it down to a
    plug on the ground."""
    _intake(col, (-width / 2 + 0.12, -depth / 2 + 0.01, 0.1), angle=-140, reach=0.2)
    x = width / 2
    outlet = [(x - 0.01, 0.05, 0.2), (x + 0.06, 0.05, 0.15), (x + 0.1, 0.08, HOSE_RADIUS), (x + 0.12, 0.18, HOSE_RADIUS),
              (x + 0.09, 0.3, HOSE_RADIUS)]
    hose = on_ground(spline(outlet), HOSE_RADIUS)
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
    cable = on_ground(spline(wire), WIRE_RADIUS)
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
    handle = spline([(-0.12, 0, top), (-0.11, 0, top + 0.05), (-0.02, 0, top + 0.05), (-0.01, 0, top)], steps=6)
    tube(col, "UtilityPump_Handle", M("insulation"), handle, 0.011, sides=10, up=(0, 1, 0))
    cord = spline([(-0.155, 0.02, z - 0.01), (-0.19, 0.025, z - 0.03), (-0.205, 0.01, z - 0.07)], steps=6)
    tube(col, "UtilityPump_Cord", M("insulation"), cord, WIRE_RADIUS, sides=8, up=(0, 1, 0))
