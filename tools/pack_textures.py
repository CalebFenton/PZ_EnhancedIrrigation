#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow==12.3.0"]
# ///
"""Builds the mod's texture pack, common/media/texturepacks/enhanced_irrigation.pack, with the
harness's lib/art/pack.py, which says how.

    tools/pack_textures.py

It packs every PNG in tools/tiles (the tile sprites) and tools/textures (the item and build-menu
icons). It needs uv (https://docs.astral.sh/uv/), which brings Pillow.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "dev", "harness", "lib"))
from art.pack import pack  # noqa: E402

PACK_FILE = os.path.join(HERE, "..", "Contents", "mods", "EnhancedIrrigation", "common", "media",
                         "texturepacks", "enhanced_irrigation.pack")
PAGE_NAME = "enhanced_irrigation0"

if __name__ == "__main__":
    pack(PACK_FILE, PAGE_NAME, os.path.join(HERE, "tiles"), os.path.join(HERE, "textures"))
