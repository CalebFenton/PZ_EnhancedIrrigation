#!/usr/bin/env bash
# Rebuilds every tile and icon of the mod with Blender (made with 5.2), the conventions of Renewable
# Energy's art/models: renders, draws the mod list icon (mod_icon.py, with Pillow; the poster and
# the Workshop preview.png are in-game shots that art/promo/compose.py lays out), writes the tile
# definitions, packs, then renders the review sheets.
# BLENDER overrides the Blender binary. To work on a few tiles, render only those, then pack:
#
#   blender -b --factory-startup --python-use-system-env -P render.py -- tiles 129 130
#
# A rebuild from unchanged sources writes the same bytes, so git shows only what a change touched:
# - A render saves the date and Cycles' timings into its PNG, so render.py saves the tile sprites
#   from the rendered pixels, as it does the icons.
# - Python salts hash() per process unless PYTHONHASHSEED fixes it, which Blender reads only with
#   --python-use-system-env; nothing here should depend on it, and fixing it keeps that so.
# - Two builds of Pillow can compress the same pixels to different bytes, so mod_icon.py and
#   tools/pack_textures.py pin the version uv installs.
set -euo pipefail
cd "$(dirname "$0")"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
export PYTHONHASHSEED=0
blender() { "$BLENDER" -b --factory-startup --python-use-system-env -P "$1"; }
blender render.py
./mod_icon.py
python3 ../../tools/make_tiles.py
../../tools/pack_textures.py
blender preview.py
