"""blender -b --factory-startup --python art/build.py -- OUT_DIR [SKIN ...]: the mod's sprites, every skin:
OUT_DIR/<skin>/<sprite>/NN.png (+ NN_shadow.png, NN_glow.png) and OUT_DIR/<skin>/icons/; art/pack.py turns them into
graphics/entity/<skin>/ sheets. The look (picked from art/concepts*.py): cyberpunk build 1 posts (a hex pad, a spike,
the head hovering over it in holo rings), a neon-link chain, a hard-case package. Units: tiles, Z up, north +Y."""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1]
CHAIN_Z = 1.95  # chain height above the ground (shared.lua's CHAIN_Z must match)
LINK = 0.125  # chain pitch: 8 links a tile
LIT = 4  # every 4th link is lit, so the pattern repeats every 0.5 tiles (shared.lua's LINK_PAIR)
R = 0.36  # the chain ring round a post (shared.lua's R)
RING_LINKS = 24  # the ring's pattern repeats every 4 links: 60 degrees (shared.lua's RING: that arc at R)

# skin -> (accent, glow): the lit parts. Glows are kept dim (the game's glow layer brightens them at night), and
# orange stays orange: a strong emission clips to yellow-white
SKINS = {
    "magenta": ((1.0, 0.1, 0.6), (0.1, 0.9, 1.0)),
    "toxic": ((0.3, 1.0, 0.15), (1.0, 0.9, 0.1)),
    "orange": ((1.0, 0.32, 0.0), (0.15, 0.4, 1.0)),
    "red": ((1.0, 0.06, 0.06), (0.9, 0.9, 1.0)),
}
GLOW_STRENGTH = 1.2


def mats(skin):
    acc, glw = SKINS[skin]
    m, g = rig.material, rig.glow
    return {
        "prim": m(f"{skin}-prim", (0.05, 0.05, 0.06), 1.0, 0.22, grime=0.1, edge=0.5),
        "sec": m(f"{skin}-sec", (0.18, 0.19, 0.22), 0.9, 0.3, edge=0.6),
        "chain": m(f"{skin}-chain", (0.07, 0.07, 0.08), 0.85, 0.4, grime=0.25, edge=0.3),
        "pkg": m(f"{skin}-pkg", (0.08, 0.08, 0.09), 0.9, 0.3, edge=0.5),
        "trim": g(f"{skin}-trim", acc, GLOW_STRENGTH),
        "glow": g(f"{skin}-glow", glw, GLOW_STRENGTH),
    }


def lit(objs, m):
    return {o for o in objs if o.data.materials and o.data.materials[0] in (m["trim"], m["glow"])}


def link(i, pos, along, m):
    """one oval link; even links lie flat, odd ones stand up; every LIT-th one glows"""
    rot = (0, 0, along) if i % 2 == 0 else (math.pi / 2, 0, along)
    return rig.torus(f"link{i}", 0.046, 0.016, pos, m["trim"] if i % LIT == 0 else m["chain"], rot=rot, scale=(1.45, 1, 1))


def pivot(name, z, parts):
    p = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(p)
    p.location = (0, 0, z)
    for o in parts:
        o.parent = p
        o.location = (o.location[0], o.location[1], o.location[2] - z)
    return p


def frames(name, objs, glow, ground, n, pose, size, shadow_size=None):
    """n frames (pose(i) sets each up): lit, glow-only, and (shadow_size: a wider image, shadows fall east) shadow"""
    for i in range(n):
        pose(i)
        rig.frame(*size)
        rig.render(os.path.join(OUT, name, f"{i:02}.png"), objs, ground)
        if glow:
            rig.render(os.path.join(OUT, name, f"{i:02}_glow.png"), objs, ground, glow=glow)
        if shadow_size:
            rig.frame(*shadow_size)
            rig.render(os.path.join(OUT, name, f"{i:02}_shadow.png"), objs, ground, shadow=True)


def icon(name, objs, ground, centre_z, tiles):
    sc = bpy.context.scene
    cam = sc.camera
    old = cam.location.copy()
    t = math.radians(rig.TILT)
    cam.location = (old[0], old[1] + centre_z * math.sin(t) * math.cos(t), old[2] + centre_z * math.sin(t) ** 2)
    sc.render.resolution_x = sc.render.resolution_y = 64
    cam.data.ortho_scale = tiles
    rig.render(os.path.join(OUT, "icons", f"{name}.png"), objs, ground)
    cam.location = old


def clear(objs):
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


def post(m, ground):
    """a hex pad with a spike; the head hovers over it in two holo rings. The ring of chain round the sprocket turns."""
    Z = CHAIN_Z
    T = rig.torus
    still = [
        rig.cyl("hex", 0.34, 0.06, (0, 0, 0.03), m["prim"], 0.008, verts=6),
        T("hexneon", 0.33, 0.01, (0, 0, 0.062), m["trim"], segs=6),
        rig.cyl("core", 0.14, 0.49, (0, 0, 0.305), m["prim"], 0.01, verts=6),
        T("coreneon", 0.145, 0.01, (0, 0, 0.45), m["glow"], segs=6),
        rig.cyl("spike", 0.05, 0.65, (0, 0, 0.875), m["prim"], verts=6),
        T("holo", 0.3, 0.006, (0, 0, Z - 0.3), m["glow"], segs=32),
        T("holo2", 0.22, 0.006, (0, 0, Z - 0.42), m["trim"], segs=32),
        rig.cyl("housing", 0.24, 0.14, (0, 0, Z - 0.11), m["prim"], 0.015),
        rig.cyl("spr", 0.3, 0.05, (0, 0, Z), m["prim"], 0.008, verts=32),
        rig.cyl("hub", 0.1, 0.08, (0, 0, Z + 0.05), m["trim"], 0.01, verts=16),
        T("rim", 0.31, 0.01, (0, 0, Z + 0.03), m["glow"], segs=32),
    ]
    turning = []
    for k in range(RING_LINKS):
        a = k * math.tau / RING_LINKS
        turning.append(link(k, (R * math.cos(a), R * math.sin(a), Z), a + math.pi / 2, m))
    for k in range(6):  # marks on the sprocket, so it reads as turning
        a = k * math.tau / 6
        turning.append(rig.box("mark", (0.05, 0.02, 0.01), (0.22 * math.cos(a), 0.22 * math.sin(a), Z + 0.026), m["sec"], 0.002, rot=(0, 0, a)))
    hub = pivot("hub", Z, turning)
    objs = still + turning

    def pose(i):  # the lit pattern (4 links, 60 degrees) over 8 frames, the chain running anticlockwise as seen from above
        hub.rotation_euler = (0, 0, math.radians(60) * i / 8)

    frames("post", objs, lit(objs, m), ground, 8, pose, (128, 320), (352, 320))
    pose(0)
    icon("post", objs, ground, 1.0, 2.4)
    clear(objs + [hub])


def span(m, ground):
    """a straight chain running east, centred on the origin (the game draws it rotated, tiled and raised to CHAIN_Z).
    One tile wide; it crawls one lit pattern (0.5 tiles) east over 8 frames."""
    links = [link(i, (-1.5 + i * LINK, 0, 0), 0, m) for i in range(int(3 / LINK) + 1)]
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in links:
        o.parent = root

    def pose(i):
        root.location = (LIT * LINK * i / 8, 0, 0)

    frames("span", links, lit(links, m), ground, 8, pose, (64, 32))
    clear(links + [root])


def package(m, ground):
    """a hard case on a hanger and trolley; it swings a little as it rides"""
    Z = CHAIN_Z
    top = Z - 0.32
    h = 0.3
    parts = [
        rig.box("case", (0.46, 0.34, h), (0, 0, top - h / 2), m["pkg"], 0.04),
        rig.box("band", (0.465, 0.345, 0.025), (0, 0, top - h / 2), m["trim"]),
        rig.box("handle", (0.2, 0.03, 0.05), (0, 0, top + 0.025), m["sec"], 0.01),
        rig.box("label", (0.12, 0.01, 0.06), (-0.1, -0.172, top - 0.08), m["glow"]),
        rig.box("lock", (0.05, 0.012, 0.05), (0.15, -0.172, top - 0.08), m["sec"], 0.005),
        rig.cyl("rod", 0.015, Z - top - 0.05, (0, 0, (Z + top + 0.05) / 2), m["sec"], verts=8),
        rig.box("trolley", (0.16, 0.06, 0.06), (0, 0, Z + 0.04), m["prim"], 0.01),
    ]
    piv = pivot("pivot", Z, parts)

    def pose(i):
        piv.rotation_euler = (math.radians(5) * math.sin(math.tau * i / 8), 0, 0)

    frames("package", parts, lit(parts, m), ground, 8, pose, (64, 256), (288, 256))
    pose(0)
    icon("package", parts, ground, top - 0.1, 0.8)
    clear(parts + [piv])


root_out = OUT
for skin in (sys.argv[sys.argv.index("--") + 2:] or SKINS):
    OUT = os.path.join(root_out, skin)
    rig.reset()
    g = rig.ground_catcher()
    mm = mats(skin)
    post(mm, g)
    span(mm, g)
    package(mm, g)
