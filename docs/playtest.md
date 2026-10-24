# Playtest list

What the in-game tests can't settle: what only a person playing can hear, see or judge. Each entry says what to check, how to set it up, and what passes. Tick an entry off by deleting it, with a line in the commit saying what you found; a finding that needs a change goes in as a fix.

Set up with `dev/run-debug-client.sh`, then main menu > Scenarios > **Enhanced Irrigation QA** (see `AGENTS.md`), unless an entry says otherwise. Play at default sandbox settings unless the entry names one.

## Zombies and sound

- **A hand pump draws zombies.** Work a Wooden Hand Pump, then an Iron one, with zombies about 10 and 20 tiles off (debug: spawn them). Pass: the wooden pump's squeal brings the near ones and some of the far ones; the iron pump brings the near ones only. The code sends noise every run: wooden radius 15, iron 8.
- **The pumps sound right.** Wooden pump: water plus a creak (the mod's sound aliases vanilla's wooden door creak) the whole time it's worked. Iron pump: water only. Pass: you can tell them apart, the creak doesn't stutter or stack, and both stop when the action ends.
- **A Pump House hums and draws zombies.** Switch one on (grid power beside a house, or a generator). Pass: a motor loop (vanilla's gas pump ambience) plays while it runs, stops when it's switched off, burns out or loses power, and starts again for a player who walks back into range. Zombies within 10 tiles (Appliance Pump) or 20 (Utility Pump) come over in time.
- **The open tap sounds.** Water from Tank plays vanilla's watering sound and stops when the tap closes.
- **A valve's water sounds.** Wind a Wind-up Valve for 5 minutes and walk off a few tiles, then come back. Pass: the watering sound plays at the tap, without gaps or stacking, while it runs and stops when it shuts; a player who walks into range hears it start.
- **A Pump House on its timer.** Set a timer on a switched-off house to open at the next hour for 10 minutes, and wait for it. Pass: the hum starts within a game minute of the hour and stops within a minute of the window's end, and zombies hear it only while it hums.

## How it plays

- **The summer-and-frost garden.** The design's playtest (`docs/design.md`, Starting numbers): a 40-plant greenhouse through a summer and the first frost, watered by a line from a raised barrel, then by a pumped line with sprinklers. Pass: about six minutes at the tap a day keeps the beds level; soak and root rot show before they kill; a line left full splits in a hard freeze about as often as the design says; the work feels like upkeep, not a grind.
- **Setting a timer by watching the soil.** Hold a tap and note how long the beds take to read Damp; set a Timer Valve to that, then to three times that, and leave each a week. Pass: the first keeps the beds healthy; the second shows Soaked, then Waterlogged, before the plants sicken; a player could tell which to pick from the menu and the plant info alone.
- **The valve panels.** Wind a Wind-up Valve and set a timer, by mouse and with a controller. Pass: the knob turns as the oven's does, the hour steps both ways and wraps past midnight, the refusal line is readable, and the panel closes when you walk off.
- **Beds of different ages on one line.** One dry bed and one full bed on the same line: filling the dry one soaks the full one. Pass or fail is a balance call: is the soak a fair price, or does it kill too easily?
- **Hand pumping is hard work.** Fill a 600 L barrel with each hand pump at default Day Length. Pass: about 75 to 100 game minutes; the character tires and stops at Exhausted before the barrel is full from rest, and the tired moodle shows. The exhausted stop depends on the endurance cost outrunning what standing still gives back, which varies with Day Length.
- **Pump House power off the grid.** Run a Pump House on a generator through a night. Pass: the generator's fuel falls faster than with nothing plugged in, and the house stops when the fuel runs out. With Renewable Energy loaded (no automated test loads both mods), a battery bank in reach and no generator: the bank's status lists **Pump House** with its watts while it's switched on or its timer is open, and not once it's off; its charge falls faster than with the house off; a Utility Pump on a lone plug-in inverter overloads it and the bank stays cut until the house is switched off; with a generator also in reach, the generator pays and the bank doesn't list it.
- **The boiler's fire.** Light a boiler with vanilla's Light, fuel it, put it out. Pass: the flames look like they belong to the firebox (they sit slightly in front of the drum), and in multiplayer the Light and Put Out actions ending early (vanilla's own behaviour) don't confuse.

## Not covered by any test

- **Troughs as a source.** Put a feeding trough with water beside a hand pump and pump into a tank. Pass: the trough's water falls by what the tank gains and other players see it fall; a trough holding feed gives nothing.
- **The forest pump tiles as a well.** A hand pump beside vanilla's forest water pump (`camping_01_64` to `67`). Pass: it draws clean water without end.
- **The welded boiler and the welding mask.** Build the welded-firebox Boiler with the mask carried but not worn. Pass or fail: say which the build menu accepts, and whether that matches vanilla's welding builds.
- **A stripped washer moved.** Salvage a washer's pump, pick the washer up, put it down elsewhere. Pass: it still won't switch on and says its pump has been salvaged.
- **Other mods' sinks.** With a mod that adds sink tiles, plumb one to a tank. Old saves' plumbed sinks of other mods keep vanilla's plumbing until plumbed again; check that's all that happens.
- **A plumbed filter across a real absence.** Plumb a Barrel Filter's inlet from a full raw barrel and its outlet to an empty lidded barrel, walk far enough that all three unload (in single player), wait two in-game days, and come back. Pass: the clean barrel holds about 4 L for every hour you were away, up to what the raw barrel and the head held; the filter's basin isn't standing full; its menu still says Ripe. The tests wind the record's clock back with the chunks loaded, so none sees the three chunks load in their own order.
- **Vanilla's Plumb on a bath.** In a house after the shutoff, set a rain barrel of tainted water on the floor above the far half of a bath, one square beyond it, and use vanilla's Plumb on the near half, then on the far half. Pass: Plumb is offered on both and both jobs finish rather than stopping as out of reach; each half then serves the barrel's water tainted. Say whether plumbing each half on its own reads right to a player, as vanilla also plumbs them one at a time.

## Art

- **Icons at inventory size.** The Appliance Pump icon read only moderately at 32 px when it was made. Pass: you can tell the Appliance Pump, Utility Pump and Lawn Sprinkler apart in a full inventory.
- **The pumps and sprinklers in the world.** Place each pump, both Pump Houses and a sprinkler on a line. Pass: their scale beside a rain barrel looks right, the character walks behind them without drawing order glitches, and the sprinkler doesn't hide the pipe.
- **The valves on a tap.** Fit each valve to a tap. Pass: each is visible and tellable apart at default zoom (the overlays are small, hung off the spout), and none floats off the tap or draws over a character in front.
