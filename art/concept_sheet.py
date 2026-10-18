"""python art/concept_sheet.py RENDER_DIR GROUND_PNG: concepts.py's renders on a patch of in-game ground (a game
screenshot at 64 px a tile), each with vanilla's steel chest for scale, in a 2x2 sheet -> RENDER_DIR/concepts.png"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

src, ground = Path(sys.argv[1]), Image.open(sys.argv[2]).convert("RGBA")
V = Path(r"G:\SteamLibrary\steamapps\common\Factorio\data\base\graphics\entity")
chest = Image.open(V / "steel-chest" / "steel-chest.png").convert("RGBA")
shadow = Image.open(V / "steel-chest" / "steel-chest-shadow.png").convert("RGBA")
k = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
k.putalpha(shadow.getchannel("A").point(lambda v: v // 2))
SETS = {
    "1": {"a-current": "A  current", "b-cog": "B  cog post (Create-like)",
          "e-arcane": "C  arcane bronze + crystal", "f-navy": "D  navy industrial",
          "g-overgrown": "E  overgrown vine", "h-forge": "F  forge-hot tungsten"},
    "2": {"b-cog": "B  cog post (ref)", "i-bolted": "G  bolted to the ground", "j-hover": "H  hover head",
          "k-magnetic": "I  magnetic crystal", "l-solarpunk": "J  solarpunk", "m-steampunk": "K  steampunk",
          "n-cyberpunk": "L  cyberpunk", "o-alien": "M  alien crystal"},
}
names = SETS[sys.argv[3] if len(sys.argv) > 3 else "1"]
COLS = 2
W, H = 448, 320
ROWS = -(-len(names) // COLS)
sheet = Image.new("RGBA", (W * COLS + 12 * (COLS - 1), H * ROWS + 12 * (ROWS - 1)), (30, 30, 30, 255))
try:
    font = ImageFont.truetype("arialbd.ttf", 18)
except OSError:
    font = ImageFont.load_default()
for i, (n, label) in enumerate(names.items()):
    patch = ground.crop((0, 0, 192, 192))  # (a clean corner of the shot, 3x3 tiles, tiled over)
    tile = Image.new("RGBA", (W, H))
    for x in range(0, W, 192):
        for y in range(0, H, 192):
            tile.paste(patch, (x, y))
    gx, gy = 224 - 96, 224 + 64  # the chest: 1.5 tiles west, 1 south of the scene's ground origin (224, 224)
    tile.alpha_composite(k, (gx - shadow.width // 2 + 14, gy - shadow.height // 2 + 4))
    tile.alpha_composite(chest, (gx - chest.width // 2, gy - chest.height // 2))
    tile.alpha_composite(Image.open(src / f"{n}.png").convert("RGBA"))
    d = ImageDraw.Draw(tile)
    d.rectangle((0, 0, 300, 28), fill=(0, 0, 0, 160))
    d.text((8, 4), label, fill=(255, 230, 160, 255), font=font)
    sheet.alpha_composite(tile, ((i % COLS) * (W + 12), (i // COLS) * (H + 12)))
sheet.save(src / f"concepts{sys.argv[3] if len(sys.argv) > 3 else ''}.png")
