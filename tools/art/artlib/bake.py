"""Atlas packing and per-texel baking of procedural materials onto meshes.

Pipeline for one model:
  pack(parts, ppm)      islands (metre UVs) -> one atlas at `ppm` pixels/metre,
                        islands snapped to whole texels, padded for mipmaps
  bake(objects, ...)    rasterises every triangle into the atlas, computes per
                        texel position / normal / tangent frame, distance to
                        sharp convex & concave edges, curvature and ray-traced
                        ambient occlusion, then runs the material functions
                        (materials.py) and writes albedo / normal / ORM maps.
"""
import math
import time

import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from . import painter

SHARP = math.radians(28.0)


# --------------------------------------------------------------------------
# packing
# --------------------------------------------------------------------------

def _islands(part, atlas_slots):
    """Union-find over faces that share an edge with matching UVs."""
    bm = part.bm
    # element indices are stale (even garbage) after bmesh ops like bevel:
    # renumber, or islands would depend on memory contents between runs
    bm.faces.index_update()
    bm.faces.ensure_lookup_table()
    uv = part.uv
    faces = [f for f in bm.faces if part.slots[f.material_index] in atlas_slots]
    parent = {f.index: f.index for f in faces}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    ok = set(parent)
    for e in bm.edges:
        lf = [f for f in e.link_faces if f.index in ok]
        if len(lf) != 2:
            continue
        f1, f2 = lf

        def uv_of(f, v):
            for loop in f.loops:
                if loop.vert == v:
                    return loop[uv].uv
            return None

        same = True
        for v in e.verts:
            a, b = uv_of(f1, v), uv_of(f2, v)
            if (a - b).length > 1e-5:
                same = False
                break
        if same:
            ra, rb = find(f1.index), find(f2.index)
            if ra != rb:
                parent[ra] = rb
    groups = {}
    for f in faces:
        groups.setdefault(find(f.index), []).append(f)
    out = []
    for fs in groups.values():
        us = [loop[uv].uv.x for f in fs for loop in f.loops]
        vs = [loop[uv].uv.y for f in fs for loop in f.loops]
        out.append({"part": part, "faces": fs, "u0": min(us), "u1": max(us), "v0": min(vs), "v1": max(vs)})
    return out


def _skyline(islands, W):
    """Bottom-left skyline packing. Returns ([(island, x, y)], used height)."""
    sky = [(0, W, 0)]          # segments (x, width, y)
    placed = []
    for i in islands:
        w, h = i["w"], i["h"]
        best = None
        for s in range(len(sky)):
            x = sky[s][0]
            if x + w > W:
                break
            # the island rests on the highest segment it spans
            y = 0
            span = 0
            k = s
            while span < w and k < len(sky):
                y = max(y, sky[k][2])
                span += sky[k][1]
                k += 1
            if span < w:
                continue
            if best is None or (y + h, x) < (best[0] + h, best[1]):
                best = (y, x)
        y, x = best
        placed.append((i, x, y))
        # rebuild the skyline with the new top
        new = []
        for sx, sw, sy in sky:
            s0, s1 = sx, sx + sw
            if s1 <= x or s0 >= x + w:
                new.append((sx, sw, sy))
                continue
            if s0 < x:
                new.append((s0, x - s0, sy))
            if s1 > x + w:
                new.append((x + w, s1 - x - w, sy))
        new.append((x, w, y + h))
        new.sort()
        merged = []
        for seg in new:
            if merged and merged[-1][2] == seg[2] and merged[-1][0] + merged[-1][1] == seg[0]:
                merged[-1] = (merged[-1][0], merged[-1][1] + seg[1], seg[2])
            else:
                merged.append(seg)
        sky = merged
    return placed, max(s[2] for s in sky)


def pack(parts, atlas_slots, ppm, pad=4, min_size=64):
    """Shelf-packs all islands of all parts. Returns (W, H)."""
    isl = []
    for part in parts:
        isl.extend(_islands(part, atlas_slots))
    for i in isl:
        i["x0"] = math.floor(i["u0"] * ppm + 1e-4)
        i["y0"] = math.floor(i["v0"] * ppm + 1e-4)
        i["w"] = max(1, math.ceil(i["u1"] * ppm - 1e-4) - i["x0"]) + 2 * pad
        i["h"] = max(1, math.ceil(i["v1"] * ppm - 1e-4) - i["y0"]) + 2 * pad
    area = sum(i["w"] * i["h"] for i in isl)
    widest = max(i["w"] for i in isl)
    isl.sort(key=lambda i: (-i["h"], -i["w"]))
    # atlas sides are multiples of 32 (not powers of two): the GPU does not
    # mind and 4 m wall strips (264 px with padding) would waste half an atlas
    best = None
    start = max(min_size, ((max(widest, int(math.sqrt(area) * 0.7)) + 31) // 32) * 32)
    for W in range(start, max(start, int(math.sqrt(area) * 2.2)) + 32, 32):
        placed, used_h = _skyline(isl, W)
        H = max(min_size, ((used_h + 31) // 32) * 32)
        if max(W, H) <= 2 * min(W, H) and (best is None or W * H < best[0]):
            best = (W * H, W, H, placed)
    if best is None:
        placed, used_h = _skyline(isl, start)
        best = (0, start, max(min_size, ((used_h + 31) // 32) * 32), placed)
    _, W, H, placed = best
    for i, px, py in placed:
        part = i["part"]
        uv = part.uv
        lay = part.bm.faces.layers.int["longu"]
        longu = 1 if (i["u1"] - i["u0"]) >= (i["v1"] - i["v0"]) else 0
        # image rows grow downwards; island top (v1) sits at row py + pad
        top = math.ceil(i["v1"] * ppm - 1e-4)
        for f in i["faces"]:
            f[lay] = longu
            for loop in f.loops:
                u, v = loop[uv].uv
                col = u * ppm - i["x0"] + px + pad
                row = top - v * ppm + py + pad
                loop[uv].uv = (col / W, 1.0 - row / H)
    return W, H


# --------------------------------------------------------------------------
# mesh -> numpy
# --------------------------------------------------------------------------

class MeshData:
    def __init__(self, obj):
        me = obj.data
        me.calc_loop_triangles()
        T = len(me.loop_triangles)
        self.T = T
        loops = np.empty(T * 3, np.int64)
        me.loop_triangles.foreach_get("loops", loops)
        verts = np.empty(T * 3, np.int64)
        me.loop_triangles.foreach_get("vertices", verts)
        self.poly = np.empty(T, np.int64)
        me.loop_triangles.foreach_get("polygon_index", self.poly)
        self.mat = np.empty(T, np.int64)
        me.loop_triangles.foreach_get("material_index", self.mat)
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        mw = np.array(obj.matrix_world)
        co_w = co @ mw[:3, :3].T + mw[:3, 3]
        cn = np.empty(len(me.loops) * 3)
        me.corner_normals.foreach_get("vector", cn)
        cn = cn.reshape(-1, 3) @ mw[:3, :3].T
        uv = np.empty(len(me.loops) * 2)
        me.uv_layers["UVMap"].data.foreach_get("uv", uv)
        uvm = np.empty(len(me.loops) * 2)
        me.uv_layers["UVM"].data.foreach_get("uv", uvm)
        self.loops = loops.reshape(T, 3)
        self.verts = verts.reshape(T, 3)
        self.co = co_w
        self.pos = co_w[self.verts]                       # (T,3,3)
        self.nrm = cn.reshape(-1, 3)[self.loops]         # (T,3,3)
        self.uv = uv.reshape(-1, 2)[self.loops]          # (T,3,2)
        self.uvm = uvm.reshape(-1, 2)[self.loops]        # (T,3,2)
        self.longu = np.ones(len(me.polygons), np.int64)
        if "longu" in me.attributes:
            me.attributes["longu"].data.foreach_get("value", self.longu)
        self.slots = [m.name.split(":", 1)[-1] if m else "" for m in me.materials]
        self.obj = obj


def _tangents(md):
    e1 = md.pos[:, 1] - md.pos[:, 0]
    e2 = md.pos[:, 2] - md.pos[:, 0]
    d1 = md.uvm[:, 1] - md.uvm[:, 0]
    d2 = md.uvm[:, 2] - md.uvm[:, 0]
    det = d1[:, 0] * d2[:, 1] - d2[:, 0] * d1[:, 1]
    ok = np.abs(det) > 1e-12
    r = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    t = (e1 * d2[:, 1:2] - e2 * d1[:, 1:2]) * r[:, None]
    b = (e2 * d1[:, 0:1] - e1 * d2[:, 0:1]) * r[:, None]

    def norm(v, fallback):
        ln = np.linalg.norm(v, axis=1, keepdims=True)
        return np.where(ln > 1e-9, v / np.maximum(ln, 1e-9), fallback)

    t = norm(t, np.array([1.0, 0, 0]))
    b = norm(b, np.array([0, 0, 1.0]))
    return t, b


# --------------------------------------------------------------------------
# rasterisation
# --------------------------------------------------------------------------

def rasterize(uv, W, H):
    """uv: (T,3,2) in [0,1]. Returns tri index map (H,W) and barycentrics (H,W,3)."""
    tri = np.full((H, W), -1, np.int64)
    bary = np.zeros((H, W, 3))
    px = np.empty_like(uv)
    px[..., 0] = uv[..., 0] * W
    px[..., 1] = (1.0 - uv[..., 1]) * H
    for t in range(uv.shape[0]):
        a, b, c = px[t]
        x0 = max(int(math.floor(min(a[0], b[0], c[0]))), 0)
        x1 = min(int(math.ceil(max(a[0], b[0], c[0]))), W - 1)
        y0 = max(int(math.floor(min(a[1], b[1], c[1]))), 0)
        y1 = min(int(math.ceil(max(a[1], b[1], c[1]))), H - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not inside.any():
            continue
        yy = ys[inside].astype(np.int64)
        xx = xs[inside].astype(np.int64)
        tri[yy, xx] = t
        bary[yy, xx, 0] = w0[inside]
        bary[yy, xx, 1] = w1[inside]
        bary[yy, xx, 2] = w2[inside]
    return tri, bary


# --------------------------------------------------------------------------
# edges, curvature, AO
# --------------------------------------------------------------------------

def _sharp_edges(obj):
    """Per polygon: arrays of sharp edge segments (world) and their convexity."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    mw = obj.matrix_world
    per_face = {}
    for e in bm.edges:
        if len(e.link_faces) != 2 or e.smooth:
            continue          # smooth-shaded edges (lathes, clay) get no painted edge
        ang = e.calc_face_angle_signed(0.0)
        if abs(ang) < SHARP:
            continue
        a = mw @ e.verts[0].co
        b = mw @ e.verts[1].co
        for f in e.link_faces:
            per_face.setdefault(f.index, []).append((tuple(a), tuple(b), 1 if ang > 0 else -1))
    curv = np.zeros(len(bm.verts))
    for v in bm.verts:
        if not v.link_edges:
            continue
        acc = 0.0
        for e in v.link_edges:
            o = e.other_vert(v)
            d = o.co - v.co
            if d.length > 1e-9:
                acc += v.normal.dot(d.normalized())
        curv[v.index] = -acc / len(v.link_edges)
    bm.free()
    return per_face, curv


def _edge_distances(tex_poly, tex_pos, per_face):
    convex = np.full(len(tex_poly), np.inf)
    concave = np.full(len(tex_poly), np.inf)
    order = np.argsort(tex_poly, kind="stable")
    sp = tex_poly[order]
    bounds = np.flatnonzero(np.diff(sp)) + 1
    starts = np.concatenate([[0], bounds])
    ends = np.concatenate([bounds, [len(sp)]])
    for s0, s1 in zip(starts, ends):
        pid = sp[s0]
        segs = per_face.get(int(pid))
        if not segs:
            continue
        idx = order[s0:s1]
        P = tex_pos[idx]
        A = np.array([s[0] for s in segs])
        B = np.array([s[1] for s in segs])
        sign = np.array([s[2] for s in segs])
        AB = B - A
        L2 = np.maximum((AB * AB).sum(1), 1e-12)
        t = np.clip(((P[:, None, :] - A[None]) * AB[None]).sum(2) / L2[None], 0.0, 1.0)
        closest = A[None] + t[..., None] * AB[None]
        d = np.linalg.norm(P[:, None, :] - closest, axis=2)
        if (sign > 0).any():
            convex[idx] = d[:, sign > 0].min(axis=1)
        if (sign < 0).any():
            concave[idx] = d[:, sign < 0].min(axis=1)
    return convex, concave


def _hemisphere(k, seed=3):
    rng = np.random.default_rng(seed)
    dirs = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(k):
        z = math.sqrt(1.0 - (i + 0.5) / k)          # cosine-weighted
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = golden * i + rng.random() * 0.3
        dirs.append((r * math.cos(a), r * math.sin(a), z))
    return np.array(dirs)


def ambient_occlusion(objects, pos, nrm, rays=12, max_dist=0.35, ground=None, stride=1, shape=None, tex_index=None,
                      planes=()):
    """Ray-traced AO per texel (1 = open). ``ground`` adds a floor plane at that Z;
    ``planes`` adds more implied planes, (axis, value) with axis "x", "y" or "z"
    (the wall a moulding is fixed to, the ceiling a coffer hangs from)."""
    verts, polys = [], []
    for obj in objects:
        me = obj.data
        mw = obj.matrix_world
        base = len(verts)
        verts.extend([tuple(mw @ v.co) for v in me.vertices])
        polys.extend([tuple(base + i for i in p.vertices) for p in me.polygons])
    if ground is not None:
        base = len(verts)
        s = 50.0
        verts.extend([(-s, -s, ground), (s, -s, ground), (s, s, ground), (-s, s, ground)])
        polys.append((base, base + 1, base + 2, base + 3))
    for axis, value in planes:
        base = len(verts)
        s = 50.0
        corners = [(-s, -s), (s, -s), (s, s), (-s, s)]
        k = "xyz".index(axis)
        for a, b in corners:
            co = [a, b]
            co.insert(k, value)
            verts.append(tuple(co))
        polys.append((base, base + 1, base + 2, base + 3))
    bvh = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
    hemi = _hemisphere(rays)
    n = len(pos)
    sel = np.arange(n)
    if stride > 1 and shape is not None and tex_index is not None:
        ys, xs = np.unravel_index(tex_index, shape)
        sel = np.flatnonzero((ys % stride == 0) & (xs % stride == 0))
    ao_sel = np.ones(len(sel))
    rng = np.random.default_rng(7)
    for j, i in enumerate(sel):
        nn = nrm[i]
        ref = np.array([0.0, 0.0, 1.0]) if abs(nn[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        tx = np.cross(nn, ref)
        tx /= max(np.linalg.norm(tx), 1e-9)
        ty = np.cross(nn, tx)
        rot = rng.random() * math.tau
        c, s = math.cos(rot), math.sin(rot)
        o = Vector(pos[i] + nn * 0.003)
        occ = 0.0
        for d in hemi:
            dx = d[0] * c - d[1] * s
            dy = d[0] * s + d[1] * c
            w = tx * dx + ty * dy + nn * d[2]
            hit = bvh.ray_cast(o, Vector(w), max_dist)
            if hit[0] is not None:
                occ += 1.0 - hit[3] / max_dist
        ao_sel[j] = 1.0 - occ / len(hemi)
    if len(sel) == n:
        return ao_sel
    # spread strided samples to their neighbours (blocky AO suits the pixel style)
    ao = np.full(n, np.nan)
    ao[sel] = ao_sel
    img = np.full(shape[0] * shape[1], np.nan)
    img[tex_index] = ao
    img = img.reshape(shape)
    filled = ~np.isnan(img)
    for _ in range(stride * 2):
        if filled[np.unravel_index(tex_index, shape)].all():
            break
        acc = np.zeros(shape)
        cnt = np.zeros(shape)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sv = np.roll(img, (dy, dx), axis=(0, 1))
            sm = np.roll(filled, (dy, dx), axis=(0, 1))
            take = sm & ~filled
            acc[take] += sv[take]
            cnt[take] += 1
        new = (cnt > 0) & ~filled
        img[new] = acc[new] / cnt[new]
        filled |= new
    out = img.ravel()[tex_index]
    return np.where(np.isnan(out), 1.0, out)


# --------------------------------------------------------------------------
# bake
# --------------------------------------------------------------------------

def bake(objects, W, H, ppm, fns, organic=(), ao_rays=12, ao_dist=0.35, ground=None, pad=4,
         normal_strength=2.0, seed=0, ao_stride=1, log=print, planes=()):
    """Paints the atlas for ``objects`` (all share one UV atlas). ``fns`` maps a
    slot name to a material function; slots missing from ``fns`` are skipped."""
    t0 = time.time()
    datas = [MeshData(o) for o in objects]
    uv_all, meta = [], []
    for oi, md in enumerate(datas):
        keep = np.array([md.slots[m] in fns for m in md.mat], dtype=bool)
        idx = np.flatnonzero(keep)
        uv_all.append(md.uv[idx])
        meta.append((oi, idx))
    uv = np.concatenate(uv_all)
    tri_map, bary = rasterize(uv, W, H)
    painted = tri_map >= 0
    tex_index = np.flatnonzero(painted.ravel())
    gt = tri_map.ravel()[tex_index]
    bw = bary.reshape(-1, 3)[tex_index]
    # map global tri -> (object, local tri)
    obj_of = np.concatenate([np.full(len(idx), oi) for oi, idx in meta])
    loc_of = np.concatenate([idx for _, idx in meta])
    N = len(tex_index)
    pos = np.zeros((N, 3))
    nrm = np.zeros((N, 3))
    uvm = np.zeros((N, 2))
    tan = np.zeros((N, 3))
    bit = np.zeros((N, 3))
    poly_global = np.zeros(N, np.int64)
    slot_name = np.empty(N, dtype=object)
    longu = np.ones(N, dtype=bool)
    part = np.zeros(N, np.int64)
    curv = np.zeros(N)
    convex = np.full(N, np.inf)
    concave = np.full(N, np.inf)
    poly_offset = 0
    for oi, md in enumerate(datas):
        m = obj_of[gt] == oi
        if not m.any():
            poly_offset += len(md.obj.data.polygons)
            continue
        lt = loc_of[gt[m]]
        w = bw[m]
        pos[m] = (md.pos[lt] * w[..., None]).sum(1)
        nn = (md.nrm[lt] * w[..., None]).sum(1)
        nrm[m] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
        uvm[m] = (md.uvm[lt] * w[..., None]).sum(1)
        t, b = _tangents(md)
        tan[m] = t[lt]
        bit[m] = b[lt]
        poly_global[m] = md.poly[lt] + poly_offset
        slot_name[m] = np.array(md.slots, dtype=object)[md.mat[lt]]
        longu[m] = md.longu[md.poly[lt]] > 0
        part[m] = oi
        per_face, vcurv = _sharp_edges(md.obj)
        cv, cc = _edge_distances(md.poly[lt], pos[m], per_face)
        convex[m] = cv
        concave[m] = cc
        if md.obj.name in organic:
            curv[m] = np.clip((vcurv[md.verts[lt]] * w).sum(1) * 4.0, -1.0, 1.0)
        poly_offset += len(md.obj.data.polygons)
    t1 = time.time()
    if ao_rays > 0:
        ao = ambient_occlusion(objects, pos, nrm, ao_rays, ao_dist, ground, ao_stride, (H, W), tex_index, planes)
    else:
        ao = np.ones(N)
    t2 = time.time()
    ctx = painter.Ctx(pos, nrm, tan, bit, 1.0 / ppm, seed)
    ctx.convex, ctx.concave, ctx.curv, ctx.ao = convex, concave, curv, ao
    ctx.long_u = longu
    ctx.part = part
    ctx.uvm = uvm
    parts = [(slot_name == name, fn) for name, fn in fns.items()]
    s = painter.combine(ctx, parts)
    imgs = _images(s, ao, tex_index, H, W, 1.0 / ppm, normal_strength, pad)
    log(f"  atlas {W}x{H}: {N} texels, raster+edges {t1 - t0:.1f}s, AO {t2 - t1:.1f}s, paint {time.time() - t2:.1f}s")
    return imgs


def _images(s, ao, tex_index, H, W, texel, normal_strength, pad):
    mask = np.zeros(H * W, dtype=bool)
    mask[tex_index] = True
    mask = mask.reshape(H, W)

    def place(values, ch, fill):
        out = np.full((H * W, ch) if ch > 1 else H * W, fill, dtype=np.float64)
        out[tex_index] = values
        return out.reshape((H, W, ch) if ch > 1 else (H, W))

    imgs = {
        "albedo": place(s.colors(), 3, 0.0),
        "height": place(s.height, 1, 0.0),
        "orm": np.stack([place(0.55 + 0.45 * ao, 1, 1.0), place(np.clip(s.rough, 0.02, 1), 1, 1.0),
                         place(np.clip(s.metal, 0, 1), 1, 0.0)], axis=-1),
    }
    if s.emit is not None:
        imgs["emit"] = place(np.clip(s.emit, 0, 1), 3, 0.0)
    if s.sss is not None:
        imgs["sss"] = place(s.sss, 1, 0.0)
    if s.alpha is not None:
        imgs["alpha"] = place(s.alpha, 1, 1.0)
    # height first grows outward so island borders get no false slopes
    h, m2 = painter.dilate(imgs["height"], mask, 2)
    imgs["normal"] = painter.normal_from_height(h, texel, normal_strength, m2)
    for k in list(imgs.keys()):
        if k == "height":
            continue
        imgs[k], _ = painter.dilate(imgs[k], mask, pad)
    imgs["mask"] = mask
    return imgs
