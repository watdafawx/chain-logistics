"""python art/variant_sheet.py RENDER_DIR GROUND_PNG: concepts3.py's renders, one sheet a style
(RENDER_DIR/variants-<style>.png): rows are the 4 builds, columns the 4 palettes, on in-game ground with vanilla's
steel chest for scale"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

src, ground = Path(sys.argv[1]), Image.open(sys.argv[2]).convert("RGBA")
V = Path(r"G:\SteamLibrary\steamapps\common\Factorio\data\base\graphics\entity")
chest = Image.open(V / "steel-chest" / "steel-chest.png").convert("RGBA")
BUILDS = {
    "solar": ["flange / leafy tube / solar petals", "planter / bamboo / sun dish", "root tripod / twisted rods / glass dome",
              "mossy tile / branching trunk / panel wings"],
    "steam": ["flange / boiler + gauge / gear", "riveted plinth / piston / flywheel", "claw tripod / pipe bundle / clock + bell",
              "tank on saddles / lattice girder / chimney"],
    "cyber": ["hex pad / spike / holo rings", "wedge / hover motes / hex ring", "cable tripod / twin rails / screens",
              "floating plates / light beam / octagon + antenna"],
    "alien": ["crystal cluster / floating core / crystal tip", "tendrils / spine / shard crown", "geode / twisted spire / orbit",
              "glowing pool / levitating monolith / eye"],
}
TITLE = {"solar": "Solarpunk", "steam": "Steampunk", "cyber": "Cyberpunk", "alien": "Alien crystal"}
W, H, S = 448, 320, 0.62
w, h = int(W * S), int(H * S)
try:
    font = ImageFont.truetype("arialbd.ttf", 15)
    big = ImageFont.truetype("arialbd.ttf", 22)
except OSError:
    font = big = ImageFont.load_default()
patch = ground.crop((0, 0, 192, 192))
bg = Image.new("RGBA", (W, H))
for x in range(0, W, 192):
    for y in range(0, H, 192):
        bg.paste(patch, (x, y))
bg.alpha_composite(chest, (224 - 96 - 32, 224 + 64 - 40))
pal = json.loads((src / "palettes.json").read_text())
for style, pnames in pal.items():
    top, left, gap = 64, 270, 6
    sheet = Image.new("RGBA", (left + 4 * (w + gap), top + 4 * (h + gap)), (28, 28, 28, 255))
    d = ImageDraw.Draw(sheet)
    d.text((10, 10), TITLE[style], fill=(255, 230, 160, 255), font=big)
    for p, n in enumerate(pnames):
        d.text((left + p * (w + gap) + 6, top - 22), f"palette {p + 1}: {n}", fill=(220, 220, 220, 255), font=font)
    for v in range(4):
        d.text((10, top + v * (h + gap) + h // 2 - 20), f"build {v + 1}", fill=(255, 230, 160, 255), font=big)
        d.text((10, top + v * (h + gap) + h // 2 + 8), BUILDS[style][v].replace(" / ", "\n"), fill=(200, 200, 200, 255), font=font)
        for p in range(4):
            tile = bg.copy()
            tile.alpha_composite(Image.open(src / f"{style}-v{v + 1}-p{p + 1}.png").convert("RGBA"))
            sheet.alpha_composite(tile.resize((w, h), Image.LANCZOS), (left + p * (w + gap), top + v * (h + gap)))
    sheet.save(src / f"variants-{style}.png")
