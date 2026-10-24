#!/usr/bin/env bash
# Rebuilds every tile and icon of the mod with Blender (made with 5.2), from the parts in items.py
# and the tile layout in tiles.py, the conventions of Renewable Energy's art/models:
#
#   render.py    tile sprites (tools/tiles), their depth map (common/media/depthmaps), the
#                32 x 32 item icons and the 48 x 48 build-menu icons (tools/textures)
#   tools/make_tiles.py and tools/pack_textures.py   enhanced_irrigation.tiles, tileGeometry.txt
#                and the pack
#   preview.py   review sheets of all of it, read back from the written files: every tile, a garden
#                of each pipe laid out as the game draws neighbouring tiles, the stand and barrels
#                beside the game's own rain barrel, and the icons
#
# Tile numbers live in sprites.py, which media/lua/shared/EnhancedIrrigation/Sprites.lua must match.
# To work on a few tiles, render only those, then pack:
#
#   blender -b --factory-startup --python-use-system-env -P render.py -- tiles 129 130
#
# BLENDER overrides the Blender binary, PREVIEWS the preview folder (default
# $TMPDIR/enhanced-irrigation-previews), PZ_MEDIA the game's media folder the preview reads its
# rain barrel from. tools/pack_textures.py runs with uv (https://docs.astral.sh/uv/), which brings
# its Pillow.
#
# A rebuild from unchanged sources writes the same bytes, so git shows only what a change touched:
# - A render saves the date and Cycles' timings into its PNG, so render.py saves the tile sprites
#   from the rendered pixels, as it does the icons.
# - Python salts hash() per process unless PYTHONHASHSEED fixes it, which Blender reads only with
#   --python-use-system-env; nothing here should depend on it, and fixing it keeps that so.
# - Two builds of Pillow can compress the same pixels to different bytes, so
#   tools/pack_textures.py pins the version uv installs.
set -euo pipefail
cd "$(dirname "$0")"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
export PYTHONHASHSEED=0
blender() { "$BLENDER" -b --factory-startup --python-use-system-env -P "$1"; }
blender render.py
python3 ../../tools/make_tiles.py
../../tools/pack_textures.py
blender preview.py
