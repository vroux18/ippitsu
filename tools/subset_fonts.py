# Réduit les polices du jeu aux caractères réellement utilisés.
# Usage : py tools/subset_fonts.py <dossier des polices complètes>
# (ShipporiMincho-ExtraBold.ttf et ZenKakuGothicNew-Bold.ttf, téléchargées depuis Google Fonts)
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = ["ShipporiMincho-ExtraBold.ttf", "ZenKakuGothicNew-Bold.ttf"]

chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set("«·»ÀÂÇÈÉÊÎÔ×àâçèéêëîïôùûŒœ–—’…")
for path in glob.glob(os.path.join(ROOT, "scripts", "*.gd")):
    with open(path, encoding="utf-8") as f:
        for ch in f.read():
            if ord(ch) > 0x7F and not ch.isspace():
                chars.add(ch)

text = "".join(sorted(chars))
src = sys.argv[1]
for name in FONTS:
    subprocess.run([sys.executable, "-m", "fontTools.subset", os.path.join(src, name),
        "--text=" + text, "--layout-features=*", "--output-file=" + os.path.join(ROOT, "assets", "fonts", name)], check=True)
    print(name, os.path.getsize(os.path.join(ROOT, "assets", "fonts", name)))
