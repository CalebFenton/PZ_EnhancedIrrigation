"""The materials the builders draw with, by name."""

# Pipe materials have no grime: its blotches follow each part's own coordinates, so two tiles'
# halves of one pipe would not match where they meet.
PALETTE = {
    # Black polyethylene drip line and its barbed fittings, dull enough that the sky's
    # reflection doesn't turn a line this thin grey.
    "poly": dict(name="EI_Poly", color="#1e1e20", roughness=0.7, grime=0.0),
    "galvanised": dict(name="EI_Galvanised", color="#858b8f", roughness=0.55, metallic=0.5, grime=0.0),
    "malleable": dict(name="EI_Malleable", color="#6f7478", roughness=0.6, metallic=0.4, grime=0.0),
    # Old lead goes dull grey-blue, its wiped joints' solder a shade darker.
    "lead": dict(name="EI_Lead", color="#5f6875", roughness=0.75, metallic=0.25, grime=0.0),
    "solder": dict(name="EI_Solder", color="#4c535c", roughness=0.6, metallic=0.35, grime=0.0),
    "clay": dict(name="EI_Clay", color="#a85d38", roughness=0.85, grime=0.0),
    "brass": dict(name="EI_Brass", color="#b08d45", roughness=0.4, metallic=0.7, grime=0.1),
    "red": dict(name="EI_Red", color="#b3261e", roughness=0.5, grime=0.1),
    # Logs with their bark on, and planks nailed up outdoors in two shades so boards read apart.
    "bark": dict(name="EI_Bark", color="#5b4633", roughness=0.9, grime=0.35, scale=14, grain="weathered"),
    "logend": dict(name="EI_LogEnd", color="#b08a5c", roughness=0.85, grime=0.3),
    "planks": dict(name="EI_Planks", color="#8a6442", roughness=0.85, grime=0.3, scale=10, grain="weathered"),
    "planksdark": dict(name="EI_PlanksDark", color="#6d4e33", roughness=0.85, grime=0.3, scale=10, grain="weathered"),
    "nail": dict(name="EI_Nail", color="#3b3936", roughness=0.6, metallic=0.5, grime=0.2),
    # The game's rain barrel (carpentry_02_122 and its kin): oak staves, iron hoops, lined with a
    # green garbage bag or an orange tarp tied round under the rim.
    "stave": dict(name="EI_Stave", color="#93582a", roughness=0.75, grime=0.25, scale=10, grain="board"),
    "stavedark": dict(name="EI_StaveDark", color="#7c4720", roughness=0.75, grime=0.25, scale=10, grain="board"),
    "barrelinside": dict(name="EI_BarrelInside", color="#3a2412", roughness=0.9, grime=0.2),
    "hoop": dict(name="EI_Hoop", color="#5c5d63", roughness=0.6, metallic=0.4, grime=0.2),
    "bag": dict(name="EI_Bag", color="#44593b", roughness=0.65, grime=0.35, scale=30),
    "tarp": dict(name="EI_Tarp", color="#d27449", roughness=0.7, grime=0.25, scale=30),
    "cord": dict(name="EI_Cord", color="#2b241f", roughness=0.8, grime=0.1),
    "lid": dict(name="EI_Lid", color="#8d5a2b", roughness=0.8, grime=0.25, scale=10, grain="board"),
    # The sand filters: washed sand, red clay bricks in two shades, and the lime mortar between them,
    # the colours of Renewable Energy's.
    "sand": dict(name="EI_Sand", color="#c9b48a", roughness=0.95, grime=0.2, scale=60, speckle=("#a48f64", 0.4)),
    "brick": dict(name="EI_Brick", color="#a5503a", roughness=0.85, grime=0.2, scale=30),
    "brickdark": dict(name="EI_BrickDark", color="#86412d", roughness=0.85, grime=0.2, scale=30),
    "mortar": dict(name="EI_Mortar", color="#b0aa9c", roughness=0.95, grime=0.2, scale=30),
    # The Filter Crock: unglazed terracotta with the charcoal mixed into its clay showing as faint
    # dark specks, paler and greyer before it is fired; and the game's galvanised pail it stands in.
    "terracotta": dict(name="EI_Terracotta", color="#935b45", roughness=0.9, grime=0.15, scale=50,
                       speckle=("#654536", 0.35)),
    "rawclay": dict(name="EI_RawClay", color="#978676", roughness=0.95, grime=0.15, scale=50, speckle=("#76695d", 0.35)),
    "pail": dict(name="EI_Pail", color="#a3a8ab", roughness=0.65, metallic=0.4, grime=0.15, scale=20),
    # The boilers: the game's grey steel Metal Drum, its lid a shade bluer, sooted round its foot
    # by the fire under it; the firebox's soot, ash and charred wood, the bricks blackened over its
    # mouth, and the welded box's sheet steel, rust running down it, and its darker angle iron.
    "drum": dict(name="EI_Drum", color="#808283", roughness=0.55, metallic=0.45, grime=0.35, scale=20,
                 scorch=("#2a2624", "#6e5a45", 0.09)),
    "drumlid": dict(name="EI_DrumLid", color="#7c878b", roughness=0.55, metallic=0.4, grime=0.25, scale=20),
    "drumdark": dict(name="EI_DrumDark", color="#4a4c4e", roughness=0.6, metallic=0.4, grime=0.15),
    "soot": dict(name="EI_Soot", color="#1e1b1a", roughness=0.95, grime=0.2, scale=30),
    "ash": dict(name="EI_Ash", color="#6d6964", roughness=0.95, grime=0.3, scale=60, speckle=("#3a3633", 0.4)),
    "charcoal": dict(name="EI_Charcoal", color="#2a2420", roughness=0.9, grime=0.3, scale=40, speckle=("#4a3a30", 0.3)),
    "brickscorch": dict(name="EI_BrickScorch", color="#4d3229", roughness=0.9, grime=0.3, scale=30),
    "plate": dict(name="EI_Plate", color="#4f5356", roughness=0.6, metallic=0.5, grime=0.35, scale=20,
                  streaks=("#7d4a2c", 0.45)),
    "ironwork": dict(name="EI_Ironwork", color="#3a3d40", roughness=0.6, metallic=0.5, grime=0.3, scale=20),
    # The pumps: the pale grey of Plastic Pipe, the black of a Rubber Hose and an electric wire's
    # insulation, a leather seal, cast iron gone dark with rust in its creases, a Pump House's sheet
    # steel, lighter than a firebox's plate; the pump parts' white appliance plastic, cast
    # aluminium, a motor's copper winding and its core's laminated iron; a sprinkler's green cap.
    "pvc": dict(name="EI_PVC", color="#cbc9be", roughness=0.5, grime=0.15, scale=20),
    "rubber": dict(name="EI_Rubber", color="#262626", roughness=0.6, grime=0.15, scale=20),
    "insulation": dict(name="EI_Insulation", color="#1f1f21", roughness=0.55, grime=0.1),
    "leather": dict(name="EI_Leather", color="#5a3a24", roughness=0.8, grime=0.2),
    "castiron": dict(name="EI_CastIron", color="#30353a", roughness=0.65, metallic=0.45, grime=0.35, scale=20,
                     streaks=("#6e4128", 0.3)),
    "sheet": dict(name="EI_Sheet", color="#80868a", roughness=0.55, metallic=0.5, grime=0.35, scale=20,
                  streaks=("#7d4a2c", 0.3)),
    "appliance": dict(name="EI_Appliance", color="#dcd9cf", roughness=0.5, grime=0.1),
    "alloy": dict(name="EI_Alloy", color="#a6abae", roughness=0.45, metallic=0.6, grime=0.2, scale=30),
    "copper": dict(name="EI_Copper", color="#b4642e", roughness=0.4, metallic=0.7, grime=0.1),
    "lamination": dict(name="EI_Lamination", color="#585d61", roughness=0.5, metallic=0.6, grime=0.15),
    "green": dict(name="EI_Green", color="#3d7034", roughness=0.5, grime=0.1),
    # The pamphlet: cream stock, green ink for the band, brown for the drawing and the type.
    "paper": dict(name="EI_Paper", color="#efe5c6", roughness=0.9, grime=0.05),
    "paperback": dict(name="EI_PaperBack", color="#ddd0ab", roughness=0.9, grime=0.05),
    "inkgreen": dict(name="EI_InkGreen", color="#3d5b36", roughness=0.8, grime=0.05),
    "ink": dict(name="EI_Ink", color="#3a2a1c", roughness=0.8, grime=0.05),
}


def M(name):
    """The material of PALETTE called `name`, made on first use."""
    # Imported here so mod_icon.py, which runs without Blender, can read the colours.
    from shading import material
    return material(**PALETTE[name])
