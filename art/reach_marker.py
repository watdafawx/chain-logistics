"""python art/reach_marker.py: graphics/reach-marker.png, the square that marks a post's farthest reachable tile (one
tile: 64 px drawn at scale 0.5), like show-max-underground-distance's marker but our own. White, so rings.lua tints
it (yellow) and sets its opacity (dim, bright on hover)."""
from pathlib import Path

from PIL import Image, ImageDraw

N, SS = 64, 4
img = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
w = 6 * SS
d.rectangle((4 * SS, 4 * SS, (N - 4) * SS - 1, (N - 4) * SS - 1), fill=(255, 255, 255, 40), outline=(255, 255, 255, 255), width=w)
out = Path(__file__).resolve().parent.parent / "graphics" / "reach-marker.png"
img.resize((N, N), Image.LANCZOS).save(out, optimize=True)
print(out)
