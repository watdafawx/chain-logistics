"""blender -b --factory-startup --python art/concepts3.py -- OUT_DIR [STYLE ...]: round three, the styles the user
liked (solarpunk, steampunk, cyberpunk, alien crystal), each in 4 builds (a different base, column and head each)
x 4 palettes -> OUT_DIR/<style>-v<build>-p<palette>.png. art/variant_sheet.py lays them out, one sheet a style."""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import concepts as C  # noqa: E402
import concepts2 as C2  # noqa: E402
import rig  # noqa: E402

OUT = C.OUT
A, B = C.A, C.B
T = rig.torus
cone, sphere, gem = C2.cone, C2.sphere, C2.gem


def tube(name, c, z0, z1, r, mat, verts=16, bevel=0.0):
    return rig.cyl(name, r, z1 - z0, (c[0], c[1], (z0 + z1) / 2), mat, bevel, verts=verts)


def alpha_mat(name, color, alpha, rough=0.1):
    s = rig.material(name, color, 0.0, rough, grime=0.05, ao=0.0)
    s.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = alpha
    return s


def chain(name, color):
    return rig.material(name, color, 0.85, 0.4, grime=0.25, edge=0.3)


# --- palettes: role -> material. Every style has prim / sec / trim / chain / dark / glow (+ its own roles) ---------
def palettes(style):
    m, g = rig.material, rig.glow
    if style == "solar":
        specs = [  # (name, prim, sec, trim, panel, leaf)
            ("ceramic + gold", (0.82, 0.8, 0.74), (0.9, 0.68, 0.25), (0.9, 0.68, 0.25), (0.05, 0.1, 0.28), (0.22, 0.48, 0.14)),
            ("terracotta + copper", (0.7, 0.36, 0.22), (0.75, 0.42, 0.22), (0.2, 0.55, 0.5), (0.04, 0.2, 0.22), (0.3, 0.5, 0.15)),
            ("white + silver", (0.9, 0.9, 0.9), (0.7, 0.72, 0.75), (0.55, 0.65, 0.45), (0.2, 0.08, 0.3), (0.45, 0.6, 0.35)),
            ("bamboo + brass", (0.62, 0.5, 0.26), (0.78, 0.58, 0.22), (0.1, 0.3, 0.1), (0.02, 0.02, 0.03), (0.12, 0.38, 0.1)),
        ]
        out = []
        for i, (n, p, s, t, pa, lf) in enumerate(specs):
            out.append((n, {"prim": m(f"s{i}p", p, 0.0, 0.4, grime=0.25, edge=0.4), "sec": m(f"s{i}s", s, 0.9, 0.3, edge=0.6),
                            "trim": m(f"s{i}t", t, 0.6, 0.35, edge=0.5), "panel": m(f"s{i}pa", pa, 0.4, 0.15, edge=0.6),
                            "leaf": m(f"s{i}l", lf, 0.0, 0.6, grime=0.35), "chain": chain(f"s{i}c", tuple(x * 0.85 for x in s)),
                            "dark": m(f"s{i}d", (0.12, 0.1, 0.08), 0.3, 0.6), "glass": alpha_mat(f"s{i}g", (0.8, 0.95, 0.9), 0.25),
                            "glow": g(f"s{i}gl", (1.0, 0.85, 0.4), 1.2), "pkg": m(f"s{i}k", (0.6, 0.42, 0.2), 0.0, 0.8, grime=0.5, edge=0.4)}))
        return out
    if style == "steam":
        specs = [  # (name, prim, sec, dark)
            ("copper + brass", (0.75, 0.38, 0.2), (0.85, 0.6, 0.22), (0.12, 0.1, 0.09)),
            ("black iron + brass", (0.12, 0.11, 0.11), (0.85, 0.6, 0.22), (0.06, 0.05, 0.05)),
            ("verdigris + bronze", (0.25, 0.5, 0.42), (0.6, 0.38, 0.18), (0.1, 0.12, 0.1)),
            ("red enamel + brass", (0.55, 0.08, 0.06), (0.85, 0.6, 0.22), (0.1, 0.06, 0.05)),
        ]
        out = []
        for i, (n, p, s, d) in enumerate(specs):
            out.append((n, {"prim": m(f"t{i}p", p, 0.8, 0.38, grime=0.35, rust=0.25, edge=0.8),
                            "sec": m(f"t{i}s", s, 0.9, 0.32, grime=0.25, edge=0.8), "trim": m(f"t{i}t", s, 0.9, 0.32, edge=0.8),
                            "dark": m(f"t{i}d", d, 0.6, 0.5, rust=0.3, edge=0.6), "chain": chain(f"t{i}c", tuple(x * 0.8 for x in s)),
                            "gauge": m(f"t{i}g", (0.9, 0.88, 0.8), 0.0, 0.4, ao=0.2), "steam": alpha_mat(f"t{i}st", (0.85, 0.85, 0.85), 0.35, 1.0),
                            "glow": g(f"t{i}gl", (1.0, 0.55, 0.15), 1.5), "pkg": m(f"t{i}k", (0.55, 0.36, 0.18), 0.0, 0.8, grime=0.5, edge=0.4)}))
        return out
    if style == "cyber":
        specs = [("magenta + cyan", (1.0, 0.1, 0.6), (0.1, 0.9, 1.0)), ("toxic green + yellow", (0.3, 1.0, 0.15), (1.0, 0.9, 0.1)),
                 ("orange + blue", (1.0, 0.45, 0.05), (0.15, 0.4, 1.0)), ("red + white", (1.0, 0.08, 0.08), (0.9, 0.9, 1.0))]
        out = []
        for i, (n, a, b) in enumerate(specs):
            out.append((n, {"prim": m(f"c{i}p", (0.05, 0.05, 0.06), 1.0, 0.22, grime=0.1, edge=0.5),
                            "sec": m(f"c{i}s", (0.18, 0.19, 0.22), 0.9, 0.3, edge=0.6), "trim": g(f"c{i}t", a, 2.0),
                            "glow": g(f"c{i}g", b, 2.0), "chain": chain(f"c{i}c", (0.07, 0.07, 0.08)),
                            "dark": m(f"c{i}d", (0.03, 0.03, 0.035), 0.8, 0.4), "beam": alpha_mat(f"c{i}b", b, 0.3, 0.0),
                            "pkg": m(f"c{i}k", (0.08, 0.08, 0.09), 0.9, 0.3, edge=0.5)}))
        return out
    specs = [("purple", (0.36, 0.1, 0.55), (0.6, 0.18, 1.0)), ("teal", (0.06, 0.4, 0.38), (0.15, 1.0, 0.8)),
             ("crimson", (0.5, 0.05, 0.1), (1.0, 0.15, 0.25)), ("amber", (0.55, 0.32, 0.05), (1.0, 0.65, 0.1))]
    out = []
    for i, (n, cr, gl) in enumerate(specs):
        out.append((n, {"prim": m(f"a{i}p", cr, 0.0, 0.1, grime=0.2, edge=0.8, ao=0.3), "glow": g(f"a{i}g", gl, 0.9),
                        "field": g(f"a{i}f", gl, 0.6), "sec": m(f"a{i}s", (0.12, 0.1, 0.12), 0.3, 0.7, grime=0.4, edge=0.4),
                        "trim": m(f"a{i}t", tuple(x * 0.6 for x in cr), 0.85, 0.35, edge=0.3),
                        "chain": chain(f"a{i}c", tuple(0.1 + x * 0.3 for x in cr)), "dark": m(f"a{i}d", (0.06, 0.05, 0.07), 0.4, 0.6),
                        "pkg": m(f"a{i}k", (0.08, 0.07, 0.09), 0.5, 0.5, edge=0.5)}))
    return out


def head(c, Z, P, housing="sec", spr="sec", hub="trim", teeth=0, verts=24):
    o = [rig.cyl("housing", 0.24, 0.14, (c[0], c[1], Z - 0.11), P[housing], 0.015, verts=verts),
         rig.cyl("spr", 0.3, 0.05, (c[0], c[1], Z), P[spr], 0.008, verts=32),
         rig.cyl("hub", 0.1, 0.08, (c[0], c[1], Z + 0.05), P[hub], 0.01, verts=16)]
    for k in range(teeth):
        a = k * math.tau / teeth
        o.append(rig.box("tooth", (0.09, 0.06, 0.06), (c[0] + 0.32 * math.cos(a), c[1] + 0.32 * math.sin(a), Z), P[spr],
                         0.006, rot=(0, 0, a)))
    return o + C.ring(c, Z, 0.36, P["chain"])


def flange(c, P, plate="prim", bolt="trim", n=8):
    o = [rig.cyl("flange", 0.33, 0.05, (c[0], c[1], 0.025), P[plate], 0.012, verts=32),
         cone("foot", 0.2, 0.11, 0.25, (c[0], c[1], 0.175), P[plate], verts=24)]
    for k in range(n):
        a = k * math.tau / n + math.pi / n
        o.append(rig.cyl("bolt", 0.033, 0.05, (c[0] + 0.27 * math.cos(a), c[1] + 0.27 * math.sin(a), 0.06), P[bolt], 0.005, verts=6))
    return o


def radial(c, n, r, z, fn, phase=0.0):
    out = []
    for k in range(n):
        a = k * math.tau / n + phase
        out += fn(c[0] + r * math.cos(a), c[1] + r * math.sin(a), z, a)
    return out


# ------------------------------------------------------------------------------------------------------------------
# solarpunk
def solar(v, c, Z, P):
    o = []
    top = Z - 0.18
    if v == 1:  # flange / slim tube + spiral leaves / solar petals
        o += flange(c, P, "prim", "sec") + [tube("col", c, 0.3, top, 0.085, P["prim"])]
        o += [rig.box("leaf", (0.14, 0.05, 0.012), (c[0] + 0.1 * math.cos(k * 1.6), c[1] + 0.1 * math.sin(k * 1.6), 0.5 + k * 0.18),
                      P["leaf"], 0.004, rot=(0.4, 0.3, k * 1.6)) for k in range(7)]
        o += radial(c, 6, 0.36, Z + 0.12, lambda x, y, z, a: [rig.box("petal", (0.28, 0.16, 0.012), (x, y, z), P["panel"], 0.004, rot=(0, -0.35, a)),
                                                               rig.box("rib", (0.29, 0.015, 0.016), (x, y, z), P["sec"], rot=(0, -0.35, a))], 0.3)
    elif v == 2:  # planter pot / bamboo / sunflower dish
        o += [cone("pot", 0.24, 0.32, 0.32, (c[0], c[1], 0.16), P["prim"], verts=20),
              rig.cyl("soil", 0.3, 0.02, (c[0], c[1], 0.31), P["dark"], verts=20)]
        o += radial(c, 7, 0.2, 0.36, lambda x, y, z, a: [cone("grass", 0.03, 0.0, 0.16, (x, y, z), P["leaf"], rot=(0.3 * math.sin(a), -0.3 * math.cos(a), 0), verts=4)])
        n = 5
        for k in range(n):
            z0 = 0.32 + k * (top - 0.32) / n
            o += [tube("bamboo", c, z0, z0 + (top - 0.32) / n - 0.02, 0.065, P["leaf"]), tube("node", c, z0 - 0.015, z0 + 0.015, 0.075, P["sec"])]
        dish = rig.cyl("dish", 0.32, 0.03, (c[0], c[1] - 0.05, Z + 0.25), P["panel"], 0.005, rot=(0.6, 0, 0), verts=24)
        o += [dish, rig.cyl("dishrim", 0.34, 0.02, (c[0], c[1] - 0.05, Z + 0.24), P["sec"], rot=(0.6, 0, 0), verts=24),
              tube("stalk", c, Z, Z + 0.22, 0.03, P["sec"])]
    elif v == 3:  # roots tripod / twisted rods / glass dome
        o += radial(c, 3, 0.18, 0.18, lambda x, y, z, a: [rig.box("root", (0.07, 0.07, 0.45), (x, y, z), P["prim"], 0.02,
                                                                   rot=(0.6 * math.sin(a), -0.6 * math.cos(a), 0)),
                                                           sphere("moss", 0.08, (x + 0.12 * math.cos(a), y + 0.12 * math.sin(a), 0.03), P["leaf"], 8)])
        for k in range(3):
            a = k * math.tau / 3
            r = rig.cyl("rod", 0.03, top - 0.35, (c[0] + 0.05 * math.cos(a), c[1] + 0.05 * math.sin(a), (top + 0.35) / 2), P["sec"],
                        rot=(0.08 * math.sin(a + 1), -0.08 * math.cos(a + 1), 0), verts=8)
            o.append(r)
        o += [sphere("dome", 0.22, (c[0], c[1], Z + 0.1), P["glass"], 16), sphere("plant", 0.12, (c[0], c[1], Z + 0.08), P["leaf"], 10),
              T("domering", 0.22, 0.015, (c[0], c[1], Z + 0.08), P["sec"])]
    else:  # mossy hex tile / tree trunk with branches / butterfly wings
        o += [rig.cyl("tile", 0.36, 0.06, (c[0], c[1], 0.03), P["prim"], 0.01, verts=6)]
        o += radial(c, 3, 0.22, 0.07, lambda x, y, z, a: [sphere("moss", 0.07, (x, y, z), P["leaf"], 8)], 0.5)
        o += [cone("trunk", 0.14, 0.08, top - 0.06, (c[0], c[1], (top + 0.06) / 2), P["prim"], verts=10)]
        for sx in (-1, 1):
            o += [rig.box("branch", (0.25, 0.04, 0.04), (c[0] + sx * 0.14, c[1], 1.1 + sx * 0.12), P["prim"], 0.01, rot=(0, -sx * 0.5, 0)),
                  sphere("leaves", 0.1, (c[0] + sx * 0.27, c[1], 1.2 + sx * 0.12), P["leaf"], 10)]
            w = rig.box("wing", (0.42, 0.3, 0.012), (c[0] + sx * 0.4, c[1], Z + 0.15), P["panel"], 0.004, rot=(0, sx * 0.4, 0))
            o += [w, rig.box("wingrib", (0.43, 0.02, 0.016), (c[0] + sx * 0.4, c[1], Z + 0.15), P["sec"], rot=(0, sx * 0.4, 0))]
    return o + head(c, Z, P, "prim", "sec", "sec")


# ------------------------------------------------------------------------------------------------------------------
# steampunk
def steam(v, c, Z, P):
    o = []
    top = Z - 0.18
    if v == 1:  # flange / boiler drum with gauge / gear head
        o += flange(c, P, "prim", "sec") + [tube("col", c, 0.3, top, 0.07, P["dark"])]
        o += [tube("drum", c, 0.72, 1.18, 0.17, P["prim"], 20, 0.02), tube("band", c, 0.76, 0.8, 0.18, P["sec"], 20),
              tube("band", c, 1.1, 1.14, 0.18, P["sec"], 20),
              rig.cyl("gauge", 0.07, 0.02, (c[0], c[1] - 0.18, 0.95), P["gauge"], rot=(math.pi / 2, 0, 0), verts=16),
              rig.cyl("gring", 0.08, 0.015, (c[0], c[1] - 0.185, 0.95), P["sec"], rot=(math.pi / 2, 0, 0), verts=16)]
        return o + head(c, Z, P, "prim", "sec", "sec", teeth=14)
    if v == 2:  # riveted plinth / piston / flywheel spokes
        o += [rig.box("plinth", (0.7, 0.7, 0.14), (c[0], c[1], 0.07), P["prim"], 0.02)]
        o += [rig.cyl("rivet", 0.025, 0.03, (c[0] + sx * 0.3, c[1] + sy * 0.3, 0.15), P["sec"], verts=8) for sx in (-1, 1) for sy in (-1, 1)]
        o += [tube("cyl", c, 0.14, 0.9, 0.13, P["prim"], 20, 0.015), tube("cap", c, 0.88, 0.94, 0.15, P["sec"], 20),
              tube("rod", c, 0.94, top, 0.045, P["sec"], 12), tube("collar", c, 0.4, 0.45, 0.14, P["sec"], 20)]
        o += head(c, Z, P, "dark", "sec", "prim")
        o += radial(c, 6, 0.17, Z + 0.035, lambda x, y, z, a: [rig.box("spoke", (0.2, 0.03, 0.025), (x, y, z), P["prim"], 0.004, rot=(0, 0, a))])
        return o
    if v == 3:  # claw-foot tripod / pipe bundle / clock face + bell
        o += radial(c, 3, 0.16, 0.2, lambda x, y, z, a: [rig.box("leg", (0.06, 0.06, 0.48), (x, y, z), P["dark"], 0.015,
                                                                  rot=(0.55 * math.sin(a), -0.55 * math.cos(a), 0)),
                                                          sphere("foot", 0.06, (c[0] + 0.3 * math.cos(a), c[1] + 0.3 * math.sin(a), 0.04), P["sec"], 10)])
        o += radial(c, 3, 0.05, 0, lambda x, y, z, a: [rig.cyl("pipe", 0.035, top - 0.38, (x, y, (top + 0.38) / 2), P["prim"], verts=10)])
        o += [tube("clamp", c, 0.7, 0.75, 0.1, P["sec"], 16), tube("clamp", c, 1.3, 1.35, 0.1, P["sec"], 16)]
        o += head(c, Z, P, "prim", "sec", "sec", teeth=10)
        o += [rig.cyl("face", 0.16, 0.02, (c[0], c[1], Z + 0.1), P["gauge"], verts=24), T("bezel", 0.16, 0.015, (c[0], c[1], Z + 0.11), P["sec"]),
              rig.box("hand", (0.12, 0.01, 0.005), (c[0] + 0.05, c[1], Z + 0.115), P["dark"], rot=(0, 0, 0.6)),
              cone("bell", 0.06, 0.02, 0.08, (c[0] + 0.2, c[1] + 0.12, Z + 0.15), P["sec"], verts=12)]
        return o
    # horizontal tank on saddles / riveted lattice girder / chimney + steam
    o += [rig.cyl("tank", 0.2, 0.8, (c[0], c[1], 0.24), P["prim"], 0.02, rot=(0, math.pi / 2, 0), verts=20)]
    o += [rig.box("saddle", (0.08, 0.36, 0.1), (c[0] + sx * 0.25, c[1], 0.05), P["dark"], 0.01) for sx in (-1, 1)]
    o += [rig.cyl("tband", 0.21, 0.03, (c[0] + sx * 0.3, c[1], 0.24), P["sec"], rot=(0, math.pi / 2, 0), verts=20) for sx in (-1, 1)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(rig.box("chord", (0.035, 0.035, top - 0.42), (c[0] + sx * 0.09, c[1] + sy * 0.09, (top + 0.42) / 2), P["dark"]))
    for k in range(5):
        z = 0.55 + k * (top - 0.6) / 5
        o += [rig.box("brace", (0.2, 0.02, 0.02), (c[0], c[1] + sy * 0.09, z), P["sec"], rot=(0, 0.7 * (1 if k % 2 else -1), 0)) for sy in (-1, 1)]
    o += head(c, Z, P, "prim", "sec", "sec", teeth=12)
    o += [tube("chimney", (c[0] + 0.1, c[1] + 0.1), Z, Z + 0.3, 0.045, P["dark"], 10), tube("lip", (c[0] + 0.1, c[1] + 0.1), Z + 0.28, Z + 0.32, 0.06, P["sec"], 10)]
    o += [sphere("steam", r, (c[0] + 0.1 + dx, c[1] + 0.1, Z + 0.4 + dz), P["steam"]) for dx, dz, r in ((0, 0, 0.07), (0.06, 0.1, 0.09), (0.14, 0.2, 0.11))]
    return o


# ------------------------------------------------------------------------------------------------------------------
# cyberpunk
def cyber(v, c, Z, P):
    o = []
    top = Z - 0.18
    if v == 1:  # hex pad / spike / hovering head with holo rings
        o += [rig.cyl("hex", 0.34, 0.06, (c[0], c[1], 0.03), P["prim"], 0.008, verts=6), T("hexneon", 0.33, 0.01, (c[0], c[1], 0.062), P["trim"]),
              tube("core", c, 0.06, 0.55, 0.14, P["prim"], 6, 0.01), T("coreneon", 0.145, 0.01, (c[0], c[1], 0.45), P["glow"]),
              tube("spike", c, 0.55, 1.2, 0.05, P["prim"], 6), T("holo", 0.3, 0.006, (c[0], c[1], Z - 0.3), P["glow"]),
              T("holo2", 0.22, 0.006, (c[0], c[1], Z - 0.42), P["trim"])]
        return o + head(c, Z, P, "prim", "prim", "trim") + [T("rim", 0.31, 0.01, (c[0], c[1], Z + 0.03), P["glow"])]
    if v == 2:  # low angular wedge / no column, motes / segmented hex ring head
        o += [cone("wedge", 0.42, 0.26, 0.14, (c[0], c[1], 0.07), P["sec"], rot=(0, 0, math.pi / 4), verts=4),
              rig.box("strip", (0.4, 0.012, 0.03), (c[0], c[1] - 0.25, 0.08), P["trim"]),
              cone("emit", 0.08, 0.03, 0.1, (c[0], c[1], 0.19), P["prim"], verts=6)]
        o += [sphere("mote", 0.025, (c[0] + 0.05 * math.sin(k * 2.1), c[1] + 0.05 * math.cos(k * 2.1), 0.4 + k * 0.28), P["glow"], 8) for k in range(5)]
        o += head(c, Z, P, "prim", "prim", "glow", verts=6)
        o += radial(c, 6, 0.27, Z - 0.11, lambda x, y, z, a: [rig.box("seg", (0.06, 0.03, 0.03), (x, y, z), P["trim"], rot=(0, 0, a))], math.pi / 6)
        return o
    if v == 3:  # cable tripod / twin rails / screens round the head
        o += radial(c, 3, 0.18, 0.22, lambda x, y, z, a: [rig.cyl("cable", 0.04, 0.5, (x, y, z), P["dark"], rot=(0.55 * math.sin(a), -0.55 * math.cos(a), 0), verts=10),
                                                           sphere("tip", 0.035, (c[0] + 0.33 * math.cos(a), c[1] + 0.33 * math.sin(a), 0.03), P["trim"], 8)])
        for sx in (-1, 1):
            o += [rig.box("rail", (0.05, 0.08, top - 0.4), (c[0] + sx * 0.07, c[1], (top + 0.4) / 2), P["sec"], 0.01),
                  rig.box("line", (0.01, 0.085, top - 0.5), (c[0] + sx * 0.07, c[1] - 0.001, (top + 0.4) / 2), P["glow"])]
        o += head(c, Z, P, "prim", "prim", "trim")
        o += radial(c, 4, 0.27, Z - 0.05, lambda x, y, z, a: [rig.box("screen", (0.012, 0.16, 0.1), (x, y, z), P["glow"], rot=(0, 0, a))], math.pi / 4)
        return o
    # floating hex plates / light beam / octagon head with antenna
    o += [rig.cyl("plate", 0.3 - k * 0.05, 0.03, (c[0], c[1], 0.04 + k * 0.2), P["prim"], 0.005, verts=6) for k in range(3)]
    o += [T("plateneon", 0.29 - k * 0.05, 0.007, (c[0], c[1], 0.056 + k * 0.2), P["trim"]) for k in range(3)]
    o += [tube("beam", c, 0.5, top, 0.05, P["beam"], 12), tube("beamcore", c, 0.5, top, 0.015, P["glow"], 8)]
    o += head(c, Z, P, "prim", "sec", "trim", verts=8)
    o += [tube("antenna", (c[0] + 0.15, c[1] + 0.1), Z, Z + 0.45, 0.012, P["sec"], 6), sphere("blink", 0.03, (c[0] + 0.15, c[1] + 0.1, Z + 0.46), P["trim"], 8)]
    return o


# ------------------------------------------------------------------------------------------------------------------
# alien crystal
def alien(v, c, Z, P):
    o = []
    if v == 1:  # crystal cluster / floating core in field rings / crystal head
        for k, (dx, dy, r, h, tx, ty) in enumerate(((0, 0, 0.13, 0.9, 0, 0), (0.15, 0.05, 0.08, 0.5, 0.3, 0.2), (-0.12, 0.1, 0.09, 0.6, -0.3, 0.25),
                                                   (0.05, -0.15, 0.07, 0.4, 0.1, -0.35), (-0.1, -0.1, 0.06, 0.35, -0.25, -0.25))):
            o.append(cone("shard", r, 0.0, h, (c[0] + dx, c[1] + dy, h / 2), P["prim"], rot=(ty, tx, k), verts=5))
        o += gem("core", 0.1, 0.32, (c[0], c[1], 1.25), P["glow"], rot=(0, 0, 0.7))
        o += [T("f1", 0.18, 0.006, (c[0], c[1], 1.25), P["field"], rot=(0.4, 0, 0)), T("f2", 0.2, 0.006, (c[0], c[1], 1.25), P["field"], rot=(-0.3, 0.4, 0))]
        o += gem("tip", 0.07, 0.22, (c[0], c[1], Z - 0.3), P["prim"], rot=(0, 0, 0.2))
        return o + head(c, Z, P, "prim", "trim", "glow")
    if v == 2:  # tendril roots / vertebrae spine / crown of shards
        o += radial(c, 5, 0.17, 0.15, lambda x, y, z, a: [rig.cyl("tendril", 0.04, 0.42, (x, y, z), P["sec"], 0.01,
                                                                   rot=(0.9 * math.sin(a), -0.9 * math.cos(a), 0), verts=8)])
        n = 8
        for k in range(n):
            z = 0.32 + k * (Z - 0.55) / n
            o.append(sphere("vert", 0.1 - k * 0.005, (c[0], c[1], z), P["sec"] if k % 2 else P["prim"], 10))
            o[-1].scale = (1, 1, 0.6)
        o += head(c, Z, P, "sec", "trim", "glow")
        o += radial(c, 7, 0.2, Z + 0.15, lambda x, y, z, a: [cone("crown", 0.04, 0.0, 0.28, (x, y, z), P["prim"], rot=(-0.3 * math.sin(a), 0.3 * math.cos(a), 0), verts=4)])
        return o
    if v == 3:  # geode / twisted spire / orbiting shards
        geo = sphere("geode", 0.34, (c[0], c[1], 0.0), P["sec"], 16)
        geo.scale = (1, 1, 0.55)
        o += [geo, rig.cyl("hollow", 0.26, 0.02, (c[0], c[1], 0.18), P["glow"], verts=16)]
        o += radial(c, 6, 0.16, 0.24, lambda x, y, z, a: [cone("inner", 0.04, 0.0, 0.14, (x, y, z), P["prim"], rot=(0.4 * math.sin(a), -0.4 * math.cos(a), 0), verts=4)])
        o += [cone("spire", 0.1, 0.03, Z - 0.6, (c[0], c[1], 0.2 + (Z - 0.6) / 2), P["prim"], rot=(0, 0, 0.5), verts=5)]
        o += radial(c, 3, 0.07, 0.9, lambda x, y, z, a: [cone("twist", 0.03, 0.0, 0.5, (x, y, z), P["prim"], rot=(0.25 * math.sin(a), -0.25 * math.cos(a), a), verts=4)])
        o += head(c, Z, P, "sec", "trim", "glow")
        o += radial(c, 6, 0.45, Z + 0.12, lambda x, y, z, a: gem("orbit", 0.04, 0.14, (x, y, z), P["glow"], rot=(0, 0, a)))
        o.append(T("orbitring", 0.45, 0.005, (c[0], c[1], Z + 0.12), P["field"]))
        return o
    # crystal plates over a glowing pool / levitating monolith / eye core
    o += [rig.cyl("pool", 0.3, 0.01, (c[0], c[1], 0.005), P["glow"], verts=20)]
    o += radial(c, 4, 0.25, 0.04, lambda x, y, z, a: [rig.cyl("plate", 0.12, 0.04, (x, y, z), P["prim"], rot=(0.3 * math.sin(a), -0.3 * math.cos(a), a), verts=6)])
    o += gem("monolith", 0.09, 0.9, (c[0], c[1], 0.95), P["prim"], rot=(0, 0, 0.3))
    o += [T("band", 0.15, 0.006, (c[0], c[1], 0.95), P["field"]), T("band2", 0.13, 0.006, (c[0], c[1], 0.75), P["field"])]
    o += head(c, Z, P, "sec", "trim", "glow")
    o += [sphere("eye", 0.12, (c[0], c[1], Z + 0.12), P["glow"], 16), T("lid", 0.14, 0.02, (c[0], c[1], Z + 0.12), P["trim"], rot=(0.5, 0, 0))]
    return o


STYLES = {"solar": solar, "steam": steam, "cyber": cyber, "alien": alien}
CHAIN_Z = {"solar": 2.0, "steam": 2.0, "cyber": 1.95, "alien": 2.0}


def scene(style, v, P):
    Z = CHAIN_Z[style]
    o = []
    for c in (A, B):
        o += STYLES[style](v, c, Z, P)
    o += C.strands(Z, 0.36, lambda p, q, z: C.chain_line(p, q, z, P["chain"]))
    x, y, top = 0.4, -0.36, Z - 0.32
    h = 0.44 * 0.78
    o += [rig.box("pk", (0.44, 0.44, h), (x, y, top - h / 2), P["pkg"], 0.025),
          rig.box("trim", (0.45, 0.45, 0.05), (x, y, top - h / 2), P["trim"], 0.005),
          rig.cyl("rod", 0.015, 0.3, (x, y, top + 0.15), P.get("dark", P["sec"]))]
    if "glow" in P:
        o.append(rig.box("light", (0.1, 0.012, 0.04), (x + 0.1, y - 0.226, top - h * 0.25), P["glow"]))
    return o


if __name__ == "__main__":
    rig.reset()
    g = rig.ground_catcher()
    g.visible_camera = True
    rig.frame(448, 320)
    bpy.context.scene.camera.location.y += 1.0 * math.cos(math.radians(45))
    bpy.context.scene.camera.location.z += 1.0 * math.sin(math.radians(45))
    only = sys.argv[sys.argv.index("--") + 2:]
    import json
    names = {}
    for style in STYLES:
        if only and style not in only:
            continue
        pals = palettes(style)
        names[style] = [n for n, _ in pals]
        for p, (pname, P) in enumerate(pals, 1):
            for v in range(1, 5):
                objs = scene(style, v, P)
                bpy.context.scene.render.filepath = os.path.join(OUT, f"{style}-v{v}-p{p}.png")
                bpy.ops.render.render(write_still=True)
                for o in objs:
                    bpy.data.objects.remove(o, do_unlink=True)
    with open(os.path.join(OUT, "palettes.json"), "w") as f:
        json.dump(names, f)
