"""Recolore les atlas KayKit dans la palette Ippitsu.

Les teintes « peau / os » (claires, orangées, peu saturées) sont gardées,
le reste est ramené vers la couleur demandée.
Usage : py tools/recolor.py <dossier des textures KayKit d'origine>
"""
import colorsys
import sys
from pathlib import Path

from PIL import Image

SRC = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent.parent / "assets" / "kaykit" / "tex"

VARIANTS = {
    # nom de sortie : (atlas d'origine, couleur, intensité)
    "rogue_ink": ("rogue_texture.png", "#4A4858", 0.85),
    "rogue_cape": ("rogue_texture.png", "#D7372B", 0.9),
    "skeleton_red": ("skeleton_texture.png", "#C7362B", 0.9),
    "skeleton_ink": ("skeleton_texture.png", "#2E2D36", 0.85),
    "skeleton_gold": ("skeleton_texture.png", "#C49A45", 0.75),
    "skeleton_prussian": ("skeleton_texture.png", "#2A4A73", 0.9),
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def is_skin(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return 0.01 <= h <= 0.13 and v >= 0.5 and s <= 0.7


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (src, color, amount) in VARIANTS.items():
        img = Image.open(SRC / src).convert("RGBA")
        tint = hex_rgb(color)
        cache = {}
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                p = px[x, y]
                if p in cache:
                    px[x, y] = cache[p]
                    continue
                r, g, b, a = (c / 255 for c in p)
                if is_skin(r, g, b):
                    q = p
                else:
                    lum = 0.299 * r + 0.587 * g + 0.114 * b
                    k = 0.55 + 0.9 * lum
                    q = tuple(round(255 * min(1.0, c * (1 - amount) + t * k * amount)) for c, t in zip((r, g, b), tint)) + (p[3],)
                cache[p] = q
                px[x, y] = q
        img.save(OUT / f"{name}.png", optimize=True)
        print(name, len(cache), "couleurs")


if __name__ == "__main__":
    main()
