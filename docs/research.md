# Enhanced Irrigation: what the game gives us

Facts from Build 42.21.0 (`~/Zomboid/version.txt`), read from the vanilla Lua and scripts (`/tmp/pzmedia`, the game's `Java/media`) and the decompiled Java (`/tmp/pzsrc`; `../RenewableEnergy/DEVELOPMENT.md` shows how to make both). Each fact names its file so it can be checked again after an update. `[INFERENCE]` marks what was reasoned from code and not seen running; `[UNVERIFIED]` marks what lives in Java that didn't decompile (`zombie.globalObjects`, `PerkFactory`, `IsoFeedingTrough`, `ClimateManager`, `IsoPuddles`).

`docs/design.md` says what the mod does with these facts.

## Plants and water

**Who owns a plant.** The server. `lua/server/Farming/SFarmingSystem.lua` and `SPlantGlobalObject.lua` start with `if isClient() then return end`. Plants are global objects in the `farming` system (saved to `gos_farming.bin`), so they tick while their chunk is unloaded. Each plant's IsoObject carries a copy of its fields in modData, which `saveData()` transmits; clients read it through `CGlobalObject:updateFromIsoObject`.

**The tick.** `Events.EveryTenMinutes` → `SFarmingSystem:EveryTenMinutes` → `checkPlant2` for every plant: growth when due, `checkWater` (rain), `checkStat` (death), sprite, `saveData()`.

**The water level.** `waterLvl`, 0 to 100, clamped every ten minutes.
- Drain: `SPlantGlobalObject:lowerWaterLvl` takes 1 point (2 with weeds, plus `floor(fliesLvl/10)`) every `hourForWater` hours. `hourForWater` comes from sandbox `PlantResilience`: 12, 8, **5** (default), 3, 2. At default that is 4.8 points a day.
- Need: `waterNeeded`, from the crop's props (`farming_vegetableconf_vegetables.lua`, `_herbs.lua`): 30 to 80 by crop and stage.
- Bands: `farming_vegetableconf.calcWater` (conf.lua 130-148). At or above need: fine. Within need/1.10: grows late by the shortfall in hours. Within need/1.30: growth fails, retried in 30 h. Below that: fails, retried in 50 h, health −4.
- Health every 2 h (`changeHealth`): +0.4 watered, −0.2 / −0.5 short.
- Death: `checkStat`: a plant past its first growth dies at `waterLvl <= 0`.
- Sprite: `getSpriteName` uses `min(health, waterLvl)`, so a thirsty plant looks sick before it is.
- Health is never shown as a number to a player: `ISFarmingInfo` prints it only under `ISFarmingMenu.cheat`. The sprite turns sickly below 50 and dying below 25; each 10 above or below 50 adds or takes one from the harvest.

**No over-watering.** Every `waterLvlMax` line in the crop props is commented out, so `waterNeededMax` is nil and the over-water branch of `calcWater` returns 0. The hooks exist (`grow`, `changeHealth`) but can't fire. Topping a plant to 100 costs nothing.

**Rain.** `checkWater` (SFarmingSystem.lua 304-320): outdoors only (`exterior`), `+30 × getClimateManager():getPrecipitationIntensity()` per ten minutes, halved with weeds. Any shower fills a plant. Greenhouses and indoor plots get none.

**By hand.** `lua/shared/Farming/TimedActions/ISWaterPlantAction.lua`, offered by `ISFarmingMenu` and the interact key (`CFarming_Interact.lua`).
- One use is `ZomboidGlobals.farmingFluidContainerMillilitresPerUse` = 200 mL (`lua/shared/defines.lua:52`) and adds 10 points: **1 L = 50 points; empty to full is 2 L.**
- Any fluid container whose primary fluid is `Water` or `TaintedWater`. Plants ignore taint.
- One tile per action; time `20 + 6 × uses` ticks. Vanilla has no hose, sprinkler or radius watering.
- `Base.WateredCan` holds 8 L (`scripts/generated/items/normal.txt:13298`): four empty plants per fill.

**Disease.** Fields `mildewLvl`, `aphidLvl`, `fliesLvl`, `slugsLvl`, 0-100.
- Onset (`defaultDiseaseCheck`): chance `max(0, waterNeeded − waterLvl)` out of 200 on each growth, so thirst invites disease.
- Aphids, flies and slugs also need `season.currentTemp > 10`. `lua/server/Seasons/season.lua` is commented out and leaves `currentTemp` at −1, so in 42.21 **mildew is the only disease that starts on its own** `[INFERENCE]`.
- Mildew grows +0.5 per `hourForWater` (+1 when short of water). Effect (`calcDisease`): below 10 nothing, below 30 slows growth, below 60 stops it, 60 or more kills.
- Cure: `Base.GardeningSprayMilk` (10 uses), each use −(10 + Farming level) (`SPlantGlobalObject:cureMildew`).

**Agriculture (`Perks.Farming`).** XP only from harvest (`SFarmingSystem:gainXp`). Skill gates what the player can read (`ISFarmingInfo.lua`): the water text always; its colour against need at 3; the water bar at 4; the hover tooltip at 3 within 6 tiles (`CFarmingSystem`); disease at 3 with the magnifier bonus.

**Writing to a plant from a mod (server).**
- Find: `SFarmingSystem.instance:getLuaObjectAt(x, y, z)` / `:getLuaObjectOnSquare(sq)`; neighbours `SFarmingSystem.instance.system:getObjectsAdjacentTo(x, y, z)` then `finishedWithList`. Java: `square:getFarmingPlant()`.
- Guard: `plant:isAlive()` and `plant.state == "seeded"`.
- Water: `plant:water(nil, uses)` (+10 each, sets `lastWaterHour`, saves), or set `plant.waterLvl` / `plant.mildewLvl` and call `plant:saveData()`. Both are saved keys.
- From a client: `CFarmingSystem.instance:sendCommand(player, "water", { x, y, z, uses })`.
- Per plant, every ten minutes, `SFarmingSystem:checkWater(luaObject)` runs from `checkPlant2` (SFarmingSystem.lua 264-290); it is a class method, so it can be wrapped.

**Sharing a square with a plant.** A plant is a plain IsoObject added over the floor (`SPlantGlobalObject:addObject` 208-217). Plowing refuses only squares that aren't free (solid, solidtrans, tree, no floor), aren't dirt, or are above ground without the sandbox option (`ISFarmingMenu.canDigHereSquare` 456-466), so a non-solid pipe doesn't stop it. But plowing deletes every object whose tile has `canBeRemoved` or `vegitation` (`SFarmingSystem:removeTallGrass` 562-574), and those flags plus `canBeCut` count as weeds, which double a plant's water loss (588-630): a pipe tile must carry none of them.

**Wet ground.** No vanilla setter darkens one square: puddles are computed from the weather (`IsoGridSquare.getPuddlesInGround`, 596-605). `IsoObject:setOverlaySprite` and attached sprites are saved and sent to clients; `setCustomColor` is saved but not sent; `setAlpha` is client-only (`IsoObject.java` 4088, 4578-4632, 1770). Wet soil has to be the mod's own tile.

**Temperature and frost.** `getClimateManager():getAirTemperatureForSquare(square)` and `:getTemperature()` work from server Lua (Renewable Energy uses both). Vanilla water never freezes: nothing in `FluidContainer` or its update system does, and snow only halves rain. `season.currentTemp` is a dead value stuck at −1 that farming still reads (`season.lua` 10, 31-33).

**How often it freezes hard.** The climate model sampled hour by hour (`getClimateValuesCopy()`, `pollDate`, `getTemperature`) over 20 game winters in two worlds, base climate only (a weather period's extra cooling left out, so real counts run a little higher). Per winter: at or below 0 °C about 2200 h in multi-day snaps from November to March; at or below −7 °C about 580 h (378-879), about 60 nights of 9 h, December to early March; at or below −10 °C about 200 h. The coldest hour of a winter falls between −14 and −17 °C.

**Why pipes burst.** Not where the ice is: continued freezing behind an ice plug raises the pressure of the water trapped between it and a closed end, and the pipe splits there; an open outlet relieves it. Unsheltered pipes began to freeze when the outdoor air fell to about −7 °C (20 °F), and plumbers saw bursts start in the teens °F (ICC and University of Illinois Building Research Council, https://www.iccsafe.org/wp-content/uploads/DIS-FreezeBurstPipe.pdf). Drip suppliers still tell gardeners to drain lines for winter, fittings and thin-walled parts failing first (https://www.dripworks.com/blog/how-to-winterize-your-drip-irrigation-system). Saturated fired clay cracks as the water in its pores freezes.

**Walls between squares.** A wall's flags sit on the square whose north or west edge it stands on. The tile loader (`IsoWorld.java` 871-1030) gives `collideN`/`collideW` to `WallN`/`WallW` (and `NW`, `Trans`), `WindowN`/`WindowW` (window frames; glass adds `windowN`/`windowW`), `HoppableN`/`HoppableW` (low fences and low walls) and garage doors, which carry `WallN`; tall fences carry `WallN` with `TallHoppableN`. Door frames (`DoorWallN`/`DoorWallW`) get only `cutN`/`cutW`, and doors (`doorN`/`doorW`) no collide flag. `IsoGridSquare.isWallTo` is `collideN`/`W` on the shared edge unless the square has `windowN`/`W` (`IsoGridSquare.java` 724-830, 3076): it blocks fences and empty window frames and passes a glazed window. `RecalcProperties` (6146-6240) drops a square's `HoppableN`/`W` when anything non-hoppable collides on that edge, so "`collideN` and not `HoppableN`" is a solid edge. `getWall(north)` matches by `cutN`/`cutW`, door frames included.

**Removing a tile.** `square:transmitRemoveItemFromSquare(obj)` is `RemoveTileObject` in single player and `GameServer.RemoveItemFromMap` → `RemoveItemFromSquarePacket.removeItemFromMap` on a server; both fire `OnObjectAboutToBeRemoved` with the object still on its square, and throw if a handler removes it. The sledgehammer (`ISDestroyCursor` → `ISDestroyStuffAction:complete`) ends in `transmitRemoveItemFromSquare` on the authority, and its cursor offers any object without `vegitation`, a floor or a few vanilla sprites (`ISDestroyCursor:canDestroy`), a line tile included.

## Water stores

| Store | How code knows it | Litres | Rain |
| --- | --- | --- | --- |
| Rain collector crate (`RainCollector`, `_Tarp`) | entity + `FluidContainer`, `carpentry_02_54` / `_120` | 400 | RainFactor 0.4 |
| Rain barrel (`RainCollectorRound`, `_Tarp`) | `carpentry_02_122` / `_124`; lid → `…Closed` `_126` / `_127` | 600 | 0.25 open, none closed |
| Amphora / closed | `crafted_04_33/35`, `crafted_04_32/34` | 300 | 0.4 / none |
| Well | entity `Well` (`entities/appliances/workstations/entity_well.txt` 11-26): `FluidContainer` 10000 L, starts 20-100% full, RainFactor 0.1, `FillsWithCleanWater`; sprite `camping_01_16`, whose tile has `waterAmount = 999999` | clean; through the IsoObject API practically infinite, since `isWaterInfinite` checks tile `WATER_AMOUNT >= 9999` first `[INFERENCE]` | 0.1 |
| Feeding troughs | `IsoFeedingTrough`; defs in `lua/shared/FeedingTrough/Definitions/FeedingTroughDefinitions.lua` | 50-150 (`maxWater`, litres) | `[UNVERIFIED]` |
| Sinks, toilets, tubs | tile flag `waterPiped`; reserve in modData after shutoff | 20 / 20 / 100 | |
| Natural water | tile flags `water` / `taintedWater`, `waterAmount = 9999` | infinite, tainted | |
| `camping_01_64..67` | tile `waterAmount = 999999`, `CanAttachAnimal` | infinite, clean | `[UNVERIFIED]` what it looks like |

- Builds: crate Woodwork 3 (4 Plank, 4 Nails, 4 garbage bags or a Tarp, hammer); barrel Woodwork 5 (6 Plank, 5 Nails) (`scripts/generated/entities/outdoors/entity_raincollector.txt`).
- Barrels found on the map are swapped for empty entity barrels (`lua/server/Map/MapObjects/MORainCollectorBarrel.lua`).
- Troughs fill 1 L per animation tick (`ISAddWaterToTrough`, `SFeedingTroughGlobalObject:addWater`); water and feed exclude each other; 1 in 6 map troughs start with some TaintedWater (`MOFeedingTrough.lua:36-38`).
- No cistern, water tower, large tank or vehicle water tank exists. RE's solar sites call a pasture's "big metal water tank" a stock tank (`RenewableEnergy/.../World/SolarSiteLocations.lua:17`); what object it is: `[UNVERIFIED]`.
- **Rain** (`zombie/entity/components/fluids/FluidContainerUpdateSystem.java` 35-104, decompiled from the 42.21 jar):
  - It fills any `FluidContainer` with `RainFactor > 0` whose square is `exterior`, while it rains, on the server or in single player only. Clients get it through `sync()` at most once a second.
  - Rain comes in as **TaintedWater**; only a container with `FillsWithCleanWater` (the Well) gets Water.
  - Rate: `0.005 × precipitation intensity × RainFactor` litres per game second, halved for snow. At full intensity that is about 7 L an hour for a crate and 4.5 for a barrel `[INFERENCE: getGameSecondsPerTick not decompiled]`.
  - A rain catcher keeps simulating while its chunk is unloaded (`isQualifiesForMetaStorage`) `[INFERENCE]`.
  - `exterior` is false in a room or under anything that blocks rain (a solid floor or `BlockRain` tile on any level above; `IsoChunk.java` 2305-2318). Height doesn't matter, so a barrel on an open platform or roof fills.
  - A closed lid works by swapping to the `…Closed` entity, which has no RainFactor.
  - The dead Lua rain system (`SRainBarrelSystem.lua`, `isValidIsoObject` returns false) also added TaintedWater.
- **Raising an object.** `IsoObject.renderYOffset` is saved, applies in B42's depth rendering, and reaches clients only inside a full object transmit (`IsoObject.java` 272, 1361, 1530, 3255, 3604). Vanilla's lid action (`ISOpenCloseLid:complete` 33-60) replaces the barrel with a new object and copies only its fluid and health, so a raised offset and the barrel's modData are lost on every lid toggle.
- **Lids** come from the entity script's `ContextMenuConfig` (`menu = CloseLid`, `customFunction = ContextMenuCode.OpenCloseLid`, `extraParam = <other sprite>`). `ISOpenCloseLid` finds the other entity by adding or stripping "Closed" on the script name and builds it with `square:addWorkstationEntity(name, sprite)`.
- Picking up a barrel moves its `FluidContainer` onto the item (`GameEntityFactory.TransferComponents`), and is refused while it holds fluid (`ISMoveableSpriteProps.lua` 1214-1218, 1383); placing moves it back (2526-2541).

**Fluid API on world objects** (`zombie/iso/IsoObject.java` 2363-3055): `getFluidAmount`, `getFluidCapacity`, `useFluid(amt)`, `addFluid(FluidType, amt)`, `transferFluidTo/From`, `hasWater`, `isTaintedWater`, `getFluidContainer()`; container methods `getAmount`, `getFreeCapacity`, `addFluid`, `removeFluid`, `FluidContainer.Transfer(a, b, amt)`. Change only on the server (or single player) and then `obj:sync()`, which sends the container and fires `OnWaterAmountChange`. B41's `getWaterAmount` / `setWaterAmount` / `useWater` are gone.

**Plumbing, the nearest vanilla cousin** (`zombie/iso/IsoObject.java` 2363-3060).
- "Plumb" shows on a `waterPiped` fixture in a room with `FindExternalWaterSource() != null`, and needs a Pipe Wrench (tag `base:pipewrench`) (`ISWorldObjectContextMenuLogic.java` 454-461, 1077-1093). Java calls the Lua handler `ISWorldObjectContextMenu.onPlumbItem` (ISWorldObjectContextMenu.lua:1528) by name. `ISPlumbItem:complete` (31-41) sets `modData.canBeWaterPiped = false`, `setUsesExternalWaterSource(true)`, and sends `IsoObjectChange.USES_EXTERNAL_WATER_SOURCE`.
- The source: `FindExternalWaterSource` (2408-2429) looks one floor up only, at the square above and its 8 neighbours. `FindWaterSourceOnSquare` (2438) takes an `IsoThumpable`, not solid floor, not itself plumbed, `getFluidCapacity() > 0`. The field `externalWaterSource` has no setter and isn't saved; only the boolean is (flag bit 32, 1353/1523). Lua can't point a fixture anywhere else.
- **Plumbed water always comes out clean.** `createSampleAndPurifyWater` (2760-2771) copies the source's mix with every TaintedWater turned to Water, on every draw. `isTaintedWater` (2988-2997) returns false while the source has fluid.
- `isWaterInfinite()` (2525-2548), in order: tile `WATER_AMOUNT >= 9999` → true; no room → false; not `waterPiped` → false; plumbed → false; `isNoWater()` → false; past shutoff → false; else true unless `modData.canBeWaterPiped == true`.
- **The shutoff reserve** (`getReserveWaterAmount` 3015, `getReserveWaterMax` 3028, `setReserveWaterAmount` 3044): `modData.waterAmount` / `waterMaxAmount`, else the tile's. It has no taint key: every read reports Water.
- **A fixture with its own `FluidContainer` keeps taint.** Each fluid method checks, in order: plumbed, infinite, own container, reserve, puddle. With its own container, `useFluid` removes from it, `transferFluidTo` calls `fc.transferTo` (2820-2826, mixture preserved), and `isTaintedWater` is `fc.getAmount() > 0 && fc.isTainted()` (3002). Lua can add one: vanilla's `Commands.object.addWaterContainer` (`lua/server/ClientCommands.lua` 380-391) does `ComponentType.FluidContainer:CreateComponent()`, `setCapacity`, `addFluid`, `GameEntityFactory.AddComponent(obj, true, fc)`. Setting `modData.canBeWaterPiped = true` turns off the infinite and reserve routes, so the container is the only answer. The menu then comes from `doFluidContainerMenu` (`ISWorldObjectContextMenuLogic.java` 2885-2945), which offers drink, fill and wash only if `canPlayerEmpty()`. Save, reload and multiplayer sync were proven in game (Fixture buffers, run in game, below).
- **Player actions at a fixture are Lua**, reached by name from Java menus: drink and fill → `ISTakeWaterAction` (water moves only in `transferFluid`, 135-149, on the server); wash self → `ISWashYourself` (`getFluidAmount` / `useFluid`, 125-140); wash clothes → `ISWashClothing` (6, 172); bandages → `ISCleanBandage` (refused when `isTaintedWater()`, Lua 1893). Drinking sickness comes from `character:DrinkFluid` and TaintedWater's Poison block (Java, `[UNVERIFIED]`). Washers need `getFluidAmount() > 0` and power to start (Java 3385, 3430); how much they use is in `ClothingWasherLogic` `[UNVERIFIED]`.
- A building's fixtures: `sq:getBuilding():getDef():getRooms()` → RoomDef `getX/getY/getX2/getY2/getZ`, `getRects()`; iterate squares and test `obj:getSprite():getProperties():has(IsoFlagType.waterPiped)` (as `SpawnRateChecker.lua` 55-59 walks rooms).
- Vanilla's stove has a shut-off timer (`IsoStove.setTimer`, `IsoStove.java:371`; knob in `lua/client/ISUI/Fireplace/ISOvenUI.lua`), the closest vanilla precedent for a timed valve.

**Fixture buffers, run in game** (phase 1's probe, now `dev/.../EnhancedIrrigationTestsFixtures.lua`, passing in single player and `--mp`):
- A sink given a `FluidContainer` from server Lua, with `modData.canBeWaterPiped = true`, then `transmitModData()` and `sync()`, reaches every client: `syncIsoObjectSend` carries the container, and a client copy without one gets it added (`IsoObject.java` 1079-1113).
- On it, vanilla's menu offers Drink, with the tainted-water warning in its tooltip, Fill and Wash. Filling a bucket moves tainted water: the bucket is tainted and the sink goes down by what it took.
- An empty buffer gives nothing, and offers no Drink, in a room before the water shutoff. A plain sink beside it gives the town's water.
- The buffer survives its chunk unloading and loading again: from the save in single player, and from the server in multiplayer.
- Vanilla's Plumb under a rain collector of tainted water gives a sink that reports clean water.
- Converting a plumbed sink (`setUsesExternalWaterSource(false)`, `sendObjectChange(IsoObjectChange.USES_EXTERNAL_WATER_SOURCE, { value = false })`, then a buffer filled from the tank) reaches the clients.
- A conversion hook on `MapObjects.OnLoadWithSprite` catches a plumbed sink as its chunk loads in single player, done a tick later because the storey above may not be in the cell yet. A multiplayer server keeps a chunk loaded long after the character leaves, so there the hook runs only when the server first loads the chunk; that path wasn't run.

**What a buffer changes in the menu** (`ISWorldObjectContextMenuLogic.java`):
- An object with a `FluidContainer` gets the fluid container submenu (`doFluidContainerMenu`, 2885-2947), not the water-source one. It holds Fluid Info, and, only while `canPlayerEmpty()`, Transfer Fluids, Drink, Fill, Wash and Empty. So a player can pour anything into a buffer or empty it.
- The washing machine's on/off toggle lives only in the water-source path, which skips objects with a `FluidContainer` (959-993). A washer given a buffer would lose its switch from the menu `[INFERENCE]`.
- Vanilla's Plumb still shows on a buffered fixture under a barrel: the `canBeWaterPiped == true` branch (456) offers it.
- Both Plumb branches need `isInARoom()` (456, 459), and so does `isWaterInfinite`. Vanilla plumbing never works in a building without rooms.

**Fixture tiles.** The base game's `waterPiped` tiles, from `newtiledefinitions.tiles` and the other `.tiles` files in `Java/media`: `appliances_laundry_01_0..7` (washers, combo washer-dryers), `fixtures_bathroom_01_0..7` (toilets), `_24..27` (baths), `_32..33` (shower), and `fixtures_sinks_01_0..25, 28..35`. A conversion hook keyed on sprites misses fixtures from other mods' tiles.

**Making water clean in vanilla.**
- Boiling: tooltip "Sterilize in an oven or over a fire"; plastic only in a microwave. The conversion is Java `[UNVERIFIED]`.
- `craftRecipe PurifyWater` (`recipes_medical.txt` 168-189): one container + `Base.WaterPurificationTablets` (20 uses); code in Java `[UNVERIFIED]`.
- `Base.Bleach` (normal.txt:3546, 1 L; JanitorChemicals and under sinks): the fluid `Bleach` is Hazardous, poison Deadly from 0.2, dilute ratio 0.1 (`fluids.txt:179`). No vanilla recipe purifies water with it. TaintedWater: poison Medium, minAmount 1.0, dilute 0.2 (`fluids.txt:18`).
- **Taint is binary.** `FluidContainer.isTainted()` is true if any `FluidType.TaintedWater` instance is in the container, at any amount (decompiled `FluidContainer.java:679-687`). `PoisonInfo.getPoisonEffect(volume, ratio)` returns the fluid's `maxEffect` and ignores both arguments, so the `minAmount` and `diluteRatio` in `fluids.txt` do nothing (`zombie/entity/components/fluids/PoisonInfo.java`, decompiled from the 42.21 jar). Drinking a sip from 600 L with one bucket of tainted water in it gives TaintedWater's full Medium poison, and any trace of Bleach gives Deadly. The inventory poison icon alone uses a ratio: `contains(TaintedWater) and getPoisonRatio() > 0.1` (ISInventoryPane 2331).
- Real-world treatment, for grounding:
  - The US EPA's emergency advice is to boil for one minute, or add 8 drops of unscented household bleach per gallon and wait 30 minutes (https://www.epa.gov/ground-water-and-drinking-water/emergency-disinfection-drinking-water).
  - The CDC: pathogens die at 60 °C held for 30 minutes (https://www.cdc.gov/yellow-book/hcp/preparing-international-travelers/water-disinfection-for-travelers.html).
  - Slow sand filters clean through a biological layer (the schmutzdecke). They are run to waste until mature after building or scraping. They are cleaned by scraping off the top layer and a little sand (US EPA AWOP, https://www.epa.gov/system/files/documents/2024-04/water-quality-goals-and-slow-sand-filtration.pdf; Idaho DEQ slow sand guidance).

**Water shutoff.** Sandbox `WaterShut` / `WaterShutModifier` (default 14 days, `SandboxOptions.java` 80-83). After it: fixtures keep a small reserve; wells and `999999` tiles stay infinite and clean; natural water stays infinite and tainted.

## Items, skills and building

**Skills.** No Plumbing skill exists. `Perks.Farming` (shown "Agriculture"), `Woodwork`, `MetalWelding`, `Electricity`, `Mechanics`, `Pottery`, `Masonry`, `Blacksmith`, `Glassmaking`, `Carving`, `Tailoring`, `Maintenance`, `Husbandry`, `FlintKnapping`, `Butchering`, `Tracking` (from Lua and `xpAward` use; `PerkFactory` didn't decompile).

**Pipe and hose** (`scripts/generated/items/`):
- `Base.Pipe` "Plastic Pipe" 1.0 (normal.txt:3659), junk, no recipe uses it; `PlumbingSupplies`, trash foraging. Renewable Energy cuts propeller blades from it.
- `Base.MetalPipe` "Iron Pipe" 1.5 (weapon.txt:3805), `CrateMetalPipes`, scrapped from plumbing moveables; no recipe makes it.
- `Base.LeadPipe` 1.5 (weapon.txt:3394), `PlumbingSupplies`. Renewable Energy melts it for battery plates.
- `Base.ClayPipeSegmentUnfired` → `Base.ClayPipeSegment` 0.3 (normal.txt 9766-9784): pottery wheel (`MakeClayPipeSegment`, 1 Clay + 0.25 Water, Pottery XP 15) then kiln (`FireClayPipeSegment`). **Nothing uses it.**
- `Base.RubberHose` 0.3 (normal.txt:11180), tag `base:siphongas`, common.
- `Base.PipeWrench` (weapon.txt:4167), tag `base:pipewrench`.
- Also: `Base.TirePiece`, `Base.TirePump` (the only pump item, normal.txt:11808), `Base.Plunger`, `Base.Cork`, `Base.RubberBand`, `Base.LeatherStrips`, `Base.Screws`, `Base.SmallSheetMetal`, `Base.SheetMetal`, `Base.ClayJar` / `ClayJarGlazed` / `ClayPot`.

**Hole makers** (the vanilla "any drill" idiom is `tags[base:drillwood;base:drillmetal;base:drillwoodpoor]`, `recipes_carpentry.txt:308`):
- `Base.HandDrill` (normal.txt:11109): `drillwood;drillmetal;drillwoodpoor`. The only `drillmetal`.
- `Base.OldDrill` "Auger Drill" (11154): `drillwoodpoor`, ConditionMax 5, forged (`Forge_Drill`, Blacksmith 5).
- `Base.StoneDrill` (11265): `drillwoodpoor;crude`.
- `Base.Awl`, `Awl_Bone`, `Awl_Stone`: `base:awl`.
- `Base.BlowTorch` (drainable.txt:1562), no tag; welding needs `tags[base:weldingmask]`.
- Hammer + `Base.Nails`.

**Timers and power.**
- `Base.Timer` (kitchen, normal.txt:4225), `Base.TimerCrafted` (`MakeTimer`, Electricity 1, `recipes_traps.txt` 99-121), `Base.AlarmClock2` (`base:alarmclock`).
- `Base.CarBattery1/2/3` (drainable.txt 2336-2391), `base:carbattery`; Renewable Energy rates them 600 Wh. `Base.CarBatteryCharger`, `Base.ElectricWire`, `Base.ElectronicsScrap`.
- Powered square: `IsoGridSquare.haveElectricity()` (generator reach; false outdoors unless `AllowExteriorGenerator`, default on) (IsoGridSquare.java:8226); `hasGridPower()` (10153); `ItemContainer.isSquarePowered(sq, includeGenerators)` (2195) is the canonical check.
- No world object runs on a clock in vanilla.

**Not in vanilla:** sprinkler, garden hose, valve or tap item, water pump, solenoid, power drill, copper or PVC pipe, ladder you can climb, scaffold, water tower, filter. `ES_WaterGenerator` ("Water Pump") is an unused entity skin (`scripts/xui/defaultskin/x_entity_test.txt:10`).

**Pump-like and motor-like items, and what uses them.**
- `Base.TirePump` (normal.txt:11808): only inflating tyres (`ISVehiclePartMenu.onInflateTire`). Loot: CarSupplyTools, ToolStore, Gigamart, GarageTools, CrateTools.
- `Base.BlowerFan` (normal.txt:1924), 5 kg, tags `base:blowerfan;base:hasmetal`: **nothing uses it.** Rare in electronics, mechanic and blacksmith lists. The best vanilla stand-in for a motor.
- `Base.Bellows` (normal.txt:10094), "use on stone furnace"; `Base.LargeBellows` (moveable.txt:212, Woodwork 1) for Forge III / Furnace III. Air only.
- `Base.KnapsackSprayer` (clothing.txt:24538): 16 L back-slot tank; the `base:sprayer` tag is read by nothing but equip workarounds. Garden and farm lists.
- `Base.GardeningSprayEmpty`: the bottle the farm sprays are made in.
- No siphon, water gun, aquarium, fountain or water heater objects.

**Appliances with pumps and valves inside** (`newtiledefinitions.tiles.txt`):
- Washing machines `appliances_laundry_01_4..7` (`IsoClothingWasher`), combo washer/dryers `_0..3` (`IsoCombinationWasherDryer`): Material `Fridge` / `MetalScrap` / `Electric`, `waterPiped`, `PickUpTool = Electrician`, `PickUpLevel = 3`.
- Dishwashers `appliances_cooking_01_72..79`: Material `Fridge` / `Electric` / `MetalScrap`.

**Scrapping** (`lua/shared/Moveables/ISMoveableDefinitions.lua`, `ISMoveableSpriteProps.lua`):
- Outputs come from the sprite's `Material`, `Material2`, `Material3` (99-124). `getScrapItemsList` (3304) rolls each material's `returnItems` at `10 + perk*10 + baseChance` (3834). Tool, perk and time come from `Material` alone (3986, 4017).
- `Electric`: screwdriver, Electricity, ElectronicsScrap and ElectricWire. `Plumbing`: blowtorch, MetalPipe and CopperScrap. `Sink`: hammer, MetalPipe. `Pipes`, `Mechanical`, `Rubber`: defined with no returns.
- Per-sprite seam: `CustomTileProps_SetPair[<sprite>] = { Material3 = "<Mine>" }` (`lua/shared/Util/CustomTileProps.lua`, applied at OnGameStart and OnServerStarted), plus `addScrapDefinition` / `addScrapItem` for `<Mine>`. Every custom material must be registered, or `getChanceByDef` fails `[INFERENCE]`.

**Loot lists** (`lua/server/Items/ProceduralDistributions.lua`; rooms in `Distributions.lua`):
- `PlumbingSupplies` (37923): Pipe, LeadPipe, MetalPipe, PipeWrench, BlowTorch, Plunger. It is mixed into storage-unit lists, not a store room.
- `ToolStoreTools/Misc/Farming` (rooms `toolstore`, `toolstorestorage`): PipeWrench, TirePump, RubberHose.
- `GigamartTools/Farming`, `GardenStoreTools/Misc` (room `gardenstore`): WateredCan, GardeningSprayEmpty, KnapsackSprayer, seeds.
- `CrateTools`, `GarageTools`, `GarageMechanics`: hose, tire pump, pipe wrench, Blower Fan.
- `JanitorTools` / `JanitorChemicals`: plunger, hose, bleach.
- `CrateGravelBags`, the sandbag crate (17242), `CrateCharcoal`.
- `Base.Timer` spawns only in `KitchenRandom` (29712). `AlarmClock2` in bedrooms.

**Filter materials.**
- `Base.Charcoal` / `CharcoalCrafted` (`MakeWoodCharcoal`, 2 Log → 12): tag `base:charcoal`.
- `Sandbag`, `Gravelbag`, `Dirtbag` (drainable.txt 332-378, four uses each), filled with a shovel from the ground.
- `RippedSheets`, `CheeseCloth`, `RagFilter`.
- Model recipe: `MakeCraftedGasMaskFilter` (`recipes_gasmasks.txt` 96-118), with charcoal, sheets and a sponge.

**Building up** (`lua/server/BuildRecipeCode/buildRecipeCode.lua`, `lua/server/BuildingObjects/ISBuildIsoEntity.lua`).
- Stairs are the only way up: `Log_Stairs` (Woodwork 3), `Wood_Stairs` (Woodwork 6), `Metal_Stairs` (MetalWelding 5). Their `OnCreate` lays a landing floor at z+1 and stacks pillars under a floating top (219-336).
- Floors at z+1 (`WoodFloorLvl1` 1 Plank + 1 Nails) need only `connectedWithFloor` (an orthogonal neighbour with a floor). Nothing checks support from below; `WoodenPole` is cosmetic.
- A rain barrel builds on any `solidfloor` square, at any level, and rain fills it there if nothing above blocks rain (Water stores, Rain).
- A water collector can't be picked up while it holds fluid (`ISMoveableSpriteProps.lua` 1214-1217); empty, a rain barrel weighs 7.5.
- The item a picked-up barrel becomes is made as `Moveables.<tile>`, but `InventoryItemFactory.CreateItem` types it `Base.<tile>` (its module plus the tile's name), and `Moveable.load` does the same on reload. Code that looks for a carried barrel has to go by `Moveable:getWorldSprite()`, not by type.
- No vanilla entity spans z levels, though `SpriteConfig` and `ISBuildIsoEntity` support it. Renewable Energy's tallest build is one tile with a 4.3 m model (about 1.75 storeys): the scale ceiling.
- The B42 Metal Drum (`crafted_01_32`) holds no fluid; its old `IsWaterCollector` tiles are unused B41 leftovers.

**Recipes and build menu.**
- `craftRecipe` blocks (`scripts/generated/recipes/*.txt`): `timedAction`, `time`, `category`, `Tags`, `SkillRequired`, `xpAward`, `NeedToBeLearn`, `AutoLearnAny`, `OnCreate`, `OnAddToMenu`; inputs `item N [A;B]`, `tags[x] mode:keep flags[MayDegradeLight]`, `-fluid 0.25 categories[Water]`.
- Buildables are `entity` scripts with a `CraftRecipe` component (rain collector above); `SpriteConfig { OnCreate = … }` hooks creation (`lua/server/BuildRecipeCode/buildRecipeCode.lua`). Build placement: `lua/server/BuildingObjects/ISBuildIsoEntity.lua`, which sets `dragNilAfterPlace = true` (one object per placement) — a pipe run needs its own cursor.
- No vanilla cursor lays a run of tiles by dragging: holding the button rotates, and each click is one `tryBuild` (`ISBuildingObject:DoTileBuilding` 97-174). A cursor that leaves `dragNilAfterPlace` false stays up for the next click. The smallest custom cursor is `ISShovelGroundCursor` (`skipBuildAction`, its own `isValid`, `render` ghost, `create` queueing its own action).
- Renewable Energy's `DEVELOPMENT.md` lists the B42 script and translation traps; they apply here unchanged.
- Brick builds use `tags[base:masonstrowel] mode:keep`, `tags[base:concrete]` (buckets of clay cement or concrete) and `Base.ClayBrick` (`entities/walls/entity_brick_doorframelvl1.txt` 39-46).

**How recipes are learned.**
- **Literature:** `LearnedRecipes = A;B` on an item with `ItemType = base:literature`, `DisplayCategory = RecipeResource`, `OnCreate = ItemCodeOnCreate.onCreateRecipeMagazine`. For example `ElectronicsMag2` teaches `MakeTimer;AddTimerToBomb` (`items/literature.txt:5324-5336`).
- **Skill:** `AutoLearnAny = Perk:N` / `AutoLearnAll` on a craftRecipe. Vanilla applies it only to `craftRecipe` scripts: `ScriptManager.checkAutoLearn` (run on every level-up from `XpUpdate.levelPerk`, and at world load) walks `craftRecipes`, which never holds a build entity's CraftRecipe. No vanilla build uses it; a mod build's `AutoLearnAny` does nothing unless the mod calls `checkAutoLearnAnySkills` on it (`shared/EnhancedIrrigation/Recipes.lua`).
  - Multiplayer: the server awards XP (`addXp` → `GameServer.addXp` → `XP.AddXP`), so `LevelPerk` and the AutoLearn it runs fire on the server's copy of the character only. The client's copy gets the new level in `PlayerXpPacket` (`XP.load`, which fires `LogLevelPerk`, not `LevelPerk`), and `learnRecipe` sends nothing: the client's copy doesn't know the recipe until the server sends `sendSyncPlayerFields(player, 1)` (`SyncPlayerFieldsPacket.PF_Recipes`, add-only), as `ISResearchRecipe` does. World-load AutoLearn (`IsoWorld.init`, and `OnCreatePlayer`) runs on the client only; a server fires neither for a joining player.
  - No server event marks a player joining (the network classes trigger only `OnConnectFailed`, `OnServerStarted` and the like), so the mod's client asks the server, from `OnCreatePlayer`, to run the check on its own copy (`Recipes.catchUp`).
- **Knowledge without a craft:** a craftRecipe with no inputs or outputs, a tag no bench asks for, and a global `OnAddToMenu` that returns false is learnable by literature and AutoLearn but never listed or craftable (`CraftRecipe.requiresSpecificWorkstation`, `ISRecipeScrollingListBox` 344-348). `isRecipeActuallyKnown(name)` reads it. Plumb to Tank is gated so.
- **Research:**
  - An item lists `ResearchableRecipes = A;B` (parsed in `zombie/scripting/objects/Item.java`, decompiled from the 42.21 jar). Right-click → "Research Craft" runs `ISResearchRecipe` (`lua/shared/TimedActions/ISResearchRecipe.lua`), which learns every listed recipe the character qualifies for. The item is not consumed.
  - A recipe qualifies if it is `NeedToBeLearn` and not tagged `CannotBeResearched` (`CraftRecipe.canResearch`, `CraftRecipe.java` 1307-1345).
  - The skill needed is `ResearchSkillLevel` if set. Otherwise it is `max(1, round(2/3 × highest SkillRequired))`, checked against `ResearchAll` / `ResearchAny` perks or the required skills. The Inventive trait takes 2 off. A recipe with no skill requirement, or tagged `CanAlwaysBeResearched`, is always researchable (`CraftRecipe.java` 186-200, 1220-1240).
- **Professions and traits:** `GrantedRecipes` (`characters/character_professions.txt`).

**Scrapping a washer or dishwasher** goes by its first material, `Fridge`: Blow Torch, welding mask, MetalWelding, base chance 0, returning sheet metal, steel, screws and wire (`ISMoveableDefinitions.lua:436-442`). A pump or valve salvaged with a screwdriver needs its own action, not the scrap table.

## Kentucky, 1993

- University of Kentucky Extension IP-4, *Cisterns for Kentucky* (September 1990), https://publications.mgcafe.uky.edu/sites/publications.ca.uky.edu/files/ip4.htm: many rural families lived on cisterns. Its system is a roof washer that diverts the first rain, then a sand-and-gravel filter (replace the top 2 in when it clogs; limestone gravel neutralises acid rain), then chlorination. 27-68% of cisterns tested had coliforms. Metal cisterns were rare because they rust.
- Slow sand filtration: James Simpson, Chelsea Water Company, London, 1829.
- Household slow sand filters keep 5-6 cm of water standing on the sand so the living layer never dries; flow falls as dirt builds up, and users restore it by stirring or scraping the top of the sand, which sets the layer back for a while (CDC, *Household Water Treatment: Slow Sand Filtration*, https://stacks.cdc.gov/view/cdc/41390/cdc_41390_DS1.pdf). Plant operators scrape the top 1-2 cm or under half an inch (EPA AWOP, https://www.epa.gov/system/files/documents/2024-04/water-quality-goals-and-slow-sand-filtration.pdf).
- Ceramic pot filter: Fernando Mazariegos, ICAITI, Guatemala, 1981 (https://en.wikipedia.org/wiki/Ceramic_water_filter); little known in the US in 1993. Ceramic candle filters are 19th century.
- Biosand filter: David Manz, University of Calgary, early 1990s (https://en.wikipedia.org/wiki/BioSand_Filter); too new for a 1993 Kentuckian.
- Farm water towers: tanks on platforms 15-20 ft up, following the windmill, from the late 19th century. Head is 0.433 psi per foot, so a storey (about 2.45 m) gives about 3.5 psi.
- IBC totes: when they became common is `[UNVERIFIED]`. Steel drums are the safe 1993 choice.

## The B41 "WaterPipes" mod

Workshop 2464581798, `mods/WaterPipes fixed b41`. Does not run on B42: it needs the disabled Lua rain-barrel system, `setWaterAmount`, B41 `recipe` syntax and drainable pipes.

How it worked: one Iron Pipe + hammer + screwdriver made 10 pipes; pipes placed tile by tile (11 shapes); every ten minutes the server rebuilt an O(n²) graph of all pipes, found barrels, and every `hourForWater` hours each pipe watered the plant on its own square, by default topping it up to just over need ("SmartPipes").

Why it went flat: it watered exactly what each plant needed, exactly when; nothing wore, clogged, froze or leaked; nothing brought the player back but the barrel level.

## Renewable Energy, for a pump to draw on

- Every battery bank is an `IsoGenerator` switched on and off by the mod, so `square:haveElectricity()` is true in its reach (20 tiles, 3 levels).
- Its load is its own scan (`server/RenewableEnergy/PowerBank/Loads.lua`, `Loads.scan`), which counts only objects where `couldBePoweredByGenerator()` is true: a fridge, freezer or piped-fuel object. A plain IsoObject pump would run on bank power and never be billed; a vanilla generator wouldn't bill it either.
- No DC output and no consumer API. The seam: `Loads.scan` / `Loads.add(load, kind, watts)`; `StatusWindow.lua` already labels unknown kinds.
- Its 12 V precedents: the arrow board trailer (`server/RenewableEnergy/World/ArrowBoardPower.lua`) runs lamps off batteries in a vehicle part with a low-voltage cutoff; `PowerBank/Battery.lua` wears batteries by depth of discharge.
- Its pasture "stock tank" solar sites have panels and no pump; a farm stash house "ran its well pump" off solar.
