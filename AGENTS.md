# Enhanced Irrigation

## Commands

- After every change: `dev/static-check.sh`. It compiles every Lua file with the game's compiler and cross-checks scripts, translations, textures and API names in seconds. After a change to `Contents/`, also run `dev/validate-server.sh`.
- In-game tests cost about 20 seconds a run in single player and 45 in multiplayer before any test starts, so batch them: make a batch of changes, committing each logical change on its own, then run `dev/run-debug-client.sh --test --changed` once (or `TESTS=<name prefix>`). Don't run the game after each edit, and don't follow one run with the server check and both suites by habit. To rerun the same tests while fixing them, use `--test --stay`, which keeps the game open and skips the start. Before pushing or merging a batch: `dev/run-debug-client.sh --test`. Before a release, also `dev/run-debug-client.sh --test --mp`; not between batches. A failed test's `suspects` line names the batch's files that reach it and their commits; rerun that test (`TESTS==<name>`) at those commits to find the one that broke it.
- Know what each run cost: read its `timing:` and `SLOWEST` lines. The full single-player suite runs its tests in under 20 seconds; a test over half a second is waiting on something it could skip.
- When agents work in parallel, they don't run the game; whoever merges their work runs the batch.
- After a change to the art (`art/models`, then `art/models/make.sh`): `dev/run-debug-client.sh --art` lays every pipe material dry and wet, a tap, crops on pipes, a line along a wall and the stands beside vanilla's rain barrel on an open lot, and saves screenshots to the cache's `Screenshots` folder, which the run prints. Look at them.
- To play the mod through by hand: `dev/run-debug-client.sh`, then main menu > Scenarios > **Enhanced Irrigation QA**. Between a farmhouse and its field, a character in god mode and invisible, who carries anything, has every skill and recipe of the mod and carries an empty rain barrel, finds beds of growing crops (some dry, some just watered) beside a raised barrel, a barrel on a deck a storey up, up Log Stairs, and one on the ground, all full; an empty Tank Stand, an empty barrel and two barrels to plumb together; and on the ground, a row to each group: pipe of every kind and the joints for a 24-tile line of each, the pipe wrench and every hole tool, the Tank Stand's materials, the pamphlet and a watering can. It prints what it laid out, and anything it couldn't, under `EIQA` in `console.txt`.

## Rules

- Check Build 42 APIs against the installed game's Lua, scripts, and decompiled Java, not web docs or memory. Most published modding docs describe Build 41, and their APIs fail silently in Build 42. `docs/research.md` holds the vanilla facts already found, with their files.
- Add in-game tests to the dev mod's `dev/EnhancedIrrigationDevHarness/42/media/lua/client/EnhancedIrrigation/Debug/EnhancedIrrigationTests*.lua`, with their server handlers in `.../server/EnhancedIrrigation/Debug/EnhancedIrrigationTestServer*.lua`. Debug and test code stays out of `Contents/`, which is published. Don't write standalone Lua tests with stubbed game APIs; the stubs encode guesses about the game, which is what the tests must check.
- A test checks what a player gets (plant water, soak, litres, items, tooltips, sprites on both sides) through the real verb, with expectations computed from the mod's constants. Don't test values a script file states, wiring or forwarding.
- A test never waits out real time. Raise the clock speed (`T.setMultiplier`) for game time, run the mod's sums for set hours on the server (`lines.flow`, `lines.age`), date a timestamp back rather than waiting past it (`lines.lapseHold`), and shorten a real-time cadence from a server handler that puts it back when the test ends (`water.runEvery`). Set a chance's roll (`lines.pinRoll`) rather than rolling many times.
- Give a new file under `Contents/` or the dev mod a `TEST_MAP` line in `dev/harness.conf` naming the tests that reach its code; without one, `--changed` runs every test.
- Comments say why, without repeating values from the code.
- When a change alters how a mechanic plays or where something spawns, update `docs/player-guide.md` in the same commit. It gives exact figures where players plan around them (costs, reach, times, levels) and rounded ones for rates. It leaves recipes' ingredients to the build menu and the crafting window, and says what kind of place has a thing and how rare it is, never every list it spawns in.
- `README.md` is the Workshop page: after changing it, run `dev/workshop-txt.sh`, which writes `workshop.txt`'s description from it; the static check fails while the two differ.
- When a change has something only a person playing can check (how it sounds, whether zombies come, how the work feels, how the art reads, a vanilla path no test drives), add it to `docs/playtest.md` in the same commit, saying how to set it up and what passes. Name those entries in your report rather than calling the change done untested.
- `shared/EnhancedIrrigation/GlobalObjects.lua`, `client/EnhancedIrrigation/ClientObjects.lua` and `client/EnhancedIrrigation/UI/Needs.lua` are copies of Renewable Energy's; change both mods or neither.
- Don't add `CLAUDE.md` files; the `AGENTS.md` files hold the agent instructions.

## Read when needed

- Before designing or balancing a feature, read `docs/design.md`: what the mod adds, the build order, and the principles every cost, payoff and repair is weighed against.
- Before changing `README.md`, read `dev/harness/docs/workshop-page.md`.
- Before running in-game tests, handing them to subagents, or debugging a failure or a `LEAK`, read `dev/harness/docs/debugging.md`: which run answers which question, and the traps that cost reruns.
- Before changing anything under `dev/harness`, read `dev/harness/AGENTS.md`: other mods share it.
- Before changing scripts, translations, multiplayer sync, loot or tests, read `../RenewableEnergy/DEVELOPMENT.md` for the Build 42 behavior that fails silently and the command to decompile the game.
