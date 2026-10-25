"""Renders the tile sprites of tiles.py, their depth map, the inventory icons of items.py and the
build-menu icons, with the harness's lib/art/render.py, which says how.

    blender -b --factory-startup --python-use-system-env -P art/models/render.py [-- tiles [INDEX ...]|icons ...]

Tiles go to tools/tiles as whole 128 x 256 cells, which tools/pack_textures.py trims and packs.
Icons go to tools/textures as Item_EnhancedIrrigation_<Item>.png, and the build-menu icons of
tiles.BUILD_ICONS as EnhancedIrrigation_Build_<Name>.png. The depth map goes to
common/media/depthmaps. Tile numbers after `tiles` render only those, over the files already
written, for working on a few.
"""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path[:0] = [HERE, os.path.join(REPO, "dev", "harness", "lib")]
import items  # noqa: E402
import tiles  # noqa: E402
from art import render  # noqa: E402
from sprites import TILESET  # noqa: E402

# The game finds a packed icon by its sprite name: Item_ and the item's name for an item's Icon,
# Build_ and a name for a build-menu icon, each carrying the mod's name to keep clear of other mods'.
ART = render.Art(media=os.path.join(REPO, "Contents/mods/EnhancedIrrigation/common/media"),
                 tile_dir=os.path.join(REPO, "tools/tiles"), icon_dir=os.path.join(REPO, "tools/textures"),
                 scratch=os.path.join(tempfile.gettempdir(), "enhanced-irrigation-render"), tilesets={TILESET: tiles.TILES},
                 items=items.ITEMS, build_icons=tiles.BUILD_ICONS, icon_prefix="Item_EnhancedIrrigation_",
                 build_icon_prefix="EnhancedIrrigation_Build_")

if __name__ == "__main__":
    render.main(ART)
