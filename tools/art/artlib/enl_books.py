"""Books for the King's Library: shelf filling, light geometry and the
pixel-art spine painter.

A shelf is filled with *volumes* (records with a size, a place and a
style). Upright volumes of similar height are merged into geometry
*blocks* (one box without back and bottom: ~10 triangles for 3-12 books);
leaning volumes and lying stacks are single boxes. Every spine is then
painted into the model's atlas texel by texel: the painter finds the volume
under each texel (by shelf and x for the upright runs, by an oriented-box
test for the loose ones) and draws its covering, raised bands, gilt rules,
title label and volume label, sun fading and scuffs. Sets of matching
volumes (same leather, same labels) give the shelves their rhythm.

Coordinates: everything here is in the model's frame BEFORE archkit.turn()
(viewer at -Y, wall at y = 0); the painter is told whether the atlas is
baked after the turn (``turned``) and maps texels back.
"""
import math
import random

import numpy as np
from mathutils import Matrix

from . import noise
from .enl_materials import CLOTHS, LEATHERS, P
from .materials import _dither
from .painter import Surface

# size classes: (height range, thickness range, depth / height)
SIZES = {
    "folio": ((0.36, 0.44), (0.05, 0.085), 0.72),
    "quarto": ((0.27, 0.33), (0.035, 0.06), 0.75),
    "octavo": ((0.2, 0.245), (0.024, 0.045), 0.68),
    "small": ((0.15, 0.185), (0.02, 0.034), 0.66),
}


class Shelf:
    def __init__(self, x0, x1, z0, clear, front, depth):
        self.x0, self.x1, self.z0, self.clear = x0, x1, z0, clear
        self.front = front          # y of the shelf's front edge (negative, toward the viewer)
        self.depth = depth          # usable depth (m)


def _size_for(clear, rng):
    fits = [k for k, (hr, _, _) in SIZES.items() if hr[1] + 0.02 <= clear]
    if not fits:
        return "small"
    big = fits[0]
    # mostly the biggest class that fits, sometimes smaller books on a tall shelf
    weights = [5.0 if k == big else 1.0 for k in fits]
    return rng.choices(fits, weights)[0]


def fill_shelf(shelf, rng, set_counter, gaps=True):
    """Volumes for one shelf: list of dicts (see module doc)."""
    vols = []
    x = shelf.x0 + rng.uniform(0.0, 0.02)
    end = shelf.x1 - 0.005
    while x < end - 0.02:
        r = rng.random()
        room = end - x
        if gaps and r < 0.05 and room > 0.4:
            # a lying stack of 2-4 volumes
            n = rng.randint(2, 4)
            hb = rng.uniform(0.22, 0.32)
            if hb > room - 0.02 or n * 0.045 > shelf.clear - 0.04:
                continue
            set_counter[0] += 1
            zz = shelf.z0
            for k in range(n):
                hk = hb * rng.uniform(0.82, 1.0) if k else hb
                tk = rng.uniform(0.028, 0.05)
                dk = min(shelf.depth - 0.02, hk * 0.75)
                vols.append(dict(kind="lying", ox=x + (hb - hk) * rng.uniform(0.2, 0.8), oz=zz, t=tk, h=hk,
                                 d=dk, yf=shelf.front + rng.uniform(0.015, 0.04), set=set_counter[0] * 7 + k,
                                 vol=k, phi=0.0))
                zz += tk
            x += hb + rng.uniform(0.01, 0.03)
            continue
        if gaps and r < 0.1 and room > 0.25:
            # a gap with a book leaning into it (the run to its right holds it up)
            cls = _size_for(shelf.clear, rng)
            (h0, h1), (t0, t1), dr = SIZES[cls]
            h = rng.uniform(h0, h1)
            t = rng.uniform(t0, t1)
            phi = math.radians(rng.uniform(10.0, 24.0))
            need = h * math.sin(phi) + t * math.cos(phi) + 0.01
            if need > room - 0.1:
                continue
            set_counter[0] += 1
            xr = x + need                              # the next run starts here
            xc = xr - h * math.sin(phi) * 0.985        # bottom-right corner on the shelf
            ox = xc - t * math.cos(phi)
            oz = shelf.z0 + t * math.sin(phi)
            vols.append(dict(kind="lean", ox=ox, oz=oz, t=t, h=h, d=min(shelf.depth - 0.02, h * dr),
                             yf=shelf.front + rng.uniform(0.02, 0.05), set=set_counter[0] * 7, vol=0, phi=phi))
            x = xr
            continue
        if gaps and r < 0.13 and room > 0.15:
            x += rng.uniform(0.03, 0.09)                 # plain gap
            continue
        # a set of matching volumes (or 1-3 singles)
        set_counter[0] += 1
        single = rng.random() < 0.3
        n = rng.randint(1, 3) if single else rng.randint(3, 11)
        cls = _size_for(shelf.clear, rng)
        (h0, h1), (t0, t1), dr = SIZES[cls]
        h = rng.uniform(h0, h1)
        t = rng.uniform(t0, t1)
        yf = shelf.front + rng.uniform(0.012, 0.04)
        for k in range(n):
            if single and k:
                cls = _size_for(shelf.clear, rng)
                (h0, h1), (t0, t1), dr = SIZES[cls]
                h = rng.uniform(h0, h1)
                t = rng.uniform(t0, t1)
                set_counter[0] += 1
            tk = t * rng.uniform(0.85, 1.15) if single else t + rng.uniform(-0.004, 0.006)
            hk = min(h + rng.uniform(-0.004, 0.004), shelf.clear - 0.015)
            if x + tk > end:
                break
            vols.append(dict(kind="up", ox=x, oz=shelf.z0, t=tk, h=hk, d=min(shelf.depth - 0.02, hk * dr),
                             yf=yf + rng.uniform(-0.003, 0.003) if single else yf, set=set_counter[0] * 7,
                             vol=k, phi=0.0))
            x += tk + (0.0015 if rng.random() < 0.7 else rng.uniform(0.003, 0.012))
    return vols


def blocks_of(vols, tol_h=0.02, tol_y=0.012, max_n=12):
    """Groups consecutive upright volumes into geometry blocks (index lists)."""
    out, cur = [], []
    for i, v in enumerate(vols):
        if v["kind"] != "up":
            if cur:
                out.append(cur)
            cur = []
            continue
        if cur:
            prev = vols[cur[-1]]
            hs = [vols[j]["h"] for j in cur]
            gap = v["ox"] - (prev["ox"] + prev["t"])
            if (max(hs + [v["h"]]) - min(hs + [v["h"]]) > tol_h or abs(v["yf"] - prev["yf"]) > tol_y
                    or len(cur) >= max_n or gap > 0.006):
                out.append(cur)
                cur = []
        cur.append(i)
    if cur:
        out.append(cur)
    return out


def _quad(p, pts, mat, want):
    f = p.poly(pts, mat)[0]
    f.normal_update()
    if f.normal.dot(want) < 0:
        f.normal_flip()
    return f


def add_books(p, vols, slot="books", slot_loose="books_loose", slot_side="books_side"):
    """Adds the geometry of a list of volumes to Part ``p``. Upright runs
    become blocks (front, top and the exposed parts of the sides); leaning
    and lying volumes are boxes. Returns the blocks (for the painter)."""
    from mathutils import Vector
    blocks = blocks_of(vols)
    spans = []
    for b in blocks:
        x0 = vols[b[0]]["ox"]
        x1 = vols[b[-1]]["ox"] + vols[b[-1]]["t"]
        top = max(vols[j]["h"] for j in b)
        yf = min(vols[j]["yf"] for j in b)
        d = max(vols[j]["d"] for j in b)
        z0 = vols[b[0]]["oz"]
        spans.append((x0, x1, z0, top, yf, d))
    for k, (x0, x1, z0, top, yf, d) in enumerate(spans):
        zt = z0 + top
        yb = yf + d
        # front and top share an edge and continuous UVs: one atlas island
        bm = p.bm
        vs = [bm.verts.new(c) for c in ((x0, yf, z0), (x1, yf, z0), (x1, yf, zt), (x0, yf, zt), (x1, yb, zt),
                                        (x0, yb, zt))]
        uvs = [(x0, z0), (x1, z0), (x1, zt), (x0, zt), (x1, zt + d), (x0, zt + d)]
        for idx, want in (((0, 1, 2, 3), Vector((0, -1, 0))), ((3, 2, 4, 5), Vector((0, 0, 1)))):
            f = p._face([vs[i] for i in idx], slot)
            f.normal_update()
            if f.normal.dot(want) < 0:
                f.normal_flip()
            for loop in f.loops:
                loop[p.uv].uv = uvs[vs.index(loop.vert)]
            f[p.lock] = 1
        for side, nb in ((-1, k - 1), (1, k + 1)):
            xs = x0 if side < 0 else x1
            low = z0
            yfn = yf
            if 0 <= nb < len(spans):
                n0, n1, nz0, ntop, nyf, nd = spans[nb]
                # a slit under 2 cm between runs shows nothing but shadow
                touching = abs((n1 if side < 0 else n0) - xs) < 0.02 and abs(nz0 - z0) < 1e-6
                if touching:
                    low = z0 + min(ntop, top)
                    yfn = nyf
            if low < zt - 1e-4:
                _quad(p, [(xs, yf, low), (xs, yb, low), (xs, yb, zt), (xs, yf, zt)], slot_side, Vector((side, 0, 0)))
            if yfn > yf + 0.004 and low > z0 + 1e-4:
                # the neighbour stands further back: the strip in front of it shows
                _quad(p, [(xs, yf, z0), (xs, yfn, z0), (xs, yfn, low), (xs, yf, low)], slot_side,
                      Vector((side, 0, 0)))
    for v in vols:
        if v["kind"] == "up":
            continue
        if v["kind"] == "lying":
            c = (v["ox"] + v["h"] / 2, v["yf"] + v["d"] / 2, v["oz"] + v["t"] / 2)
            p.box(c, (v["h"], v["d"], v["t"]), slot_loose, bevel=0.002)
        else:
            phi = v["phi"]
            a = (math.cos(phi), -math.sin(phi))
            b = (math.sin(phi), math.cos(phi))
            cx = v["ox"] + a[0] * v["t"] / 2 + b[0] * v["h"] / 2
            cz = v["oz"] + a[1] * v["t"] / 2 + b[1] * v["h"] / 2
            p.box((cx, v["yf"] + v["d"] / 2, cz), (v["t"], v["d"], v["h"]), slot_loose, bevel=0.002,
                  rot=Matrix.Rotation(phi, 3, 'Y'))
    return blocks


def restyle(p, faces, pred, slot):
    """Moves the faces passing ``pred(centre, normal)`` to material ``slot``
    (e.g. the inside of a box to a world-mapped tile field)."""
    idx = p.slot(slot)
    for f in faces:
        if f.is_valid:
            f.normal_update()
            if pred(f.calc_center_median(), f.normal):
                f.material_index = idx
    return faces


def cull(p, pred):
    """Deletes the faces of Part ``p`` for which ``pred(centre, normal)`` is
    true (hidden faces waste atlas space: backs against the wall, ends inside
    a stile, tops under a cornice)."""
    import bmesh
    bm = p.bm
    bm.normal_update()
    drop = [f for f in bm.faces if pred(f.calc_center_median(), f.normal)]
    if drop:
        bmesh.ops.delete(bm, geom=drop, context='FACES')
    return len(drop)


# --------------------------------------------------------------------------
# styles
# --------------------------------------------------------------------------

def _style(set_id, seed):
    rng = random.Random(set_id * 7919 + seed * 104729 + 17)
    r = rng.random()
    if r < 0.6:
        kind = 0
        ramp = rng.choices(LEATHERS, (45, 20, 15, 10, 10))[0]
    elif r < 0.88:
        kind = 1
        ramp = rng.choice(CLOTHS)
    else:
        kind = 2
        ramp = "enl_vellum"
    n_ramp = len(P[ramp])
    center = rng.uniform(n_ramp * 0.42, n_ramp * 0.68)
    if ramp == "enl_black":
        center = rng.uniform(2.5, 4.0)
    label_choices = [k for k in ("enl_morocco_red", "enl_black", "enl_morocco_green") if k != ramp]
    return dict(kind=kind, ramp=ramp, center=center,
                bands=rng.choice((4, 5, 5, 5, 6)) if kind == 0 else 0,
                gilt=rng.random() < (0.75 if kind == 0 else 0.6),
                label=rng.choice(label_choices) if (kind == 0 and rng.random() < 0.75) else None,
                label2=rng.random() < 0.5,
                top_gilt=rng.random() < 0.25,
                fade=rng.uniform(0.0, 1.0) ** 2 * 1.6,
                title_rows=rng.choice((1, 2, 2, 3)),
                cloth_band=kind == 1 and rng.random() < 0.35)


def _tables(vols, seed):
    """numpy arrays of the volume records and their styles."""
    n = len(vols)
    ox = np.array([v["ox"] for v in vols])
    oz = np.array([v["oz"] for v in vols])
    t = np.array([v["t"] for v in vols])
    h = np.array([v["h"] for v in vols])
    yf = np.array([v["yf"] for v in vols])
    d = np.array([v["d"] for v in vols])
    phi = np.array([v["phi"] for v in vols])
    lying = np.array([v["kind"] == "lying" for v in vols], dtype=bool)
    ax = np.where(lying, 0.0, np.cos(phi))
    az = np.where(lying, 1.0, -np.sin(phi))
    bx = np.where(lying, 1.0, np.sin(phi))
    bz = np.where(lying, 0.0, np.cos(phi))
    styles = [_style(v["set"], seed) for v in vols]
    return dict(n=n, ox=ox, oz=oz, t=t, h=h, yf=yf, d=d, ax=ax, az=az, bx=bx, bz=bz, styles=styles,
                vol=np.array([v["vol"] for v in vols]), set=np.array([v["set"] for v in vols]))


# --------------------------------------------------------------------------
# the painter
# --------------------------------------------------------------------------

def spines(vols, seed=0, turned=True):
    """Material function for the "books" and "books_loose" slots of a model
    whose volumes are ``vols`` (all shelves). ``seed`` restyles the sets
    (texture variants on the same mesh)."""
    T = _tables(vols, seed)
    up = np.array([v["kind"] == "up" for v in vols], dtype=bool)
    # upright volumes per shelf (by their base z), sorted by x
    shelves = {}
    for i in np.flatnonzero(up):
        shelves.setdefault(round(float(T["oz"][i]), 4), []).append(i)
    shelf_z = np.array(sorted(shelves))
    shelf_ids = [np.array(sorted(shelves[z], key=lambda i: T["ox"][i])) for z in shelf_z]
    loose = np.flatnonzero(~up)

    def fn(ctx):
        sgn = np.array([-1.0, -1.0, 1.0]) if turned else np.ones(3)
        q = ctx.p * sgn
        nn = ctx.n * sgn
        N = ctx.N
        bid = np.full(N, -1, dtype=np.int64)
        # upright: shelf by z, volume by x (nudged inside for side faces)
        if len(shelf_z):
            k = np.searchsorted(shelf_z, q[:, 2] + 0.003) - 1
            xa = q[:, 0] - nn[:, 0] * 0.0008
            for si, ids in enumerate(shelf_ids):
                m = k == si
                if not m.any():
                    continue
                x0s = T["ox"][ids]
                j = np.searchsorted(x0s, xa[m], side="right") - 1
                ok = (j >= 0)
                jj = np.clip(j, 0, len(ids) - 1)
                cand = ids[jj]
                ok &= xa[m] <= T["ox"][cand] + T["t"][cand] + 0.004
                sel = np.flatnonzero(m)
                bid[sel[ok]] = cand[ok]
                # texels in the space between volumes inside a block: take the left volume
                bid[sel[~ok & (j >= 0)]] = cand[~ok & (j >= 0)]
        # loose: oriented boxes
        for i in loose:
            rx, rz = q[:, 0] - T["ox"][i], q[:, 2] - T["oz"][i]
            u = rx * T["ax"][i] + rz * T["az"][i]
            v = rx * T["bx"][i] + rz * T["bz"][i]
            y = q[:, 1] - T["yf"][i]
            e = 0.004
            inside = (u > -e) & (u < T["t"][i] + e) & (v > -e) & (v < T["h"][i] + e) & (y > -e) & \
                     (y < T["d"][i] + e) & (bid < 0)
            bid[inside] = i
        bid = np.where(bid < 0, 0, bid)
        rx, rz = q[:, 0] - T["ox"][bid], q[:, 2] - T["oz"][bid]
        u = rx * T["ax"][bid] + rz * T["az"][bid]
        v = rx * T["bx"][bid] + rz * T["bz"][bid]
        ydep = q[:, 1] - T["yf"][bid]
        na = nn[:, 0] * T["ax"][bid] + nn[:, 2] * T["az"][bid]
        nb = nn[:, 0] * T["bx"][bid] + nn[:, 2] * T["bz"][bid]
        front = nn[:, 1] < -0.6
        head = ~front & (np.abs(nb) >= np.abs(na))
        cover = ~front & ~head
        return paint(ctx, T, bid, u, v, ydep, front, head, nb > 0, cover, seed)
    return fn


def paint(ctx, T, bid, u, v, ydep, front, head, head_top, cover, seed):
    """Paints volumes: ``bid`` = volume per texel, (u, v) = metres across
    and up the spine from the volume's bottom-left corner, ``ydep`` = depth
    behind the spine; face classes front (spine), head (top / bottom of the
    book block) and cover (the boards)."""
    N = ctx.N
    tx = ctx.texel
    s = Surface(N)
    t = T["t"][bid]
    h = T["h"][bid]
    styles = T["styles"]
    st_ramp = np.array([styles[i]["ramp"] for i in range(T["n"])], dtype=object)[bid]
    st_center = np.array([styles[i]["center"] for i in range(T["n"])])[bid]
    st_kind = np.array([styles[i]["kind"] for i in range(T["n"])])[bid]
    st_bands = np.array([styles[i]["bands"] for i in range(T["n"])])[bid]
    st_gilt = np.array([styles[i]["gilt"] for i in range(T["n"])])[bid]
    st_label = np.array([styles[i]["label"] or "" for i in range(T["n"])], dtype=object)[bid]
    st_label2 = np.array([styles[i]["label2"] for i in range(T["n"])])[bid]
    st_topgilt = np.array([styles[i]["top_gilt"] for i in range(T["n"])])[bid]
    st_fade = np.array([styles[i]["fade"] for i in range(T["n"])])[bid]
    st_rows = np.array([styles[i]["title_rows"] for i in range(T["n"])])[bid]
    st_cband = np.array([styles[i]["cloth_band"] for i in range(T["n"])])[bid]
    vol_r = noise.rand_cells(bid * 31 + seed * 7, 5)          # per-volume jitter
    iu = np.floor(u / tx + 1e-6).astype(np.int64)
    nu = np.maximum(1, np.round(t / tx).astype(np.int64))
    iv = np.floor(v / tx + 1e-6).astype(np.int64)
    nv = np.maximum(1, np.round(h / tx).astype(np.int64))
    rnd = ctx.rand(seed + 3)
    # ---- base covering --------------------------------------------------------
    fu = np.clip(u / np.maximum(t, 1e-4), 0.0, 1.0)
    base = st_center + (vol_r - 0.5) * 1.2 + _dither(ctx, 0.55, seed + 4)
    round_sh = (1.0 - (2.0 * fu - 1.0) ** 2) * 1.3 - 0.55
    base = np.where(front, base + round_sh, base)
    seam = front & (nu >= 3) & ((iu <= 0) | (iu >= nu - 1))
    base -= seam * 1.3
    base += front * (iv >= nv - 1) * 0.9 - front * (iv <= 0) * 1.0
    fade = st_fade * np.clip((v / np.maximum(h, 1e-4) - 0.35) / 0.65, 0.0, 1.0)
    base += np.where(front, fade, 0.0)
    scuff = front & (rnd > 0.985)
    base += scuff * 1.4
    gold = np.zeros(N, dtype=bool)
    label_m = np.zeros(N, dtype=bool)
    label_sh = np.zeros(N)
    height = np.where(front, np.sin(fu * np.pi) * 0.0015, 0.0)
    # ---- leather: raised bands, gilt rules, labels ---------------------------------
    lea = front & (st_kind == 0) & (nv >= 12)
    nbands = np.maximum(st_bands, 1)
    top_m = np.round(nv * 0.88).astype(np.int64)
    bot_m = np.round(nv * 0.12).astype(np.int64)
    band_rows = []
    for k in range(6):
        rowk = bot_m + np.round((top_m - bot_m) * (k / np.maximum(nbands - 1, 1))).astype(np.int64)
        valid = lea & (k < nbands)
        band_rows.append((rowk, valid))
        on = valid & (iv == rowk)
        below = valid & (iv == rowk - 1)
        base += on * 2.0 - below * 1.5
        height += on * 0.0012
        g1 = valid & st_gilt & ((iv == rowk + 2) | (iv == rowk - 3)) & (iu > 0) & (iu < nu - 1) & (nu >= 3)
        gold |= g1
    # label in the second panel from the top, volume label in the fourth
    r_top = band_rows[0][0]
    r_next = np.where(nbands >= 2, bot_m + np.round((top_m - bot_m) * ((nbands - 2) / np.maximum(nbands - 1, 1))
                                                      ).astype(np.int64), bot_m)
    lab_lo, lab_hi = r_next + 2, top_m - 2
    has_lab = lea & (st_label != "") & (nbands >= 4)
    in_lab = has_lab & (iv >= lab_lo) & (iv <= lab_hi) & (iu >= 1) & (iu <= nu - 2)
    label_m |= in_lab
    label_sh = np.where(in_lab, 3.5 + (vol_r - 0.5), label_sh)
    mid = (lab_lo + lab_hi) // 2
    letters = in_lab & (np.abs(iv - mid) <= 1) & (iv != mid) & (iu >= 1) & (iu <= nu - 2) & \
        (noise.hash_float(iu, iv, bid, seed + 9) < 0.55)
    letters |= in_lab & (iv == mid) & (iu >= 2) & (iu <= nu - 3) & (noise.hash_float(iu, iv, bid, seed + 10) < 0.35)
    gold |= letters
    # volume number: a small dark disc with a gold dot in the third panel from the top
    r3 = bot_m + np.round((top_m - bot_m) * ((nbands - 3) / np.maximum(nbands - 1, 1))).astype(np.int64)
    r4 = bot_m + np.round((top_m - bot_m) * ((nbands - 4) / np.maximum(nbands - 1, 1))).astype(np.int64)
    vmid = (r3 + r4) // 2
    vol_lab = lea & st_label2 & (nbands >= 5) & (np.abs(iv - vmid) <= 1) & (iu >= 1) & (iu <= nu - 2) & (nu >= 4)
    label_m |= vol_lab
    label_sh = np.where(vol_lab, 2.5, label_sh)
    gold |= vol_lab & (iv == vmid) & (iu == nu // 2)
    # panel ornaments: a gold dot in the middle of the other panels
    for k in range(5):
        lo_r, va = band_rows[k]
        hi_r, vb = band_rows[k + 1]
        pm = (lo_r + hi_r) // 2
        orn = lea & va & vb & st_gilt & (iv == pm) & (iu == nu // 2) & ~label_m & (nu >= 3)
        gold |= orn
    # ---- cloth: gilt title near the top, rules, publisher at the foot -----------------
    clo = front & (st_kind == 1) & (nv >= 10)
    rule = clo & st_gilt & ((iv == nv - 3) | (iv == 2)) & (iu >= 1) & (iu <= nu - 2)
    gold |= rule
    trow0 = np.round(nv * 0.8).astype(np.int64)
    title = clo & (iu >= 1) & (iu <= nu - 2) & (nu >= 3)
    trows = np.zeros(N, dtype=bool)
    for r in range(3):
        trows |= (iv == trow0 - 2 * r) & (r < st_rows)
    tt = title & trows & (noise.hash_float(iu, iv, bid, seed + 11) < 0.6)
    gold |= tt
    pub = clo & (iv == np.round(nv * 0.09).astype(np.int64)) & (iu >= 1) & (iu <= nu - 2) & \
        (noise.hash_float(iu, iv, bid, seed + 12) < 0.5)
    gold |= pub
    cband = clo & st_cband & (iv >= np.round(nv * 0.66)) & (iv <= np.round(nv * 0.9)) & ~gold
    label_m |= cband
    label_sh = np.where(cband, 1.6, label_sh)
    # ---- vellum: inked hand title, a paper label --------------------------------------
    vel = front & (st_kind == 2)
    ink = vel & (iu >= 1) & (iu <= nu - 2) & (iv >= np.round(nv * 0.62)) & (iv <= np.round(nv * 0.8)) & \
        (np.mod(iv, 2) == 0) & (noise.hash_float(iu, iv, bid, seed + 13) < 0.5)
    base += vel * ctx.fbm(14.0, 2, seed + 14) * 0.9
    # ---- head / tail of the block and the boards ----------------------------------------
    board_w = tx * 1.2
    pages = head & (u > board_w) & (u < t - board_w) & (ydep > tx * 1.0)
    edge_gilt = pages & st_topgilt & head_top
    covering = (front & ~label_m) | (head & ~pages) | cover
    cov_sh = base + np.where(cover, -0.6 + (ydep < tx * 1.5) * -0.8, 0.0) + np.where(head & ~pages, -0.4, 0.0)
    # ---- assemble ----------------------------------------------------------------------------
    s.shade = np.zeros(N)
    for ramp in sorted(set(st_ramp[covering]) if covering.any() else []):
        m = covering & (st_ramp == ramp)
        s.use_ramp(P[ramp], mask=m, shade=cov_sh - (1.0 - ctx.ao) * 3.0)
    for ramp in sorted(set(st_label[label_m]) - {""}) if label_m.any() else []:
        m = label_m & (st_label == ramp)
        s.use_ramp(P[ramp], mask=m, shade=label_sh - (1.0 - ctx.ao) * 2.5 + _dither(ctx, 0.4, seed + 15))
    cm = label_m & (st_label == "")
    if cm.any():
        s.use_ramp(P["enl_black"], mask=cm, shade=label_sh + 1.0)
    pg = pages & ~edge_gilt
    if pg.any():
        dust = ctx.fbm(9.0, 2, seed + 16) * 0.8
        s.use_ramp(P["enl_paper"], mask=pg, shade=5.6 + dust + _dither(ctx, 0.7, seed + 17) - (1.0 - ctx.ao) * 4.0
                   - (np.mod(np.floor(ydep / tx), 3) == 0) * 0.4)
    gm = gold | edge_gilt
    if gm.any():
        s.use_ramp(P["gold"], mask=gm, shade=7.0 + _dither(ctx, 1.4, seed + 18) - (1.0 - ctx.ao) * 2.5
                   + st_fade * 0.3 - edge_gilt * 1.2)
    if ink.any():
        s.use_ramp(P["enl_ink"], mask=ink, shade=np.full(N, 1.6))
    s.metal = np.where(gm, 0.75, 0.0)
    rough = np.where(st_kind == 0, 0.48, np.where(st_kind == 1, 0.82, 0.7))
    s.rough = np.where(gm, 0.32, np.where(pages, 0.9, rough)) + ctx.rand(seed + 19) * 0.05
    s.height = height + gm * 0.0004 - seam * 0.0015
    return s


def cover_painter(style, turned=False):
    """A flat cover board in a style dict (flying books, desk books): gilt
    double rule border, corner fleurons and a central lozenge, in the
    face's metre UVs. Returns a material function."""
    def fn(ctx):
        s = Surface(ctx.N)
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        base = style["center"] + ctx.fbm(7.0, 3, 701) * 0.7 + _dither(ctx, 0.6, 702)
        base += ctx.edge(1.0) * 1.6 - ctx.cavity(3.0) * 1.2 - (1.0 - ctx.ao) * 3.0
        s.use_ramp(P[style["ramp"]], shade=base)
        s.rough = np.full(ctx.N, 0.5)
        return s
    return fn
