"""Geometry and material helpers shared by the builders in items.py, and the stage and pixel helpers
that render.py and preview.py share.

Units are metres and the scene is Blender's: +Z up. An item is built standing on z = 0, centred on
the origin, with its front facing -Y. In a tile, -Y is south and +X east (Blender's +Y is the
game's north, because the game's y axis points south).
"""
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# Materials ----------------------------------------------------------------------------------------


def hex_rgb(value):
    """'#rrggbb' to linear RGB, so the colours below read like the sRGB values of a paint chip."""
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
    multicrystalline cells sparkle, or rust on scrap steel. `streaks` = (colour, amount) runs that
    colour down its sides in thin streaks, as rust and soot run down a drum left out in the rain.
    `scorch` = (soot, tint, height) blackens it from its foot up to a ragged line `height` metres
    up, with a band of heat tint above, as a fire inside leaves a stove. `grain`, a kind in GRAIN,
    draws dark grain lines along each part's longest side, as `_object` laid them out."""
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
    # 0 within a twentieth of a metre of an edge, where tiles meet, rising to 1 inside 0.3.
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


# Directions ---------------------------------------------------------------------------------------


def heading(degrees):
    """The level unit vector `degrees` from east, anticlockwise seen from above."""
    return Vector((math.cos(math.radians(degrees)), math.sin(math.radians(degrees)), 0))


def circle(radius, z, step=10):
    """Points round a level circle of `radius` at height `z`, every `step` degrees, closed: its first
    point repeated at its end, for a tube round it."""
    return [(radius * math.cos(math.radians(a)), radius * math.sin(math.radians(a)), z) for a in range(0, 361, step)]


# Meshes -------------------------------------------------------------------------------------------


# Each mesh carries its own wood grain coordinates (attribute "grain"): its vertices' positions
# turned so its longest side runs along X, where a grain material stretches its figure, and moved by
# an offset of its own, so boards side by side don't match. They stay in the part's frame, so the
# grain follows each board however it is placed.
_grain_offsets = random.Random(0)


def _object(name, bm, mat, collection):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    extent = [max(v.co[i] for v in bm.verts) - min(v.co[i] for v in bm.verts) for i in range(3)]
    axes = sorted(range(3), key=lambda i: -extent[i])
    offset = Vector([_grain_offsets.uniform(-20, 20) for _ in range(3)])
    layer = bm.verts.layers.float_vector.new("grain")
    for v in bm.verts:
        v[layer] = Vector([v.co[i] for i in axes]) + offset
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def box(collection, name, mat, size, at=(0, 0, 0), bevel=0.0, rotate=None):
    """A box of `size` whose bottom centre is at `at`, optionally rotated (euler degrees) about that
    point. A small bevel catches light along the edges, which keeps low-poly boxes readable."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((0, 0, size[2] / 2)), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) / 2.5), segments=1,
                        affect="EDGES", profile=0.5)
    obj = _object(name, bm, mat, collection)
    place(obj, at, rotate)
    return obj


def beam(collection, name, mat, start, end, section, bevel=0.0):
    """A straight post, board or bar from `start` to `end`, `section` = (width, thickness) across
    it: a box turned the shortest way from upright, so a beam in the YZ plane keeps its width on
    X and one along X stands its width up on Z."""
    start, end = Vector(start), Vector(end)
    run = end - start
    obj = box(collection, name, mat, (section[0], section[1], run.length), bevel=bevel)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(run)
    obj.location = start
    return obj


def _round_sides(bm, ends):
    """Smooth-shades every face but `ends`, and keeps the edges round them sharp: a drum or a pipe
    drawn in flat facets shows vertical bands that the game's own round things don't."""
    for face in bm.faces:
        face.smooth = face not in ends
    for face in ends:
        for edge in face.edges:
            edge.smooth = False


def cylinder(collection, name, mat, radius, height, at=(0, 0, 0), rotate=None, segments=12, radius_top=None):
    """An upright cylinder (or cone, with `radius_top`) whose bottom centre is at `at`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
                          radius2=radius if radius_top is None else radius_top, depth=height)
    bmesh.ops.translate(bm, vec=Vector((0, 0, height / 2)), verts=bm.verts)
    bm.normal_update()
    _round_sides(bm, {face for face in bm.faces if abs(face.normal.z) > 0.999})
    obj = _object(name, bm, mat, collection)
    place(obj, at, rotate)
    return obj


def tube(collection, name, mat, points, radius, sides=6, up=None):
    """A cable or pipe along `points`, with closed ends. `up` holds one side of every ring toward it,
    so a pipe bent in a plane square to `up` doesn't twist round its bends, and two pipes meeting
    end to end on neighbouring tiles have the same rings."""
    points = [Vector(p) for p in points]
    bm = bmesh.new()
    rings = []
    for i, point in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        across = (Vector(up) - tangent * tangent.dot(Vector(up))).normalized() if up else tangent.orthogonal().normalized()
        other = tangent.cross(across)
        rings.append([bm.verts.new(point + (across * math.cos(a) + other * math.sin(a)) * radius)
                      for a in (2 * math.pi * k / sides for k in range(sides))])
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    ends = {bm.faces.new(list(reversed(rings[0]))), bm.faces.new(rings[-1])}
    _round_sides(bm, ends)
    return _object(name, bm, mat, collection)


def lathe(collection, name, mat, profile, segments=24, arc=(0.0, 360.0), at=(0, 0, 0), shape=None, smooth=True):
    """A surface turned about Z through `profile`, a list of (radius, z) points from the bottom up,
    over `arc` degrees (a slice of it, for one barrel stave). `shape(angle, row)` returns a
    (radial, vertical) nudge in metres for each vertex, to crumple a sheet into folds. Open at its
    ends: close it with a profile point at radius 0."""
    whole = arc[1] - arc[0] >= 360
    columns = segments if whole else segments + 1
    bm = bmesh.new()
    rows = []
    for row, (radius, z) in enumerate(profile):
        ring = []
        for k in range(columns):
            angle = arc[0] + (arc[1] - arc[0]) * k / segments
            out, up = shape(angle, row) if shape else (0.0, 0.0)
            a = math.radians(angle)
            ring.append(bm.verts.new(((radius + out) * math.cos(a), (radius + out) * math.sin(a), z + up)))
        rows.append(ring)
    for a, b in zip(rows, rows[1:]):
        for k in range(segments):
            nxt = (k + 1) % columns
            quad = (a[k], a[nxt], b[nxt], b[k])
            # A ring of radius 0 closes the surface: its points are one, so its quads are triangles.
            unique = [v for i, v in enumerate(quad) if all((v.co - w.co).length > 1e-7 for w in quad[:i])]
            if len(unique) >= 3:
                bm.faces.new(unique)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    for face in bm.faces:
        face.smooth = smooth
    bm.normal_update()
    obj = _object(name, bm, mat, collection)
    place(obj, at)
    return obj


def profile_radius(profile, z):
    """The radius of a lathe `profile` at height `z`, held at its end radii beyond its ends."""
    if z < profile[0][1]:
        return profile[0][0]
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z0 <= z <= z1 and z0 < z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return profile[-1][0]


def text(collection, name, mat, body, size, at=(0, 0, 0), rotate=(90, 0, 0), align="CENTER"):
    """Flat lettering as a mesh, by default standing upright and reading from the front (-Y), its
    baseline centre at `at`. Lift it a millimetre off the surface it is printed on."""
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = align
    curve.align_y = "BOTTOM_BASELINE"
    curve.resolution_u = 3
    temp = bpy.data.objects.new(name + "_curve", curve)
    collection.objects.link(temp)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(temp.evaluated_get(depsgraph))
    bpy.data.objects.remove(temp)
    bpy.data.curves.remove(curve)
    mesh.materials.clear()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    place(obj, at, rotate)
    return obj


def place(obj, at, rotate=None):
    obj.location = Vector(at)
    if rotate:
        obj.rotation_euler = [math.radians(a) for a in rotate]
    return obj


def group(collection, name, objects, at=(0, 0, 0), rotate=None):
    """Moves and turns several parts as one, through a parent empty."""
    empty = bpy.data.objects.new(name, None)
    collection.objects.link(empty)
    for obj in objects:
        obj.parent = empty
    place(empty, at, rotate)
    return empty


def parts(collection, build, *args, **options):
    """Runs `build(collection, ...)` and returns the top-level objects it added, for `group`."""
    before = set(collection.objects)
    build(collection, *args, **options)
    return [obj for obj in collection.objects if obj not in before and obj.parent is None]


# Stage and pixels ---------------------------------------------------------------------------------


def clear(stage):
    """Takes every object off the stage, and the meshes nothing uses any more, and starts the grain
    offsets over, so a build's parts get the same grain whatever was built before it."""
    _grain_offsets.seed(0)
    for obj in list(stage.objects):
        bpy.data.objects.remove(obj)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)


def load_pixels(path):
    """An image file as a float array of rows from the top, RGBA."""
    image = bpy.data.images.load(path)
    width, height = image.size
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)[::-1]
    bpy.data.images.remove(image)
    return pixels


def save_pixels(path, pixels):
    """Writes a load_pixels array as a PNG, its values as they are, without a colour transform."""
    height, width, _ = pixels.shape
    image = bpy.data.images.new("out", width, height, alpha=True)
    image.colorspace_settings.name = "Non-Color"
    image.pixels[:] = np.clip(pixels[::-1], 0, 1).ravel()
    image.filepath_raw = path
    image.file_format = "PNG"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save()
    bpy.data.images.remove(image)
