"""blender -b --factory-startup --python art/concepts4.py -- OUT_DIR [combos|palettes K Q]: round four. The posts are
settled (cyberpunk build 1, all 4 palettes); this redoes the chain and the package for them: 4 chains x 4 packages
(palette 1), or one chain + package in every palette. Rendered closer (96 px a tile) so the small parts read.
-> OUT_DIR/k<chain>-q<package>-p<palette>.png; art/combo_sheet.py lays them out."""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import concepts as C  # noqa: E402
import concepts2 as C2  # noqa: E402
import concepts3 as C3  # noqa: E402
import rig  # noqa: E402

OUT = C.OUT
A, B = C.A, C.B
Z = C3.CHAIN_Z["cyber"]
R = 0.36
T = rig.torus


def along(p, q, step, fn):
    """fn(x, y, angle, i) at every step along p -> q"""
    dx, dy = q[0] - p[0], q[1] - p[1]
    n = int(math.hypot(dx, dy) / step)
    a = math.atan2(dy, dx)
    out = []
    for i in range(n + 1):
        out += fn(p[0] + dx * i / n, p[1] + dy * i / n, a, i)
    return out


def around(c, step_n, fn):
    """fn(x, y, tangent angle, i) round a post's ring"""
    out = []
    for i in range(step_n):
        a = i * math.tau / step_n
        out += fn(c[0] + R * math.cos(a), c[1] + R * math.sin(a), a + math.pi / 2, i)
    return out


def both(fn_line, fn_ring):
    o = C.strands(Z, R, fn_line)
    for c in (A, B):
        o += fn_ring(c)
    return o


# --- chains -------------------------------------------------------------------------------------------------------
def k1_neon_links(P):
    """black links, every 4th lit"""
    def link(x, y, a, i):
        rot = (0, 0, a) if i % 2 == 0 else (math.pi / 2, 0, a)
        return [T("l", 0.046, 0.016, (x, y, Z), P["trim"] if i % 4 == 0 else P["chain"], rot=rot, scale=(1.45, 1, 1))]
    return both(lambda p, q, z: along(p, q, 0.125, link), lambda c: around(c, 24, link))


def k2_light_cable(P):
    """a black cable with a lit stripe on top and chrome clamps every half tile"""
    def line(p, q, z):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L, a = math.hypot(dx, dy), math.atan2(dy, dx)
        mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        o = [rig.cyl("cable", 0.035, L, (*mid, z), P["dark"], rot=(0, math.pi / 2, a), verts=12),
             rig.box("stripe", (L, 0.016, 0.01), (*mid, z + 0.034), P["glow"], rot=(0, 0, a))]
        return o + along(p, q, 0.5, lambda x, y, a, i: [rig.cyl("clamp", 0.045, 0.04, (x, y, z), P["sec"], rot=(0, math.pi / 2, a), verts=12)])
    return both(line, lambda c: [T("ringcable", R, 0.035, (c[0], c[1], Z), P["dark"]), T("ringstripe", R, 0.009, (c[0], c[1], Z + 0.034), P["glow"])])


def k3_armored_track(P):
    """a flat track of armour plates with neon edges"""
    def plate(x, y, a, i):
        return [rig.box("plate", (0.1, 0.15, 0.025), (x, y, Z), P["sec"] if i % 2 else P["prim"], 0.005, rot=(0, 0, a))]

    def line(p, q, z):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L, a = math.hypot(dx, dy), math.atan2(dy, dx)
        nx, ny = -math.sin(a) * 0.08, math.cos(a) * 0.08
        mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        return along(p, q, 0.11, plate) + [rig.box("edge", (L, 0.01, 0.012), (mid[0] + s * nx, mid[1] + s * ny, z + 0.01), P["trim"], rot=(0, 0, a)) for s in (-1, 1)]
    return both(line, lambda c: around(c, 22, plate) + [T("ringedge", R + s * 0.08, 0.006, (c[0], c[1], Z + 0.01), P["trim"]) for s in (-1, 1)])


def k4_laser(P):
    """light itself: a lit strand through chrome guide rings every tile"""
    def line(p, q, z):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L, a = math.hypot(dx, dy), math.atan2(dy, dx)
        mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        return [rig.cyl("beam", 0.014, L, (*mid, z), P["glow"], rot=(0, math.pi / 2, a), verts=8),
                rig.cyl("halo", 0.04, L, (*mid, z), P["beam"], rot=(0, math.pi / 2, a), verts=12)] + \
            along(p, q, 1.0, lambda x, y, a, i: [T("guide", 0.06, 0.012, (x, y, z), P["sec"], rot=(0, math.pi / 2, a))])
    return both(line, lambda c: [T("ringbeam", R, 0.014, (c[0], c[1], Z), P["glow"]), T("ringhalo", R, 0.04, (c[0], c[1], Z), P["beam"])])


# --- packages (x, y: under the chain; top: the package's top) -----------------------------------------------------
def hanger(P, x, y, top):
    return [rig.cyl("rod", 0.015, Z - top, (x, y, (Z + top) / 2), P["sec"], verts=8),
            rig.box("trolley", (0.16, 0.06, 0.06), (x, y, Z + 0.04), P["prim"], 0.01)]


def q1_hard_case(P, x, y, top):
    h = 0.3
    return hanger(P, x, y, top + 0.05) + [
        rig.box("case", (0.46, 0.34, h), (x, y, top - h / 2), P["pkg"], 0.04),
        rig.box("band", (0.465, 0.345, 0.025), (x, y, top - h / 2), P["trim"]),
        rig.box("handle", (0.2, 0.03, 0.05), (x, y, top + 0.025), P["sec"], 0.01),
        rig.box("label", (0.12, 0.01, 0.06), (x - 0.1, y - 0.172, top - 0.08), P["glow"]),
        rig.box("lock", (0.05, 0.012, 0.05), (x + 0.15, y - 0.172, top - 0.08), P["sec"], 0.005)]


def q2_hover_pod(P, x, y, top):
    zc = top - 0.17
    o = [rig.cyl("pod", 0.16, 0.34, (x, y, zc), P["pkg"], 0.01, rot=(0, math.pi / 2, 0), verts=20)]
    for s in (-1, 1):
        o.append(C2.sphere("cap", 0.16, (x + s * 0.17, y, zc), P["pkg"], 16))
    o += [rig.cyl("band", 0.165, 0.04, (x, y, zc), P["trim"], rot=(0, math.pi / 2, 0), verts=20),
          rig.cyl("window", 0.06, 0.01, (x + 0.1, y - 0.16, zc + 0.03), P["glow"], rot=(math.pi / 2, 0, 0), verts=12),
          rig.box("clamp", (0.06, 0.08, 0.18), (x, y, top + 0.03), P["sec"], 0.01)]
    return o + hanger(P, x, y, top + 0.12)


def q3_holo_cube(P, x, y, top):
    s = 0.42
    zc = top - s / 2
    o = [rig.box("field", (s, s, s), (x, y, zc), P["beam"]), rig.box("cargo", (0.2, 0.2, 0.2), (x, y, zc), P["pkg"], 0.01)]
    for ax in range(3):  # the 12 edges, lit
        for a in (-1, 1):
            for b in (-1, 1):
                size = [0.012, 0.012, 0.012]
                size[ax] = s
                pos = [x, y, zc]
                others = [i for i in range(3) if i != ax]
                pos[others[0]] += a * s / 2
                pos[others[1]] += b * s / 2
                o.append(rig.box("edge", tuple(size), tuple(pos), P["trim"]))
    return o + hanger(P, x, y, top)


def q4_claw_crate(P, x, y, top):
    s = 0.38
    zc = top - s / 2 - 0.04
    o = [rig.box("crate", (s, s, s), (x, y, zc), P["pkg"], 0.02),
         rig.box("stripe", (s + 0.005, s + 0.005, 0.03), (x, y, zc - 0.1), P["trim"]),
         rig.cyl("hub", 0.08, 0.08, (x, y, top + 0.04), P["prim"], 0.01, verts=8)]
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        o.append(rig.box("claw", (0.03, 0.03, 0.3), (x + 0.17 * math.cos(a), y + 0.17 * math.sin(a), top - 0.05), P["sec"], 0.005,
                         rot=(-0.5 * math.sin(a), 0.5 * math.cos(a), 0)))
    o += [C2.sphere("eye", 0.018, (x + s * 0.5 * sx * 0.3, y - 0.07, top + 0.06), P["glow"], 8) for sx in (-1, 1)]
    return o + hanger(P, x, y, top + 0.08)


CHAINS = {1: ("neon links", k1_neon_links), 2: ("light cable", k2_light_cable), 3: ("armoured track", k3_armored_track),
          4: ("laser + guide rings", k4_laser)}
PACKAGES = {1: ("hard case", q1_hard_case), 2: ("hover pod", q2_hover_pod), 3: ("holo cube", q3_holo_cube), 4: ("claw crate", q4_claw_crate)}


def scene(P, k, q):
    ring = C.ring
    C.ring = lambda *a, **kw: []  # (the chain variant draws the ring round each post itself)
    try:
        o = []
        for c in (A, B):
            o += C3.cyber(1, c, Z, P)
    finally:
        C.ring = ring
    return o + CHAINS[k][1](P) + PACKAGES[q][1](P, 0.4, -R, Z - 0.32)


if __name__ == "__main__":
    rig.reset()
    g = rig.ground_catcher()
    g.visible_camera = True
    W, H, PX = 672, 400, 96
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.camera.data.ortho_scale = W / PX
    sc.camera.location.y += 1.1 * math.cos(math.radians(45))
    sc.camera.location.z += 1.1 * math.sin(math.radians(45))
    pals = C3.palettes("cyber")
    args = sys.argv[sys.argv.index("--") + 2:]
    if args and args[0] == "palettes":
        jobs = [(int(args[1]), int(args[2]), p) for p in range(1, 5)]
    else:
        jobs = [(k, q, 1) for k in CHAINS for q in PACKAGES]
    for k, q, p in jobs:
        objs = scene(pals[p - 1][1], k, q)
        sc.render.filepath = os.path.join(OUT, f"k{k}-q{q}-p{p}.png")
        bpy.ops.render.render(write_still=True)
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
