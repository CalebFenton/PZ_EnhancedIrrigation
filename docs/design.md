# Enhanced Irrigation: design

Mod id `cf_enhanced_irrigation`. Its pamphlet, *Cisterns for Kentucky*, teaches most of what's here. The pamphlet is named after the University of Kentucky's 1990 extension leaflet that described rural water supply in the years this game is set. This file says why the mod is shaped the way it is, what it adds, and how it sits on the game and on Renewable Energy. `docs/research.md` holds the vanilla facts it leans on, with their files. Numbers are starting points; once there is code they move into it and this file keeps the reasons.

## The kernel

The game opens with "This is how you died." You are alone, fighting back against entropy and against hordes of monsters that used to be people: depression, the elements, sickness, starvation, zombification. It's bleak, but if you're strong enough you can run into the woods and hold out, if you're committed, determined, resourceful and resilient.

Two or three weeks in, the taps run dry. A month or two in, you're planting. Water becomes something you carry, bucket by bucket, to a garden and to a sink. This mod lets a survivor build their way back to running water: a barrel up high, pipe down to the beds and the sinks, a pump to fill it, a filter or a fire to make it safe. Every part is scavenged or improvised, every part wears, and none of it is smart. Water runs downhill, a pump runs while it's on, and a filter only works while you keep it alive. The player is the only part of the system that knows anything.

## What vanilla gives us

- **Garden water is a chore of clicks, not litres.** 200 mL adds 10 points, so 2 L fills an empty plant. A plant loses about 5 points a day, so a full one lasts four to six days. The grind is fifty plants, a can that fills four, and the walk to the barrel. Rain fills every outdoor plant. Greenhouses get none.
- **You can't over-water.** The crop props carry `waterLvlMax` lines, all commented out. Mildew is the only disease that starts on its own in 42.21, and the milk spray already cures it.
- **Plumbing is one narrow trick.** "Plumb" a sink with a pipe wrench and it draws from a barrel on the floor directly above it (3×3, one level up, nowhere else). The water comes out **clean**: the engine purifies everything drawn through a plumbed fixture. A barrel on the roof is a permanent, free water purifier.
- **Shutoff leaves fixtures a small clean reserve** (sink 20 L, bath 100 L), then nothing.
- **Taint is all or nothing.** A container is tainted if it holds any Tainted Water at all (`FluidContainer.isTainted`). The poison it gives doesn't shrink with dilution (`PoisonInfo.getPoisonEffect` ignores both volume and ratio). One bucket of river water in a clean 600 L tank taints all 600 L.
- **"Houses" are only the map's buildings.** Map houses have a building and rooms (`getBuilding()`, `RoomDef`). A cabin the player builds in the woods may have neither `[UNVERIFIED]`. Anything tied to "the house" would fail exactly where late-game survivors live. So this mod connects fixtures one at a time, never by building.
- **No pumps, valves, sprinklers or filters exist.** The parts that could become them do: a Blower Fan (an electric motor) that no recipe uses; washing machines and dishwashers in every house, each with a pump and a water valve inside; Plastic Pipe no recipe takes; Clay Pipe Segments with nowhere to go; sand, gravel and charcoal in bags and crates; Metal Drums that already sit over fires as charcoal burners; kitchen timers and alarm clocks.
- **Building up is already possible.** Stairs lay a floor at the top, floors spread sideways, and a rain barrel can be built on any floor.
- **Three ways to learn a recipe, all vanilla.**
  - A magazine or pamphlet teaches it (`LearnedRecipes`).
  - A skill level teaches it (`AutoLearnAny`).
  - Researching an item teaches it: right-click the item, and it isn't consumed (`ResearchableRecipes` on the item). Research needs the recipe's skill at about two-thirds of what the recipe requires (`round(2/3 × SkillRequired)`, at least 1), and the Inventive trait lowers that by 2.
- **Kentucky had exactly this problem.** *Cisterns for Kentucky* (1990) describes the rural water supply of the time: a roof washer, a sand-and-gravel filter whose top two inches you replace when it clogs, then disinfection. Between a quarter and two thirds of the cisterns tested carried coliform bacteria.

## What follows from it

**Water runs downhill, and it needs a storey to push.** Anything that sprays, drips or comes out of a tap needs its tank a full storey above it, and a higher tank pushes harder. Anything that just fills (a filter, a boiler, another tank) needs its source no lower than itself. Only a pump drives a sprinkler. The rule fits in one tooltip line, and it makes height the thing worth building.

**Every watering is something the player does, or something they set up to do it for them.** Nothing stays on until you remember it. You hold a valve open in a timed action and watch the beds darken, the way you chop. A wind-up valve shuts itself after the minutes you give it, like the oven's timer. An alarm clock wired to a salvaged water valve opens it every morning, if it has power. Each step up buys back time and costs parts, skill and power.

**Too much water costs something you can see.** Water the mod delivers to a full plant soaks the soil, and waterlogged soil rots the roots. Rain alone never soaks, so vanilla play is unchanged. A timer that runs through a wet week rots a bed.

**What you see is the world, not a panel.** Wet soil darkens under the pipe. Running water sounds while a valve is open. Plants show thirst and sickness in vanilla's sprites and info window, at vanilla's Agriculture levels. Tanks, filter outlets and fixtures show litres and "Tainted" the way vanilla already does. There is no network screen.

**Clean water costs something, and stays clean only if you keep it apart.** Water through this mod's pipes keeps whatever taint it had. Cleaning is slow, or burns fuel, so survivors run two tanks: a big raw one for the garden, the animals and the toilet, and a small clean one, filled only through a filter or a boiler, for the kitchen. One careless bucket taints the clean tank, and it has to be emptied.

**Reuse beats invention.** A new item has to earn its place: it's something 1993 had, nothing vanilla stands in for, and it has more than one use. Everything else is a new job for something already in the world.

**Entropy is the opponent** (Renewable Energy's rule, unchanged). Full pipes crack in a freeze. Pump seals wear. Electric pumps run dry and burn out. A sand filter's living layer dies if it dries out. A boiler run dry scorches. Each repair restores a little less, the way vanilla repairs do, until the part is remade. Wear is something the player can see and reason about (a crack, a frost, a dry filter), never a hidden percentage.

**Risk buys reward.** The clean water is on someone else's farm (a well) or in the open (a river bank). Pumps and sprinkler timers sit in hardware stores in town. A generator to run a pump is loud. Hand-pumping is sweat and squeal.

**Commitment is the price of the big payoffs.** A barrel and a short line move with you. A tank stand, a pump on a well and a plumbed kitchen tie you to that place.

**Feel like the base game.** A pipe wrench fits things to water, as in vanilla plumbing. Timed actions with endurance cost, as in chopping. A timer knob like the oven's. A boiler fuelled and lit like a vanilla fire. Vanilla's exchange rate of water to plants, its plant health, its all-or-nothing taint, its "Tainted" tooltip and Empty action. Build in the build menu. Learn from a pamphlet, a skill level, or research, the three ways vanilla teaches.

**Grounded in 1993 Kentucky.** Cisterns, rain barrels, slow sand filters, sump and utility pumps, oscillating lawn sprinklers and plug-in sprinkler timers were all on sale or in the extension leaflets that year. Rain sensors, moisture sensors and float switches existed too. They are left out on purpose: the system stays dumb.

## The mechanics

### Tanks and height

- **A tank** is any fixed store that holds water in a vanilla fluid container above ground: a rain barrel or collector, an amphora, or a barrel on a Tank Stand. A well's water stands underground, so only a pump draws on it. Feeding troughs keep their water in their own system rather than a fluid container, so they aren't tanks yet; the trough float valve under "Later" is where they join.
- **A tank's level** is the floor it stands on (z), plus one if it's on a Tank Stand.
- **Two rules decide every flow:**
  - **Pressure (taps, holes, sprinklers, fixtures):** the tank's level must be at least one above the outlet's floor. A barrel on the ground waters nothing by gravity. A barrel on a stand, a platform or an upstairs floor waters the ground floor.
  - **Filling (into a filter, a boiler, another tank):** the source's level must be at least the receiver's level. Water trickles in; it doesn't need to push.
- **Pumps** ignore both rules and lift water from a source up to their rated number of storeys.
- **Joined tanks:** barrels on the same level linked with "Plumb to Tank" share their water and act as one tank. A platform of barrels becomes a cistern.
- Tanks fill from rain (open barrels), buckets, pumps, and filter or boiler outlets.
- A barrel can only be picked up empty (vanilla), so it goes up empty and is filled where it stands.

### Connections: two kinds

1. **Plumb** (point to point). With a Pipe Wrench, connect one thing to one tank: a fixture, a filter's inlet, a boiler's inlet, a filter's or boiler's outlet into a tank, a pump's outlet, or another tank.
   - Reach: up to 10 tiles across, between vanilla plumbing's 1 and a generator's 20. Height follows the two rules above.
   - Cost: one pipe of any kind for every 3 tiles of distance, plus a joint per pipe: Glue, Epoxy or Duct Tape for plastic; the wrench alone for iron and lead.
   - Time grows with distance. The pipe runs out of sight, through walls and under floors, as vanilla's plumbing does. Buried like that, it doesn't freeze or wear. The player picks which pipe to bury, as when laying a line.
   - The pipe stays in the ground when a tank leaves its end, and carries water again once a tank stands there. You find it by knowing where it was: the other tank's Unplumb lists it, and so does the bare floor at either end. "Unplumb" gives back every length of pipe as it went in; the joints are spent.
   - Each fixture is plumbed on its own and picks its own tank. So the toilet and the washing machine can run off the raw tank while the kitchen sink runs off the clean one. There's no "house" to wire.
2. **Lay line** (tile by tile, for gardens). Pipe laid on the ground, one length a tile, each click of a cursor that stays up between clicks, as vanilla's build cursors do (vanilla has no drag-to-lay). The first tile must sit under or beside the tank's tile, the way vanilla's plumbing reaches 3×3 below. Lines are visible because their holes have to be where the plants are.

### Fixtures

- Plumbing a sink, tub, toilet or washing machine to a tank gives it a buffer of its vanilla reserve size (sink 20 L, bath 100 L; washers and showers, which have none, 20 L). It fills at once as the pipe goes in, then every ten minutes refills from its tank, up to 20 L, as far as the tank has water and stands a storey above the fixture.
- **The town's water wins while it runs.** A plumbed fixture the town still supplies gives the town's clean water, and its tank isn't drawn; its buffer waits empty and starts filling at the first pass after the shutoff. Plumbing early costs nothing.
- The fixture's vanilla reserve, what its pipes hold after the shutoff, is set aside while it's plumbed, so a dry tank means a dry tap. Unplumbing gives it back: an unplumbed fixture has what vanilla would give it, plus what's left in its buffer.
- A buffer stays when the fixture is unplumbed: the engine tells clients of a container added, never of one taken away.
- Drinking, washing, filling a bottle and the washing machine all use vanilla's own actions on the buffer. The buffer holds the tank's water as a vanilla fluid mixture, so a raw tank gives "Tainted" taps and a clean tank gives clean ones, with vanilla's sickness and its bandage refusal.
- **Rooftop barrels stop purifying.** The vanilla "Plumb" option (a barrel straight above) still appears and needs no learning. It now makes the same buffer connection. Fixtures already plumbed in an older save are converted the first time their square loads. Nothing is left on the vanilla path that purifies. A sandbox option (on by default) can turn this off for players who want vanilla plumbing.

### Garden lines

- **Holes.** "Drill Holes" on a laid pipe. A hole is a hole: about a litre an hour at a storey of head. The tool only decides what it can get into: an awl only soft pipe (plastic, lead), an Auger Drill, Stone Drill or hammer and nail anything but iron, a Hand Drill everything. Punching (hammer and nail, Stone Drill) may crack plastic or clay as it goes in.
- **Flow.** Every hole on the line runs while the tap is open. A higher tank pushes harder (rate × √storeys of head, as water falls). Water reaches plants at vanilla's rate (1 L = 50 points). A hole over bare ground wastes its share.
- **The tap.** "Fit Tap" (Pipe Wrench, one length of the line's own pipe, its joint) on a tile beside a tank a storey up. Each time it runs it draws from the highest tank beside it that holds water. One person at a tap at a time. Three ways to run it:
  1. **Hold it.** "Water from Tank" is a timed action at the tap. While you stand there, every hole on the line runs, the beds darken and the water sounds. Stop when you judge it's enough, or when the tank gives out.
  2. **Wind-up Valve.** Wind it with the oven's timer knob. It opens, runs, and shuts when it runs down. You start it each time.
  3. **Timer Valve** or a found **Sprinkler Timer.** It opens at one hour every day for the minutes you set, while its square has power. If the power fails, it shuts.
- **Sprinklers.** A Lawn Sprinkler set on a line tile throws water over a wide rectangle. It needs a pump driving the line, since a storey of head is about 3.5 psi and a sprinkler wants several times that. It's fast and wasteful: about half goes to air and paths, and it soaks soil faster.
- **Too much water.**
  - Each outlet tile keeps a `soak` value. Water delivered to a plant already at 100 raises it, and it dries a little each day.
  - While the soil is waterlogged the plant's roots rot: it loses health at vanilla's own drought rate, which stops when the soil dries. Health is vanilla's hidden 0-100 score: it falls when a plant is thirsty, cold or sick, sets the harvest, and at 0 the plant dies; the plant's sprite turns sickly below half and dying below a quarter. Rain never adds soak.
  - Seen as darker soil. The plant info shows "damp / soaked / waterlogged" from Agriculture 2.
- **Frost.** A full outdoor pipe can split in a hard freeze, rarely or now and then by material: a line left full all winter loses a length or two of iron, a few of clay, and seldom one of lead or plastic. A line stays full from its first watering until it is drained: its holes don't empty it, and those rates are for a line left full. "Drain Line" from any tile empties it. A split wastes water onto the ground while the tap runs (the soil shows wet); "Patch Crack" with glue, epoxy or duct tape makes the length whole again. A length still cracked is scrap when taken up.
- **Ollas.** An unglazed Clay Jar buried in a bed. Fill it by hand; it seeps into the eight tiles around it for days. It needs no line and no height.

### Pumps

| Pump | How it runs | Lift | Rate | Costs |
| --- | --- | --- | --- | --- |
| Wooden Hand Pump | "Pump" timed action at the pump | 1 storey | 6 L a game minute | endurance; a squeal you can hear; the seal wears; the wood wears faster than iron |
| Iron Hand Pump | "Pump" timed action at the pump | 2 storeys | 8 L a game minute | endurance; the seal wears |
| Pump House + Appliance Pump | its switch, or a Timer Valve, while its square has power | 1 storey | 6 L a game minute | power; wear per hour; heavy wear run dry |
| Pump House + Utility Pump | the same | 2 storeys | 20 L a game minute | the same |

- **Sources.** A pump draws from the source it stands on or beside: a well, a barrel or trough, or water tiles reached by its Rubber Hose intake. It delivers through "Plumb" to a tank (filling rule ignored up to its lift), or straight into a garden line (which is how a sprinkler gets its push).
- **Hand pump seals**, best first: Leather Strips, Tire Piece, Tarp Piece, a Plunger cup. Each lasts fewer litres than the one before; when it's done the pump squeals and lifts nothing until you replace it.
- **Power** for the Pump House: grid until shutoff, a running generator, or a Renewable Energy bank. On a generator the mod burns fuel for the pump's draw at vanilla's rate.
- **Endgame:** a Timer Valve on the Pump House fills the raw tank from the river every morning, and a Timer Valve on the tap waters the beds every evening. Neither knows if it rained, if the river is low, or if the tank is already full. A full tank overflows and wastes the work. A dry source burns the pump.
- **Left out:**
  - The tire pump. Nobody pumps water with a tyre pump, and the wooden hand pump is a better low-skill pump.
  - Bellows. They move air; the only honest water use is a weak airlift pump in a deep well.

### Making water safe

Every method turns Tainted Water into Water completely or not at all; the game has no "mostly clean". What separates them is speed, cost and upkeep.

- **Two tanks.** The raw tank is big and high; it feeds the garden, the animals and the filter. The clean tank is small and closed (its vanilla lid shut, so nothing gets in), filled only from a filter's or boiler's outlet or a pumped well, and it feeds the kitchen. One bucket of raw water in the clean tank taints it; vanilla's Empty action pours it out. Rain comes in tainted, so an open clean tank is a raw tank by the next shower: the lid matters.
- **The height chain.** Raw tank on a platform, filter beside it on the same level, clean tank beside that, sinks below. A single-storey platform or an upstairs room does it all; a pump can stand in for any step.
- **Slow sand filter: the living filter.**
  - The part that cleans is the mat of algae and bacteria that grows on the sand (the schmutzdecke). That's the "plants that clean water" idea, and it's real. It also means you keep it alive.
  - **Ripening:** a new filter puts out tainted water for 3 days, and for 1 day after a cleaning. Real filters are run to waste until mature. The filter doesn't divert: check its outlet (vanilla's tooltip says "Tainted" or not), Empty it, and only then plumb its outlet to the clean tank. Plumb it too soon and you taint the clean tank.
  - **Alive:** feed it every day or so. Two dry days, or a hard freeze, kill the layer, and it ripens again from scratch.
  - **Slow:** a Barrel Filter yields about 100 L a day however hard you push. Its head (the water waiting on the sand) holds what the barrel holds, and nothing bypasses the sand: Pour In leaves what doesn't fit in your container, and an inlet draws only what fits. A Brick Filter yields four times that.
  - **Clogged:** after enough water has passed, it slows to a trickle and its menu says so: one step, not a slow fade. "Clean Filter" stirs and skims the top of the sand by hand; a shovel or a trowel makes it quicker. It ripens for a day after. The sand lasts years. (Real household filters are cleaned the same way, by stirring or scraping the top centimetre or two: CDC, EPA; *Cisterns for Kentucky* says replace the top two inches when it clogs.)
  - **Frozen:** a hard freeze with water on the sand kills the film, and the ice passes nothing that hour. An empty filter rides out the frost.
- **Boiler: clean water for fuel.**
  - A Metal Drum over a firebox, with an inlet from the raw tank and an outlet to the clean tank. Water held at 60 °C for half an hour, or boiled, is safe (CDC).
  - Fuel it and light it like a vanilla fire. After about an hour hot, it passes about 30 L an hour clean until the fuel's gone. A drum that never got hot passes nothing.
  - It's a fire, under vanilla's fire rules: outdoors, away from walls, and never on a wooden platform you care about. Run it with the raw tank empty and the drum scorches.
- **Filter Crock: clean water without plumbing.**
  - A porous fired clay pot set in a bucket. "Pour In" raw water from any container; clean water seeps into the bucket below at about 10 L a day. Drink or fill from it with vanilla's actions. The crock holds 8 L, the bucket 10.
  - Always clean: charcoal crushed into the clay burns out in the kiln and leaves pores too fine for what taints the water, so there is nothing to ripen and nothing to keep alive.
  - It clogs after 300 L, in one visible step, to a tenth of its rate; "Scrub Crock" by hand (15 minutes) restores it. A hard freeze with any water in it cracks it: the water runs out and it passes nothing more. "Take Down" gives back the bucket with its water, and the crock unless it's cracked; raw water still in the crock spills.
- **Also:** boiling and tablets as in vanilla; a well is clean and practically endless, once something pumps it.
- **Left out:**
  - **Bleach.** In real life it's the EPA's emergency advice (8 drops a gallon, 30 minutes). In this game any trace of Bleach fluid is deadly, so a dose would fight the engine.
  - **Reed beds and aquariums.** They clean water for plants and fish, not for drinking.
  - **Cloth or charcoal on their own.** They leave water tainted.

## The climb

What a survivor does, in order, and what each step asks and gives back. Each needs the one before and buys back time; the later ones tie you to a place and fail in ways you only find by walking the garden.

1. **Carry** (vanilla). A watering can and a barrel. Fifty plants is an afternoon of clicks.
2. **Raise a barrel.** Upstairs, on log stairs and a deck, or on a Tank Stand (the pamphlet and Woodwork 3, or Woodwork 5). Height, and nothing yet to use it.
3. **Lay a line.** Scavenged pipe, a joint per plastic length, something to drill with, and a Pipe Wrench from town for the tap. A bed waters while you stand at the tap. In return: drain before a frost, don't drown the roots, patch what splits.
4. **Join tanks.** Plumb to Tank: a platform of barrels becomes a cistern.
5. **Plumb the house.** A sink that runs again, raw water staying raw.
6. **Make it safe.** A filter you keep alive or a boiler you feed, and a second tank kept apart.
7. **Lift it.** Sweat at a hand pump, or a pump house on power: loud, worn, salvaged from town.
8. **Let it run.** Timers that water and fill while you're away, as long as the power holds, knowing nothing of the weather.

## Catalogue

Skill levels are starting points. "Learn" lists every way a recipe is taught. Research uses vanilla's rule: about two-thirds of the recipe's skill, minus 2 for Inventive. Every recipe that says "Pamphlet" is in *Cisterns for Kentucky*.

### New items

Weights sit beside vanilla's nearest item: the pamphlet a Brochure's, the Utility Pump a Blower Fan's and a bit, the Appliance Pump a Hair Dryer's, the Water Valve a kitchen Timer's, the Sprinkler Timer a crafted timer's, the crock a Clay Pot's.

| Item | Weight | Where it comes from | Used for |
| --- | --- | --- | --- |
| **Cisterns for Kentucky** (pamphlet) | 0.1 | farmhouses, garden and farm-supply stores, libraries and post offices (exact lists picked with a loot census) | teaches the Pamphlet recipes below; researchable from nothing else |
| **Utility Pump** | 6 | found in tool stores, Gigamart tools, garages and basements; or made (below) | Pump House part, the strong one. Research it to learn the Pump House and Make Utility Pump |
| **Appliance Pump** | 1 | "Salvage Pump" on a washing machine or dishwasher (below) | Pump House part, the weak one. Research it to learn the Pump House |
| **Water Valve** | 0.3 | "Salvage Pump" on a washing machine or dishwasher; rarely in plumbing supplies | Timer Valve. Research it to learn the Timer Valve |
| **Lawn Sprinkler** | 1 | found in garden stores, garages and sheds; or made (below) | set on a line tile. Research it to learn Make Pipe Sprinkler |
| **Sprinkler Timer** | 0.5 | found in tool and garden stores | a ready-made Timer Valve: fit it to a tap or a Pump House with no skill. Research it to learn the Timer Valve |
| **Filter Crock (Unfired)** → **Filter Crock** | 0.5 | made (below) | placed as the crock filter |

New items stop there. Everything else is vanilla items given a new job, plus placed objects.

### Crafted items

| Recipe | Skill | Inputs (tools kept) | Output | Learn |
| --- | --- | --- | --- | --- |
| **Make Utility Pump** | Electricity 3, MetalWelding 2 | Blower Fan, 2 Small Sheet Metal, 4 Screws, 2 Electric Wire, Rubber Hose; Blow Torch (uses), Welding Rods (uses), welding mask, screwdriver | Utility Pump, lower condition ceiling than a found one | research a Utility Pump (Electricity 2); auto at Electricity 6 |
| **Make Pipe Sprinkler** | MetalWelding 2 | Iron Pipe, empty Gardening Spray bottle (the head), 2 Screws; Hand Drill, pliers | Lawn Sprinkler, lower condition ceiling | research a Lawn Sprinkler (MetalWelding 1); auto at MetalWelding 4 |
| **Shape Filter Crock** | Pottery 4 | 4 Clay, 2 Charcoal (crushed into the clay: it burns out and leaves pores), 0.5 L water; pottery wheel | Filter Crock (Unfired) | auto at Pottery 5; research a Clay Jar (Pottery 3) or a Filter Crock |
| **Fire Filter Crock** | Pottery 4 | Filter Crock (Unfired), something to light it, a log or charcoal; kiln | Filter Crock | with Shape Filter Crock, by every route |

### Actions on the world (no build menu)

| Action | Skill | Takes | Learn |
| --- | --- | --- | --- |
| **Plumb** (vanilla, barrel straight above) | none | Pipe Wrench | everyone, as in vanilla |
| **Plumb to Tank** (up to 10 tiles) | none | Pipe Wrench; 1 pipe per 3 tiles; a joint per pipe | Pamphlet; auto at Woodwork 4 or MetalWelding 3 |
| **Lay Line** | none | 1 Plastic, Iron or Lead Pipe, or 2 Clay Pipe Segments, per tile; joints as above (clay: 1 use of clay cement per tile) | everyone |
| **Drill Holes** | none | a tool that pierces the pipe: Hand Drill (any), Auger or Stone Drill or hammer and a nail (not iron), awl (plastic or lead) | everyone |
| **Fit Tap** | none | Pipe Wrench, 1 length of the line's pipe, a joint | everyone |
| **Water from Tank** | none | standing at the tap | everyone |
| **Drain Line** | none | standing at any tile of the line | everyone |
| **Salvage Pump** (washing machine or dishwasher) | Electricity 2 | screwdriver, pliers; the appliance stays but won't run again | auto at Electricity 2 |
| **Bury Olla** | Pottery 1 | an unglazed Clay Jar; a trowel or shovel | auto at Pottery 1 |
| **Pump** (at a hand pump) | none | endurance | everyone |
| **Replace Seal** (hand pump) | none | Leather Strips, Tire Piece, Tarp Piece or Plunger; screwdriver | everyone |
| **Clean Filter** | none | bare hands, 60 minutes; 30 with a shovel, garden trowel or mason's trowel | with the filter |
| **Pour In** (filters, crock) | none | any container of water, 1 minute per 4 L | everyone |
| **Scrub Crock** | none | bare hands, 15 minutes | everyone |
| **Take Down** (crock) | none | 2 minutes | everyone |
| **Plumb Inlet**, **Plumb Outlet** (filters, boiler) | none | as Plumb to Tank | as Plumb to Tank |

### Builds (build menu)

| Build | Skill | Inputs (tools kept) | Learn |
| --- | --- | --- | --- |
| **Tank Stand** (one tile; carries one rain barrel a storey up) | Woodwork 3 | 4 Logs, 6 Planks, 8 Nails; hammer, saw. Then set an empty rain barrel on it | Pamphlet; auto at Woodwork 5 |
| **Wooden Hand Pump** | Woodwork 2 | 4 Planks, 4 Nails, 2 Plastic Pipe, 1 Rubber Hose, 1 seal (Leather Strips, Tire Piece or Tarp Piece); hammer, saw, any drill | Pamphlet; auto at Woodwork 4 |
| **Iron Hand Pump** | MetalWelding 3 | 2 Iron Pipe, 2 Small Sheet Metal, 4 Screws, 1 Rubber Hose, 1 seal; Blow Torch, Welding Rods, mask, Hand Drill | Pamphlet; auto at MetalWelding 5 |
| **Pump House** (wood or sheet-metal box; takes one pump part) | Woodwork 2 or MetalWelding 1, plus Electricity 1 to wire it | 4 Planks + 4 Nails, or 2 Small Sheet Metal + 4 Screws; 2 Electric Wire, 2 Rubber Hose; screwdriver | research a Utility or Appliance Pump (Electricity 1); Pamphlet |
| **Wind-up Valve** (on a tap) | none | Kitchen Timer, 2 Screws, 1 Rubber Hose (the diaphragm); screwdriver | everyone |
| **Timer Valve** (on a tap or a Pump House) | Electricity 2 | Alarm Clock, Water Valve, 2 Electric Wire, 1 Electronics Scrap; screwdriver, pliers, Pipe Wrench | research a Water Valve or Sprinkler Timer (Electricity 1); auto at Electricity 4 |
| **Barrel Filter** | Woodwork 2 | 6 Planks, 5 Nails (the barrel), 1 Gravel Bag, 2 Sand Bags, **5 Charcoal** (required), 1 pipe of any kind and a joint (the outlet); hammer, shovel | Pamphlet; auto at Woodwork 6 |
| **Brick Filter** | Masonry 3 | 24 Clay Bricks, 4 uses of cement (`base:concrete`), 2 Gravel Bags, 6 Sand Bags, **15 Charcoal**, 1 Iron Pipe; mason's trowel, shovel | Pamphlet; auto at Masonry 5 |
| **Boiler** (stone firebox) | Masonry 2 | Metal Drum, 12 Clay Bricks or Stone Blocks, 2 uses of cement, 2 Iron Pipe; mason's trowel, Pipe Wrench | research a Metal Drum (Masonry 1); auto at Masonry 4 |
| **Boiler** (welded firebox) | MetalWelding 3 | Metal Drum, 4 Small Sheet Metal, 2 Iron Pipe, 4 Screws; Blow Torch, Welding Rods, mask | research a Metal Drum (MetalWelding 2); auto at MetalWelding 5 |
| **Filter Crock** (placed) | none | a Filter Crock and an empty bucket of any kind under it | with Shape Filter Crock, by every route |

Charcoal (`base:charcoal`) is required in both sand filters. Sand is a shovel and a bag away. Charcoal means a kiln, a burner or a scavenged crate, which makes a working filter feel earned. It also makes the filter clog slower.

### What the pamphlet teaches

*Cisterns for Kentucky*: Tank Stand, Plumb to Tank, Wooden Hand Pump, Iron Hand Pump, Pump House, Barrel Filter, Brick Filter. That is the leaflet's own scope: storing, lifting and filtering water. Electrical work is learned by researching the parts. The boiler is learned by researching a drum, and pottery from the wheel. Each skill has a door that doesn't need the pamphlet:

| Skill | Learns without the pamphlet |
| --- | --- |
| Woodwork | Barrel Filter (6), Tank Stand (5), Wooden Hand Pump (4), Plumb to Tank (4) |
| MetalWelding | Iron Hand Pump (5), Pipe Sprinkler (4, or research a sprinkler), welded Boiler (5, or research a drum), Plumb to Tank (3) |
| Masonry | Brick Filter (5), stone Boiler (4, or research a drum) |
| Electricity | Salvage Pump (2), Timer Valve (4, or research a valve or sprinkler timer), Utility Pump (6, or research one), Pump House (research a pump) |
| Pottery | Olla (1), Filter Crock (5, or research a Clay Jar) |

The Barrel Filter is the pamphlet's prize: built at Woodwork 2 by anyone who finds it, or worked out alone only by a master carpenter at Woodwork 6. Clean water from your own backyard is the leaflet's whole point.

## Entropy, in one place

| Part | Wears by | Patch | Remake |
| --- | --- | --- | --- |
| Pipe | a hard freeze when full, rare to uncommon (clay > iron > lead > plastic); a punched hole may crack plastic or clay | glue, epoxy or duct tape on the crack; still scrap when taken up | new length |
| Hand pump | the seal per litre; the body slowly (wood faster) | Replace Seal | rebuild |
| Electric pump | per hour; heavily when dry | Electronics Scrap and a Tire Piece, lowering its ceiling | a new pump part |
| Sand filter | clogs after so many litres (one visible step); the living layer dies after two dry days or a hard freeze | Clean Filter by hand, then a day of ripening | fresh sand and charcoal, then a full ripening |
| Boiler | drum condition per hour burning; heavily when dry | weld a patch (Small Sheet Metal, torch), lowering its ceiling | a new drum |
| Filter Crock | clogs after 300 L (one visible step); cracks if a hard freeze finds water in it | scrub it by hand | fire a new one |
| Timer Valve, Sprinkler Timer | — | — | works until its power fails |

Upkeep lands in batches: feed and clean the filter, check the tanks, drain the pipes before a frost.

## Where the parts are (risk)

- **Town:** tool stores, Gigamart, garden stores. Utility Pumps, Sprinkler Timers, Lawn Sprinklers, Plastic Pipe, pipe wrenches. The best parts, with the most danger.
- **Every house:** washing machines and dishwashers (pumps and valves, at the cost of the appliance); kitchen timers; alarm clocks; garages with hose and sprinklers.
- **Countryside:** the pamphlet in farmhouses; worn sprinklers and pumps in sheds; wells, troughs, rivers.
- **Made:** clay pipe and crocks (a wheel and a kiln: commitment), charcoal (a kiln or burner), sand and gravel (a shovel and bags).

## Renewable Energy

The mod stands alone. With Renewable Energy:

- A bank in reach powers Pump Houses and Timer Valves through `square:haveElectricity()`, as it powers any appliance.
- **Change to RE:** `RenewableEnergy.Loads.addConsumer(fn)`, so `Loads.scan` bills a pump at its schedule's average watts under its own label.
- RE's pasture stock-tank solar sites gain a worn Utility Pump by the tank.
- Later: a windmill pump, and a solar pasteurizer (a black drum in a glazed box: clean water on sunny days only).

## How it's built

- **Authority and state.** The server owns everything. Each line tile is a record in a global object system (`enhanced_irrigation_line`), saved with `setObjectModDataKeys` so it lives, dries and freezes while its chunk is unloaded; clients get a rounded summary per tile. Tank-to-tank links have no tile of their own, so they live in a second system's own saved data (`enhanced_irrigation_link`), sent to clients whole when they change. Tanks keep no record: a tank is what its entity says, which survives the vanilla lid swap that drops an object's modData. Filters have records of their own (Treatment units, below), which wait while unloaded; pumps and boilers will.
- **Topology.** A line is worked out from its tiles when it runs (breadth-first from the tap through same-floor neighbours), not stored, so laying or lifting a tile needs no bookkeeping beyond reshaping its neighbours' sprites, whatever lifts it: Take Up, a sledgehammer or another mod. Two neighbours join unless a solid wall or a window stands between them (`Lines.joins`); a doorway, door or not, joins, so a line enters a greenhouse by its door, and a fence or low wall joins, as a pipe is laid over what a player hops. Laying, the shapes and the flow ask the same test. An edge on a square that isn't loaded joins, as its walls can't be read; every edge a player works at is loaded.
- **Ticks.** `EveryTenMinutes` on the server, as farming does, with elapsed time from `getWorldAgeHours()`. Water from Tank runs the flow for the world time that passed: from the action's `update()` in single player, from the server's `animEvent` (`emulateAnimEvent`, as vanilla's trough filling does) in multiplayer.
- **Unloaded chunks.**
  - A tank's water lives in its chunk. A link with an end unloaded waits; the hand-held tap needs the player there, so phase 2 moves no water while unloaded.
  - Rain catchers keep collecting while unloaded (vanilla's meta simulation), so a tank's water can only be under-counted by the mod, never over.
  - Pumps and timers (phases 5 and 6) will need the snapshot-and-owe scheme: on unload a link snapshots its tank; flows draw on the snapshot and record what they owe; on load, the owed litres come out of the real container.
- **Plants.** `SFarmingSystem.instance:getLuaObjectOnSquare`; set `waterLvl` and `health`, then `saveData()`. A plant's record is saved by its own system even while unloaded, and goes back onto the plant when it loads. Vanilla farming files are never replaced.
- **Tank Stand.** Stand and barrel are one tile and entity, swapped in and out the way vanilla's lid swaps a barrel. A raised offset on vanilla's own barrel was the alternative; the lid swap drops it, and a barrel is only half the picture of a stand.
- **Fixtures.**
  - Each plumbed fixture gets its own `FluidContainer` component (vanilla's own `addWaterContainer` command does this). The engine reads its fluid sources in order: plumbed, the town's (infinite), own container, reserve. So the town's water wins with no flag to set, and the reserve is held back by setting `modData.waterAmount` to 0, with the litres kept on the link for Unplumb. The engine keeps the container's taint through drink, fill, wash and tooltips.
  - `isTaintedWater` alone reads the container before the town's water, so a buffer with water in it would make the town's taps read tainted. While the town's water runs, the link pass empties the buffer instead of filling it.
  - The vanilla Plumb handler (`ISWorldObjectContextMenu.onPlumbItem`) is a Lua function the Java menu calls by name, so the mod routes it here.
  - Fixtures already flagged `usesExternalWaterSource` in a save are converted on load: the flag is cleared, and a buffer is linked to the tank they used. The hook is `MapObjects.OnLoadWithSprite` on the base game's `waterPiped` tiles, run a tick later, when the storey above is in the cell.
  - **Proven in game** (phase 1, single player and multiplayer): the buffer reaches clients, survives a chunk reload, gets vanilla's Drink, Fill and Wash, and keeps taint into a filled bucket. A converted sink reaches clients. A plumbed sink in a room before the shutoff gives the town's clean water, with no taint warning, and leaves its tank alone. Details in `docs/research.md`, "Fixture buffers, run in game".
  - **What phase 3 settled from the probe:**
    - A buffer moves a fixture to vanilla's fluid container menu, which drops a washing machine's on/off switch; the fixture menu adds it back. A washer-dryer keeps vanilla's own switch, which its menu shows either way.
    - The same menu lets a player pour into or empty a buffer. Accepted: it's a basin, and pouring tainted water into a clean-tank fixture taints it, as it should.
    - Vanilla's Plumb still shows on a buffered fixture under a barrel; the fixture menu takes it out once the fixture is plumbed.
    - Plumb to Tank on a fixture needs no room, so player-built cabins work; vanilla's Plumb still needs one.
    - A multiplayer server converts an old save's fixtures only when it first loads their chunk. The conversion itself is tested on a loaded chunk in multiplayer, and through a reload in single player.
- **Treatment units** (the filters and the crock now; the boiler later). One shape for all of them: a head of raw water in a record (`enhanced_irrigation_treatment`: litres, all-or-nothing taint, litres passed, the film's wet and dry hours, a crock's crack and its bucket), treated at the unit's rate into its basin, the entity's own `FluidContainer`, which vanilla's menus drink, fill and empty. A kind's rules live in one table on each side (`Treatment.KINDS`, `TreatmentObject.KINDS`), so the crock and boiler add rows, not branches.
  - The basin is `InputLocked`, which hides vanilla's pour, so water reaches it only through the unit; the record unlocks it for the moment it adds. No rain: a filter under the sky would otherwise fill its clean basin with tainted rain.
  - Unlike a line tile, a unit's record waits while its chunk is unloaded, as the basin it fills lives on the unit, and catches up the whole gap (at most a week) in steps of an hour once it loads: the head drains, then the sand dries, in that order.
  - Built from the build menu, which never fires `OnObjectAdded`, so the entity's `OnCreate` gives it its record at once.
  - Inlet and outlet are links like a fixture's (`inlet`, `outlet`), with Plumb to Tank's reach, pipe, time and learning. Water runs in from a tank at least level with the unit and out to one no higher; an inlet takes only a tank of nothing but water. One of each per unit, and not both to the same tank.
  - Pour In takes 1 minute per 4 L, about vanilla's pour. A hard freeze is the line's (−7 °C, the square's own air, which a room warms).
  - Sand and gravel are uses of vanilla's bags, four to a bag, as vanilla's sand floor and clay cement take them, so each empty sack comes back. The Barrel Filter's outlet is any pipe and a joint, glue or tape: the build menu can't ask for the joint only with plastic, and a threaded pipe still wants sealing into a stave. Clean Filter is quicker with any tool that lifts sand: a shovel or garden trowel (`base:takedirt`) or a mason's trowel.
  - The crock's bucket is any `base:bucket`, as every kind holds 10 L. Its build input counts items (`ItemCount`): without it the game keeps an input that holds a fluid container. The `OnCreate` notes which bucket the build took, from the recipe's chosen inputs, and Take Down gives that one back. The crock is learned with its recipes rather than by everyone, as the design's Builds table has it; researching a Filter Crock teaches all three, so a crock made by someone else can still be set up.
  - The crock's tile blocks placement but not walking, as vanilla's potted floor plants do; it has no scrap, so vanilla's Disassemble can't lose its water and record.
- **Salvage.** "Salvage Pump" is the mod's own action on washer sprites (`appliances_laundry_01_0..7`) and dishwasher sprites (`appliances_cooking_01_72..79`). It marks the appliance stripped in its modData. Vanilla scrapping is left alone: it runs on the appliance's first material (`Fridge`: blowtorch and MetalWelding), so a scrap-table route would demand a welder for what is screwdriver work.
- **Teaching.**
  - The pamphlet's `LearnedRecipes`.
  - `AutoLearnAny` on each recipe. Vanilla never applies it to a build entity's recipe, so the mod checks its builds' skills itself on each level-up and when a character loads.
  - World actions that need knowing (Plumb to Tank) are gated by a recipe that is never listed or craftable, so the pamphlet and the skill teach them the vanilla way.
  - `ResearchableRecipes` on the new items.
  - For vanilla items (Clay Jar; the Metal Drum to come), `ResearchableRecipes` added as the mod's Lua loads, through the item script's own parser (`Item.DoParam`), which keeps only recipes that need learning. Each side loads its scripts before its Lua, so a file-load call suffices; a test researches a Clay Jar in single player and multiplayer.
  - The crock's wheel and kiln recipes are craftRecipes, which vanilla's AutoLearn checks itself; they are in the mod's list too, so a multiplayer level up that teaches them reaches the client, as Plumb to Tank's does.
- **Actions.** Timed actions whose `complete()` runs on the server and re-validates, as Renewable Energy's do. Endurance drawn like `ISChopTreeAction:useEndurance`. Noise through the world sound system.
- **UI.** The Wind-up Valve and Timer Valve reuse the oven UI's timer knob. No other windows.
- **Art.** Pipe tiles auto-shaped from their neighbours, per material, with a wet variant whose dark soil runs on from tile to tile along the pipe; tap, valves, stand, pumps, Pump House, filters, boiler, crock, sprinkler, olla. Made with Renewable Energy's Blender pipeline (`art/models/make.sh`, deterministic) and its own `tiledef` number (6143). The dev mod's `--art` mode stages every tile in the world and screenshots it, the check that previews alone can't give (depth, joins, scale beside vanilla).
- **Harness.** `dev/harness` as a submodule, `dev/harness.conf`, and a dev mod, as Hearing Aid's are set up. Tests play each verb and check plant water, soak, tank litres, taint and wear after set game time, single player and `--mp`. Unloaded catch-up, fixture save/reload and plumbed-fixture conversion get their own tests.

## Build order

Each phase is playable on its own:

1. **Prove the risk.** Done: a throwaway test of fixture buffers (save, reload, multiplayer, vanilla menus, taint) and of plumbed-fixture conversion, in the dev mod, since replaced by phase 3's tests.
2. **Gravity garden.** Done: tanks and height, Tank Stand, Plumb to Tank between tanks, Lay Line, Drill Holes, Fit Tap, Water from Tank, soak and root rot, frost, patching and draining, the pamphlet, its loot and learning, each with in-game tests in single player and multiplayer. Not yet played through: the summer-and-frost playtest under Starting numbers.
3. **Fixtures.** Done: Plumb to Tank on fixtures, the vanilla Plumb override and old-save conversion behind the Plumbing Keeps Taint option, the washer's switch, each with in-game tests in single player and multiplayer. Two tanks, raw and clean, wait on phase 4's filters.
4. **Safe water.** Barrel and Brick Filters and the Filter Crock done: Pour In, inlet and outlet links, ripening, dying dry or frozen, clogging and Clean Filter; the crock shaped and fired, set in a bucket, clogging and Scrub Crock, cracking in a frost, Take Down; learning, each with in-game tests in single player and multiplayer. Still to come: the Boiler.
5. **Pumps.** Hand pumps and seals, Salvage Pump, Pump House, Utility Pump, sprinklers.
6. **Automation.** Wind-up Valve, Timer Valve, Sprinkler Timer, Renewable Energy billing.

## Starting numbers

Vanilla's yardsticks: 1 L = 50 plant points; a plant drains about 4.8 points a day; a watering can holds 8 L; a rain barrel 600 L; a sink's reserve 20 L.

| What | Start | Reasoning |
| --- | --- | --- |
| Hole | 1 L/h at one storey of head, × √storeys above that | six minutes a day keeps a plant level; half an hour tops one up from 70; a tank two storeys up does it in 70% of the time |
| Plumb to Tank | 10 tiles; 1 pipe per 3 tiles | a kitchen sink 6 tiles from the tower costs 2 pipes |
| Fixture refill | up to 20 L per ten minutes | a bath refills in under an hour |
| Hand pumps | 6 / 8 L a game minute | a 600 L barrel in about 75-100 minutes of sweat |
| Appliance / Utility Pump | 6 / 20 L a game minute | a barrel in under two hours / half an hour |
| Lawn sprinkler | 600 L/h over about 15 tiles, half lost | ten minutes soaks a bed; an hour empties a barrel |
| Soak | dries 10 a day out, 5 in; waterlogged above 30; roots lose health at vanilla's drought rate while waterlogged | an hour too long sets a plant back; a forgotten night can kill a bed, sooner indoors |
| Barrel / Brick Filter | about 4 / 16 L an hour; ripens in 3 days, 1 after a cleaning; dies after 2 dry days | a household's daily water from one barrel |
| Boiler | about 30 L an hour once hot; heats in an hour; a log keeps it hot about an hour | fast clean water that costs a woodpile |
| Filter Crock | about 10 L a day; holds 8 L; clogs after 300 L | one person's drinking and cooking; a month of it before a scrub |

Playtest: a 40-plant greenhouse and two survivors through one Kentucky summer and the first frost.

## Later, not now

- Fertigation: fertilizer in the tank, dosed dumbly to every outlet.
- Float valve for an animal trough.
- Windmill pump and solar pasteurizer (with Renewable Energy).
- Propane burner for the boiler.
- Soaker hose from Tire Pieces.
- Roof washer for rain barrels.
- Rain, moisture and float sensors: never.

## Decided

- **Mod id** `cf_enhanced_irrigation`, folder `Workshop/EnhancedIrrigation`; the pamphlet keeps the name *Cisterns for Kentucky*.
- **Barrel Filter** is taught by the pamphlet, or by Woodwork 6.
- **Plumb to Tank** reaches 10 tiles.
- **Rooftop barrels stop purifying**, with a sandbox option on by default.
- **A tap, a drip line or a fixture needs a full storey of head.**
- **One kind of hole; no silt, no flushing.** Hole kinds and a slowly clogging rate were hidden numbers the player never sees; frost and overwatering are the line's wear.
- **Height above a storey pushes harder** (√head), with no cap on holes. A cap on a hole count isn't how water behaves.
- **Plumb to Tank pipe is buried**: it neither freezes nor wears.
- **Laid and plumbed pipe keeps its condition**, so laying an iron or lead pipe and taking it up never mends a weapon.
- **No tire pump.**

## Questions for any new feature

The same six as Renewable Energy's:

1. **Cost:** what does it take, and what does the player give up for it?
2. **Risk:** where must they go, and what noise do they make, to get it or run it?
3. **Payoff:** what do they get the day it works, and does it beat carrying buckets without making buckets pointless?
4. **Decay:** how does it wear, what patches it, how does each patch fall short, what remakes it, and what finally ends it?
5. **Vanilla:** which vanilla mechanic, number or verb does it mirror? If none, why is it needed?
6. **Doom:** does it make the game less bleak than it should be? If it removes a threat for good, cut it or make it cost more.
