"""Allège les modèles KayKit (.glb) : ne garde que les animations utilisées par le jeu.

- supprime les animations absentes de KEEP ;
- retire les accessors / bufferViews devenus inutiles et compacte le buffer binaire
  (tous les index sont renumérotés partout où ils apparaissent) ;
- optionnel : réduit la texture embarquée à --tex N pixels (Lanczos) si elle est plus grande.

Idempotent : relancer le script sur des fichiers déjà allégés ne change rien.

Usage :
  py tools/strip_anims.py [--tex 512] [--orig <dossier des .glb d'origine>] [fichiers.glb ...]
  (par défaut : assets/kaykit/*.glb ; --orig vérifie que maillages/peau sont identiques à l'octet)

Si le jeu se met à jouer une nouvelle animation, l'ajouter à KEEP et relancer le script
sur les .glb d'origine (pack KayKit Adventurers / Skeletons).
"""
import argparse
import io
import json
import struct
import sys
from pathlib import Path

# Union de tous les noms joués dans scripts/*.gd (hero, enemy, boss, main, character).
# Appliquée à chaque modèle (un nom absent d'un modèle est simplement ignoré).
KEEP = {
    # boucles
    "Idle", "Idle_Combat", "Blocking", "Walking_A", "Walking_B", "Walking_D_Skeletons",
    # héros
    "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Stab",
    "2H_Melee_Attack_Spinning", "Block", "Jump_Full_Short", "Death_A", "Hit_A",
    # ennemis / boss
    "1H_Melee_Attack_Chop", "2H_Melee_Attack_Chop", "Spawn_Ground_Skeletons", "Death_C_Skeletons",
    "Spellcast_Shoot", "Throw",
}

ROOT = Path(__file__).resolve().parent.parent
GLB_MAGIC, CH_JSON, CH_BIN = 0x46546C67, 0x4E4F534A, 0x004E4942


def read_glb(path):
    d = Path(path).read_bytes()
    magic, ver, total = struct.unpack_from("<III", d, 0)
    assert magic == GLB_MAGIC and ver == 2 and total == len(d), path
    jl, jt = struct.unpack_from("<II", d, 12)
    assert jt == CH_JSON
    j = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl, bt = struct.unpack_from("<II", d, off)
    assert bt == CH_BIN
    return j, d[off + 8:off + 8 + bl]


def write_glb(path, j, bin_):
    js = json.dumps(j, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    js += b" " * (-len(js) % 4)
    bin_ += b"\0" * (-len(bin_) % 4)
    total = 12 + 8 + len(js) + 8 + len(bin_)
    out = struct.pack("<III", GLB_MAGIC, 2, total) + struct.pack("<II", len(js), CH_JSON) + js
    out += struct.pack("<II", len(bin_), CH_BIN) + bin_
    Path(path).write_bytes(out)
    return total


def bv_bytes(j, bin_, i):
    bv = j["bufferViews"][i]
    o = bv.get("byteOffset", 0)
    return bin_[o:o + bv["byteLength"]]


def accessor_refs(j):
    """Yield (container, key) pairs holding an accessor index."""
    for m in j.get("meshes", []):
        for p in m["primitives"]:
            for k in p["attributes"]:
                yield p["attributes"], k
            if "indices" in p:
                yield p, "indices"
            for t in p.get("targets", []):
                for k in t:
                    yield t, k
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            yield s, "inverseBindMatrices"
    for a in j.get("animations", []):
        for s in a["samplers"]:
            yield s, "input"
            yield s, "output"


def bufferview_refs(j):
    for a in j.get("accessors", []):
        if "bufferView" in a:
            yield a, "bufferView"
        sp = a.get("sparse")
        if sp:
            yield sp["indices"], "bufferView"
            yield sp["values"], "bufferView"
    for im in j.get("images", []):
        if "bufferView" in im:
            yield im, "bufferView"


def strip(j, bin_, keep, tex_size):
    anims = j.get("animations", [])
    j["animations"] = [a for a in anims if a.get("name") in keep]
    if not j["animations"]:
        del j["animations"]

    # textures embarquées : remplacer les octets avant compaction
    new_images = {}
    if tex_size:
        from PIL import Image
        for ii, im in enumerate(j.get("images", [])):
            if "bufferView" not in im:
                continue
            img = Image.open(io.BytesIO(bv_bytes(j, bin_, im["bufferView"])))
            if max(img.size) <= tex_size:
                continue
            w, h = img.size
            f = tex_size / max(w, h)
            img = img.resize((max(1, round(w * f)), max(1, round(h * f))), Image.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, "PNG", optimize=True)
            new_images[im["bufferView"]] = buf.getvalue()
            im["mimeType"] = "image/png"

    # accessors utilisés
    used_acc = sorted({c[k] for c, k in accessor_refs(j)})
    acc_map = {old: new for new, old in enumerate(used_acc)}
    for c, k in accessor_refs(j):
        c[k] = acc_map[c[k]]
    j["accessors"] = [j["accessors"][i] for i in used_acc]

    # bufferViews utilisés
    used_bv = sorted({c[k] for c, k in bufferview_refs(j)})
    bv_map = {old: new for new, old in enumerate(used_bv)}
    out = bytearray()
    new_bvs = []
    for old in used_bv:
        bv = dict(j["bufferViews"][old])
        data = new_images.get(old, bv_bytes(j, bin_, old))
        out += b"\0" * (-len(out) % 4)
        bv["buffer"] = 0
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(data)
        out += data
        new_bvs.append(bv)
    out += b"\0" * (-len(out) % 4)
    for c, k in bufferview_refs(j):
        c[k] = bv_map[c[k]]
    j["bufferViews"] = new_bvs
    assert len(j["buffers"]) == 1
    j["buffers"][0]["byteLength"] = len(out)
    return j, bytes(out)


COMP_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


def accessor_bytes(j, bin_, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    elem = COMP_SIZE[a["componentType"]] * TYPE_N[a["type"]]
    stride = bv.get("byteStride", elem)
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    span = stride * (a["count"] - 1) + elem
    return bin_[start:start + span]


def validate(path, orig_path=None):
    j, b = read_glb(path)
    errs = []
    nacc, nbv, nnodes = len(j["accessors"]), len(j["bufferViews"]), len(j["nodes"])
    if j["buffers"][0]["byteLength"] != len(b):
        errs.append("buffer length mismatch")
    for c, k in accessor_refs(j):
        if not 0 <= c[k] < nacc:
            errs.append(f"accessor index {c[k]} out of range")
    for c, k in bufferview_refs(j):
        if not 0 <= c[k] < nbv:
            errs.append(f"bufferView index {c[k]} out of range")
    for i, bv in enumerate(j["bufferViews"]):
        o = bv.get("byteOffset", 0)
        if o % 4:
            errs.append(f"bufferView {i} not 4-byte aligned")
        if o + bv["byteLength"] > len(b):
            errs.append(f"bufferView {i} overflows buffer")
    for i, a in enumerate(j["accessors"]):
        bv = j["bufferViews"][a["bufferView"]]
        elem = COMP_SIZE[a["componentType"]] * TYPE_N[a["type"]]
        if a.get("byteOffset", 0) + bv.get("byteStride", elem) * (a["count"] - 1) + elem > bv["byteLength"]:
            errs.append(f"accessor {i} overflows its bufferView")
    for a in j.get("animations", []):
        for ch in a["channels"]:
            if not 0 <= ch["target"]["node"] < nnodes:
                errs.append(f"anim {a['name']}: bad target node")
            if not 0 <= ch["sampler"] < len(a["samplers"]):
                errs.append(f"anim {a['name']}: bad sampler")
    for s in j.get("skins", []):
        for n in s["joints"]:
            if not 0 <= n < nnodes:
                errs.append("skin joint out of range")
    if orig_path:
        oj, ob = read_glb(orig_path)
        for k in ("nodes", "scenes", "materials", "textures", "samplers"):
            if oj.get(k) != j.get(k):
                errs.append(f"'{k}' differs from original")
        # maillages + peaux identiques à l'octet
        for mi, (om, nm) in enumerate(zip(oj["meshes"], j["meshes"])):
            for pi, (op, np_) in enumerate(zip(om["primitives"], nm["primitives"])):
                pairs = [(op["attributes"][k], np_["attributes"][k]) for k in op["attributes"]]
                if "indices" in op:
                    pairs.append((op["indices"], np_["indices"]))
                for oa, na in pairs:
                    if accessor_bytes(oj, ob, oa) != accessor_bytes(j, b, na):
                        errs.append(f"mesh {mi} prim {pi} data differs")
        if len(oj["meshes"]) != len(j["meshes"]):
            errs.append("mesh count differs")
        for si, (os_, ns) in enumerate(zip(oj["skins"], j["skins"])):
            if os_["joints"] != ns["joints"] or accessor_bytes(oj, ob, os_["inverseBindMatrices"]) != accessor_bytes(j, b, ns["inverseBindMatrices"]):
                errs.append(f"skin {si} differs")
        # animations gardées identiques à l'octet
        oa_by = {a["name"]: a for a in oj.get("animations", [])}
        for a in j.get("animations", []):
            o = oa_by[a["name"]]
            if [c["target"] for c in o["channels"]] != [c["target"] for c in a["channels"]]:
                errs.append(f"anim {a['name']} channels differ")
            for os2, ns2 in zip(o["samplers"], a["samplers"]):
                if os2.get("interpolation") != ns2.get("interpolation"):
                    errs.append(f"anim {a['name']} interpolation differs")
                for k in ("input", "output"):
                    if accessor_bytes(oj, ob, os2[k]) != accessor_bytes(j, b, ns2[k]):
                        errs.append(f"anim {a['name']} {k} data differs")
        expected = sorted(n for n in oa_by if n in KEEP)
        if sorted(a["name"] for a in j.get("animations", [])) != expected:
            errs.append("kept animation set mismatch")
    return errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--tex", type=int, default=0, help="taille max de la texture embarquée (0 = inchangée)")
    ap.add_argument("--orig", help="dossier des .glb d'origine pour la vérification octet par octet")
    args = ap.parse_args()
    files = [Path(f) for f in args.files] or sorted((ROOT / "assets" / "kaykit").glob("*.glb"))
    ok = True
    for f in files:
        before = f.stat().st_size
        j, b = read_glb(f)
        names = [a.get("name") for a in j.get("animations", [])]
        j, b = strip(j, b, KEEP, args.tex)
        after = write_glb(f, j, b)
        kept = [a["name"] for a in j.get("animations", [])]
        print(f"{f.name}: {before} -> {after} octets, animations {len(names)} -> {len(kept)}")
        print("   gardées :", ", ".join(kept))
        errs = validate(f, Path(args.orig) / f.name if args.orig else None)
        for e in errs[:20]:
            print("   ERREUR :", e)
        ok = ok and not errs
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
