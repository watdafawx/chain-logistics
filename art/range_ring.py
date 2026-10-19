"""python art/range_ring.py: graphics/range-ring.png, the circle a post's span range shows as (data.lua's
radius_visualisation_specification stretches it over 2 x range tiles; tinted per skin there). White, so a tint
colours it; a thin bright rim over a faint fill, drawn 4x and scaled down for a smooth edge."""
from pathlib import Path

from PIL import Image, ImageDraw

N, SS = 512, 4
img = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
r = N * SS / 2
d.ellipse((0, 0, 2 * r - 1, 2 * r - 1), fill=(255, 255, 255, 28))
w = 6 * SS  # rim: 6 px at 512 (about 0.4 of a tile over 32 tiles: reads on grass)
d.ellipse((0, 0, 2 * r - 1, 2 * r - 1), outline=(255, 255, 255, 255), width=w)
out = Path(__file__).resolve().parent.parent / "graphics" / "range-ring.png"
img.resize((N, N), Image.LANCZOS).save(out, optimize=True)
print(out)
