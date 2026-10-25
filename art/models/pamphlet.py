"""The pamphlet."""
from art.kit import box, text
from palette import M


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
