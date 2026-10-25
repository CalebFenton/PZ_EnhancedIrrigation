#!/usr/bin/env bash
# Rebuilds every tile and icon of the mod with Blender (made with 5.2), on the harness's art library
# (dev/harness/docs/art.md): renders, draws the mod list icon (mod_icon.py, with Pillow; the poster
# and the Workshop preview.png are in-game shots that art/promo/compose.py lays out), writes the
# tile definitions, packs, then renders the review sheets.
# BLENDER overrides the Blender binary. To work on a few tiles, render only those, then pack:
#
#   blender -b --factory-startup --python-use-system-env -P render.py -- tiles 129 130
#
# A rebuild from unchanged sources writes the same bytes, so git shows only what a change touched;
# the art library's docs say how.
set -euo pipefail
cd "$(dirname "$0")"
. ../../dev/harness/lib/blender.sh
blender render.py
./mod_icon.py
python3 ../../tools/make_tiles.py
../../tools/pack_textures.py
blender preview.py
