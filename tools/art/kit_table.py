"""Inventory of the lobby architecture kit, straight from the built files:
triangles per model (glTF index counts), atlas size and texel density
(albedo PNG), texture sets. Plain Python, no Blender needed:
    python tools/art/kit_table.py            -> text table on stdout
    python tools/art/kit_table.py --html     -> <tr> rows for the style guide
The model list is ArtLibrary.KIT in src/style/art_library.gd.
"""
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "assets" / "models"
TEX = ROOT / "assets" / "textures"


def kit_ids():
    src = (ROOT / "src" / "style" / "art_library.gd").read_text(encoding="utf-8")
    block = src[src.index("const KIT := {"):src.index("}", src.index("const KIT := {"))]
    return re.findall(r'&"([a-z0-9_]+)"', block)


def kit_sets():
    src = (ROOT / "src" / "style" / "art_library.gd").read_text(encoding="utf-8")
    start = src.index("const KIT_SETS := {")
    block = src[start:src.index("}", start)]
    out = {}
    for line in block.splitlines():
        m = re.match(r'\s*&"([a-z0-9_]+)": \[(.*)\],', line)
        if m:
            out[m.group(1)] = re.findall(r'"([a-z0-9_]+)"', m.group(2))
    return out


def triangles(glb):
    data = glb.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    tris = 0
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            if "indices" in prim:
                tris += doc["accessors"][prim["indices"]]["count"] // 3
            else:
                tris += doc["accessors"][prim["attributes"]["POSITION"]]["count"] // 3
    return tris


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def rows():
    sets = kit_sets()
    out = []
    for mid in kit_ids():
        glb = MODELS / f"{mid}.glb"
        if not glb.exists():
            out.append((mid, None, None, sets.get(mid, [])))
            continue
        albedo = TEX / f"{mid}_albedo.png"
        atlas = png_size(albedo) if albedo.exists() else None
        out.append((mid, triangles(glb), atlas, sets.get(mid, [])))
    return out


def main(argv):
    data = rows()
    if "--html" in argv:
        for mid, tris, atlas, extra in data:
            a = f"{atlas[0]}×{atlas[1]}" if atlas else "— (tile)"
            s = ", ".join(f"<code>{x}</code>" for x in extra)
            print(f'<tr><td><code>{mid}</code></td><td class="num">{tris:,}</td><td>{a}</td><td>{s}</td></tr>'
                  .replace(",", " ", 1) if tris and tris >= 1000 else
                  f'<tr><td><code>{mid}</code></td><td class="num">{tris}</td><td>{a}</td><td>{s}</td></tr>')
        return
    total = 0
    for mid, tris, atlas, extra in data:
        total += tris or 0
        a = f"{atlas[0]}x{atlas[1]}" if atlas else "tile"
        print(f"{mid:24s} {tris if tris is not None else 'MISSING':>6} {a:>10}  {' '.join(extra)}")
    print(f"{len(data)} models, {sum(len(r[3]) for r in data)} extra texture sets, {total} triangles in all")


if __name__ == "__main__":
    main(sys.argv[1:])
