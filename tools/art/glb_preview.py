"""Software preview of exported .glb models: no Blender, no Cycles, no window.

A plain numpy rasteriser (z-buffer, nearest texels, the albedo's alpha cut at
0.5, lambert + ambient, glass blended over) for looking at a model right after
`build_models.py ... --no-preview`, e.g. at night when no render may run:

    "D:/Program Files/Blender Foundation/Blender 5.1/5.1/python/bin/python.exe" \
        tools/art/glb_preview.py <model> [model ...] [--views=front,side,back,top,34,43]
        [--size=320] [--out=tests/_out/art/glb_<first model>.png] [--focus=x,y,z --radius=r]

Each model gets a row of orthographic views in Godot axes (Y up, the front
faces -Z): front = seen from -Z, side = from +X, back = from +Z, top = from
above (front down), 34 / 43 = three-quarter views from the front left / right
(a view may also be a "yaw:elevation" pair in degrees, yaw 0 = from +Z).
Textures: assets/textures/<material>_albedo.png ("tile:<set>" materials use
<set>). A grey 1.8 m bar left of each view shows a guard's height. Prints each
model's bounds and triangle count.
"""
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "art"))
from artlib import imageio  # noqa: E402

COMP = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
VIEWS = {"front": (180.0, 0.0), "side": (90.0, 0.0), "back": (0.0, 0.0), "left": (-90.0, 0.0),
         "top": (180.0, 89.0), "34": (-145.0, 18.0), "43": (145.0, 18.0)}
BACKGROUND = np.array([0.05, 0.055, 0.07])
GUARD = 1.8


def load_glb(path):
    data = Path(path).read_bytes()
    off = 12
    js = binc = None
    while off < len(data):
        ln, typ = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8: off + 8 + ln]
        if typ == b"JSON":
            js = json.loads(chunk)
        elif typ[:3] == b"BIN":
            binc = chunk
        off += 8 + ln
    return js, binc


def accessor(js, binc, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    dt = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    count = a["count"]
    item = np.dtype(dt).itemsize * n
    if stride and stride != item:
        raw = np.frombuffer(binc, dtype=np.uint8, count=stride * (count - 1) + item, offset=start)
        rows = np.stack([raw[k * stride: k * stride + item] for k in range(count)])
        arr = rows.view(dt).reshape(count, n)
    else:
        arr = np.frombuffer(binc, dtype=dt, count=count * n, offset=start).reshape(count, n)
    return arr.astype(np.float64) if dt == np.float32 else arr.astype(np.int64)


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def node_mat(n):
    if "matrix" in n:
        return np.array(n["matrix"]).reshape(4, 4).T
    m = np.eye(4)
    m[:3, :3] = quat_mat(n.get("rotation", [0, 0, 0, 1])) @ np.diag(n.get("scale", [1, 1, 1]))
    m[:3, 3] = n.get("translation", [0, 0, 0])
    return m


_TEX = {}


def texture(name):
    name = name.split(":", 1)[-1]
    if name not in _TEX:
        p = ROOT / "assets" / "textures" / f"{name}_albedo.png"
        _TEX[name] = imageio.load_png(p) if p.exists() else None
    return _TEX[name]


def triangles(path):
    """[(world verts (n, 3, 3), uvs (n, 3, 2), material name)] of a .glb."""
    js, binc = load_glb(path)
    out = []

    def walk(i, parent):
        n = js["nodes"][i]
        m = parent @ node_mat(n)
        if "mesh" in n:
            for prim in js["meshes"][n["mesh"]]["primitives"]:
                attrs = prim["attributes"]
                pos = accessor(js, binc, attrs["POSITION"])
                uv = accessor(js, binc, attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else np.zeros((len(pos), 2))
                idx = accessor(js, binc, prim["indices"]).reshape(-1, 3) if "indices" in prim \
                    else np.arange(len(pos)).reshape(-1, 3)
                w = (m[:3, :3] @ pos.T).T + m[:3, 3]
                mat = js["materials"][prim["material"]]["name"] if "material" in prim else ""
                out.append((w[idx], uv[idx], mat))
        for c in n.get("children", []):
            walk(c, m)
    for r in js["scenes"][js.get("scene", 0)]["nodes"]:
        walk(r, np.eye(4))
    return out


def _raster(img, zb, sx, sy, sz, uvs, nrm, fwd, light, tex, glass):
    size = img.shape[0]
    for t in range(len(sx)):
        x0, x1 = int(max(0, math.floor(sx[t].min()))), int(min(size - 1, math.ceil(sx[t].max())))
        y0, y1 = int(max(0, math.floor(sy[t].min()))), int(min(size - 1, math.ceil(sy[t].max())))
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        ax, ay, bx, by, cx, cy = sx[t, 0], sy[t, 0], sx[t, 1], sy[t, 1], sx[t, 2], sy[t, 2]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not inside.any():
            continue
        z = l0 * sz[t, 0] + l1 * sz[t, 1] + l2 * sz[t, 2]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        win = inside & (z > sub)
        if not win.any():
            continue
        n = nrm[t] if nrm[t] @ fwd >= 0 else -nrm[t]
        shade = 0.28 + 0.62 * max(0.0, float(n @ light)) + 0.18 * max(0.0, float(n @ fwd))
        region = img[y0:y1 + 1, x0:x1 + 1]
        if glass:
            region[win] = region[win] * 0.6 + np.array([0.55, 0.7, 0.8]) * shade * 0.4
            continue
        if tex is not None:
            u = l0 * uvs[t, 0, 0] + l1 * uvs[t, 1, 0] + l2 * uvs[t, 2, 0]
            v = l0 * uvs[t, 0, 1] + l1 * uvs[t, 1, 1] + l2 * uvs[t, 2, 1]
            h, w = tex.shape[:2]
            px = np.clip((np.mod(u, 1.0) * w).astype(int), 0, w - 1)
            py = np.clip((np.mod(v, 1.0) * h).astype(int), 0, h - 1)
            col = tex[py, px, :3]
            if tex.shape[2] == 4:
                win &= tex[py, px, 3] >= 0.5
        else:
            col = np.zeros(inside.shape + (3,)) + 0.6
        sub[win] = z[win]
        region[win] = col[win] * shade


def render(tris, yaw, elev, size, bounds, focus=None, rad=None):
    lo, hi = bounds
    c = (lo + hi) * 0.5 if focus is None else np.asarray(focus, dtype=float)
    radius = max(np.linalg.norm(hi - lo) * 0.5, GUARD * 0.5, 0.05) if rad is None else rad
    ya, el = math.radians(yaw), math.radians(elev)
    # fwd: from the model toward the camera
    fwd = np.array([math.sin(ya) * math.cos(el), math.sin(el), math.cos(ya) * math.cos(el)])
    right = np.cross([0.0, 1.0, 0.0], fwd)
    right /= np.linalg.norm(right)
    up = np.cross(fwd, right)
    light = np.array([0.4, 0.8, -0.45])
    light /= np.linalg.norm(light)
    img = np.zeros((size, size, 3)) + BACKGROUND
    zb = np.full((size, size), -np.inf)
    scale = size / (2.1 * radius)
    # the guard's height beside the model (on its floor)
    if elev < 60.0:
        y_foot = size / 2 - (np.array([0.0, lo[1] - c[1], 0.0]) @ up) * scale
        y_head = size / 2 - (np.array([0.0, lo[1] + GUARD - c[1], 0.0]) @ up) * scale
        ya0, ya1 = int(max(0, min(y_head, y_foot))), int(min(size, max(y_head, y_foot)))
        img[ya0:ya1, 3:6] = 0.3
    glass = []
    for verts, uvs, mat in tris:
        rel = verts - c
        sx = (rel @ right) * scale + size / 2
        sy = size / 2 - (rel @ up) * scale
        sz = rel @ fwd
        nrm = np.cross(verts[:, 1] - verts[:, 0], verts[:, 2] - verts[:, 0])
        nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
        if mat == "glass" or mat.endswith("_glass"):
            glass.append((sx, sy, sz, uvs, nrm))
            continue
        _raster(img, zb, sx, sy, sz, uvs, nrm, fwd, light, texture(mat), False)
    for sx, sy, sz, uvs, nrm in glass:
        _raster(img, zb.copy(), sx, sy, sz, uvs, nrm, fwd, light, None, True)
    return img


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    views = []
    for v in opts.get("views", "front,side,top,34").split(","):
        views.append(VIEWS[v] if v in VIEWS else tuple(float(x) for x in v.split(":")))
    size = int(opts.get("size", "320"))
    focus = [float(v) for v in opts["focus"].split(",")] if "focus" in opts else None
    rad = float(opts["radius"]) if "radius" in opts else None
    out = Path(opts.get("out", ROOT / "tests" / "_out" / "art" / f"glb_{args[0]}.png"))
    rows = []
    for name in args:
        tris = triangles(ROOT / "assets" / "models" / f"{name}.glb")
        allv = np.concatenate([t[0].reshape(-1, 3) for t in tris])
        bounds = (allv.min(0), allv.max(0))
        print(f"{name}: bounds {np.round(bounds[0], 3)} .. {np.round(bounds[1], 3)} size "
              f"{np.round(bounds[1] - bounds[0], 3)} tris {sum(len(t[0]) for t in tris)} materials "
              f"{sorted({t[2] for t in tris})}")
        rows.append(np.concatenate([render(tris, y, e, size, bounds, focus, rad) for y, e in views], axis=1))
    out.parent.mkdir(parents=True, exist_ok=True)
    imageio.save_png(out, np.clip(np.concatenate(rows, axis=0), 0, 1))
    print(out)


if __name__ == "__main__":
    main(sys.argv[1:])
