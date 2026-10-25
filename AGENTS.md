# Enhanced Irrigation

## Commands

- After every change: `dev/static-check.sh`, which compiles every Lua file with the game's compiler and cross-checks scripts, translations, textures and API names in seconds. After a change to `Contents/`, also `dev/validate-server.sh`.
- Each in-game test run pays for a game start, so batch: commit each logical change on its own, then run `dev/run-debug-client.sh --test --changed` once per batch, not after each edit, and don't follow it with the server check and both suites by habit. To rerun the same tests while fixing them, `--test --stay` keeps the game open. Before pushing or merging: `dev/run-debug-client.sh --test`. Before a release, also `dev/run-debug-client.sh --test --mp`.
- When agents work in parallel, they don't run the game; whoever merges their work runs the batch.
- A test that takes over half a second is waiting on something it could skip: read each run's `timing:` and `SLOWEST` lines.
- After `art/models/make.sh`, run `dev/run-debug-client.sh --art` and look at every screenshot it saves; the run prints the folder.
- After a change to what the Workshop images show, reshoot with `dev/run-debug-client.sh --promo` (`PROMO=<group>,...` for some groups), then lay them out with `art/promo/compose.py`. Look at every capture, and at each image at the size Steam shows it.

## Rules

- Check Build 42 APIs against the installed game's Lua, scripts and decompiled Java, not web docs or memory: most published modding docs describe Build 41, whose APIs fail silently in Build 42. `docs/research.md` holds the vanilla facts already found, with their files.
- Test in the game, in the dev mod's `EnhancedIrrigationTests*.lua` with server handlers in `EnhancedIrrigationTestServer*.lua`, never with standalone Lua and stubbed game APIs: the stubs encode guesses about the game, which is what the tests must check.
- A test checks what a player gets (plant water, soak, litres, items, tooltips, sprites on both sides) through the real verb, with expectations computed from the mod's constants. Don't test values a script file states, wiring or forwarding.
- A test never waits out real time. Raise the clock speed (`T.setMultiplier`) for game time, run the mod's sums for set hours on the server (`lines.flow`, `lines.age`), date a timestamp back rather than waiting past it (`lines.lapseHold`), and shorten a real-time cadence from a server handler that puts it back when the test ends (`water.runEvery`). Set a chance's roll (`lines.pinRoll`) rather than rolling many times.
- Comments say why, without repeating values from the code: a copied value goes stale and nothing fails.
- Code another of Caleb's mods could use goes in the library mod cf_commonlib (`../cf_commonlib`), never in a copy here: look there before writing a helper, and change it there when a change here touches what it does.
- When a change alters how a mechanic plays or where something spawns, update `docs/player-guide.md` in the same commit: exact figures where players plan around them (costs, reach, times, levels), rounded ones for rates, and what kind of place has a thing and how rare it is rather than every list it spawns in.
- When a change has something only a person playing can check (how it sounds, whether zombies come, how the work feels, how the art reads, a vanilla path no test drives), add it to `docs/playtest.md` in the same commit, saying how to set it up and what passes, and name those entries in your report rather than calling the change done untested.
- When a test or check contradicts what you were asked to do, or fails on uncommitted work that isn't yours, stop and report it rather than editing the test or the other person's work.

## STOP

- Hand edits to generated files: the next run overwrites them. Edit the builders under `art/models` and `art/promo/compose.py`, never the models, textures, tiles or images they write.

## Read when needed

- Before running in-game tests, handing them to subagents, or debugging a failure or a `LEAK`, read `dev/harness/docs/debugging.md`: which run answers which question, and the traps that cost reruns.
- Before changing scripts, translations, multiplayer sync, loot or tests, read `../RenewableEnergy/DEVELOPMENT.md`: the Build 42 behaviour that fails silently, and the command to decompile the game.
- Before changing anything under `dev/harness`, read `dev/harness/AGENTS.md`; before changing anything in `../cf_commonlib`, read its `AGENTS.md`. Other mods use both.
- Before changing `README.md`, the Workshop page, read `dev/harness/docs/workshop-page.md`.
- Before designing or balancing a feature, read `docs/design.md`: what the mod adds, the build order, and the principles every cost, payoff and repair is weighed against.
