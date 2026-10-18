"""python art/combo_sheet.py RENDER_DIR GROUND_PNG [K Q]: concepts4.py's renders on in-game ground (scaled to 96 px
a tile) -> RENDER_DIR/combos.png (rows: chains, columns: packages), or with K Q -> palettes-kK-qQ.png (one combo in
every palette)"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

src, ground = Path(sys.argv[1]), Image.open(sys.argv[2]).convert("RGBA")
CHAINS = ["neon links", "light cable", "armoured track", "laser + guide rings"]
PACKAGES = ["hard case", "hover pod", "holo cube", "claw crate"]
PALS = ["magenta + cyan", "toxic green + yellow", "orange + blue", "red + white"]
W, H = 672, 400
S = 1.0 if len(sys.argv) > 4 else 0.5  # (one combo in every palette: full size)
CROP = (40, 40, 632, 330)  # the span and both heads
w, h = int((CROP[2] - CROP[0]) * S), int((CROP[3] - CROP[1]) * S)
try:
    font = ImageFont.truetype("arialbd.ttf", 15)
    big = ImageFont.truetype("arialbd.ttf", 20)
except OSError:
    font = big = ImageFont.load_default()
patch = ground.crop((0, 0, 192, 192)).resize((288, 288), Image.LANCZOS)  # (64 -> 96 px a tile)
bg = Image.new("RGBA", (W, H))
for x in range(0, W, 288):
    for y in range(0, H, 288):
        bg.paste(patch, (x, y))


def cell(name):
    t = bg.copy()
    t.alpha_composite(Image.open(src / name).convert("RGBA"))
    return t.crop(CROP).resize((w, h), Image.LANCZOS)


def close(name, box, z=2.5):
    t = bg.copy()
    t.alpha_composite(Image.open(src / name).convert("RGBA"))
    c = t.crop(box)
    return c.resize((int(c.width * z), int(c.height * z)), Image.LANCZOS)


if len(sys.argv) > 3 and sys.argv[3] == "detail":  # close-ups: the 4 packages, then the 4 chains (2.5x)
    PK, CH = (300, 165, 450, 295), (150, 120, 330, 205)
    cells = [(f"package {q + 1}: {PACKAGES[q]}", close(f"k1-q{q + 1}-p1.png", PK)) for q in range(4)]
    cells += [(f"chain {k + 1}: {CHAINS[k]}", close(f"k{k + 1}-q1-p1.png", CH)) for k in range(4)]
    cw = max(c.width for _, c in cells)
    rows = [cells[:4], cells[4:]]
    hs = [max(c.height for _, c in r) for r in rows]
    sheet = Image.new("RGBA", (4 * (cw + 6), sum(hs) + 2 * 30 + 6), (28, 28, 28, 255))
    d = ImageDraw.Draw(sheet)
    y = 0
    for r, hh in zip(rows, hs):
        for i, (label, c) in enumerate(r):
            d.text((i * (cw + 6) + 6, y + 6), label, fill=(255, 230, 160, 255), font=font)
            sheet.alpha_composite(c, (i * (cw + 6), y + 30))
        y += hh + 36
    sheet.save(src / "detail.png")
elif len(sys.argv) > 4:
    k, q = int(sys.argv[3]), int(sys.argv[4])
    sheet = Image.new("RGBA", (2 * w + 6, 2 * h + 6 + 40), (28, 28, 28, 255))
    d = ImageDraw.Draw(sheet)
    d.text((8, 8), f"{CHAINS[k - 1]} + {PACKAGES[q - 1]}, every palette", fill=(255, 230, 160, 255), font=big)
    for p in range(4):
        x, y = (p % 2) * (w + 6), 40 + (p // 2) * (h + 6)
        sheet.alpha_composite(cell(f"k{k}-q{q}-p{p + 1}.png"), (x, y))
        d.text((x + 6, y + 4), PALS[p], fill=(230, 230, 230, 255), font=font)
    sheet.save(src / f"palettes-k{k}-q{q}.png")
else:
    left, top = 170, 40
    sheet = Image.new("RGBA", (left + 4 * (w + 6), top + 4 * (h + 6)), (28, 28, 28, 255))
    d = ImageDraw.Draw(sheet)
    for q in range(4):
        d.text((left + q * (w + 6) + 6, 12), f"package {q + 1}: {PACKAGES[q]}", fill=(220, 220, 220, 255), font=font)
    for k in range(4):
        d.text((8, top + k * (h + 6) + h // 2 - 20), f"chain {k + 1}", fill=(255, 230, 160, 255), font=big)
        d.text((8, top + k * (h + 6) + h // 2 + 6), CHAINS[k], fill=(200, 200, 200, 255), font=font)
        for q in range(4):
            sheet.alpha_composite(cell(f"k{k + 1}-q{q + 1}-p1.png"), (left + q * (w + 6), top + k * (h + 6)))
    sheet.save(src / "combos.png")
