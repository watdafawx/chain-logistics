"""blender -b --factory-startup --python art/calibrate.py -- OUT_DIR: a 0.9-tile box at a few heights, to hold
next to vanilla's steel chest (64x80 px) and check the camera"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402

out = sys.argv[sys.argv.index("--") + 1]
rig.reset()
rig.frame(128, 128)
ground = rig.ground_catcher()
steel = rig.material("steel", (0.42, 0.42, 0.44), 0.8, 0.45)
for h in (0.6, 0.75, 0.9):
    b = rig.box("b", (0.9, 0.9, h), (0, 0, h / 2), steel)
    rig.render(os.path.join(out, f"box_{h}.png"), [b], ground)
    rig.render(os.path.join(out, f"box_{h}_shadow.png"), [b], ground, shadow=True)
    import bpy
    bpy.data.objects.remove(b)
