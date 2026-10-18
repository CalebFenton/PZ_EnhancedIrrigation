# Enhanced Irrigation

## Commands

- After every change: `dev/static-check.sh`. It compiles every Lua file with the game's compiler and cross-checks scripts, translations, textures and API names in seconds. After a change to `Contents/`, also run `dev/validate-server.sh`.
- While you iterate: `dev/run-debug-client.sh --test --changed --stay`, or `TESTS=<name prefix>` instead of `--changed`, adding `--mp` when the change touches what the server does or sends. Before committing: `dev/run-debug-client.sh --test` and `dev/run-debug-client.sh --test --mp`.
- After a change to the art (`art/models`, then `art/models/make.sh`): `dev/run-debug-client.sh --art` lays every pipe material dry and wet, a tap, crops on pipes, a line along a wall and the stands beside vanilla's rain barrel on an open lot, and saves screenshots to the cache's `Screenshots` folder, which the run prints. Look at them.
- To play the mod through by hand: `dev/run-debug-client.sh`, then main menu > Scenarios > **Enhanced Irrigation QA**. Between a farmhouse and its field, a character in god mode and invisible, who carries anything, has every skill and recipe of the mod and carries an empty rain barrel, finds beds of growing crops (some dry, some just watered) beside a raised barrel, a barrel on a deck a storey up and one on the ground, all full; an empty Tank Stand, an empty barrel and two barrels to plumb together; and on the ground, a row to each group: pipe of every kind and the joints for a 24-tile line of each, the pipe wrench and every hole tool, the Tank Stand's materials, the pamphlet and a watering can. It prints what it laid out, and anything it couldn't, under `EIQA` in `console.txt`.

## Rules

- Check Build 42 APIs against the installed game's Lua, scripts, and decompiled Java, not web docs or memory. Most published modding docs describe Build 41, and their APIs fail silently in Build 42. `docs/research.md` holds the vanilla facts already found, with their files.
- Add in-game tests to the dev mod's `dev/EnhancedIrrigationDevHarness/42/media/lua/client/EnhancedIrrigation/Debug/EnhancedIrrigationTests*.lua`, with their server handlers in `.../server/EnhancedIrrigation/Debug/EnhancedIrrigationTestServer*.lua`. Debug and test code stays out of `Contents/`, which is published. Don't write standalone Lua tests with stubbed game APIs; the stubs encode guesses about the game, which is what the tests must check.
- A test checks what a player gets (plant water, soak, litres, items, tooltips, sprites on both sides) through the real verb, with expectations computed from the mod's constants. Don't test values a script file states, wiring or forwarding.
- Give a new file under `Contents/` or the dev mod a `TEST_MAP` line in `dev/harness.conf` naming the tests that reach its code; without one, `--changed` runs every test.
- Comments say why, without repeating values from the code.
- `shared/EnhancedIrrigation/GlobalObjects.lua`, `client/EnhancedIrrigation/ClientObjects.lua` and `client/EnhancedIrrigation/UI/Needs.lua` are copies of Renewable Energy's; change both mods or neither.
- Don't add `CLAUDE.md` files; the `AGENTS.md` files hold the agent instructions.

## Read when needed

- Before designing or balancing a feature, read `docs/design.md`: what the mod adds, the build order, and the principles every cost, payoff and repair is weighed against.
- Before running in-game tests, handing them to subagents, or debugging a failure or a `LEAK`, read `dev/harness/docs/debugging.md`: which run answers which question, and the traps that cost reruns.
- Before changing anything under `dev/harness`, read `dev/harness/AGENTS.md`: other mods share it.
- Before changing scripts, translations, multiplayer sync, loot or tests, read `../RenewableEnergy/DEVELOPMENT.md` for the Build 42 behavior that fails silently and the command to decompile the game.
