"""blender -b --factory-startup --python art/concepts.py -- OUT_DIR: look concepts, each a whole scene (two posts
5 tiles apart, the span, a package on it, shadows) in the game's camera, for picking a direction. Not the mod's
sprites."""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
A, B = (-2.5, 0.0), (2.5, 0.0)


def mats():
    m = rig.material
    return {
        # warm, worn, with a full spread of light and dark (vanilla's steel chest is violet-brown steel + rust)
        "steel": m("steel", (0.36, 0.3, 0.29), 0.55, 0.5, rust=0.5, edge=0.7),
        "dark": m("dark", (0.13, 0.11, 0.1), 0.5, 0.55, rust=0.3, edge=0.5),
        "chain": m("chain", (0.27, 0.24, 0.22), 0.8, 0.4, grime=0.2, edge=0.3),
        "chain_bronze": m("chain_bronze", (0.5, 0.31, 0.14), 0.9, 0.4, grime=0.3, edge=0.3),
        "chain_gun": m("chain_gun", (0.18, 0.19, 0.21), 0.8, 0.42, edge=0.3),
        "chain_tung": m("chain_tung", (0.24, 0.24, 0.27), 0.9, 0.4, edge=0.3),
        "paint": m("paint", (0.9, 0.58, 0.08), 0.1, 0.5, rust=0.35, edge=0.5),
        "card": m("card", (0.66, 0.44, 0.2), 0.0, 0.85, edge=0.3),
        "tape": m("tape", (0.8, 0.66, 0.4), 0.0, 0.5),
        "wood": m("wood", (0.6, 0.35, 0.13), 0.0, 0.75, grime=0.45, edge=0.5),
        "brass": m("brass", (0.85, 0.6, 0.22), 0.9, 0.3, edge=0.8),
        "stone": m("stone", (0.5, 0.46, 0.41), 0.0, 0.9, grime=0.4, edge=0.4),
        "rust": m("rust", (0.45, 0.22, 0.1), 0.4, 0.7, grime=0.5, rust=0.6, edge=0.6),
        "crate": m("crate", (0.6, 0.4, 0.18), 0.0, 0.8, grime=0.5, edge=0.4),
        "red": m("red", (0.7, 0.13, 0.07), 0.2, 0.5, rust=0.3, edge=0.5),
        # from the user's pack: Arcanyx (carved sandstone, bronze, purple crystal), Castra / Logistic Cannon (navy
        # paint), Carna (teal energy), Iridescent Industry (moss, iridescent crystal), heat_glow / Vulcanus (hot metal)
        "sand": m("sand", (0.62, 0.5, 0.34), 0.0, 0.85, grime=0.45, edge=0.6),
        "bronze": m("bronze", (0.6, 0.38, 0.18), 0.9, 0.38, grime=0.3, rust=0.25, edge=0.9),
        "amethyst": rig.glow("amethyst", (0.62, 0.22, 0.95), 1.6),
        "navy": m("navy", (0.12, 0.2, 0.42), 0.3, 0.45, rust=0.2, edge=0.8),
        "gunmetal": m("gunmetal", (0.2, 0.21, 0.23), 0.7, 0.45, edge=0.8),
        "teal": rig.glow("teal", (0.1, 0.95, 0.85), 1.6),
        "moss": m("moss", (0.2, 0.36, 0.12), 0.0, 0.9, grime=0.5, edge=0.2),
        "mossstone": m("mossstone", (0.4, 0.42, 0.36), 0.0, 0.9, grime=0.5, rust=0.0, edge=0.4),
        "vine": m("vine", (0.16, 0.3, 0.1), 0.0, 0.7, grime=0.4, edge=0.4),
        "pink": rig.glow("pink", (0.95, 0.35, 0.7), 1.3),
        "pod": m("pod", (0.55, 0.62, 0.25), 0.0, 0.5, grime=0.4, edge=0.5),
        "char": m("char", (0.09, 0.08, 0.08), 0.6, 0.6, grime=0.3, rust=0.3, edge=0.9),
        "hot": rig.glow("hot", (1.0, 0.42, 0.06), 2.2),
        "tungsten": m("tungsten", (0.3, 0.3, 0.33), 0.9, 0.35, edge=0.9),
    }


def chain_line(p, q, z, m, pitch=0.125, major=0.046, minor=0.016):
    dx, dy = q[0] - p[0], q[1] - p[1]
    n = int(math.hypot(dx, dy) / pitch)
    a = math.atan2(dy, dx)
    out = []
    for i in range(n + 1):
        f = i / n
        rot = (0, 0, a) if i % 2 == 0 else (math.pi / 2, 0, a)
        out.append(rig.torus("l", major, minor, (p[0] + dx * f, p[1] + dy * f, z), m, rot=rot, scale=(1.45, 1, 1)))
    return out


def strands(z, r, fn):
    """both strands of the span between A and B, r off the centre line (fn draws one)"""
    return fn((A[0], A[1] - r), (B[0], B[1] - r), z) + fn((A[0], A[1] + r), (B[0], B[1] + r), z)


def ring(c, z, r, m, n=24):
    out = []
    for k in range(n):
        a = k * math.tau / n
        rot = (0, 0, a + math.pi / 2) if k % 2 == 0 else (math.pi / 2, 0, a + math.pi / 2)
        out.append(rig.torus("r", 0.046, 0.016, (c[0] + r * math.cos(a), c[1] + r * math.sin(a), z), m, rot=rot,
                             scale=(1.45, 1, 1)))
    return out


def box_package(m, x, y, top, size=0.44, crate=False):
    h = size * 0.78
    o = [rig.box("pk", (size, size, h), (x, y, top - h / 2), m["crate" if crate else "card"], 0.02)]
    if crate:
        for sx in (-1, 1):
            for sy in (-1, 1):
                o.append(rig.box("c", (0.06, 0.06, h + 0.01), (x + sx * size / 2, y + sy * size / 2, top - h / 2), m["dark"], 0.005))
        o.append(rig.box("band", (size + 0.01, size + 0.01, 0.05), (x, y, top - h / 2), m["dark"], 0.005))
    else:
        o.append(rig.box("t", (size + 0.02, 0.07, h + 0.02), (x, y, top - h / 2), m["tape"], 0.005))
        o.append(rig.box("t2", (0.07, size + 0.02, 0.008), (x, y, top + 0.002), m["tape"], 0.002))
    return o


# --- A: the current look -------------------------------------------------------------------------------------------
def concept_current(m):
    Z = 2.0
    o = []
    for c in (A, B):
        o += [rig.box("base", (0.72, 0.72, 0.1), (c[0], c[1], 0.05), m["dark"], 0.02),
              rig.box("mast", (0.26, 0.26, 1.72), (c[0], c[1], 0.96), m["steel"], 0.02),
              rig.box("stripe", (0.28, 0.28, 0.1), (c[0], c[1], 1.2), m["paint"], 0.01),
              rig.cyl("head", 0.2, 0.2, (c[0], c[1], Z - 0.14), m["dark"], 0.01),
              rig.cyl("spr", 0.3, 0.05, (c[0], c[1], Z), m["steel"], 0.008, verts=32)]
        o += ring(c, Z, 0.36, m["chain"])
    o += strands(Z, 0.36, lambda p, q, z: chain_line(p, q, z, m["chain"]))
    o += box_package(m, 0.4, -0.36, Z - 0.32)
    o.append(rig.cyl("rod", 0.015, 0.3, (0.4, -0.36, Z - 0.16), m["dark"]))
    return o


# --- B: Create-like: a stone casing, a big wooden cog the chain wraps, brass hub; packages hook straight on --------
def concept_cog(m):
    Z = 1.55
    o = []
    for c in (A, B):
        o += [rig.box("casing", (0.9, 0.9, 0.55), (c[0], c[1], 0.275), m["stone"], 0.04),
              rig.box("frame", (0.96, 0.96, 0.08), (c[0], c[1], 0.56), m["wood"], 0.02),
              rig.box("frame2", (0.96, 0.96, 0.08), (c[0], c[1], 0.04), m["wood"], 0.02),
              rig.cyl("shaft", 0.09, Z - 0.55, (c[0], c[1], 0.55 + (Z - 0.55) / 2), m["wood"], 0.01),
              rig.cyl("cog", 0.42, 0.12, (c[0], c[1], Z), m["wood"], 0.015, verts=40),
              rig.cyl("hub", 0.15, 0.18, (c[0], c[1], Z + 0.02), m["brass"], 0.01)]
        for k in range(16):
            a = k * math.tau / 16
            o.append(rig.box("tooth", (0.12, 0.08, 0.12), (c[0] + 0.45 * math.cos(a), c[1] + 0.45 * math.sin(a), Z),
                             m["wood"], 0.01, rot=(0, 0, a)))
        o += ring(c, Z, 0.5, m["chain"], 28)
    o += strands(Z, 0.5, lambda p, q, z: chain_line(p, q, z, m["chain"], 0.14, 0.055, 0.02))
    o += box_package(m, 0.3, -0.5, Z - 0.12, 0.52)
    o.append(rig.torus("hook", 0.05, 0.012, (0.3, -0.5, Z - 0.05), m["dark"], rot=(math.pi / 2, 0, 0)))
    return o


# --- C: lattice pylon with pulleys, a steel cable, crates on hook trolleys (ropeway) ------------------------------
def concept_pylon(m):
    Z = 2.6
    o = []
    for c in (A, B):
        for sx in (-1, 1):
            for sy in (-1, 1):
                leg = rig.box("leg", (0.05, 0.05, Z - 0.1), (0, 0, 0), m["rust"], 0.005)
                leg.location = (c[0] + sx * 0.22, c[1] + sy * 0.22, (Z - 0.1) / 2)
                leg.rotation_euler = (sy * math.radians(5), -sx * math.radians(5), 0)
                o.append(leg)
        for zz in (0.6, 1.2, 1.8):
            w = 0.5 - zz * 0.12
            for sy in (-1, 1):
                o.append(rig.box("x", (w, 0.03, 0.03), (c[0], c[1] + sy * w / 2, zz), m["rust"], 0.003))
                o.append(rig.box("y", (0.03, w, 0.03), (c[0] + sy * w / 2, c[1], zz), m["rust"], 0.003))
        o.append(rig.box("arm", (0.1, 0.9, 0.1), (c[0], c[1], Z), m["red"], 0.01))
        for sy in (-1, 1):
            o.append(rig.cyl("pulley", 0.16, 0.04, (c[0], c[1] + sy * 0.38, Z + 0.06), m["dark"], 0.005,
                             rot=(0, math.pi / 2, 0), verts=24))
    def cable(p, q, z):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy)
        return [rig.cyl("cable", 0.035, L, ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, z), m["chain"],
                        rot=(0, math.pi / 2, math.atan2(dy, dx)), verts=8)]
    o += strands(Z + 0.2, 0.38, cable)
    x, y = 0.4, -0.38
    o += [rig.box("trolley", (0.24, 0.07, 0.1), (x, y, Z + 0.24), m["red"], 0.01),
          rig.box("hanger", (0.04, 0.04, 0.55), (x, y, Z - 0.05), m["red"], 0.005)]
    o += box_package(m, x, y, Z - 0.32, 0.48, crate=True)
    return o


# --- D: overhead I-beam rail on T-columns, a yellow trolley under it carrying a crate (monorail) -------------------
def concept_rail(m):
    Z = 2.3
    o = []
    for c in (A, B):
        o += [rig.box("foot", (0.7, 0.7, 0.12), (c[0], c[1], 0.06), m["dark"], 0.02),
              rig.box("col", (0.3, 0.3, Z - 0.1), (c[0], c[1], (Z - 0.1) / 2 + 0.1), m["paint"], 0.02),
              rig.box("t", (0.2, 1.1, 0.16), (c[0], c[1], Z + 0.05), m["paint"], 0.02)]
        for sy in (-1, 1):
            o.append(rig.box("brace", (0.06, 0.5, 0.06), (c[0], c[1] + sy * 0.25, Z - 0.25), m["dark"], 0.005,
                             rot=(sy * math.radians(-40), 0, 0)))

    def beam(p, q, z):
        L = q[0] - p[0]
        cx = (p[0] + q[0]) / 2
        return [rig.box("top", (L, 0.16, 0.03), (cx, p[1], z + 0.08), m["steel"], 0.005),
                rig.box("web", (L, 0.03, 0.14), (cx, p[1], z), m["steel"], 0.005),
                rig.box("bot", (L, 0.16, 0.03), (cx, p[1], z - 0.08), m["steel"], 0.005)]
    o += strands(Z - 0.08, 0.42, beam)
    x, y = 0.3, -0.42
    o += [rig.box("car", (0.34, 0.2, 0.12), (x, y, Z - 0.2), m["paint"], 0.02),
          rig.box("arm", (0.04, 0.04, 0.2), (x, y, Z - 0.35), m["dark"])]
    o += box_package(m, x, y, Z - 0.45, 0.5, crate=True)
    return o


# --- E: Arcanyx-like: a carved sandstone plinth, a bronze sprocket, a purple crystal hub that glows ----------------
def concept_arcane(m):
    Z = 1.8
    o = []
    for c in (A, B):
        o += [rig.box("plinth", (0.8, 0.8, 0.35), (c[0], c[1], 0.175), m["sand"], 0.04),
              rig.box("step", (0.62, 0.62, 0.2), (c[0], c[1], 0.45), m["sand"], 0.03),
              rig.cyl("col", 0.16, Z - 0.75, (c[0], c[1], 0.55 + (Z - 0.75) / 2), m["sand"], 0.02, verts=8),
              rig.cyl("collar", 0.22, 0.08, (c[0], c[1], 1.2), m["bronze"], 0.01, verts=8),
              rig.cyl("spr", 0.34, 0.06, (c[0], c[1], Z), m["bronze"], 0.01, verts=12),
              rig.cyl("crystal", 0.11, 0.3, (c[0], c[1], Z + 0.12), m["amethyst"], verts=6)]
        for k in range(4):  # carved runes: glowing slots in the plinth's faces
            a = k * math.pi / 2
            o.append(rig.box("rune", (0.18, 0.02, 0.06), (c[0] + 0.401 * math.sin(a), c[1] - 0.401 * math.cos(a), 0.18),
                             m["amethyst"], rot=(0, 0, a)))
        o += ring(c, Z, 0.4, m["chain_bronze"])
    o += strands(Z, 0.4, lambda p, q, z: chain_line(p, q, z, m["chain_bronze"]))
    x, y, top = 0.4, -0.4, Z - 0.3
    o += [rig.box("chest", (0.46, 0.36, 0.3), (x, y, top - 0.15), m["wood"], 0.02),
          rig.box("lid", (0.48, 0.38, 0.06), (x, y, top), m["bronze"], 0.01),
          rig.box("band", (0.06, 0.38, 0.32), (x, y, top - 0.15), m["bronze"], 0.005),
          rig.cyl("gem", 0.04, 0.02, (x, y - 0.19, top - 0.12), m["amethyst"], rot=(math.pi / 2, 0, 0), verts=6),
          rig.cyl("rod", 0.015, 0.3, (x, y, top + 0.15), m["bronze"])]
    return o


# --- F: navy industrial (Castra / Logistic Cannon / K2): a painted housing with a teal status strip, gunmetal chain -
def concept_navy(m):
    Z = 2.0
    o = []
    for c in (A, B):
        o += [rig.box("foot", (0.86, 0.86, 0.12), (c[0], c[1], 0.06), m["gunmetal"], 0.02),
              rig.box("house", (0.62, 0.62, 0.6), (c[0], c[1], 0.42), m["navy"], 0.04),
              rig.box("vent", (0.4, 0.01, 0.2), (c[0], c[1] - 0.311, 0.42), m["gunmetal"], 0.005),
              rig.box("strip", (0.5, 0.012, 0.04), (c[0], c[1] - 0.312, 0.64), m["teal"]),
              rig.box("mast", (0.24, 0.24, Z - 0.75), (c[0], c[1], 0.72 + (Z - 0.75) / 2), m["gunmetal"], 0.02),
              rig.box("cap", (0.5, 0.5, 0.12), (c[0], c[1], Z - 0.14), m["navy"], 0.02),
              rig.cyl("spr", 0.32, 0.05, (c[0], c[1], Z), m["tungsten"], 0.006, verts=32),
              rig.cyl("lamp", 0.06, 0.06, (c[0], c[1], Z + 0.06), m["teal"], verts=12)]
        o += ring(c, Z, 0.38, m["chain_gun"])
    o += strands(Z, 0.38, lambda p, q, z: chain_line(p, q, z, m["chain_gun"]))
    x, y, top = 0.4, -0.38, Z - 0.3
    o += [rig.box("can", (0.46, 0.46, 0.36), (x, y, top - 0.18), m["gunmetal"], 0.03),
          rig.box("stripe", (0.47, 0.47, 0.08), (x, y, top - 0.2), m["navy"], 0.01),
          rig.box("light", (0.08, 0.012, 0.04), (x + 0.12, y - 0.236, top - 0.06), m["teal"]),
          rig.box("clamp", (0.16, 0.06, 0.32), (x, y, top + 0.12), m["navy"], 0.01)]
    return o


# --- G: overgrown (Gleba / Iridescent Industry): mossy stone posts, a living vine cable with glowing bulbs, a pod ---
def concept_overgrown(m):
    Z = 1.9
    o = []
    for c in (A, B):
        o += [rig.cyl("stump", 0.34, 0.4, (c[0], c[1], 0.2), m["mossstone"], 0.04, verts=10),
              rig.cyl("trunk", 0.15, Z - 0.3, (c[0], c[1], 0.3 + (Z - 0.3) / 2), m["mossstone"], 0.02, verts=8),
              rig.cyl("mosscap", 0.37, 0.08, (c[0], c[1], 0.42), m["moss"], 0.03, verts=10),
              rig.cyl("crown", 0.3, 0.12, (c[0], c[1], Z), m["moss"], 0.03, verts=10)]
        for k in range(5):  # iridescent crystal shards round the crown
            a = k * math.tau / 5
            o.append(rig.cyl("shard", 0.04, 0.22, (c[0] + 0.2 * math.cos(a), c[1] + 0.2 * math.sin(a), Z + 0.12),
                             m["pink"], rot=(0.3 * math.sin(a), 0.3 * math.cos(a), 0), verts=5))

    def vine(p, q, z):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy)
        out = [rig.cyl("vine", 0.035, L, ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, z), m["vine"],
                       rot=(0, math.pi / 2, math.atan2(dy, dx)), verts=8)]
        for i in range(1, int(L / 0.5)):
            f = i * 0.5 / L
            out.append(rig.mesh_from(bpy.ops.mesh.primitive_uv_sphere_add, "bulb", m["pink"] if i % 3 == 0 else m["moss"],
                                     radius=0.05 if i % 3 == 0 else 0.04,
                                     location=(p[0] + dx * f, p[1] + dy * f, z - 0.03), segments=8, ring_count=6))
        return out
    o += strands(Z, 0.3, vine)
    x, y = 0.4, -0.3
    o += [rig.mesh_from(bpy.ops.mesh.primitive_uv_sphere_add, "pod", m["pod"], radius=0.24, location=(x, y, Z - 0.4),
                        segments=16, ring_count=10),
          rig.cyl("stem", 0.02, 0.2, (x, y, Z - 0.12), m["vine"])]
    o[-2].scale = (1, 1, 1.3)
    return o


# --- H: forge (Vulcanus / heat_glow): blackened tungsten posts with glowing seams, a heavy chain, a hot-riveted crate
def concept_forge(m):
    Z = 2.0
    o = []
    for c in (A, B):
        o += [rig.box("anvil", (0.9, 0.9, 0.2), (c[0], c[1], 0.1), m["char"], 0.03),
              rig.box("seam", (0.92, 0.92, 0.025), (c[0], c[1], 0.2), m["hot"]),
              rig.box("block", (0.6, 0.6, 0.3), (c[0], c[1], 0.36), m["char"], 0.03),
              rig.cyl("mast", 0.15, Z - 0.5, (c[0], c[1], 0.5 + (Z - 0.5) / 2), m["tungsten"], 0.01, verts=6),
              rig.cyl("ring", 0.18, 0.04, (c[0], c[1], 1.0), m["hot"], verts=6),
              rig.cyl("ring2", 0.18, 0.04, (c[0], c[1], 1.5), m["hot"], verts=6),
              rig.cyl("spr", 0.33, 0.07, (c[0], c[1], Z), m["char"], 0.008, verts=8),
              rig.cyl("core", 0.1, 0.09, (c[0], c[1], Z + 0.01), m["hot"], verts=8)]
        o += ring(c, Z, 0.4, m["chain_tung"], 22)
    o += strands(Z, 0.4, lambda p, q, z: chain_line(p, q, z, m["chain_tung"], 0.15, 0.06, 0.022))
    x, y, top = 0.4, -0.4, Z - 0.3
    o += box_package(m, x, y, top, 0.46, crate=True)
    o += [rig.box("glowband", (0.47, 0.47, 0.025), (x, y, top - 0.12), m["hot"]),
          rig.cyl("rod", 0.02, 0.3, (x, y, top + 0.15), m["char"])]
    return o


def run(concepts, extra_mats=None):
    """render each (name, fn) concept (or only the names after OUT_DIR on the command line)"""
    rig.reset()
    g = rig.ground_catcher()
    g.visible_camera = True
    mm = mats()
    if extra_mats:
        mm.update(extra_mats())
    rig.frame(448, 320)
    bpy.context.scene.camera.location.y += 1.0 * math.cos(math.radians(45))  # (frame the scene: posts reach up)
    bpy.context.scene.camera.location.z += 1.0 * math.sin(math.radians(45))
    only = sys.argv[sys.argv.index("--") + 2:]
    for name, fn in concepts:
        if only and name not in only:
            continue
        objs = fn(mm)
        bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)


CONCEPTS = (("a-current", concept_current), ("b-cog", concept_cog), ("e-arcane", concept_arcane),
            ("f-navy", concept_navy), ("g-overgrown", concept_overgrown), ("h-forge", concept_forge),
            ("c-pylon", concept_pylon), ("d-rail", concept_rail))
if __name__ == "__main__":
    run(CONCEPTS)
