#!/usr/bin/env bash
# Starts the game client in debug mode (no Steam) with its own cache dir, this mod, its dev mod
# dev/EnhancedIrrigationDevHarness and the shared harness mod (dev/harness, see its README.md).
#
#   dev/run-debug-client.sh          play by hand: main menu > Scenarios > Enhanced Irrigation
#                                    starts a test world, and Debug menu > Dev > Unit Tests >
#                                    Timed Actions runs the irrigation_* tests
#   dev/run-debug-client.sh --test   starts the scenario, runs every irrigation_* test and quits
#                                    the game. Runs unattended. Prints the results and exits 1 if
#                                    a test failed or any Lua error was logged.
#   dev/run-debug-client.sh --test --stay
#                                    the same, but the game stays open after the run, and the next
#                                    --test --stay reruns the tests in it, after reloading the
#                                    test files, instead of starting the game again
#   dev/run-debug-client.sh --test --mp [--stay]
#                                    the same tests in multiplayer: a dedicated server and a client
#                                    that joins it as the admin (dev/harness/docs/multiplayer.md)
#
# CACHE overrides the cache dir (default: $TMPDIR/pz-irrigation-client, -mpclient with --mp),
# TIMEOUT the seconds a run may take (default 300), and TESTS, a comma-separated list of test
# name prefixes, limits --test to those tests (e.g. TESTS=irrigation_probe_).
. "$(dirname "$0")/harness/bin/run-client.sh"
