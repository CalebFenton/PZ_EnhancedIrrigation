# Enhanced Irrigation: player's guide

How the mod's systems work, for players who want more than the Workshop page tells them, and where to start looking for the gear. Figures assume the default sandbox settings and vanilla's own plant figures: 1 L of water is 50 water points, a plant holds 100, and a plant uses about 5 a day.

This version has raised tanks, tanks plumbed together, sinks, baths, toilets and washers plumbed to a tank, garden lines, sand filters, a filter crock and boilers that make rain water safe to drink, hand pumps that lift water from a well, a barrel or a river into a tank or a garden line, Pump Houses that do it on electric power, lawn sprinklers that a pumped line drives, and valves and timers that run a tap with nobody holding it.

## Mechanics

### Tanks and height

| Mechanic | How it works |
|---|---|
| What counts as a tank | Any of vanilla's rain barrels or rain collectors, an amphora, and a rain barrel on a Tank Stand, with the lid open or shut. Wells, troughs, sinks and toilets aren't tanks, though a hand pump draws from a well or a trough. |
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
| Where it goes | Open ground or floor, not water and not a square furniture blocks. The first tile goes on or beside a tank: in the 3×3 around it, with the tank on the same floor or one floor up; or in the 3×3 around a pump, on its floor, for the pump to feed. After that, each tile goes next to the line. A line stays on one floor. Walls and windows split it; doorways, fences and low walls don't. |
| A tap or a pump | A line takes one tap or one pump's outlet, not both: Fit Tap is greyed out on a line a pump feeds, a pump's Plumb Outlet on a tapped line or one another pump feeds, and you can't lay a tile that would join two lines that each have a tap or a pump. |
| Drill Holes | 2 minutes a tile; a tile is either holed or not. It uses the first suitable tool you carry, in this order: Hand Drill (any pipe); Auger Drill (anything but iron); an awl, Ice Pick, Handiknife, Multitool or small punch set (plastic and lead only); Stone Drill (anything but iron); a hammer and a nail, which uses up the nail (anything but iron). The Stone Drill and the hammer punch rather than cut, so 1 hole in 5 cracks plastic or clay pipe, and the menu warns you. |
| Fit Tap | 10 minutes, with a Pipe Wrench, one more length of the line's own pipe and its joint. The tap goes on a line tile that has a tank at least a level above it, on or beside the tile or on the floor above. |
| Water from Tank | Stand at the tap. Every hole on the line runs, the soil darkens and you hear water, until you stop, walk off, or the tank runs dry or loses its height. Holding the tap open costs no endurance. Only one person can hold a tap at a time. |
| Which tank | Each time water runs, the tap draws from the highest tank in its reach that holds water, and the fullest of those if two are equally high. Tanks plumbed to that one refill it every ten minutes. |
| Rate | Each holed tile gives 1 L an hour from a tank one level up, more from higher ones. That fills a dry plant in about 2 game hours. Keeping a plant level takes about 6 minutes at the tap a day. Every hole runs at once, so 24 holes draw 24 L an hour from the tank. A tank that can't keep up gives every hole the same share. |
| Wet soil | The ground under a working hole, a crack, or a spot where a line was drained shows wet for 4 hours, and longer while the soil is soaked. |
| Pumped lines | Plumb a pump's outlet to any tile of a line (Hand pumps, Pump Houses, below). The line runs while its pump does, as if its tap were held: a hand pump while you work it, a Pump House while it runs. A pump pushes harder than a tank: each hole gives 2 L an hour from a hand pump or an Appliance Pump and 3 from a Utility Pump. The line takes no more than the pump lifts, every hole and sprinkler getting the same share of it, and the pump draws (and a hand pump wears) only what the line takes. While the pump runs, the line's menu says **water running**. |

### Sprinklers

| Mechanic | How it works |
|---|---|
| Set Sprinkler | From a line tile's menu, carrying a Lawn Sprinkler and a Pipe Wrench, which you keep: 5 minutes. It sets the sprinkler you carry in the best condition, as worn as it is. Not on the tap's tile, and one to a tile; a tile with a sprinkler takes no tap. **Take Sprinkler** (3 minutes, with the wrench) gives it back as it went on; so does Take Up Pipe on its tile. |
| Only on a pump | A sprinkler runs only on a line a pump drives, while the pump runs: a storey of tank head can't turn it, so on a tapped line it does nothing. |
| Rate | It asks the line for about 1 L a minute, which any pump lifts with plenty to spare for the line's holes. Half of it is lost to the air and the paths. |
| Where it waters | A patch 5 squares long and 3 wide, centred on it, the long side along the line at its tile: north to south where the line runs or ends that way, east to west anywhere else. Every square gets the same share, about 1.8 L an hour: its plant fills up to full and the rest soaks the soil. That fills a dry bed in about an hour; about 3 minutes a day keeps it level, and the soil dries off what up to 10 minutes gives past that. |
| Its soil | Soil a sprinkler soaks off the line dries and rots roots exactly as a line tile's does (Too much water, below), even once the sprinkler is taken or its patch turns away. Where two sprinklers' patches overlap, the square has one soil, which both soak. The plant info's **Soil** line shows the wettest of the soil under the plant's own tile and of the soil a sprinkler soaked there. |
| Wear | Sprinklers don't wear. |
| Make Pipe Sprinkler | Welding 2, in hand: an iron pipe, an empty gardening spray can and 2 screws; a hand drill and pliers, which you keep. It gives Welding XP, and the sprinkler comes out at 80%, its ceiling, which travels with it. Learned at Welding 4 or by researching a Lawn Sprinkler from Welding 1. |

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
| Drain Line | From any tile of the line. It takes 2 minutes plus 1 for every 5 tiles, empties the whole line and wets the spot where you opened it. It's greyed out while a pump runs the line. |
| Cracks | A cracked tile leaks about 3 L an hour while the tap runs, more from a higher tank. The water wets the ground but no plant gets it. **Patch Crack** takes 3 minutes and one use of glue, epoxy or duct tape on any pipe. |
| Take Up Pipe | 3 minutes. Each length comes back in the condition it went in; laid pipe doesn't wear. A cracked length is lost, and a tap's length and a sprinkler come back with their tile. The joints are used up. A sledgehammer also removes a tile, but you lose the pipe and its sprinkler. |

### Making water safe

| Mechanic | How it works |
|---|---|
| Building a filter | In the build menu, beside the rain collectors. **Barrel Filter**: Carpentry 2; 6 planks, 5 nails, a gravel bag, 2 sand bags, 5 charcoal, one plastic, iron or lead pipe and one use of glue, epoxy or duct tape; a hammer and a shovel, which you keep. **Brick Filter**: Masonry 3; 24 clay bricks, a bucket of cement or concrete (4 uses), 2 gravel bags, 6 sand bags, 15 charcoal and an iron pipe; a mason's trowel and a shovel, which you keep. Each emptied bag gives its sack back. Both give XP. You learn them from *Cisterns for Kentucky*, or at Carpentry 6 and Masonry 5. |
| How it works | Raw water waits on top of the sand and seeps through into the filter's basin below, about 4 L an hour in a Barrel Filter (about 100 L a day) and 16 L an hour in a Brick Filter. The top holds 50 L in a barrel and 200 L in brick; so does the basin. Once the basin is full, the water waits on top. The menu's first line says how much is waiting and how the sand is. |
| Pour In | Right-click the filter, crock or boiler, then **Pour In** and the container. Any container of water or tainted water in your main inventory; nothing else goes in. It takes a minute for every 4 L, and the container keeps what doesn't fit. |
| Ripening | A new filter passes water as tainted as it came in for its first 3 days of use (72 hours with water on the sand), then clean. Check the basin with vanilla's tooltip, and Empty it before plumbing its outlet to a clean tank, or the first batch taints the tank. |
| Keeping it alive | The sand's film needs water. Two days with nothing on the sand kill it, and it ripens again from scratch. So does a hard freeze (-7 °C or colder) while water stands on the sand, and nothing passes that hour. An empty filter, or one in a heated room, rides out the frost. |
| Clogging | After 2000 L through a Barrel Filter, or 8000 L through a Brick Filter, it slows to a tenth of its rate and its menu says **Clogged**. **Clean Filter** takes 60 minutes by hand, or 30 with a shovel, garden trowel or mason's trowel. After a cleaning the filter passes tainted water for a day while it ripens again. |
| Drinking from it | The basin, the crock's bucket or the boiler's tap works with vanilla's own actions: drink, fill a container, or empty it. Vanilla won't pour into it, so water only reaches it through the sand, the clay or the fire. |
| Plumb Inlet | From the filter's or boiler's menu, to a tank in reach. Reach, pipe, joints, time and learning are the same as Plumb to Tank. The tank must stand at least level with it. Every ten minutes it tops the filter or drum up, as long as the tank holds nothing but water. Taint goes with it. If you come back to a filter or boiler whose inlet tank is still out of range, it waits for the tank before catching up. |
| Plumb Outlet | From the filter's or boiler's menu, to a tank that stands no higher than it. Every ten minutes it empties the basin into the tank. Use a lidded tank so rain can't taint it. A filter or boiler has one inlet and one outlet, to different tanks. |
| Unplumb | From the filter or boiler, the tank, or the bare floor where either stood, as for tanks. |
| Making a Filter Crock | Shape it at a pottery wheel: **Shape Filter Crock** takes Pottery 4, 4 clay, 2 charcoal and half a litre of water from any container you carry, which you keep, and gives Pottery XP. Then fire it at a kiln: **Fire Filter Crock**, also Pottery 4, takes the unfired crock, something to light the fire and a log or charcoal. Pottery 5 teaches both, and so does researching a Clay Jar or a Filter Crock. |
| Setting the crock up | In the build menu, beside the rain collectors: a Filter Crock and an empty bucket of any kind. No skill; you learn it with the crock's recipes. |
| How the crock works | Pour In up to 8 L of raw water. It seeps through the clay into the bucket below, clean however tainted it went in, at about 10 L a day. There's nothing to ripen and nothing to plumb. Whatever bucket it stands in, it fills to a common bucket's 10 L; once that's full, the water waits in the crock. |
| Scrub Crock | After 300 L the crock slows to a tenth of its rate and its menu says **Clogged**. **Scrub Crock** takes 15 minutes by hand and brings the full rate back at once. |
| Frost and the crock | A hard freeze (-7 °C or colder) with any water in the crock cracks it. The water runs out, it passes nothing more, Pour In is refused and its menu says **cracked**. An empty crock, or one in a heated room, is safe. |
| Take Down | 2 minutes, from the crock's menu. You get back the bucket it stood in, with whatever water the bucket holds, and the crock unless it's cracked. Raw water still in the crock spills. |
| Building a boiler | In the build menu, beside the rain collectors, outdoors only and with no wall on the boiler's square or the eight around it. **Boiler (Stone Firebox)**: Masonry 2; a Metal Drum, 12 clay bricks or stone blocks, 2 uses of cement or concrete and 2 iron pipes; a mason's trowel and a pipe wrench, which you keep. **Boiler (Welded Firebox)**: Welding 3; a Metal Drum, 4 small steel sheets, 4 screws and 2 iron pipes, with 4 uses of a welding torch and of welding rods; a welder mask, which you keep. Both give XP. Masonry 4 teaches the stone one and Welding 5 the welded one; researching a Metal Drum teaches each you have the skill to research (Masonry 1, Welding 2). Both work the same. |
| Its fire | The boiler is a vanilla fire, like the Barrel Oven: its menu holds vanilla's fuel line, **Add Fuel**, **Light** and **Put Out**, and it burns its fuel down, lights and warms the area like one. Like vanilla's fireplaces, it never spreads fire. |
| How it works | Raw water waits in the drum, up to 200 L. Lit, the drum is hot after an hour; while hot, it passes about 30 L an hour into its tap, clean however tainted it went in, until the tap holds 200 L. The fire banks up to two hours of heat: put out after that, the drum stays hot about half an hour, then passes nothing. A boiler that never got hot passes nothing. The menu's line says how much is waiting, whether the drum is cold, heating or hot, and its condition. |
| Wear | Every hour of fire wears the drum a little while it holds water, so a drum lasts about 200 hours of fire. Run dry, it scorches fast: 10 hours of fire with nothing in the drum burn it through. A burnt-through drum holds and passes nothing, Pour In is refused, the inlet draws nothing, and its menu says **burnt through**. |
| Patch Drum | From the boiler's menu: Welding 2, a small steel sheet, 2 uses of a welding torch and 1 of welding rods, and a welder mask; 30 minutes. Each patch restores the drum 10% less than the last: to 90%, then 80%, and so on. It's refused while the drum is already in better shape than the patch would leave it, and once there's nothing left to patch; then build a new boiler. |

### Hand pumps

| Mechanic | How it works |
|---|---|
| Building a hand pump | In the build menu, beside the rain collectors. **Wooden Hand Pump**: Carpentry 2; 4 planks, 4 nails, 2 plastic pipes, a rubber hose and a seal (Leather Strips, a Tire Piece or a Tarp Piece); a hammer, a saw and any drill, which you keep. **Iron Hand Pump**: Welding 3; 2 iron pipes, 2 small steel sheets, 4 screws, a rubber hose and a seal, with 2 uses of a welding torch and of welding rods; a welder mask and a hand drill, which you keep. The seal goes in whole: Leather Strips leave no dirty strips. Both give XP. You learn them from *Cisterns for Kentucky*, or at Carpentry 4 and Welding 5. Build it anywhere; it says **No water to draw** until it has a source. |
| Where it draws | From the first of: a well beside it (the stone well, or the forest's old hand pump), clean and endless; the fullest rain barrel, rain collector, amphora or water trough beside it, its water as it is, taint and all; or, for a pump on the ground, the nearest river or pond water within 3 tiles, which its hose reaches, endless and always tainted. Beside means the 8 squares around it. The menu's first line names the source, then the seal, the pump's condition and the tank it fills or the line it feeds. |
| Plumb Outlet | From the pump's menu, to one tank or garden line in reach, with the same reach, pipe, joints, time and learning as Plumb to Tank; a line is listed by its nearest tile. A Wooden Hand Pump fills a tank up to a level above its floor: a barrel on a Tank Stand beside it, or on the floor above. An Iron Hand Pump fills one up to two levels above: a barrel on a stand one storey up. A tank too high is greyed out saying how high the pump lifts. The tank it fills is never its source. A line it feeds runs while you work the handle (Garden lines, above). Unplumb from the pump, the tank, the line's tile or the floor where either stood. |
| Pump | Stand at the pump and work the handle: about 6 L a minute from a wooden pump and 8 from an iron one, so a 600 L barrel takes about 100 or 75 minutes. It's hard work, about 60% of your endurance an hour, less what standing still gives back. It stops by itself when the tank is full, the source runs dry, the seal or the pump wears out, or you're exhausted; feeding a line, it runs until you stop or one of the others. You hear the water, and a wooden pump squeals. Zombies hear it too: about 15 tiles off for a wooden pump, 8 for an iron one. Only one person can work a pump at a time. |
| Seals | Each seal lifts so many litres before it's worn through: Leather Strips 3000, a Tire Piece 2000, a Tarp Piece 1200 and a Plunger's cup 600. The menu shows what's left of it. A worn-out seal lifts nothing, and Pump is greyed out until you replace it. |
| Replace Seal | From the pump's menu, then the seal, from the Leather Strips, Tire Pieces, Tarp Pieces and Plungers you carry: 10 minutes with a screwdriver, which you keep. The old seal is thrown away. Anyone can do it, whenever they like. |
| Wear | Every 300 L lifted takes 1% off a wooden pump, every 1500 L off an iron one: about 30,000 L in all from a wooden pump and 150,000 from an iron one. At 0% it's worn out and lifts nothing; knock it down with a sledgehammer and build a new one. |

### Pump Houses

| Mechanic | How it works |
|---|---|
| Building a Pump House | In the build menu, beside the rain collectors. **Pump House (Wood)**: Carpentry 2 and Electricity 1; 4 planks, 4 nails, 2 electrical wires, 2 rubber hoses; a hammer and a screwdriver, which you keep. **Pump House (Sheet Metal)**: Welding 1 and Electricity 1; 2 small steel sheets, 4 screws, 2 electrical wires, 2 rubber hoses; a screwdriver. It is built empty, and draws from the same sources as a hand pump. You learn both from *Cisterns for Kentucky*, or by researching an Appliance Pump or a Utility Pump. |
| Pump parts | **Appliance Pump** (weight 1): about 6 L a minute, fills a tank up to a level above, 1% wear an hour running. **Utility Pump** (weight 6): about 20 L a minute, up to two levels above, 0.5% an hour. |
| Fit Pump, Take Out Pump | From the house's menu, with a screwdriver: Fit Pump takes a part from your inventory as worn as it is (15 minutes), Take Out Pump gives it back as it was (10 minutes) and switches the house off. Plumb Outlet works once a part is in, to a tank or a garden line, with Plumb to Tank's reach, pipe and learning; the part's lift decides how high the tank may stand. A line it feeds runs while the house runs (Garden lines, above). |
| Turn On, Turn Off | From the house's menu, 1 minute. Turn On is greyed out without power. Switched on, it runs every ten minutes while it has power: the water stops when the tank is full, the pump doesn't. The menu says whether it is running, off, or on with no power. You hear its motor; zombies hear it about 10 tiles off for an Appliance Pump and 20 for a Utility Pump. |
| Power | The grid, free, until the shutoff, but only in a room or right beside one, as for a washer: never out in the open. Otherwise a running generator in reach, which burns fuel for the pump at vanilla's rate (as much as a washer for an Appliance Pump, about twice for a Utility Pump) and switches off when it runs dry. With no generator in reach, a Renewable Energy battery bank powers it and bills it as an appliance, at the same rate: its status window lists the Pump House while it is switched on or its timer is open, and a Utility Pump alone is more than a plug-in inverter carries. |
| Wear | Running with nothing to draw wears the part ten times as fast. At 0% it burns out, stops and switches off. |
| Repair Pump | Electricity 2; a screwdriver, Scrap Electronics and a Tire Piece; 30 minutes. Brings the part back to 10% below its last ceiling (90%, then 80%, …), and is refused while the part is better than that. The ceiling travels with the part. |
| Away | While the house's area isn't loaded it waits, and catches the time up when you come back: grid hours count up to the shutoff, a generator's as far as its fuel goes, and nothing if it has no power when you return. |
| Salvage Pump | On a washing machine, washer-dryer or dishwasher: Electricity 2 (learned automatically at that level), a screwdriver and pliers, 30 minutes. Gives an Appliance Pump at 60-100% and a Water Valve, and leaves the appliance where it stands, switched off; it never switches on again ("Its pump has been salvaged"), even moved. Refused on one already stripped. |
| Make Utility Pump | Electricity 3 and Welding 2, at a table or counter: a Blower Fan, 2 small steel sheets, 4 screws, 2 electrical wires, a rubber hose, 2 uses of a welding torch and 1 of welding rods; a welder mask and a screwdriver. The pump comes out at 80%, its ceiling. Learned at Electricity 6 or by researching a Utility Pump. |

### Valves and timers

| Mechanic | How it works |
|---|---|
| Three valves | A **Wind-up Valve** runs a tap for the minutes you wind it, then shuts. A **Timer Valve** or a **Sprinkler Timer** runs it every day at the hour you set, for the minutes you set, while it has power. All three run the tap as if you held it: every hole on the line runs, the soil darkens and you hear water. None of them wears out. |
| Fit Valve, Take Off Valve | From a tap's menu, with a Pipe Wrench, which you keep: Fit Valve (5 minutes) screws on the valve you pick from the ones you carry, one to a tap; Take Off Valve (3 minutes) gives it back and forgets its setting. Take Up Pipe on the tap's tile gives it back too. |
| Wind Valve | Walks you to the tap and opens the valve's knob, the oven timer's: 1 to 5, 10 to 30 in fives, then 40, 50, 60, 90 or 120 minutes. **Wind** turns it there (1 minute at the tap); winding to 0 shuts it. **Wind** is greyed out, saying why, while someone holds the tap or no tank can feed it. With a controller, A winds and B closes. |
| Set Timer | Walks you to the tap and opens the timer's panel: the hour it starts, stepped with ^ and v, and the same knob for how long it runs; 0 never runs. **Set** sets it (1 minute at the tap). |
| How long to run it | A tank one level up gives each hole a little under 1 point of plant water a minute, and a plant drinks about 5 points a day, so about 6 minutes a day keeps a bed level and the soil dries off what up to 15 gives past that (Too much water, above). A tank two levels up runs faster, so less. Hold the tap and watch the soil to judge it. |
| While it runs | The tap's menu says **water running**, and Water from Tank and Drain Line are greyed out. If someone holds the tap when a timer would open, their watering counts and the timer's doesn't. |
| Power | A timer needs its tap's square powered, as a washer does: the grid in or right beside a room until the shutoff, a generator in reach, or a Renewable Energy bank. It draws too little to bill. Without power it doesn't open. |
| Away | While the tap's area isn't loaded its valve waits, then catches up when you come back (a week at most): every time it would have run, from the tank as it stands then. A timer counts the hours only if it has power when you return, or the grid's until the shutoff if the grid powered it when you left. |
| On a Pump House | **Fit Timer** (5 minutes, with a screwdriver) puts a Timer Valve or a Sprinkler Timer between the house and its power; **Take Off Timer** (3 minutes) gives it back; **Set Timer** opens the same panel. Switched off, the house runs in the timer's window each day, with the power, wear and generator fuel of any run; switched on, it runs whatever the timer says. The menu names the timer and how it's set. A Wind-up Valve doesn't fit: it has no switch. |
| Make Wind-up Valve | Anyone, at a table or counter: a kitchen timer, 2 screws and a rubber hose; a screwdriver, which you keep. |
| Make Timer Valve | Electricity 2, at a table or counter: an alarm clock, a Water Valve, 2 electrical wires and scrap electronics; a screwdriver, pliers and a Pipe Wrench, which you keep. Gives Electricity XP. Learned at Electricity 4 or by researching a Water Valve or a Sprinkler Timer, from Electricity 1. |

### Learning and options

| Mechanic | How it works |
|---|---|
| *Cisterns for Kentucky* | Teaches the Tank Stand, Plumb to Tank (for tanks, fixtures, filters, boilers and pumps), the Wooden and Iron Hand Pumps, both Pump Houses and the Barrel and Brick Filters. Reading it eases boredom and stress, as vanilla's magazines do. |
| Skills | Carpentry 4 teaches the Wooden Hand Pump, Carpentry 5 the Tank Stand, Carpentry 6 the Barrel Filter, Masonry 5 the Brick Filter, Masonry 4 the stone-firebox Boiler, Welding 4 Make Pipe Sprinkler, Welding 5 the welded-firebox Boiler and the Iron Hand Pump, Pottery 5 the Filter Crock (shaping, firing and setting it up), Electricity 2 Salvage Pump, Electricity 4 Make Timer Valve, Electricity 6 Make Utility Pump; Carpentry 4 or Welding 3 teaches Plumb to Tank. A character who already has those levels when the mod is added learns them on entering the world. |
| Research | Researching a Clay Jar, from Pottery 3, teaches the Filter Crock's recipes; so does researching a Filter Crock. Researching a Metal Drum teaches the stone-firebox Boiler from Masonry 1 and the welded-firebox Boiler from Welding 2. Researching an Appliance Pump or a Utility Pump teaches the Pump Houses; a Utility Pump also Make Utility Pump. Researching a Lawn Sprinkler, from Welding 1, teaches Make Pipe Sprinkler. Researching a Water Valve or a Sprinkler Timer, from Electricity 1, teaches Make Timer Valve. |
| Parts loot | A sandbox option multiplies how often Utility Pumps, Lawn Sprinklers, Sprinkler Timers and Water Valves turn up (0 leaves them out). |
| No learning needed | Vanilla's Plumb, laying lines, drilling holes, fitting taps, watering, patching, draining and taking up pipe, Set and Take Sprinkler, Pour In, Clean Filter, Scrub Crock, Take Down, Patch Drum, Pump, Replace Seal, Fit Pump, Take Out Pump, Turn On and Off, Fit and Take Off Valve, Fit and Take Off Timer, Wind Valve, Set Timer, Make Wind-up Valve, and Repair Pump (Electricity 2). |
| XP | Building the Tank Stand, the Barrel Filter and the Wooden Hand Pump give Carpentry XP; the Brick Filter and the stone-firebox Boiler give Masonry XP; the welded-firebox Boiler, the Iron Hand Pump and Make Pipe Sprinkler give Welding XP; shaping a Filter Crock gives Pottery XP; Make Timer Valve gives Electricity XP. |
| Sandbox | **Cisterns for Kentucky loot** multiplies how often the pamphlet is found, from 0 to 4. At 0 it's never found, and only the skills teach its plans. **Plumbing keeps taint** (on by default): vanilla's Plumb makes the mod's connection and old plumbed fixtures change over; off, vanilla's plumbing is untouched and a rooftop barrel's water comes out clean. |
| Adding to a save | The pamphlet turns up only in containers nobody has opened yet. Barrels already in your world count as tanks straight away. |

## Items and recipes

| What | Kind | Made from, or found | Used for |
|---|---|---|---|
| *Cisterns for Kentucky* | Pamphlet, weight 0.1 | Found only | Teaches the Tank Stand, the hand pumps, the Pump Houses, the filters and Plumb to Tank |
| Appliance Pump | Part, weight 1 | Salvage Pump on a washer or dishwasher | A Pump House's weak pump |
| Utility Pump | Part, weight 6 | Found in hardware stores, the Gigamart, garages and basements; or Make Utility Pump | A Pump House's strong pump |
| Lawn Sprinkler | Part, weight 1 | Found in garden stores, garages, sheds and farm crates; or Make Pipe Sprinkler (Welding 2: an iron pipe, an empty gardening spray can, 2 screws; hand drill, pliers) | Set on a line tile, waters a 5 × 3 patch while a pump drives the line |
| Water Valve | Part, weight 0.3 | Salvage Pump on a washer or dishwasher; rarely in plumbing supplies | Make Timer Valve |
| Wind-up Valve | Valve, weight 0.6 | Make Wind-up Valve (anyone: a kitchen timer, 2 screws, a rubber hose; screwdriver) | Fitted to a tap, runs it for the minutes you wind |
| Timer Valve | Valve, weight 1.3 | Make Timer Valve (Electricity 2: an alarm clock, a Water Valve, 2 electrical wires, scrap electronics; screwdriver, pliers, Pipe Wrench) | Fitted to a tap or a Pump House, runs it at its hour every day while powered |
| Sprinkler Timer | Valve, weight 0.5 | Found in garden stores and hardware stores' and the Gigamart's farm aisles | The same as a Timer Valve |
| Tank Stand | Built | Carpentry 3: 4 logs, 6 planks, 8 nails; hammer, saw | Holds one rain barrel a level up |
| Raised Rain Barrel | A barrel on a stand | Set Barrel on Stand | A 600 L tank a level up |
| Barrel Filter | Built | Carpentry 2: 6 planks, 5 nails, gravel bag, 2 sand bags, 5 charcoal, a pipe and a joint; hammer, shovel | About 100 L of clean water a day, once ripe |
| Brick Filter | Built | Masonry 3: 24 clay bricks, 4 uses of cement, 2 gravel bags, 6 sand bags, 15 charcoal, an iron pipe; mason's trowel, shovel | Four times a Barrel Filter's water |
| Filter Crock (Unfired) | Item, weight 0.5 | Pottery 4 at a pottery wheel: 4 clay, 2 charcoal, 0.5 L of water | Fired at a kiln into a Filter Crock |
| Filter Crock | Item, weight 0.5 | Fired at a kiln: the unfired crock and fuel | Set in a bucket |
| Filter Crock in a bucket | Built | A Filter Crock and an empty bucket | About 10 L of clean water a day |
| Boiler (Stone Firebox) | Built | Masonry 2: Metal Drum, 12 clay bricks or stone blocks, 2 uses of cement, 2 iron pipes; mason's trowel, pipe wrench | About 30 L of clean water an hour while its fire keeps it hot |
| Boiler (Welded Firebox) | Built | Welding 3: Metal Drum, 4 small steel sheets, 4 screws, 2 iron pipes, 4 uses of torch and rods; welder mask | The same |
| Wooden Hand Pump | Built | Carpentry 2: 4 planks, 4 nails, 2 plastic pipes, a rubber hose, a seal; hammer, saw, any drill | Lifts about 6 L a minute from a well, barrel, trough or river into a tank up to a level above |
| Iron Hand Pump | Built | Welding 3: 2 iron pipes, 2 small steel sheets, 4 screws, a rubber hose, a seal, 2 uses of torch and rods; welder mask, hand drill | Lifts about 8 L a minute, into a tank up to two levels above |
| Pump House (Wood, Sheet Metal) | Built | Carpentry 2 or Welding 1, and Electricity 1: planks and nails or steel sheets and screws, 2 electrical wires, 2 rubber hoses; screwdriver (and hammer) | Takes a pump part and runs it on power |
| Garden line tile | Laid | One tile of pipe and its joint | Carries water; holed, it waters the plant on its square |
| Tap | Fitted to a line tile | A Pipe Wrench, one length of pipe and its joint | Where you run the line |
| Buried pipe | Plumbed between tanks, from a tank to a fixture, into and out of a filter or boiler, or out of a pump into a tank or a line | 1 length of pipe per 3 tiles, with joints; none for vanilla's Plumb | Moves water between tanks, into a fixture, through a filter or boiler, or from a pump |
| Plumbed fixture | A vanilla sink, bath, shower, toilet or washer | Plumb to Tank, or vanilla's Plumb | Holds its tank's water for vanilla's drink, fill, wash and washer |

Everything else is vanilla:

| Vanilla item | Used for |
|---|---|
| Plastic, Iron and Lead Pipe; Clay Pipe Segments | Lines, taps, buried pipe and a filter's outlet; plastic and iron pipe build the hand pumps; an iron pipe makes a sprinkler |
| Glue, Epoxy, Duct Tape | Joints in plastic pipe; patching any crack; the Barrel Filter's outlet |
| Bucket of Clay Cement or Concrete | Joints in clay pipe; the Brick Filter; the stone-firebox Boiler |
| Pipe Wrench | Laying iron or lead line, Fit Tap, Set and Take Sprinkler, Fit and Take Off Valve, Plumb to Tank, Plumb Inlet and Outlet, a pump's Plumb Outlet, vanilla's Plumb, Unplumb; the stone-firebox Boiler; Make Timer Valve |
| Hand Drill, Auger Drill, awls, Stone Drill, hammer and nails | Drill Holes; a drill builds the Wooden Hand Pump, a Hand Drill the Iron one and makes a sprinkler |
| Rain barrel | Set on a Tank Stand |
| Sand Bag, Gravel Bag, Charcoal, Clay Bricks | The filters |
| Clay, Charcoal; a pottery wheel and a kiln | Making the Filter Crock |
| Bucket, of any kind | Under the Filter Crock |
| Clay Jar | Research it to learn the Filter Crock |
| Metal Drum | The boiler's drum; research it to learn the boilers |
| Clay Bricks or Stone Blocks, Iron Pipe | The stone-firebox Boiler |
| Small Steel Sheet, Screws, Welding Torch, Welding Rods, Welder Mask | The welded-firebox Boiler; Patch Drum; the Iron Hand Pump; screws for Make Pipe Sprinkler |
| Empty Gardening Spray Can | A made sprinkler's head |
| Rubber Hose | A hand pump's intake; a Wind-up Valve |
| Leather Strips, Tire Piece, Tarp Piece, Plunger | A hand pump's seal; the Plunger only through Replace Seal |
| Screwdriver | Replace Seal; Pump Houses, Fit and Take Out Pump, Repair Pump, Salvage Pump; the valves |
| Pliers | Salvage Pump; Make Pipe Sprinkler; Make Timer Valve |
| Electrical Wire, Scrap Electronics, Blower Fan | Pump Houses; Repair Pump; Make Utility Pump; Make Timer Valve |
| Kitchen Timer, Alarm Clock | Make Wind-up Valve; Make Timer Valve |
| Well, forest hand pump, river or pond, water trough | Water for a hand pump |
| Logs, planks and anything else vanilla burns; a lighter or matches and tinder | Fuelling and lighting a boiler, as any vanilla fire |
| Shovel, garden trowel, mason's trowel | Building the filters and the stone-firebox Boiler; Clean Filter |

## Where to look

### Loot

| What | Where to look | How often |
|---|---|---|
| *Cisterns for Kentucky* | Garden centres' shelves most of all; farm crates, homesteaders' boxes, hardware stores' farm aisles, libraries' gardening shelves and magazine racks, post offices; less often farm tool cabinets, barn tool crates, garden-centre tools, the Gigamart's farm aisle and libraries' reference shelves | Uncommon: about as often as one of vanilla's farming magazines |
| Utility Pump | Hardware stores' and the Gigamart's tools; less often garage tools and the tool crates of garages and basements; worn, in old tool crates | Rare: about as often as a Blower Fan |
| Lawn Sprinkler | Garden stores' tools and shelves; less often garage tools and the farm and garden crates of sheds, barns and garages; worn, in old tool crates | Rare: a fifth to a tenth as often as an empty gardening spray can |
| Sprinkler Timer | Garden stores' tools and shelves, hardware stores' farm aisle; less often the Gigamart's | Rare: as often as a Lawn Sprinkler |
| Water Valve | Plumbing supplies | Very rare: Salvage Pump is the way to get one |
| Plastic pipe | Hardware stores' plumbing aisle, craft supplies, junk bins | Uncommon |
| Iron pipe | Crates of pipe in warehouses and on building sites, plumbing aisles, plumbers' vans | Common |
| Lead pipe | Plumbing aisles, construction trucks, wherever vanilla keeps melee weapons | Uncommon |
| Clay pipe | Never found: make it at a kiln | |
| Pipe Wrench | Plumbers' and propane trucks, hardware stores' plumbing aisle, old tool crates | Uncommon |

### Places already set up

None. Every stand, line, filter and link is one you build.
