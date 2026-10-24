# Enhanced Irrigation: player's guide

How the mod's systems work, for players who want more than the Workshop page tells them, and where to start looking for the gear. Figures assume the default sandbox settings and vanilla's own plant figures: 1 L of water is 50 water points, a plant holds 100, and a plant uses about 5 a day.

This version has raised tanks, tanks plumbed together, sinks, baths, toilets and washers plumbed to a tank, garden lines, and sand filters and a filter crock that make rain water safe to drink. Pumps, boilers and timers are planned, but they aren't in the game yet.

## Mechanics

### Tanks and height

| Mechanic | How it works |
|---|---|
| What counts as a tank | Any of vanilla's rain barrels or rain collectors, an amphora, and a rain barrel on a Tank Stand, with the lid open or shut. Wells, troughs, sinks and toilets aren't tanks. |
| Level | A tank's level is the floor it stands on, plus one if it's on a Tank Stand. A barrel on the ground is level 0. A barrel on a stand, or on the floor one storey up, is level 1. A barrel on a stand one storey up is level 2. |
| Pressure | A tap runs only from a tank at least one level above the line. A barrel on the ground waters nothing by gravity. Each extra level pushes harder: two levels above the line run about 1.4 times as fast, three about 1.7 times. |
| Filling a tank | Rain, through an open lid, as with vanilla's barrels. You can also pour in water with vanilla's fluid menu, or let a tank plumbed to it fill it from above. |
| Taint | Water keeps whatever taint it had. Rain comes in tainted; a ripe sand filter is what cleans it (Making water safe, below). |

### Tank Stand

| Mechanic | How it works |
|---|---|
| Building it | In the build menu, beside the rain collectors. It needs Carpentry 3, 4 logs, 6 planks and 8 nails, plus a hammer and a saw, which you keep. It gives Carpentry XP. You learn it from *Cisterns for Kentucky*, or at Carpentry 5. |
| Set Barrel on Stand | Carry an empty rain barrel to the stand. It has to be the round 600 L barrel, with or without a tarp, its lid open or shut. Vanilla only lets you pick one up when it's empty. It takes 5 minutes of heavy work. The square rain collector and the amphora don't fit on a stand. |
| The raised barrel | A raised barrel is a level higher than the floor it stands on. It holds 600 L and catches rain as vanilla's barrel does while its lid is open. |
| Take Barrel Down | Empty the barrel first. It takes 5 minutes and gives back vanilla's barrel, leaving the stand empty. |
| Moving it | An empty stand can't be picked up. Disassembling it gives some planks and nails back, as wooden furniture does. A barrel on a stand can be neither picked up nor disassembled; take it down first. |
| Where to find barrels | Rain barrels already on the map are vanilla's round barrel, so they fit a stand. Building one yourself takes Carpentry 5 in vanilla. |

### Plumb to Tank

| Mechanic | How it works |
|---|---|
| Learning | *Cisterns for Kentucky* teaches it, as do Carpentry 4 and Welding 3. Without learning it, the option tells you what's missing. |
| Reach | Up to 10 tiles of pipe, counted as the straight distance across, rounded up, plus 2 tiles for each storey between the two tanks. One storey apart leaves 8 tiles across. |
| Cost | A Pipe Wrench, which you keep. One length of pipe for every 3 tiles, rounded up, so a run takes at most 4 lengths. Pick the pipe in the menu from the kinds you carry. Plastic takes one use of glue, epoxy or duct tape for each length. Clay takes 2 segments a length and one use of cement or concrete. Iron and lead take nothing more. It takes 10 minutes plus 3 a tile, so the longest run takes 40 minutes. |
| How water moves | Every ten minutes, while both tanks are loaded. Tanks on the same level share their water until each is filled to the same fraction. Between different levels, the higher tank fills the lower one until the lower one is full or the higher one is empty. Water never runs uphill. A link moves at most 360 L an hour. Taint goes with the water. |
| Watch out | Plumbing a raised barrel to a barrel on the ground empties the raised one into the ground one. |
| Cisterns | A tank can be plumbed to several others, so a deck of barrels on one level acts as one big tank. |
| Buried pipe | The pipe runs out of sight, through walls and under floors, and never freezes or wears. It stays in the ground when a tank leaves its end, and a tank placed on that square is connected again. |
| Unplumb | From either tank, or from the bare floor where a tank stood. It takes 10 minutes and a Pipe Wrench. Every length comes back in the condition it went in; the joints are used up. |

### Sinks, baths, toilets and washers

| Mechanic | How it works |
|---|---|
| Plumb to Tank on a fixture | Right-click a sink, bath, shower, toilet or washing machine for **Plumb to Tank**. It lists the tanks in reach, with the same reach, pipe, joints, time and learning as plumbing two tanks. The fixture doesn't need to be in a room, so a cabin you built yourself works. Each fixture has one tank; a tank can feed many fixtures. |
| Height | The tank must stand at least a level above the fixture, as for a tap. One on the fixture's own level is greyed out, saying so. |
| Vanilla's Plumb | Vanilla's **Plumb**, on a fixture in a room under a barrel one storey up, still works without learning and takes no pipe, only a Pipe Wrench. It makes the same connection as Plumb to Tank, so the barrel's water stays tainted. A rooftop barrel no longer purifies. Sandbox: **Plumbing keeps taint**. |
| The fixture's water | Where no town water reaches it (after the shutoff, or in a cabin you built), a plumbed fixture holds its own water: 20 L for a sink, toilet, shower or washer, 100 L for a bath. It fills from the tank, then refills up to 20 L every ten minutes while the tank has water and the height. Drink, fill, wash and the washer use vanilla's own actions on it. |
| Taint | The fixture holds the tank's water as it is. A tainted tank gives tainted taps, with vanilla's warning and sickness. Plumb the fixture to a clean tank that a filter fills. |
| The town's water | While the town's water still runs, it wins: a plumbed fixture in a house gives clean town water and leaves the tank alone. Within ten minutes of the shutoff it switches to the tank. The water vanilla leaves in a fixture's pipes after the shutoff (20 L in a sink) is set aside while it's plumbed, and comes back when you unplumb it, along with whatever the fixture still holds. |
| Unplumb | From the fixture, the tank, or the bare floor where the tank stood: 10 minutes with a Pipe Wrench. Every length comes back; vanilla's Plumb laid none. |
| Washer | A plumbed washing machine keeps its **Turn On** switch. It needs power, and draws about a litre a minute while it runs, which the tank keeps up with. |
| Old saves | With **Plumbing keeps taint** on, a fixture vanilla plumbed before you added the mod changes over the first time its area loads. A fixture fed by another mod's container stays on vanilla's plumbing. |

### Garden lines

| Mechanic | How it works |
|---|---|
| Lay Line | Right-click the ground while carrying pipe, then pick the kind under **Lay Line**. The cursor stays up, so you can click out a run tile by tile. Each tile takes 3 minutes and no skill. Per tile: 1 plastic pipe and one use of glue, epoxy or duct tape; 1 iron or lead pipe, joined with a Pipe Wrench, which you keep; or 2 clay pipe segments and one use of cement or concrete. Wood glue and adhesive tape don't hold water. Lay the line on the plants' own squares: a hole waters only the plant on its tile. |
| Where it goes | Open ground or floor, not water and not a square furniture blocks. The first tile goes on or beside a tank: in the 3×3 around it, with the tank on the same floor or one floor up. After that, each tile goes next to the line. A line stays on one floor. Walls and windows split it; doorways, fences and low walls don't. |
| One tap a line | You can't lay a tile that would join two lines that each have a tap. |
| Drill Holes | 2 minutes a tile; a tile is either holed or not. It uses the first suitable tool you carry, in this order: Hand Drill (any pipe); Auger Drill (anything but iron); an awl, Ice Pick, Handiknife, Multitool or small punch set (plastic and lead only); Stone Drill (anything but iron); a hammer and a nail, which uses up the nail (anything but iron). The Stone Drill and the hammer punch rather than cut, so 1 hole in 5 cracks plastic or clay pipe, and the menu warns you. |
| Fit Tap | 10 minutes, with a Pipe Wrench, one more length of the line's own pipe and its joint. The tap goes on a line tile that has a tank at least a level above it, on or beside the tile or on the floor above. |
| Water from Tank | Stand at the tap. Every hole on the line runs, the soil darkens and you hear water, until you stop, walk off, or the tank runs dry or loses its height. Holding the tap open costs no endurance. Only one person can hold a tap at a time. |
| Which tank | Each time water runs, the tap draws from the highest tank in its reach that holds water, and the fullest of those if two are equally high. Tanks plumbed to that one refill it every ten minutes. |
| Rate | Each holed tile gives 1 L an hour from a tank one level up, more from higher ones. That fills a dry plant in about 2 game hours. Keeping a plant level takes about 6 minutes at the tap a day. Every hole runs at once, so 24 holes draw 24 L an hour from the tank. A tank that can't keep up gives every hole the same share. |
| Wet soil | The ground under a working hole, a crack, or a spot where a line was drained shows wet for 4 hours, and longer while the soil is soaked. |

### Too much water

| Mechanic | How it works |
|---|---|
| Soak | Water a hole gives past what its plant can take soaks the soil, as does everything a hole over bare ground gives, up to 100 points. Rain never soaks the soil, so vanilla farming is unchanged. |
| Drying | Soil dries 10 points a day outdoors and 5 indoors. |
| Soil line | From Agriculture 2, the plant info window shows a **Soil** line: Damp, Soaked, then Waterlogged above 30. |
| Root rot | While the soil is waterlogged, the plant loses health about as fast as a parched one. Holding the tap an hour past full keeps a plant waterlogged for about 2 days outdoors and 4 indoors. Two hours past full keeps it waterlogged for a week outdoors or two indoors, which can kill a weak plant. |
| Mixed beds | Every hole runs together. Topping up one thirsty plant soaks every full plant on the same line, so plant a line's beds at the same time, or water a newcomer by hand. |

### Frost and repairs

| Mechanic | How it works |
|---|---|
| Full lines | Once a tap has run, its line stays full of water until you drain it. |
| Freezing | At -7 °C or colder, a full tile may split. A heated room keeps its tiles safe. Left full outdoors all winter, a 24-tile line can expect about 3 cracks in clay, 1 or 2 in iron, and seldom one in lead or plastic. |
| Drain Line | From any tile of the line. It takes 2 minutes plus 1 for every 5 tiles, empties the whole line and wets the spot where you opened it. |
| Cracks | A cracked tile leaks about 3 L an hour while the tap runs, more from a higher tank. The water wets the ground but no plant gets it. **Patch Crack** takes 3 minutes and one use of glue, epoxy or duct tape on any pipe. |
| Take Up Pipe | 3 minutes. Each length comes back in the condition it went in; laid pipe doesn't wear. A cracked length is lost, and a tap's length comes back with its tile. The joints are used up. A sledgehammer also removes a tile, but you lose the pipe. |

### Making water safe

| Mechanic | How it works |
|---|---|
| Building a filter | In the build menu, beside the rain collectors. **Barrel Filter**: Carpentry 2; 6 planks, 5 nails, a gravel bag, 2 sand bags, 5 charcoal, one plastic, iron or lead pipe and one use of glue, epoxy or duct tape; a hammer and a shovel, which you keep. **Brick Filter**: Masonry 3; 24 clay bricks, a bucket of cement or concrete (4 uses), 2 gravel bags, 6 sand bags, 15 charcoal and an iron pipe; a mason's trowel and a shovel, which you keep. Each emptied bag gives its sack back. Both give XP. You learn them from *Cisterns for Kentucky*, or at Carpentry 6 and Masonry 5. |
| How it works | Raw water waits on top of the sand and seeps through into the filter's basin below, about 4 L an hour in a Barrel Filter (about 100 L a day) and 16 L an hour in a Brick Filter. The top holds 50 L in a barrel and 200 L in brick; so does the basin. Once the basin is full, the water waits on top. The menu's first line says how much is waiting and how the sand is. |
| Pour In | Right-click the filter or crock, then **Pour In** and the container. Any container of water or tainted water in your main inventory; nothing else goes in. It takes a minute for every 4 L, and the container keeps what doesn't fit. |
| Ripening | A new filter passes water as tainted as it came in for its first 3 days of use (72 hours with water on the sand), then clean. Check the basin with vanilla's tooltip, and Empty it before plumbing its outlet to a clean tank, or the first batch taints the tank. |
| Keeping it alive | The sand's film needs water. Two days with nothing on the sand kill it, and it ripens again from scratch. So does a hard freeze (-7 °C or colder) while water stands on the sand, and nothing passes that hour. An empty filter, or one in a heated room, rides out the frost. |
| Clogging | After 2000 L through a Barrel Filter, or 8000 L through a Brick Filter, it slows to a tenth of its rate and its menu says **Clogged**. **Clean Filter** takes 60 minutes by hand, or 30 with a shovel, garden trowel or mason's trowel. After a cleaning the filter passes tainted water for a day while it ripens again. |
| Drinking from it | The basin, or the crock's bucket, works with vanilla's own actions: drink, fill a container, or empty it. Vanilla won't pour into it, so water only reaches it through the sand or the clay. |
| Plumb Inlet | From the filter's menu, to a tank in reach. Reach, pipe, joints, time and learning are the same as Plumb to Tank. The tank must stand at least level with the filter. Every ten minutes it tops the filter up, as long as the tank holds nothing but water. Taint goes with it. |
| Plumb Outlet | From the filter's menu, to a tank that stands no higher than the filter. Every ten minutes it empties the basin into the tank. Use a lidded tank so rain can't taint it. A filter has one inlet and one outlet, to different tanks. |
| Unplumb | From the filter, the tank, or the bare floor where either stood, as for tanks. |
| Making a Filter Crock | Shape it at a pottery wheel: **Shape Filter Crock** takes Pottery 4, 4 clay, 2 charcoal and half a litre of water from any container you carry, which you keep, and gives Pottery XP. Then fire it at a kiln: **Fire Filter Crock**, also Pottery 4, takes the unfired crock, something to light the fire and a log or charcoal. Pottery 5 teaches both, and so does researching a Clay Jar or a Filter Crock. |
| Setting the crock up | In the build menu, beside the rain collectors: a Filter Crock and an empty bucket of any kind. No skill; you learn it with the crock's recipes. |
| How the crock works | Pour In up to 8 L of raw water. It seeps through the clay into the bucket below, clean however tainted it went in, at about 10 L a day. There's nothing to ripen and nothing to plumb. The bucket holds 10 L; once it's full, the water waits in the crock. |
| Scrub Crock | After 300 L the crock slows to a tenth of its rate and its menu says **Clogged**. **Scrub Crock** takes 15 minutes by hand and brings the full rate back at once. |
| Frost and the crock | A hard freeze (-7 °C or colder) with any water in the crock cracks it. The water runs out, it passes nothing more, Pour In is refused and its menu says **cracked**. An empty crock, or one in a heated room, is safe. |
| Take Down | 2 minutes, from the crock's menu. You get back the bucket it stood in, with whatever water the bucket holds, and the crock unless it's cracked. Raw water still in the crock spills. |

### Learning and options

| Mechanic | How it works |
|---|---|
| *Cisterns for Kentucky* | Teaches the Tank Stand, Plumb to Tank (for tanks, fixtures and filters) and the Barrel and Brick Filters. Reading it eases boredom and stress, as vanilla's magazines do. |
| Skills | Carpentry 5 teaches the Tank Stand, Carpentry 6 the Barrel Filter, Masonry 5 the Brick Filter, Pottery 5 the Filter Crock (shaping, firing and setting it up); Carpentry 4 or Welding 3 teaches Plumb to Tank. A character who already has those levels when the mod is added learns them on entering the world. |
| Research | Researching a Clay Jar, from Pottery 3, teaches the Filter Crock's recipes; so does researching a Filter Crock. |
| No learning needed | Vanilla's Plumb, laying lines, drilling holes, fitting taps, watering, patching, draining and taking up pipe, Pour In, Clean Filter, Scrub Crock and Take Down. |
| XP | Building the Tank Stand and the Barrel Filter give Carpentry XP; the Brick Filter gives Masonry XP; shaping a Filter Crock gives Pottery XP. |
| Sandbox | **Cisterns for Kentucky loot** multiplies how often the pamphlet is found, from 0 to 4. At 0 it's never found, and only the skills teach its plans. **Plumbing keeps taint** (on by default): vanilla's Plumb makes the mod's connection and old plumbed fixtures change over; off, vanilla's plumbing is untouched and a rooftop barrel's water comes out clean. |
| Adding to a save | The pamphlet turns up only in containers nobody has opened yet. Barrels already in your world count as tanks straight away. |

## Items and recipes

| What | Kind | Made from, or found | Used for |
|---|---|---|---|
| *Cisterns for Kentucky* | Pamphlet, weight 0.1 | Found only | Teaches the Tank Stand, the filters and Plumb to Tank |
| Tank Stand | Built | Carpentry 3: 4 logs, 6 planks, 8 nails; hammer, saw | Holds one rain barrel a level up |
| Raised Rain Barrel | A barrel on a stand | Set Barrel on Stand | A 600 L tank a level up |
| Barrel Filter | Built | Carpentry 2: 6 planks, 5 nails, gravel bag, 2 sand bags, 5 charcoal, a pipe and a joint; hammer, shovel | About 100 L of clean water a day, once ripe |
| Brick Filter | Built | Masonry 3: 24 clay bricks, 4 uses of cement, 2 gravel bags, 6 sand bags, 15 charcoal, an iron pipe; mason's trowel, shovel | Four times a Barrel Filter's water |
| Filter Crock (Unfired) | Item, weight 0.5 | Pottery 4 at a pottery wheel: 4 clay, 2 charcoal, 0.5 L of water | Fired at a kiln into a Filter Crock |
| Filter Crock | Item, weight 0.5 | Fired at a kiln: the unfired crock and fuel | Set in a bucket |
| Filter Crock in a bucket | Built | A Filter Crock and an empty bucket | About 10 L of clean water a day |
| Garden line tile | Laid | One tile of pipe and its joint | Carries water; holed, it waters the plant on its square |
| Tap | Fitted to a line tile | A Pipe Wrench, one length of pipe and its joint | Where you run the line |
| Buried pipe | Plumbed between tanks, from a tank to a fixture, or into and out of a filter | 1 length of pipe per 3 tiles, with joints; none for vanilla's Plumb | Moves water between tanks, into a fixture, or through a filter |
| Plumbed fixture | A vanilla sink, bath, shower, toilet or washer | Plumb to Tank, or vanilla's Plumb | Holds its tank's water for vanilla's drink, fill, wash and washer |

Everything else is vanilla:

| Vanilla item | Used for |
|---|---|
| Plastic, Iron and Lead Pipe; Clay Pipe Segments | Lines, taps, buried pipe and a filter's outlet |
| Glue, Epoxy, Duct Tape | Joints in plastic pipe; patching any crack; the Barrel Filter's outlet |
| Bucket of Clay Cement or Concrete | Joints in clay pipe; the Brick Filter |
| Pipe Wrench | Laying iron or lead line, Fit Tap, Plumb to Tank, Plumb Inlet and Outlet, vanilla's Plumb, Unplumb |
| Hand Drill, Auger Drill, awls, Stone Drill, hammer and nails | Drill Holes |
| Rain barrel | Set on a Tank Stand |
| Sand Bag, Gravel Bag, Charcoal, Clay Bricks | The filters |
| Clay, Charcoal; a pottery wheel and a kiln | Making the Filter Crock |
| Bucket, of any kind | Under the Filter Crock |
| Clay Jar | Research it to learn the Filter Crock |
| Shovel, garden trowel, mason's trowel | Building the filters; Clean Filter |

## Where to look

### Loot

| What | Where to look | How often |
|---|---|---|
| *Cisterns for Kentucky* | Garden centres' shelves most of all; farm crates, homesteaders' boxes, hardware stores' farm aisles, libraries' gardening shelves and magazine racks, post offices; less often farm tool cabinets, barn tool crates, garden-centre tools, the Gigamart's farm aisle and libraries' reference shelves | Uncommon: about as often as one of vanilla's farming magazines |
| Plastic pipe | Hardware stores' plumbing aisle, craft supplies, junk bins | Uncommon |
| Iron pipe | Crates of pipe in warehouses and on building sites, plumbing aisles, plumbers' vans | Common |
| Lead pipe | Plumbing aisles, construction trucks, wherever vanilla keeps melee weapons | Uncommon |
| Clay pipe | Never found: make it at a kiln | |
| Pipe Wrench | Plumbers' and propane trucks, hardware stores' plumbing aisle, old tool crates | Uncommon |

### Places already set up

None. Every stand, line, filter and link is one you build.
