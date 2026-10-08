import colorsys
from PIL import Image
SRC = "assets/kaykit/tex/rogue_ink.png"
V = {"indigo": "#2B4C7E", "matcha": "#5E7F4A", "kaki": "#E8692A", "sakura": "#D98AA0",
     "neige": "#FBF8F2", "glycine": "#7A5FA0", "or": "#E2B04A"}
def rgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))
def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.01 <= h <= 0.13 and v >= 0.5 and s <= 0.7
for name, col in V.items():
    img = Image.open(SRC).convert("RGBA"); px = img.load(); t = rgb(col); cache = {}
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p not in cache:
                r, g, b, a = (c / 255 for c in p)
                if is_skin(r, g, b):
                    q = p
                else:
                    lum = 0.299 * r + 0.587 * g + 0.114 * b
                    k = 0.78 + 1.4 * (lum - 0.27)
                    q = tuple(round(255 * max(0.0, min(1.0, c * 0.12 + tc * k * 0.88))) for c, tc in zip((r, g, b), t)) + (p[3],)
                cache[p] = q
            px[x, y] = cache[p]
    img.save(f"assets/kaykit/tex/rogue_{name}.png", optimize=True)
    print(name, len(cache))
