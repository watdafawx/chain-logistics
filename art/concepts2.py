"""blender -b --factory-startup --python art/concepts2.py -- OUT_DIR [NAME ...]: round two of the look concepts, on
the user's notes: no heavy block base (bolted to the ground, a hovering head, a head held over its base by a
magnetic crystal with nothing between), and solarpunk, steampunk, cyberpunk and alien-crystal styles."""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import concepts as C  # noqa: E402
import rig  # noqa: E402

A, B = C.A, C.B


def extra():
    m, g = rig.material, rig.glow
    return {
        "ceramic": m("ceramic", (0.82, 0.8, 0.74), 0.0, 0.35, grime=0.25, edge=0.3),
        "panel": m("panel", (0.05, 0.1, 0.28), 0.4, 0.15, grime=0.1, edge=0.6),
        "leaf": m("leaf", (0.22, 0.48, 0.14), 0.0, 0.6, grime=0.35),
        "gold": m("gold", (0.9, 0.68, 0.25), 0.95, 0.28, grime=0.2, edge=0.6),
        "copper": m("copper", (0.75, 0.38, 0.2), 0.9, 0.35, grime=0.35, rust=0.2, edge=0.8),
        "chain_copper": m("chain_copper", (0.6, 0.3, 0.15), 0.9, 0.4, grime=0.3, edge=0.3),
        "chain_gold": m("chain_gold", (0.75, 0.55, 0.2), 0.95, 0.35, edge=0.3),
        "gauge": m("gauge", (0.9, 0.88, 0.8), 0.0, 0.4, ao=0.2),
        "chrome": m("chrome", (0.05, 0.05, 0.06), 1.0, 0.22, grime=0.1, edge=0.5),
        "chain_black": m("chain_black", (0.07, 0.07, 0.08), 0.9, 0.3, edge=0.25),
        "neon_mag": g("neon_mag", (1.0, 0.1, 0.6), 2.0),
        "neon_cyan": g("neon_cyan", (0.1, 0.9, 1.0), 2.0),
        "crystal": m("crystal", (0.36, 0.1, 0.55), 0.0, 0.1, grime=0.2, edge=0.8, ao=0.3),
        "crystal_glow": g("crystal_glow", (0.6, 0.18, 1.0), 0.9),
        "field": g("field", (0.5, 0.3, 1.0), 0.8),
        "chain_purple": m("chain_purple", (0.18, 0.1, 0.24), 0.85, 0.35, edge=0.3),
        "steam": _steam(),
    }


def _steam():
    s = rig.material("steam", (0.85, 0.85, 0.85), 0.0, 1.0, grime=0.1, ao=0.0)
    s.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.35
    return s


def cone(name, r1, r2, depth, loc, mat, rot=(0, 0, 0), verts=16):
    return rig.mesh_from(bpy.ops.mesh.primitive_cone_add, name, mat, radius1=r1, radius2=r2, depth=depth,
                         location=loc, rotation=rot, vertices=verts)


def sphere(name, r, loc, mat, seg=12):
    return rig.mesh_from(bpy.ops.mesh.primitive_uv_sphere_add, name, mat, radius=r, location=loc, segments=seg,
                         ring_count=max(4, seg // 2))


def gem(name, r, h, loc, mat, rot=(0, 0, 0)):
    """an octahedral crystal: two 4-sided cones point to point"""
    x, y, z = loc
    return [cone(name, r, 0, h / 2, (x, y, z + h / 4), mat, rot, 4), cone(name, 0, r, h / 2, (x, y, z - h / 4), mat, rot, 4)]


def head(c, Z, housing, spr, chain, hub, r=0.36, teeth=0):
    """the sprocket head every style shares: a housing under the sprocket, the chain ring round it, a hub cap"""
    o = [rig.cyl("housing", 0.24, 0.14, (c[0], c[1], Z - 0.11), housing, 0.015, verts=24),
         rig.cyl("spr", r - 0.06, 0.05, (c[0], c[1], Z), spr, 0.008, verts=32),
         rig.cyl("hub", 0.1, 0.08, (c[0], c[1], Z + 0.05), hub, 0.01, verts=16)]
    for k in range(teeth):
        a = k * math.tau / teeth
        o.append(rig.box("tooth", (0.09, 0.06, 0.06), (c[0] + (r - 0.04) * math.cos(a), c[1] + (r - 0.04) * math.sin(a), Z),
                         spr, 0.006, rot=(0, 0, a)))
    return o + C.ring(c, Z, r, chain)


def bolted(c, plate, bolt, tube, top):
    """a flange bolted to the ground (8 hex bolts), a short cone, a slim tube up to the head"""
    o = [rig.cyl("flange", 0.33, 0.05, (c[0], c[1], 0.025), plate, 0.012, verts=32),
         cone("foot", 0.2, 0.11, 0.3, (c[0], c[1], 0.2), plate, verts=24),
         rig.cyl("tube", 0.085, top - 0.35, (c[0], c[1], 0.35 + (top - 0.35) / 2), tube, 0.008, verts=16)]
    for k in range(8):
        a = k * math.tau / 8 + math.pi / 8
        o.append(rig.cyl("bolt", 0.035, 0.05, (c[0] + 0.27 * math.cos(a), c[1] + 0.27 * math.sin(a), 0.06), bolt,
                         0.005, verts=6))
    for k in range(4):  # gussets
        a = k * math.pi / 2
        g = rig.box("gusset", (0.025, 0.18, 0.18), (0, 0, 0), plate, 0.004)
        g.location = (c[0] + 0.15 * math.cos(a), c[1] + 0.15 * math.sin(a), 0.14)
        g.rotation_euler = (math.pi / 4, 0, a + math.pi / 2)
        o.append(g)
    return o


def package(m, x, y, top, body, trim, light=None, size=0.44):
    h = size * 0.78
    o = [rig.box("pk", (size, size, h), (x, y, top - h / 2), m[body], 0.025),
         rig.box("trim", (size + 0.01, size + 0.01, 0.05), (x, y, top - h / 2), m[trim], 0.005),
         rig.cyl("rod", 0.015, 0.3, (x, y, top + 0.15), m["dark"])]
    if light:
        o.append(rig.box("light", (0.1, 0.012, 0.04), (x + 0.1, y - size / 2 - 0.006, top - h * 0.25), m[light]))
    return o


# --- 1. bolted: vanilla palette, a flange bolted down instead of a block ------------------------------------------
def bolted_industrial(m):
    Z = 2.0
    o = []
    for c in (A, B):
        o += bolted(c, m["steel"], m["dark"], m["steel"], Z - 0.18)
        o += [rig.cyl("stripe", 0.095, 0.12, (c[0], c[1], 1.15), m["paint"], verts=16)]
        o += head(c, Z, m["dark"], m["steel"], m["chain"], m["paint"], teeth=12)
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, m["chain"]))
    return o + package(m, 0.4, -0.36, Z - 0.32, "card", "tape")


# --- 2. hover: a flush ground pad, the head floats over it on a field ---------------------------------------------
def hover(m):
    Z = 1.9
    o = []
    for c in (A, B):
        o += [rig.cyl("pad", 0.3, 0.04, (c[0], c[1], 0.02), m["gunmetal"], 0.01, verts=32),
              rig.cyl("padtop", 0.2, 0.05, (c[0], c[1], 0.05), m["steel"], 0.01, verts=24),
              C.rig.torus("padring", 0.25, 0.012, (c[0], c[1], 0.05), m["neon_cyan"])]
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            o.append(rig.cyl("bolt", 0.03, 0.04, (c[0] + 0.26 * math.cos(a), c[1] + 0.26 * math.sin(a), 0.05),
                             m["dark"], verts=6))
        o += [C.rig.torus("halo", 0.2, 0.014, (c[0], c[1], Z - 0.24), m["neon_cyan"]),
              C.rig.torus("halo2", 0.13, 0.01, (c[0], c[1], Z - 0.36), m["neon_cyan"]),
              cone("emitter", 0.1, 0.0, 0.16, (c[0], c[1], Z - 0.26), m["gunmetal"], rot=(math.pi, 0, 0))]
        o += head(c, Z, m["gunmetal"], m["steel"], m["chain_gun"], m["neon_cyan"])
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, m["chain_gun"]))
    return o + package(m, 0.4, -0.36, Z - 0.32, "gunmetal", "navy", "neon_cyan")


# --- 3. magnetic crystal: a bolted cradle, a crystal floating in field rings, the head floating over it -----------
def magnetic(m):
    Z = 2.0
    o = []
    for c in (A, B):
        o += [rig.cyl("flange", 0.3, 0.05, (c[0], c[1], 0.025), m["dark"], 0.012, verts=32)]
        for k in range(6):
            a = k * math.tau / 6
            o.append(rig.cyl("bolt", 0.032, 0.05, (c[0] + 0.25 * math.cos(a), c[1] + 0.25 * math.sin(a), 0.06),
                             m["steel"], verts=6))
        for k in range(3):  # claws: below, holding up; above, holding down
            a = k * math.tau / 3
            for z0, tilt in ((0.3, 0.35), (Z - 0.4, -0.35)):
                cl = rig.box("claw", (0.05, 0.05, 0.42), (0, 0, 0), m["bronze"], 0.01)
                cl.location = (c[0] + 0.12 * math.cos(a), c[1] + 0.12 * math.sin(a), z0)
                cl.rotation_euler = (tilt * math.sin(a), -tilt * math.cos(a), 0)
                o.append(cl)
        o += gem("crystal", 0.16, 0.5, (c[0], c[1], 1.0), m["crystal_glow"], rot=(0, 0, 0.4))
        o += [C.rig.torus("f1", 0.24, 0.008, (c[0], c[1], 0.85), m["field"]),
              C.rig.torus("f2", 0.28, 0.008, (c[0], c[1], 1.15), m["field"], rot=(0.25, 0, 0))]
        o += head(c, Z, m["dark"], m["bronze"], m["chain_bronze"], m["crystal_glow"], teeth=12)
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, m["chain_bronze"]))
    return o + package(m, 0.4, -0.36, Z - 0.32, "wood", "bronze", "crystal_glow")


# --- 4. solarpunk: white ceramic and gold, solar petals round the head, leaves climbing the column ---------------
def solarpunk(m):
    Z = 2.0
    o = []
    for c in (A, B):
        o += bolted(c, m["ceramic"], m["gold"], m["ceramic"], Z - 0.18)
        for k in range(7):  # leaves spiralling up
            a = k * 1.6
            z = 0.5 + k * 0.18
            lf = rig.box("leaf", (0.14, 0.05, 0.012), (c[0] + 0.1 * math.cos(a), c[1] + 0.1 * math.sin(a), z), m["leaf"],
                         0.004, rot=(0.4, 0.3, a))
            o.append(lf)
        for k in range(6):  # solar petals
            a = k * math.tau / 6 + 0.3
            p = rig.box("petal", (0.28, 0.16, 0.012), (0, 0, 0), m["panel"], 0.004)
            p.location = (c[0] + 0.36 * math.cos(a), c[1] + 0.36 * math.sin(a), Z + 0.12)
            p.rotation_euler = (0, -0.35, a)
            o.append(p)
            o.append(rig.box("rib", (0.29, 0.015, 0.016), p.location, m["gold"], rot=(0, -0.35, a)))
        o += head(c, Z, m["ceramic"], m["gold"], m["chain_gold"], m["gold"])
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, m["chain_gold"]))
    o += package(m, 0.4, -0.36, Z - 0.32, "crate", "gold")
    o.append(rig.box("sprig", (0.12, 0.05, 0.01), (0.45, -0.36, Z - 0.3), m["leaf"], rot=(0.3, 0, 0.5)))
    return o


# --- 5. steampunk: riveted copper, a boiler drum on the column, a gauge, pipes, a puff of steam ------------------
def steampunk(m):
    Z = 2.0
    o = []
    for c in (A, B):
        o += bolted(c, m["copper"], m["brass"], m["dark"], Z - 0.18)
        o += [rig.cyl("drum", 0.17, 0.42, (c[0], c[1], 0.95), m["copper"], 0.02, verts=20),
              rig.cyl("band1", 0.18, 0.03, (c[0], c[1], 0.78), m["brass"], verts=20),
              rig.cyl("band2", 0.18, 0.03, (c[0], c[1], 1.12), m["brass"], verts=20),
              rig.cyl("gauge", 0.07, 0.02, (c[0], c[1] - 0.18, 1.0), m["gauge"], rot=(math.pi / 2, 0, 0), verts=16),
              rig.cyl("gaugering", 0.08, 0.015, (c[0], c[1] - 0.185, 1.0), m["brass"], rot=(math.pi / 2, 0, 0), verts=16),
              rig.box("needle", (0.008, 0.002, 0.05), (c[0] + 0.01, c[1] - 0.195, 1.01), m["dark"], rot=(0, 0.6, 0)),
              rig.cyl("pipe", 0.025, 0.7, (c[0] + 0.2, c[1], 1.4), m["brass"], verts=10),
              rig.cyl("elbow", 0.03, 0.12, (c[0] + 0.15, c[1], 1.75), m["brass"], rot=(0, math.pi / 2, 0), verts=10),
              rig.cyl("chimney", 0.04, 0.2, (c[0] - 0.2, c[1] + 0.05, 1.3), m["dark"], verts=10)]
        for k, (dx, dz, r) in enumerate(((0, 0.0, 0.07), (0.05, 0.1, 0.09), (0.12, 0.2, 0.11))):
            o.append(sphere("steam", r, (c[0] - 0.2 + dx, c[1] + 0.05, 1.5 + dz), m["steam"]))
        o += head(c, Z, m["copper"], m["brass"], m["chain_copper"], m["brass"], teeth=14)
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, m["chain_copper"]))
    return o + package(m, 0.4, -0.36, Z - 0.32, "crate", "brass")


# --- 6. cyberpunk: black chrome on a hex pad, neon edges, a hovering head with a holo ring ------------------------
def cyberpunk(m):
    Z = 1.95
    o = []
    for c in (A, B):
        o += [rig.cyl("hex", 0.34, 0.06, (c[0], c[1], 0.03), m["chrome"], 0.008, verts=6),
              C.rig.torus("hexneon", 0.33, 0.01, (c[0], c[1], 0.062), m["neon_mag"]),
              rig.cyl("core", 0.14, 0.5, (c[0], c[1], 0.3), m["chrome"], 0.01, verts=6),
              C.rig.torus("coreneon", 0.145, 0.01, (c[0], c[1], 0.45), m["neon_cyan"]),
              rig.cyl("spike", 0.05, 0.6, (c[0], c[1], 0.85), m["chrome"], verts=6),
              C.rig.torus("holo", 0.3, 0.006, (c[0], c[1], Z - 0.3), m["neon_cyan"]),
              C.rig.torus("holo2", 0.22, 0.006, (c[0], c[1], Z - 0.42), m["neon_mag"])]
        o += head(c, Z, m["chrome"], m["chrome"], m["chain_black"], m["neon_mag"])
        o.append(C.rig.torus("rim", 0.31, 0.01, (c[0], c[1], Z + 0.03), m["neon_cyan"]))
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, m["chain_black"]))
    o += package(m, 0.4, -0.36, Z - 0.32, "chrome", "neon_mag", "neon_cyan")
    return o


# --- 7. alien crystal: a cluster grown from the ground is the base; the head floats over it, glowing ------------
def alien(m):
    Z = 2.0
    o = []
    for c in (A, B):
        for k, (dx, dy, r, h, tx, ty) in enumerate(((0, 0, 0.13, 0.9, 0, 0), (0.15, 0.05, 0.08, 0.5, 0.3, 0.2),
                                                   (-0.12, 0.1, 0.09, 0.6, -0.3, 0.25), (0.05, -0.15, 0.07, 0.4, 0.1, -0.35),
                                                   (-0.1, -0.1, 0.06, 0.35, -0.25, -0.25))):
            o.append(cone("shard", r, 0.0, h, (c[0] + dx, c[1] + dy, h / 2), m["crystal"], rot=(ty, tx, k), verts=5))
        o += gem("core", 0.1, 0.32, (c[0], c[1], 1.25), m["crystal_glow"], rot=(0, 0, 0.7))
        o += [C.rig.torus("f1", 0.18, 0.006, (c[0], c[1], 1.25), m["field"], rot=(0.4, 0, 0)),
              C.rig.torus("f2", 0.2, 0.006, (c[0], c[1], 1.25), m["field"], rot=(-0.3, 0.4, 0))]
        o += gem("tip", 0.07, 0.22, (c[0], c[1], Z - 0.3), m["crystal"], rot=(0, 0, 0.2))
        o += head(c, Z, m["crystal"], m["chain_purple"], m["chain_purple"], m["crystal_glow"])
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, m["chain_purple"]))
    return o + package(m, 0.4, -0.36, Z - 0.32, "dark", "chain_purple", "crystal_glow")


CONCEPTS = (("b-cog", C.concept_cog), ("i-bolted", bolted_industrial), ("j-hover", hover), ("k-magnetic", magnetic),
            ("l-solarpunk", solarpunk), ("m-steampunk", steampunk), ("n-cyberpunk", cyberpunk), ("o-alien", alien))
if __name__ == "__main__":
    C.run(CONCEPTS, extra)
