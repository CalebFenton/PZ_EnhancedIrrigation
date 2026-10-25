"""The Cycles shader node graphs the palette's materials and the wet soil's stain are drawn with."""
import math

import bpy


def hex_rgb(value):
    """'#rrggbb' to linear RGB, so the palette's colours read like the sRGB values of a paint chip."""
    def channel(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(channel(int(value[i:i + 2], 16)) for i in (1, 3, 5))


def _principled(material):
    if not material.node_tree:
        material.use_nodes = True
    nodes = material.node_tree.nodes
    return nodes, nodes.get("Principled BSDF") or nodes.new("ShaderNodeBsdfPrincipled")


_MATERIALS = {}

# Wood grain, by kind: the size across the grain of the figure the grain lines follow (metres),
# how many times longer it runs along the grain, how many lines cross one figure, and how dark a
# line is. Boards are sawn, so their grain runs in long straight streaks. Weathered planks, as the
# game draws its own crates and composters, are dark with grain cut deep by the rain.
GRAIN = {"board": (0.08, 12.0, 3.0, 0.5), "weathered": (0.05, 14.0, 4.0, 0.3)}
GRAIN_EARLY = 1.1  # the pale wood between grain lines


def _math(nodes, links, operation, a, b=None, c=None, clamp=False):
    """A math node on sockets or numbers, returning its output socket."""
    node = nodes.new("ShaderNodeMath")
    node.operation = operation
    node.use_clamp = clamp
    for i, value in enumerate((a, b, c)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            node.inputs[i].default_value = value
        else:
            links.new(value, node.inputs[i])
    return node.outputs[0]


def material(name, color, roughness=0.6, metallic=0.0, grime=0.12, scale=40.0, speckle=None, grain=None, streaks=None,
             scorch=None):
    """A painted, plastic or metal surface. `grime` darkens it in blotches, so flat colours don't
    look like a render. `speckle` = (colour, amount) mottles it with a second colour in a web of
    flakes, the base colour left at each flake's centre and less of it the higher `amount`: the way
    sand and ash are flecked with darker grains. `streaks` = (colour, amount) runs that
    colour down its sides in thin streaks, as rust and soot run down a drum left out in the rain.
    `scorch` = (soot, tint, height) blackens it from its foot up to a ragged line `height` metres
    up, with a band of heat tint above, as a fire inside leaves a stove. `grain`, a kind in GRAIN,
    draws dark grain lines along each part's longest side, as kit's `_object` laid them out."""
    if name in _MATERIALS:
        return _MATERIALS[name]
    mat = bpy.data.materials.new(name)
    nodes, bsdf = _principled(mat)
    links = mat.node_tree.links
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    base = (*hex_rgb(color), 1.0)
    coords = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale / 8
    noise.inputs["Detail"].default_value = 6.0
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (1 - grime, 1 - grime, 1 - grime, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs[6].default_value = base
    links.new(ramp.outputs["Color"], tint.inputs[7])
    color_out = tint.outputs[2]
    if speckle:
        flakes = nodes.new("ShaderNodeTexVoronoi")
        flakes.inputs["Scale"].default_value = scale * 6
        links.new(coords.outputs["Object"], flakes.inputs["Vector"])
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        steps = nodes.new("ShaderNodeMath")
        steps.operation = "MULTIPLY"
        steps.inputs[1].default_value = speckle[1]
        links.new(flakes.outputs["Distance"], steps.inputs[0])
        links.new(steps.outputs[0], mix.inputs["Factor"])
        links.new(color_out, mix.inputs[6])
        mix.inputs[7].default_value = (*hex_rgb(speckle[0]), 1.0)
        color_out = mix.outputs[2]
    if streaks:
        # Noise squeezed tall: its features run down the part's local Z, and only its peaks show.
        squeeze = nodes.new("ShaderNodeVectorMath")
        squeeze.operation = "MULTIPLY"
        squeeze.inputs[1].default_value = (1.0, 1.0, 0.06)
        links.new(coords.outputs["Object"], squeeze.inputs[0])
        runs = nodes.new("ShaderNodeTexNoise")
        runs.inputs["Scale"].default_value = scale * 1.5
        runs.inputs["Detail"].default_value = 4.0
        links.new(squeeze.outputs[0], runs.inputs["Vector"])
        peaks = nodes.new("ShaderNodeValToRGB")
        peaks.color_ramp.elements[0].position = 0.5
        peaks.color_ramp.elements[0].color = (0, 0, 0, 1)
        peaks.color_ramp.elements[1].position = 0.75
        peaks.color_ramp.elements[1].color = (streaks[1], streaks[1], streaks[1], 1)
        links.new(runs.outputs["Fac"], peaks.inputs["Fac"])
        # Only down the sides: rain runs down a wall, not across a lid.
        normal = nodes.new("ShaderNodeNewGeometry")
        axes = nodes.new("ShaderNodeSeparateXYZ")
        links.new(normal.outputs["Normal"], axes.inputs[0])
        flat = _math(nodes, links, "ABSOLUTE", axes.outputs["Z"])
        side = _math(nodes, links, "SUBTRACT", 1.0, flat)
        amount = _math(nodes, links, "MULTIPLY", peaks.outputs["Color"], side)
        run = nodes.new("ShaderNodeMix")
        run.data_type = "RGBA"
        links.new(amount, run.inputs["Factor"])
        links.new(color_out, run.inputs[6])
        run.inputs[7].default_value = (*hex_rgb(streaks[0]), 1.0)
        color_out = run.outputs[2]
    if scorch:
        # Soot up to a ragged line `scorch[2]` above the part's foot, and a band of heat tint above it.
        soot, tint, height = scorch
        axes = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coords.outputs["Object"], axes.inputs[0])
        ragged = nodes.new("ShaderNodeTexNoise")
        ragged.inputs["Scale"].default_value = 9.0
        ragged.inputs["Detail"].default_value = 3.0
        links.new(coords.outputs["Object"], ragged.inputs["Vector"])
        wobble = _math(nodes, links, "MULTIPLY_ADD", ragged.outputs["Fac"], 0.16, -0.08)
        level = _math(nodes, links, "ADD", axes.outputs["Z"], wobble)
        below = _math(nodes, links, "SUBTRACT", height, level)
        sooted = _math(nodes, links, "MULTIPLY", below, 20.0, clamp=True)
        above = _math(nodes, links, "SUBTRACT", level, height + 0.05)
        band = _math(nodes, links, "ABSOLUTE", above)
        tinted = _math(nodes, links, "MULTIPLY_ADD", band, -12.0, 0.7, clamp=True)
        for factor, colour in ((tinted, tint), (sooted, soot)):
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            links.new(factor, mix.inputs["Factor"])
            links.new(color_out, mix.inputs[6])
            mix.inputs[7].default_value = (*hex_rgb(colour), 1.0)
            color_out = mix.outputs[2]
    if grain:
        across, stretch, lines, line = GRAIN[grain]
        attribute = nodes.new("ShaderNodeAttribute")
        attribute.attribute_name = "grain"
        along = nodes.new("ShaderNodeVectorMath")
        along.operation = "MULTIPLY"
        along.inputs[1].default_value = (1 / stretch, 1, 1)
        links.new(attribute.outputs["Vector"], along.inputs[0])
        figure = nodes.new("ShaderNodeTexNoise")
        figure.inputs["Scale"].default_value = 1 / across
        figure.inputs["Detail"].default_value = 2.0
        links.new(along.outputs[0], figure.inputs["Vector"])
        # The figure's contour lines: up and down `lines` times over its range, a dark line at each
        # low.
        count = nodes.new("ShaderNodeMath")
        count.operation = "MULTIPLY"
        count.inputs[1].default_value = lines * 2
        links.new(figure.outputs["Fac"], count.inputs[0])
        wave = nodes.new("ShaderNodeMath")
        wave.operation = "PINGPONG"
        wave.inputs[1].default_value = 1.0
        links.new(count.outputs[0], wave.inputs[0])
        shade = nodes.new("ShaderNodeValToRGB")
        shade.color_ramp.elements[0].position = 0.0
        shade.color_ramp.elements[0].color = (line, line, line, 1)
        shade.color_ramp.elements[1].position = 0.3
        shade.color_ramp.elements[1].color = (1, 1, 1, 1)
        early = shade.color_ramp.elements.new(1.0)
        early.color = (GRAIN_EARLY, GRAIN_EARLY, GRAIN_EARLY, 1)
        links.new(wave.outputs[0], shade.inputs["Fac"])
        streaked = nodes.new("ShaderNodeMix")
        streaked.data_type = "RGBA"
        streaked.blend_type = "MULTIPLY"
        streaked.inputs["Factor"].default_value = 1.0
        links.new(color_out, streaked.inputs[6])
        links.new(shade.outputs["Color"], streaked.inputs[7])
        color_out = streaked.outputs[2]
    links.new(color_out, bsdf.inputs["Base Color"])
    _MATERIALS[name] = mat
    return mat


def _periodic_noise(nodes, links, axes, scale, detail, variant):
    """Noise over a tile's floor that repeats every metre along X and Y, so it matches itself
    across the edge between two tiles, as long as `variant` is 0. Each axis is wrapped round a
    circle a metre round, which keeps the noise's size per metre; `variant` moves the whole
    pattern somewhere else."""
    tau = 2 * math.pi
    parts = []
    for axis in ("X", "Y"):
        angle = _math(nodes, links, "MULTIPLY", axes.outputs[axis], tau)
        for operation in ("COSINE", "SINE"):
            parts.append(_math(nodes, links, "MULTIPLY_ADD", _math(nodes, links, operation, angle), 1 / tau,
                               variant * 7.31))
    point = nodes.new("ShaderNodeCombineXYZ")
    for i in range(3):
        links.new(parts[i], point.inputs[i])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "4D"
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    links.new(point.outputs[0], noise.inputs["Vector"])
    links.new(parts[3], noise.inputs["W"])
    return noise.outputs["Fac"]


def _tile_noise(nodes, links, axes, scale, detail, variant, inland):
    """Periodic noise near the tile's edges, where neighbouring tiles must match, blending by
    `inland` (0 at the edges, 1 in the middle) into the same noise moved by `variant`, so tiles
    don't all show the same blotches."""
    edge = _periodic_noise(nodes, links, axes, scale, detail, 0)
    middle = _periodic_noise(nodes, links, axes, scale, detail, variant)
    return _math(nodes, links, "MULTIPLY_ADD", _math(nodes, links, "SUBTRACT", middle, edge), inland, edge)


def stain(name, color, arms, centre, near, far, softness, ragged, opacity, scale=6.0, variant=1):
    """A flat patch lying on a tile's floor that draws as `color` whatever the light: wet soil,
    which the game's grass shows through at the edge. It covers a round patch `centre` metres
    across round the tile's middle and a band along each of `arms` (unit (x, y) directions) out to
    the tile's edge, `near` metres to either side at the middle narrowing to `far` at the edge.
    It is opaque inside and fades out over `softness` metres, its edge moved in and out by up to
    `ragged` metres of noise. A band leaves the tile as its neighbour's band of the opposite arm
    comes in, noise and all, so the patches of a run of wet tiles join into one strip, while a
    tile alone narrows to a neck at each edge rather than ending square. It is unlit because the
    floor it darkens is lit by the game, and a lit surface this large takes grain from the
    render's samples."""
    if name in _MATERIALS:
        return _MATERIALS[name]
    mat = bpy.data.materials.new(name)
    if not mat.node_tree:
        mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    for node in list(nodes):
        if node.type != "OUTPUT_MATERIAL":
            nodes.remove(node)
    coords = nodes.new("ShaderNodeTexCoord")
    axes = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coords.outputs["Object"], axes.inputs[0])
    flat = nodes.new("ShaderNodeCombineXYZ")
    links.new(axes.outputs["X"], flat.inputs[0])
    links.new(axes.outputs["Y"], flat.inputs[1])
    length = nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    links.new(flat.outputs[0], length.inputs[0])
    # How far outside the patch each point is, in metres: the least of the round patch's and each
    # band's. A band's half width shrinks from `near` to `far` along it; behind the middle the
    # round patch covers.
    outside = _math(nodes, links, "SUBTRACT", length.outputs["Value"], centre / 2)
    for dx, dy in arms:
        along = _math(nodes, links, "MULTIPLY", axes.outputs["X" if dx else "Y"], dx or dy)
        across = _math(nodes, links, "ABSOLUTE", axes.outputs["Y" if dx else "X"])
        way = _math(nodes, links, "MULTIPLY", along, 2.0, clamp=True)
        half = _math(nodes, links, "MULTIPLY_ADD", way, far - near, near)
        band = _math(nodes, links, "MAXIMUM", _math(nodes, links, "SUBTRACT", across, half),
                     _math(nodes, links, "MULTIPLY", along, -1.0))
        outside = _math(nodes, links, "MINIMUM", outside, band)
    # 0 at the tile's edges, where neighbours must match, rising to 1 inland.
    reach = _math(nodes, links, "MAXIMUM", _math(nodes, links, "ABSOLUTE", axes.outputs["X"]),
                  _math(nodes, links, "ABSOLUTE", axes.outputs["Y"]))
    inland = _math(nodes, links, "MULTIPLY", _math(nodes, links, "SUBTRACT", 0.45, reach), 1 / 0.15, clamp=True)
    jag = _tile_noise(nodes, links, axes, scale, 1.5, variant, inland)
    edge = _math(nodes, links, "ADD", outside, _math(nodes, links, "MULTIPLY_ADD", jag, ragged, -ragged / 2))
    fade = _math(nodes, links, "DIVIDE", edge, -softness, clamp=True)
    alpha = _math(nodes, links, "MULTIPLY", fade, opacity)
    # Darker in blotches, as soil dries unevenly.
    blotch = _tile_noise(nodes, links, axes, scale * 2, 1.0, variant, inland)
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[0].color = (0.75, 0.75, 0.75, 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (1.15, 1.15, 1.15, 1)
    links.new(blotch, ramp.inputs["Fac"])
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs[6].default_value = (*hex_rgb(color), 1.0)
    links.new(ramp.outputs["Color"], tint.inputs[7])
    glow = nodes.new("ShaderNodeEmission")
    glow.inputs["Strength"].default_value = 1.0
    links.new(tint.outputs[2], glow.inputs["Color"])
    clear = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(alpha, mix.inputs["Fac"])
    links.new(clear.outputs[0], mix.inputs[1])
    links.new(glow.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], nodes.get("Material Output").inputs["Surface"])
    _MATERIALS[name] = mat
    return mat
