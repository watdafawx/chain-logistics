"""Blender scene helpers: a camera and sun matched to vanilla sprites, materials, and frame renders.

Runs inside Blender (bpy). 1 Blender unit = 1 tile, Z up, north = +Y. The camera is orthographic at 45 degrees,
64 px per tile (vanilla's high-res, drawn at scale 0.5), aimed at the world origin: the origin (an entity's position
on the ground) is the image centre, so pack.py can work out each sprite's shift from where it crops.
"""
import math
import os

import bpy

PX_PER_TILE = 64
TILT = 45  # degrees from straight down (vanilla's steel chest and small pole match this)
SUN_ELEVATION = 45  # degrees above the horizon; shadows fall straight east, as long as the thing is tall, like vanilla's


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.world = bpy.data.worlds.new("world")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.13, 0.13, 0.15, 1)  # fill light: vanilla's shaded sides aren't black
    bg.inputs["Strength"].default_value = 1.0

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    t = math.radians(TILT)
    cam.location = (0, -20 * math.sin(t), 20 * math.cos(t))
    cam.rotation_euler = (t, 0, 0)
    cam.data.clip_end = 100
    sc.collection.objects.link(cam)
    sc.camera = cam

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 7.5
    sun.data.color = (1.0, 0.96, 0.9)  # warm key, like vanilla's
    sun.data.angle = math.radians(2)
    e = math.radians(90 - SUN_ELEVATION)
    sun.rotation_euler = (0, -e, 0)  # light from the west: shadows east
    sc.collection.objects.link(sun)
    return sc


def frame(width, height):
    """image size in px around the origin"""
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = width, height
    sc.render.resolution_percentage = 100
    sc.camera.data.ortho_scale = max(width, height) / PX_PER_TILE


RUST = (0.36, 0.15, 0.06)


def _mix(nt, a, b, fac, blend="MIX"):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    nt.links.new(fac, m.inputs[0])
    for i, v in ((6, a), (7, b)):
        if isinstance(v, tuple):
            m.inputs[i].default_value = (*v, 1)
        else:
            nt.links.new(v, m.inputs[i])
    return m.outputs[2]


def _ramp(nt, src, lo, hi, a=(0, 0, 0), b=(1, 1, 1)):
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[0].color = lo, (*a, 1)
    r.color_ramp.elements[1].position, r.color_ramp.elements[1].color = hi, (*b, 1)
    nt.links.new(src, r.inputs["Fac"])
    return r.outputs["Color"]


def glow(name, color, strength=6.0):
    """a self-lit material (crystals, lamps, hot seams)"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Emission Color"].default_value = (*color, 1)
    p.inputs["Emission Strength"].default_value = strength
    return m


def material(name, color, metallic=0.0, rough=0.6, grime=0.35, rust=0.0, edge=0.0, ao=0.65):
    """Vanilla-style worn surface: grime blotches darken the colour, rust (0-1) eats patches of it, edge (0-1)
    wears convex edges bright, ao (0-1) darkens crevices and contacts. Vanilla's look comes from that spread of
    light and dark plus warm colour, never a flat grey."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    coord = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]

    def noise(scale, detail):
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        nt.links.new(coord, n.inputs["Vector"])
        return n.outputs["Fac"]

    col = _ramp(nt, noise(18, 6), 0.35, 0.65, tuple(c * (1 - grime) for c in color), color)
    if rust:
        mask = _ramp(nt, noise(5, 10), 0.62 - 0.12 * rust, 0.7 - 0.1 * rust)
        col = _mix(nt, col, RUST, mask)
    if edge:
        # edges: where a bevelled normal turns away from the true one (only near real corners)
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        bev = nt.nodes.new("ShaderNodeBevel")
        bev.inputs["Radius"].default_value = 0.02
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        nt.links.new(bev.outputs["Normal"], dot.inputs[0])
        nt.links.new(geo.outputs["Normal"], dot.inputs[1])
        wear = _ramp(nt, dot.outputs["Value"], 0.9, 0.99, (edge, edge, edge), (0, 0, 0))
        worn = tuple(min(1, c * 1.6 + 0.3) for c in color)
        col = _mix(nt, col, worn, wear)
    if ao:
        a = nt.nodes.new("ShaderNodeAmbientOcclusion")
        a.inputs["Distance"].default_value = 0.25
        shade = _ramp(nt, a.outputs["AO"], 0.0, 1.0, (1 - ao,) * 3, (1, 1, 1))
        col = _mix(nt, col, shade, _value(nt, 1.0), "MULTIPLY")
    nt.links.new(col, p.inputs["Base Color"])
    return m


def _value(nt, v):
    n = nt.nodes.new("ShaderNodeValue")
    n.outputs[0].default_value = v
    return n.outputs[0]


def link(obj, mat=None, bevel=0.0):
    bpy.context.scene.collection.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        b = obj.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    return obj


def mesh_from(fn, name, mat=None, bevel=0.0, **kw):
    """fn: a bpy.ops.mesh primitive; the new object, unselected and linked"""
    fn(**kw)
    o = bpy.context.active_object
    o.name = name
    if mat:
        o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    return o


def box(name, size, loc, mat=None, bevel=0.01, rot=(0, 0, 0)):
    o = mesh_from(bpy.ops.mesh.primitive_cube_add, name, mat, bevel, size=1, location=loc, rotation=rot)
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return o


def cyl(name, r, depth, loc, mat=None, bevel=0.0, rot=(0, 0, 0), verts=24):
    return mesh_from(bpy.ops.mesh.primitive_cylinder_add, name, mat, bevel, radius=r, depth=depth, location=loc,
                     rotation=rot, vertices=verts)


def torus(name, major, minor, loc, mat=None, rot=(0, 0, 0), scale=(1, 1, 1), segs=16):
    o = mesh_from(bpy.ops.mesh.primitive_torus_add, name, mat, 0, major_radius=major, minor_radius=minor,
                  location=loc, rotation=rot, major_segments=segs, minor_segments=8)
    o.scale = scale
    return o


def ground_catcher():
    """a shadow-catching ground plane (seen only in the shadow pass)"""
    o = mesh_from(bpy.ops.mesh.primitive_plane_add, "ground", size=60, location=(0, 0, 0))
    o.is_shadow_catcher = True
    o.visible_camera = False
    return o


def render(path, objs, ground, shadow=False, glow=None):
    """one frame: the objects lit (ground hidden); with shadow=True only the shadow they cast on the ground; with
    glow (a set of the self-lit objects) only those, the rest cut out in front of them (the game's glow layer)"""
    for o in objs:
        o.visible_camera = not shadow
        o.is_holdout = glow is not None and o not in glow
    ground.visible_camera = shadow
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
