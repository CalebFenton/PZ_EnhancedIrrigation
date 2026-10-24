#!/usr/bin/env bash
# Starts the game client with this mod, its dev mod and the harness mod; dev/harness/docs/running.md
# lists the flags and environment variables. Its scenarios, under the main menu's Scenarios:
# Enhanced Irrigation, a test world, and Enhanced Irrigation QA, a farm with everything of the mod
# laid out. --art lays out the art on an open lot and saves screenshots. Tests are named irrigation_*.
. "$(dirname "$0")/harness/bin/run-client.sh"
