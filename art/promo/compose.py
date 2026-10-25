#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==12.3.0"]
# ///
"""Lays out the Workshop page's images from the captures `dev/run-debug-client.sh --promo` saved,
with the harness's lib/promo.py (dev/harness/docs/workshop-page.md, "Laying out the images").
Rerun it after editing a layout; recapture only when the game's look or the mod's names change:

    art/promo/compose.py

Writes the README's images, images/*.png; the Workshop gallery, gallery/NN-<name>.jpg in upload
order; and the mod list's poster, 42/poster.png, which is also the Workshop preview, preview.png.
Item, recipe and skill names come from captures/promo.json, which the game wrote in its own
words; the captions are the README's.
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "dev" / "harness" / "lib"))
sys.path.insert(0, str(REPO / "art" / "models"))
import promo  # noqa: E402
from mod_icon import HOOP_LIGHT, STAVE_LIGHT  # noqa: E402
from promo import PAGE, WIDTH  # noqa: E402

HERE = Path(__file__).resolve().parent
CAPTURES = promo.Captures(HERE / "captures")
IMAGES = HERE / "images"
GALLERY = HERE / "gallery"
POSTER_FILES = [REPO / "Contents" / "mods" / "EnhancedIrrigation" / "42" / "poster.png", REPO / "preview.png"]
TITLE = CAPTURES.strings["modName"]

# The rain barrel's water, along the top of the poster's band and the clean water recipes.
WATER = (64, 142, 210)
TAGLINE = "Running water after the taps run dry"
POSTER_LINE = "Tanks · Lines · Filters · Pumps"
# The poster's scene, the shape of the part above its band: both barrels' rims to the cabbages.
POSTER_CROP = (0, 40, 1104, 885)

# Where each world shot is cropped, in capture pixels, around what the promo run built in it, less
# the open grass above and below; a reshoot that frames a shot differently needs its box moved.
# The banner keeps the whole capture, whose left half is open grass for the title.
CROPS = {"homestead": (0, 120, 1260, 940), "filters": (0, 300, 1260, 960), "pumps": (0, 340, 1260, 910),
         "sprinklers": (0, 130, 1260, 905), "banner": None}

# items.png: the mod's items, what the build menu builds, and the pipe and wrench the lines take,
# by what they're for, a full line of cards each.
ITEM_ROWS = [
    ("Tanks and garden lines: the stand, the pipe, and the wrench that fits a tap",
     ["EnhancedIrrigation_TankStand", "Base.Pipe", "Base.MetalPipe", "Base.LeadPipe", "Base.ClayPipeSegment",
      "Base.PipeWrench"]),
    ("Clean water", ["EnhancedIrrigation_BarrelFilter", "EnhancedIrrigation_BrickFilter",
                     "EnhancedIrrigation.FilterCrockUnfired", "EnhancedIrrigation.FilterCrock",
                     "EnhancedIrrigation_BoilerStone", "EnhancedIrrigation_BoilerWelded"]),
    ("Pumps", ["EnhancedIrrigation_WoodenHandPump", "EnhancedIrrigation_IronHandPump",
               "EnhancedIrrigation_PumpHouseWood", "EnhancedIrrigation_PumpHouseMetal",
               "EnhancedIrrigation.AppliancePump", "EnhancedIrrigation.UtilityPump"]),
    ("Sprinklers, valves, and the pamphlet that teaches most of it",
     ["EnhancedIrrigation.LawnSprinkler", "EnhancedIrrigation.WaterValve", "EnhancedIrrigation.WindUpValve",
      "EnhancedIrrigation.TimerValve", "EnhancedIrrigation.SprinklerTimer", "EnhancedIrrigation.CisternsForKentucky"]),
]
ITEM_COLUMNS = 6
# recipes.png: the recipes by what they're for, each section's cards under its colour.
RECIPE_SECTIONS = [
    ("Tanks", ["EnhancedIrrigation_TankStand", "EnhancedIrrigation_PlumbToTank"]),
    ("Clean water", ["EnhancedIrrigation_BarrelFilter", "EnhancedIrrigation_BrickFilter",
                     "EnhancedIrrigation_ShapeFilterCrock", "EnhancedIrrigation_FireFilterCrock",
                     "EnhancedIrrigation_FilterCrock", "EnhancedIrrigation_BoilerStone",
                     "EnhancedIrrigation_BoilerWelded"]),
    ("Pumps", ["EnhancedIrrigation_WoodenHandPump", "EnhancedIrrigation_IronHandPump",
               "EnhancedIrrigation_SalvagePump", "EnhancedIrrigation_MakeUtilityPump",
               "EnhancedIrrigation_PumpHouseWood", "EnhancedIrrigation_PumpHouseMetal"]),
    ("Sprinklers and valves", ["EnhancedIrrigation_MakePipeSprinkler", "EnhancedIrrigation_MakeWindUpValve",
                               "EnhancedIrrigation_MakeTimerValve"]),
]
# The stand's oak and the pumps' iron, lit as the mod list icon draws them, and the sprinklers'
# brass; the clean water recipes take WATER.
ACCENTS = {"Tanks": STAVE_LIGHT, "Pumps": HOOP_LIGHT, "Sprinklers and valves": (196, 160, 80)}

ITEMS = promo.ItemSheet(CAPTURES, ITEM_ROWS)
RECIPES = promo.RecipeSheet(CAPTURES, RECIPE_SECTIONS, WATER, ACCENTS)

# The gallery: the item sheet and the recipe sheet drawn this many times the README's size, as large
# as the fullest page allows, which keeps their smallest text readable.
ITEM_K = 2
RECIPE_K = 1.5
GALLERY_ITEMS = [
    ("items-tanks-water", "Tanks, lines and clean water", [title for title, _ in ITEM_ROWS[:2]], ITEM_COLUMNS),
    ("items-pumps-valves", "Pumps, sprinklers and valves", [title for title, _ in ITEM_ROWS[2:]], ITEM_COLUMNS),
]
GALLERY_RECIPES = [
    ("recipes-tanks-filters", "Recipes: the Tank Stand, plumbing and filters",
     [("Tanks", slice(None)), ("Clean water", slice(0, 2))]),
    ("recipes-crock-boilers", "Recipes: the Filter Crock and the boilers", [("Clean water", slice(2, None))]),
    ("recipes-hand-pumps", "Recipes: hand pumps, and pumps to salvage or make", [("Pumps", slice(0, 4))]),
    ("recipes-pump-houses-valves", "Recipes: Pump Houses, sprinklers and valves",
     [("Pumps", slice(4, None)), ("Sprinklers and valves", slice(None))]),
]


def world(name, width=WIDTH):
    """A world capture cropped to CROPS, at the width given, or as captured."""
    shot = CAPTURES(name)
    if CROPS[name]:
        shot = shot.crop(CROPS[name])
    return promo.full_width(shot, width) if width else shot


def banner():
    """The mod's name over the garden, which the banner capture leaves room for on its left."""
    image = world("banner")
    promo.title_over(image, TITLE, 84, TAGLINE)
    return image


def interface(width=WIDTH, height=None):
    """The tap's menu with Fit Valve open beside the Timer Valve's panel, both at one scale, as
    large as the card leaves room for, centred on it."""
    margin, gap = round(width / 40), round(width / 30)
    menu, timer = CAPTURES("menu_tap"), CAPTURES("timer")
    factor = (width - 2 * margin - gap) / (menu.width + timer.width)
    if height:
        factor = min(factor, (height - 2 * margin) / max(menu.height, timer.height))
    menu, timer = promo.scaled(menu, factor), promo.scaled(timer, factor)
    image = promo.canvas(height or max(menu.height, timer.height) + 2 * margin, width)
    left = (width - menu.width - gap - timer.width) // 2
    promo.paste(image, menu, (left + menu.width / 2, image.height / 2))
    promo.paste(image, timer, (left + menu.width + gap + timer.width / 2, image.height / 2))
    return image


def shot(name):
    """A world capture, cropped to CROPS, as large as fits the page."""
    return promo.shot_page(promo.fit(world(name, None), *PAGE))


def gallery():
    """The gallery's pictures in upload order, the hero first, each with its file's name."""
    pictures = [
        ("hero", promo.page(TAGLINE, promo.hero(world("banner", None), TITLE))),
        ("homestead", promo.page("A barrel up on a stand, a line down the rows, a tap", shot("homestead"))),
        ("filters", promo.page("Sand, fired clay or fire: water you can drink", shot("filters"))),
        ("pumps", promo.page("A pump on the well, and the sweat to work it", shot("pumps"))),
        ("sprinklers", promo.page("Sprinklers on a pumped line water the beds", shot("sprinklers"))),
        ("interface", promo.page("Water from Tank, and a valve that opens on time", interface(*PAGE))),
    ]
    pictures += ITEMS.pages(GALLERY_ITEMS, ITEM_K)
    pictures += RECIPES.pages(GALLERY_RECIPES, RECIPE_K)
    return pictures


def main():
    for name, make in [("banner", banner), ("homestead", lambda: world("homestead")),
                       ("filters", lambda: world("filters")), ("pumps", lambda: world("pumps")),
                       ("sprinklers", lambda: world("sprinklers")), ("interface", interface),
                       ("items", lambda: ITEMS.draw(columns=ITEM_COLUMNS)), ("recipes", RECIPES.draw)]:
        promo.save(make(), IMAGES / f"{name}.png")
    scene = CAPTURES("poster").crop(POSTER_CROP)
    promo.save_poster(promo.poster(scene, TITLE, POSTER_LINE, WATER), POSTER_FILES)
    promo.save_gallery(gallery(), GALLERY)


if __name__ == "__main__":
    main()
