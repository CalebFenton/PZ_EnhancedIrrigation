"""The valves and timers, found on their own and fitted to a tap or a Pump House."""
from mathutils import Vector

from art.kit import FACING, LEFT, RIGHT, SQUARE, TOWARD, UP, box, cylinder, spline, tube
from lines import TAP_SPOUT_END
from palette import M
from pumps import HOSE_RADIUS, HOUSE_PLUG, WIRE_RADIUS


# The valves ----------------------------------------------------------------------------------------
#
# Each faces the viewer (TOWARD), its dial square to the camera. Found, it is drawn on its own for
# its icon; fitted, it hangs off the tap's spout, which a hose-end timer screws onto, or sits by a
# Pump House's plug, which a plug-in timer goes between.


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
        wire = spline([start, start + UP * 0.012 - TOWARD * 0.03, (start + end) / 2 - TOWARD * 0.035, end], steps=6)
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
    cord = spline([side, side + RIGHT * 0.02 - UP * 0.005, side + RIGHT * 0.03 - UP * 0.03 + TOWARD * 0.01], steps=5)
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
