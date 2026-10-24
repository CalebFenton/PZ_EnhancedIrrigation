"""The materials the builders draw with, by name."""
from kit import material


def M(name):
    """The shared materials, made on first use. Pipe materials have no grime: its blotches follow
    each part's own coordinates, so two tiles' halves of one pipe would not match where they meet."""
    return {
        # Black polyethylene drip line and its barbed fittings, dull enough that the sky's
        # reflection doesn't turn a line this thin grey.
        "poly": lambda: material("EI_Poly", "#1e1e20", roughness=0.7, grime=0.0),
        "galvanised": lambda: material("EI_Galvanised", "#858b8f", roughness=0.55, metallic=0.5, grime=0.0),
        "malleable": lambda: material("EI_Malleable", "#6f7478", roughness=0.6, metallic=0.4, grime=0.0),
        # Old lead goes dull grey-blue, its wiped joints' solder a shade darker.
        "lead": lambda: material("EI_Lead", "#5f6875", roughness=0.75, metallic=0.25, grime=0.0),
        "solder": lambda: material("EI_Solder", "#4c535c", roughness=0.6, metallic=0.35, grime=0.0),
        "clay": lambda: material("EI_Clay", "#a85d38", roughness=0.85, grime=0.0),
        "brass": lambda: material("EI_Brass", "#b08d45", roughness=0.4, metallic=0.7, grime=0.1),
        "red": lambda: material("EI_Red", "#b3261e", roughness=0.5, grime=0.1),
        # Logs with their bark on, and planks nailed up outdoors in two shades so boards read apart.
        "bark": lambda: material("EI_Bark", "#5b4633", roughness=0.9, grime=0.35, scale=14, grain="weathered"),
        "logend": lambda: material("EI_LogEnd", "#b08a5c", roughness=0.85, grime=0.3),
        "planks": lambda: material("EI_Planks", "#8a6442", roughness=0.85, grime=0.3, scale=10, grain="weathered"),
        "planksdark": lambda: material("EI_PlanksDark", "#6d4e33", roughness=0.85, grime=0.3, scale=10, grain="weathered"),
        "nail": lambda: material("EI_Nail", "#3b3936", roughness=0.6, metallic=0.5, grime=0.2),
        # The game's rain barrel (carpentry_02_122 and its kin): oak staves, iron hoops, lined with a
        # green garbage bag or an orange tarp tied round under the rim.
        "stave": lambda: material("EI_Stave", "#93582a", roughness=0.75, grime=0.25, scale=10, grain="board"),
        "stavedark": lambda: material("EI_StaveDark", "#7c4720", roughness=0.75, grime=0.25, scale=10, grain="board"),
        "barrelinside": lambda: material("EI_BarrelInside", "#3a2412", roughness=0.9, grime=0.2),
        "hoop": lambda: material("EI_Hoop", "#5c5d63", roughness=0.6, metallic=0.4, grime=0.2),
        "bag": lambda: material("EI_Bag", "#44593b", roughness=0.65, grime=0.35, scale=30),
        "tarp": lambda: material("EI_Tarp", "#d27449", roughness=0.7, grime=0.25, scale=30),
        "cord": lambda: material("EI_Cord", "#2b241f", roughness=0.8, grime=0.1),
        "lid": lambda: material("EI_Lid", "#8d5a2b", roughness=0.8, grime=0.25, scale=10, grain="board"),
        # The sand filters: washed sand, red clay bricks in two shades, and the lime mortar between them,
        # the colours of Renewable Energy's.
        "sand": lambda: material("EI_Sand", "#c9b48a", roughness=0.95, grime=0.2, scale=60, speckle=("#a48f64", 0.4)),
        "brick": lambda: material("EI_Brick", "#a5503a", roughness=0.85, grime=0.2, scale=30),
        "brickdark": lambda: material("EI_BrickDark", "#86412d", roughness=0.85, grime=0.2, scale=30),
        "mortar": lambda: material("EI_Mortar", "#b0aa9c", roughness=0.95, grime=0.2, scale=30),
        # The Filter Crock: unglazed terracotta with the charcoal mixed into its clay showing as faint
        # dark specks, paler and greyer before it is fired; and the game's galvanised pail it stands in.
        "terracotta": lambda: material("EI_Terracotta", "#935b45", roughness=0.9, grime=0.15, scale=50,
                                       speckle=("#654536", 0.35)),
        "rawclay": lambda: material("EI_RawClay", "#978676", roughness=0.95, grime=0.15, scale=50, speckle=("#76695d", 0.35)),
        "pail": lambda: material("EI_Pail", "#a3a8ab", roughness=0.65, metallic=0.4, grime=0.15, scale=20),
        # The boilers: the game's grey steel Metal Drum, its lid a shade bluer, sooted round its foot
        # by the fire under it; the firebox's soot, ash and charred wood, the bricks blackened over its
        # mouth, and the welded box's sheet steel, rust running down it, and its darker angle iron.
        "drum": lambda: material("EI_Drum", "#808283", roughness=0.55, metallic=0.45, grime=0.35, scale=20,
                                 scorch=("#2a2624", "#6e5a45", 0.09)),
        "drumlid": lambda: material("EI_DrumLid", "#7c878b", roughness=0.55, metallic=0.4, grime=0.25, scale=20),
        "drumdark": lambda: material("EI_DrumDark", "#4a4c4e", roughness=0.6, metallic=0.4, grime=0.15),
        "soot": lambda: material("EI_Soot", "#1e1b1a", roughness=0.95, grime=0.2, scale=30),
        "ash": lambda: material("EI_Ash", "#6d6964", roughness=0.95, grime=0.3, scale=60, speckle=("#3a3633", 0.4)),
        "charcoal": lambda: material("EI_Charcoal", "#2a2420", roughness=0.9, grime=0.3, scale=40, speckle=("#4a3a30", 0.3)),
        "brickscorch": lambda: material("EI_BrickScorch", "#4d3229", roughness=0.9, grime=0.3, scale=30),
        "plate": lambda: material("EI_Plate", "#4f5356", roughness=0.6, metallic=0.5, grime=0.35, scale=20,
                                  streaks=("#7d4a2c", 0.45)),
        "ironwork": lambda: material("EI_Ironwork", "#3a3d40", roughness=0.6, metallic=0.5, grime=0.3, scale=20),
        # The pumps: the pale grey of Plastic Pipe, the black of a Rubber Hose and an electric wire's
        # insulation, a leather seal, cast iron gone dark with rust in its creases, a Pump House's sheet
        # steel, lighter than a firebox's plate; the pump parts' white appliance plastic, cast
        # aluminium, a motor's copper winding and its core's laminated iron; a sprinkler's green cap.
        "pvc": lambda: material("EI_PVC", "#cbc9be", roughness=0.5, grime=0.15, scale=20),
        "rubber": lambda: material("EI_Rubber", "#262626", roughness=0.6, grime=0.15, scale=20),
        "insulation": lambda: material("EI_Insulation", "#1f1f21", roughness=0.55, grime=0.1),
        "leather": lambda: material("EI_Leather", "#5a3a24", roughness=0.8, grime=0.2),
        "castiron": lambda: material("EI_CastIron", "#30353a", roughness=0.65, metallic=0.45, grime=0.35, scale=20,
                                     streaks=("#6e4128", 0.3)),
        "sheet": lambda: material("EI_Sheet", "#80868a", roughness=0.55, metallic=0.5, grime=0.35, scale=20,
                                  streaks=("#7d4a2c", 0.3)),
        "appliance": lambda: material("EI_Appliance", "#dcd9cf", roughness=0.5, grime=0.1),
        "alloy": lambda: material("EI_Alloy", "#a6abae", roughness=0.45, metallic=0.6, grime=0.2, scale=30),
        "copper": lambda: material("EI_Copper", "#b4642e", roughness=0.4, metallic=0.7, grime=0.1),
        "lamination": lambda: material("EI_Lamination", "#585d61", roughness=0.5, metallic=0.6, grime=0.15),
        "green": lambda: material("EI_Green", "#3d7034", roughness=0.5, grime=0.1),
        # The pamphlet: cream stock, green ink for the band, brown for the drawing and the type.
        "paper": lambda: material("EI_Paper", "#efe5c6", roughness=0.9, grime=0.05),
        "paperback": lambda: material("EI_PaperBack", "#ddd0ab", roughness=0.9, grime=0.05),
        "inkgreen": lambda: material("EI_InkGreen", "#3d5b36", roughness=0.8, grime=0.05),
        "ink": lambda: material("EI_Ink", "#3a2a1c", roughness=0.8, grime=0.05),
    }[name]()
