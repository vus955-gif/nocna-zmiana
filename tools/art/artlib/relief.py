"""Relief sculpture in 2D layers -> a height field in metres (numpy only).

How a sculptor cuts a frieze: every figure is a stack of PLANES, the far legs
of a horse lowest, its body above them, the near legs and the rider on top.
Here each plane is a LAYER: a shape given as a signed distance field (metres,
negative inside), raised to its own height with a rounded edge that drops
onto whatever lies under it (the background or a farther layer), and a soft
bulge toward its middle. Layers are applied far to near; a layer only ever
raises the surface. Muscles are bumps, drapery folds and incised lines are
grooves, manes and hair a noisy texture, and the damage of 2,400 years is
carved last (lost heads, broken limbs, chipped edges, slab joints).

    R = Relief(4.0, 1.1, ppm=128)          # metres, texels per metre
    lid = R.layer(R.ell((1, 0.5), 0.3, 0.12), top=0.03, tag=HORSE)
    R.groove(R.polyline(...), 0.004, 0.01, on=[lid])
    maps = R.finish()                       # height, tag, ao, curv, edge, cavity

The field is computed at ``ss`` x the output density and averaged down
(smooth silhouettes, crisp texels). ``finish`` derives what the painter
needs: ambient occlusion from the height horizon in 8 directions, curvature,
convex edges (bright rims) and cavities, all at the output density.
Coordinates: x right, y up, metres, origin at the bottom-left corner.
"""
import math

import numpy as np

from . import noise

# material tags (what the painter colours each texel as)
BG, SKIN, CLOTH, HORSE, HAIR, TACK, CATTLE, WOOD, SHIELD, BREAK, METAL, ROCK = range(12)


def ease(t):
    t = np.clip(t, 0.0, 1.0)
    return 1.0 - (1.0 - t) ** 2


def smin(a, b, k):
    """Polynomial smooth minimum (blends two distance fields over ``k`` metres)."""
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


class Shape:
    """A signed distance field on a window [r0:r1, c0:c1] of the relief grid
    (outside the window the shape is far away)."""
    __slots__ = ("r0", "r1", "c0", "c1", "d")

    def __init__(self, r0, r1, c0, c1, d):
        self.r0, self.r1, self.c0, self.c1, self.d = r0, r1, c0, c1, d

    @property
    def empty(self):
        return self.d.size == 0


def bezier(pts, n=16):
    """Points on a Bezier curve of any degree (de Casteljau)."""
    P = np.asarray(pts, dtype=np.float64)
    out = []
    for i in range(n + 1):
        t = i / n
        Q = P.copy()
        while len(Q) > 1:
            Q = Q[:-1] * (1 - t) + Q[1:] * t
        out.append(Q[0])
    return np.array(out)


class Frame:
    """Local figure coordinates -> relief metres: origin, scale (metres per
    unit), facing (+1 right, -1 left) and an optional rotation (degrees,
    counter-clockwise, about the local origin, applied before facing)."""

    def __init__(self, ox, oy, s, face=1, rot=0.0, pivot=(0.0, 0.0)):
        self.ox, self.oy, self.s, self.face = ox, oy, s, face
        self.c, self.sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        self.pivot = pivot

    def inv(self, wx, wy):
        """Relief point -> local coordinates (inverse of ``p``)."""
        x = (wx - self.ox) / (self.face * self.s)
        y = (wy - self.oy) / self.s
        px, py = self.pivot
        x, y = x - px, y - py
        x, y = x * self.c + y * self.sn + px, -x * self.sn + y * self.c + py
        return (x, y)

    def ang(self, a):
        """A local angle (degrees, counter-clockwise from +x) in relief space
        (good for ellipse axes: mirroring negates it)."""
        return self.face * (a + math.degrees(math.atan2(self.sn, self.c)))

    def p(self, x, y):
        px, py = self.pivot
        x, y = x - px, y - py
        x, y = x * self.c - y * self.sn + px, x * self.sn + y * self.c + py
        return (self.ox + self.face * self.s * x, self.oy + self.s * y)

    def r(self, r):
        return r * self.s

    def sub(self, x, y, rot=0.0, s=1.0):
        """A child frame at local (x, y), turned ``rot`` degrees (in the
        figure's own sense, so facing mirrors it) and scaled."""
        ox, oy = self.p(x, y)
        f = Frame(ox, oy, self.s * s, self.face)
        total = math.degrees(math.atan2(self.sn, self.c)) + rot
        f.c, f.sn = math.cos(math.radians(total)), math.sin(math.radians(total))
        return f


class Relief:
    def __init__(self, w, h, ppm=128, ss=2, seed=0):
        self.w, self.h = float(w), float(h)
        self.out_ppm = ppm
        self.ss = ss
        self.ppm = ppm * ss
        self.W = int(round(w * ppm)) * ss
        self.H = int(round(h * ppm)) * ss
        self.height = np.zeros((self.H, self.W))
        self.tag = np.zeros((self.H, self.W), np.int16)
        self.lid = np.zeros((self.H, self.W), np.int32)
        self.n_layers = 0
        self.seed = seed

    # --- grid ---------------------------------------------------------------
    def _win(self, x0, x1, y0, y1):
        c0 = max(0, int(math.floor(x0 * self.ppm - 0.5)))
        c1 = min(self.W, int(math.ceil(x1 * self.ppm + 0.5)) + 1)
        r0 = max(0, int(math.floor((self.h - y1) * self.ppm - 0.5)))
        r1 = min(self.H, int(math.ceil((self.h - y0) * self.ppm + 0.5)) + 1)
        return r0, max(r0, r1), c0, max(c0, c1)

    def _xy(self, r0, r1, c0, c1):
        xs = (np.arange(c0, c1) + 0.5) / self.ppm
        ys = self.h - (np.arange(r0, r1) + 0.5) / self.ppm
        return np.meshgrid(xs, ys)

    def _shape(self, bounds, fn, margin=0.0):
        x0, x1, y0, y1 = bounds
        r0, r1, c0, c1 = self._win(x0 - margin, x1 + margin, y0 - margin, y1 + margin)
        if r1 <= r0 or c1 <= c0:
            return Shape(0, 0, 0, 0, np.zeros((0, 0)))
        X, Y = self._xy(r0, r1, c0, c1)
        return Shape(r0, r1, c0, c1, fn(X, Y))

    # --- primitives (all in relief metres) -----------------------------------
    def cap(self, a, b, ra, rb=None):
        """Tapered capsule from a (radius ra) to b (radius rb)."""
        rb = ra if rb is None else rb
        a, b = np.asarray(a, float), np.asarray(b, float)
        m = max(ra, rb)
        bounds = (min(a[0], b[0]) - m, max(a[0], b[0]) + m, min(a[1], b[1]) - m, max(a[1], b[1]) + m)

        def fn(X, Y):
            e = b - a
            L2 = max(float(e @ e), 1e-12)
            t = np.clip(((X - a[0]) * e[0] + (Y - a[1]) * e[1]) / L2, 0.0, 1.0)
            dx = X - (a[0] + t * e[0])
            dy = Y - (a[1] + t * e[1])
            return np.sqrt(dx * dx + dy * dy) - (ra + (rb - ra) * t)
        return self._shape(bounds, fn, 0.01)

    def ell(self, c, rx, ry, rot=0.0):
        """Ellipse (approximate distance), rotated ``rot`` degrees."""
        cx, cy = c
        m = max(rx, ry)
        co, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))

        def fn(X, Y):
            dx, dy = X - cx, Y - cy
            u = dx * co + dy * sn
            v = -dx * sn + dy * co
            k = np.sqrt((u / rx) ** 2 + (v / ry) ** 2)
            return (k - 1.0) * min(rx, ry)
        return self._shape((cx - m, cx + m, cy - m, cy + m), fn, 0.01)

    def circle(self, c, r):
        return self.ell(c, r, r)

    def poly(self, pts):
        P = np.asarray(pts, float)
        bounds = (P[:, 0].min(), P[:, 0].max(), P[:, 1].min(), P[:, 1].max())

        def fn(X, Y):
            d = np.full(X.shape, np.inf)
            s = np.ones(X.shape)
            n = len(P)
            for i in range(n):
                a, b = P[i], P[i - 1]
                ex, ey = b[0] - a[0], b[1] - a[1]
                wx, wy = X - a[0], Y - a[1]
                L2 = max(ex * ex + ey * ey, 1e-12)
                t = np.clip((wx * ex + wy * ey) / L2, 0.0, 1.0)
                qx, qy = wx - ex * t, wy - ey * t
                d = np.minimum(d, qx * qx + qy * qy)
                c1 = Y >= a[1]
                c2 = Y < b[1]
                c3 = ex * wy > ey * wx
                flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
                s = np.where(flip, -s, s)
            return s * np.sqrt(d)
        return self._shape(bounds, fn, 0.01)

    def tube(self, pts, r0, r1=None, n=None):
        """A tapered tube along a polyline (or, with ``n``, along the Bezier
        curve of control points ``pts``)."""
        r1 = r0 if r1 is None else r1
        P = bezier(pts, n) if n else np.asarray(pts, float)
        L = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
        L = L / max(L[-1], 1e-9)
        out = None
        for i in range(len(P) - 1):
            ra = r0 + (r1 - r0) * L[i]
            rb = r0 + (r1 - r0) * L[i + 1]
            s = self.cap(P[i], P[i + 1], ra, rb)
            out = s if out is None else self.union(out, s)
        return out

    def union(self, *shapes, k=0.0):
        shapes = [s for s in shapes if s is not None and not s.empty]
        if not shapes:
            return Shape(0, 0, 0, 0, np.zeros((0, 0)))
        r0 = min(s.r0 for s in shapes)
        r1 = max(s.r1 for s in shapes)
        c0 = min(s.c0 for s in shapes)
        c1 = max(s.c1 for s in shapes)
        d = np.full((r1 - r0, c1 - c0), 1.0)
        first = True
        for s in shapes:
            sub = np.full((r1 - r0, c1 - c0), 1.0)
            sub[s.r0 - r0:s.r1 - r0, s.c0 - c0:s.c1 - c0] = s.d
            d = sub if first else smin(d, sub, k)
            first = False
        return Shape(r0, r1, c0, c1, d)

    def subtract(self, a, b):
        """a minus b (b's window clipped into a's)."""
        if a.empty or b.empty:
            return a
        d = a.d.copy()
        r0, r1 = max(a.r0, b.r0), min(a.r1, b.r1)
        c0, c1 = max(a.c0, b.c0), min(a.c1, b.c1)
        if r1 > r0 and c1 > c0:
            sa = d[r0 - a.r0:r1 - a.r0, c0 - a.c0:c1 - a.c0]
            sb = b.d[r0 - b.r0:r1 - b.r0, c0 - b.c0:c1 - b.c0]
            d[r0 - a.r0:r1 - a.r0, c0 - a.c0:c1 - a.c0] = np.maximum(sa, -sb)
        return Shape(a.r0, a.r1, a.c0, a.c1, d)

    # --- carving ----------------------------------------------------------------
    def layer(self, shape, top, tag, edge=0.008, bulge=0.0, bulge_w=0.06, flat=None):
        """Raises ``shape`` to ``top`` metres (plus ``bulge`` toward its
        middle, over ``bulge_w`` metres from the outline). The rounded edge
        (``edge`` metres wide) drops onto whatever is under it. ``flat``
        (0..1) flattens the face toward the plane behind (low relief of far
        figures). Returns the layer id (for grooves, bumps and textures)."""
        if shape is None or shape.empty:
            return -1
        self.n_layers += 1
        lid = self.n_layers
        sl = (slice(shape.r0, shape.r1), slice(shape.c0, shape.c1))
        d = shape.d
        under = self.height[sl]
        z_top = top + bulge * ease(-d / max(bulge_w, 1e-6))
        z = under + (z_top - under) * ease(-d / max(edge, 1e-6))
        take = (d < 0.0) & (z > under + 1e-6)
        self.height[sl] = np.where(take, z, under)
        self.tag[sl] = np.where(take, tag, self.tag[sl])
        self.lid[sl] = np.where(take, lid, self.lid[sl])
        return lid

    def _on(self, sl, on):
        if on is None:
            return np.ones(self.lid[sl].shape, bool)
        return np.isin(self.lid[sl], np.asarray(list(on)))

    def bump(self, shape, amp, width=0.03, on=None):
        """Adds a soft swelling inside ``shape`` (muscles, knees, a jaw),
        only on the layers in ``on`` (ids)."""
        if shape is None or shape.empty:
            return
        sl = (slice(shape.r0, shape.r1), slice(shape.c0, shape.c1))
        m = self._on(sl, on) & (shape.d < 0)
        self.height[sl] += np.where(m, amp * ease(-shape.d / width), 0.0)

    def groove(self, pts, depth, width, on=None, n=None, sharp=False):
        """Cuts a groove along a polyline (or Bezier with ``n``): drapery
        folds, incised lines, the edge of a mane. ``sharp``: V-profile."""
        P = bezier(pts, n) if n else np.asarray(pts, float)
        x0, x1 = P[:, 0].min() - width, P[:, 0].max() + width
        y0, y1 = P[:, 1].min() - width, P[:, 1].max() + width
        r0, r1, c0, c1 = self._win(x0, x1, y0, y1)
        if r1 <= r0 or c1 <= c0:
            return
        X, Y = self._xy(r0, r1, c0, c1)
        dist = np.full(X.shape, np.inf)
        for i in range(len(P) - 1):
            a, b = P[i], P[i + 1]
            e = b - a
            L2 = max(float(e @ e), 1e-12)
            t = np.clip(((X - a[0]) * e[0] + (Y - a[1]) * e[1]) / L2, 0, 1)
            dist = np.minimum(dist, np.hypot(X - a[0] - t * e[0], Y - a[1] - t * e[1]))
        sl = (slice(r0, r1), slice(c0, c1))
        m = self._on(sl, on)
        k = np.clip(1.0 - dist / width, 0.0, 1.0)
        prof = k if sharp else 1.0 - (1.0 - k) ** 2
        self.height[sl] -= np.where(m, depth * prof, 0.0)

    def texture(self, on, amp, freq, seed=0, kind="curls", region=None):
        """Surface texture on the layers ``on``: "curls" (hair, beards, wool:
        bumpy cells), "mane" (vertical tufts), "rough" (fbm)."""
        if region is None:
            r0, r1, c0, c1 = 0, self.H, 0, self.W
        else:
            r0, r1, c0, c1 = self._win(*region)
        sl = (slice(r0, r1), slice(c0, c1))
        m = self._on(sl, on)
        if not m.any():
            return
        X, Y = self._xy(r0, r1, c0, c1)
        P = np.stack([X.ravel(), Y.ravel(), np.zeros(X.size)], axis=1)
        if kind == "curls":
            f1, _, _ = noise.worley(P * freq, self.seed + seed)
            v = (0.5 - np.clip(f1, 0, 1)).reshape(X.shape) * 2.0
        elif kind == "mane":
            q = np.stack([X.ravel() * freq, Y.ravel() * freq * 0.25, np.zeros(X.size)], axis=1)
            v = np.abs(noise.fbm(q, 2, self.seed + seed)).reshape(X.shape) * -2.0 + 0.5
        else:
            v = noise.fbm(P * freq, 3, self.seed + seed).reshape(X.shape)
        self.height[sl] += np.where(m, amp * v, 0.0)

    def break_off(self, shape, seed=0, depth=0.004, keep=0.0, frac=0.0, jag=0.35):
        """Damage: everything raised inside ``shape`` is broken back to a
        rough fracture ``keep`` metres above the background, or to ``frac``
        of its own height (a stump), with a jagged outline (a lost head, a
        snapped leg); the fracture is tagged BREAK for the painter."""
        if shape is None or shape.empty:
            return
        sl = (slice(shape.r0, shape.r1), slice(shape.c0, shape.c1))
        X, Y = self._xy(shape.r0, shape.r1, shape.c0, shape.c1)
        P = np.stack([X.ravel(), Y.ravel(), np.zeros(X.size)], axis=1)
        rough = noise.fbm(P * 60.0, 3, self.seed + 911 + seed).reshape(X.shape) * depth
        size = max(X.shape) / self.ppm * 0.5
        outline = noise.fbm(P * (3.0 / max(size, 0.01)), 3, self.seed + 917 + seed).reshape(X.shape)
        inside = (shape.d + outline * jag * size) < 0
        h = self.height[sl]
        floor = np.maximum(keep, h * frac) + depth * 0.5 + rough
        hit = inside & (h > floor) & (self.tag[sl] != BG)
        self.height[sl] = np.where(hit, floor, h)
        self.tag[sl] = np.where(hit, BREAK, self.tag[sl])

    def chips(self, n, seed=0, y_band=None, size=(0.01, 0.035)):
        """Random small breaks on raised figure edges (worn arrises)."""
        rng = np.random.default_rng(self.seed * 31 + seed)
        y0, y1 = y_band if y_band else (0.0, self.h)
        for _ in range(n):
            x = rng.uniform(0, self.w)
            y = rng.uniform(y0, y1)
            r = rng.uniform(*size)
            self.break_off(self.ell((x, y), r, r * rng.uniform(0.5, 1.0), rng.uniform(0, 180)), seed=int(x * 100),
                           depth=0.003, keep=0.0)

    def joints(self, xs, width=0.006, depth=0.006, chip=0.4, seed=0):
        """Vertical slab joints at ``xs`` (metres): a dark gap, chipped."""
        rng = np.random.default_rng(self.seed * 17 + seed)
        for x in xs:
            pts = [(x + rng.uniform(-0.003, 0.003), -0.01)]
            for k in range(1, 8):
                pts.append((x + rng.uniform(-0.004, 0.004), self.h * k / 7 + 0.01))
            self.groove(pts, depth, width, sharp=True)
            r0, r1, c0, c1 = self._win(x - width * 1.5, x + width * 1.5, 0, self.h)
            self.tag[r0:r1, c0:c1] = np.where(self.height[r0:r1, c0:c1] < -depth * 0.5, BG, self.tag[r0:r1, c0:c1])
            for _ in range(int(chip * 6)):
                y = rng.uniform(0.05, self.h - 0.05)
                r = rng.uniform(0.01, 0.03)
                self.break_off(self.ell((x, y), r, r * 0.8), depth=0.003)

    # --- helpers ------------------------------------------------------------------
    def polyline(self, pts):
        return np.asarray(pts, float)

    # --- output -------------------------------------------------------------------
    def finish(self, ao_reach=0.06):
        """Averages down to the output density and derives the painter's maps."""
        ss = self.ss
        H, W = self.H // ss, self.W // ss
        h = self.height[:H * ss, :W * ss].reshape(H, ss, W, ss).mean(axis=(1, 3))
        # the tag of the highest sample in each block (silhouettes stay crisp)
        t = self.tag[ss // 2::ss, ss // 2::ss][:H, :W]
        lid = self.lid[ss // 2::ss, ss // 2::ss][:H, :W]
        texel = 1.0 / self.out_ppm
        maps = {"height": h, "tag": t, "lid": lid, "texel": texel, "w": self.w, "h": self.h,
                "ppm": self.out_ppm}
        maps.update(derive(h, texel, ao_reach))
        # the part of the relief a coarse mesh cannot carry (for displaced
        # geometry: the normal map then adds only this)
        b = h
        for _ in range(3):
            b = (b * 2 + _shift(b, 1, 0) + _shift(b, -1, 0) + _shift(b, 0, 1) + _shift(b, 0, -1)) / 6.0
        maps["smooth"] = b
        maps["detail"] = h - b
        return maps


def _shift(a, dy, dx):
    """a shifted by (dy, dx) texels with edge clamping."""
    H, W = a.shape
    ys = np.clip(np.arange(H) - dy, 0, H - 1)
    xs = np.clip(np.arange(W) - dx, 0, W - 1)
    return a[ys][:, xs]


def derive(h, texel, reach=0.06):
    """AO (horizon), curvature, convex edge and cavity maps of a height field."""
    steps = [1, 2, 3, 5, 8, 12, 18]
    steps = [s for s in steps if s * texel <= reach * 1.5] or [1]
    occ = np.zeros_like(h)
    dirs = [(0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1), (-1, 0), (-1, 1)]
    for dy, dx in dirs:
        best = np.zeros_like(h)
        for s in steps:
            dist = s * texel * math.hypot(dx, dy)
            rise = _shift(h, dy * s, dx * s) - h
            best = np.maximum(best, rise / dist)
        occ += best / np.sqrt(1.0 + best * best)       # sin of the horizon angle
    ao = 1.0 - occ / len(dirs)
    # curvature: laplacian of a slightly blurred field (metres -> unitless)
    b = (h * 4 + _shift(h, 1, 0) + _shift(h, -1, 0) + _shift(h, 0, 1) + _shift(h, 0, -1)) / 8.0
    lap = (_shift(b, 1, 0) + _shift(b, -1, 0) + _shift(b, 0, 1) + _shift(b, 0, -1) - 4 * b)
    curv = np.clip(-lap / (texel * 0.35), -1.0, 1.0)
    nb_min = np.minimum.reduce([_shift(h, 1, 0), _shift(h, -1, 0), _shift(h, 0, 1), _shift(h, 0, -1)])
    nb_max = np.maximum.reduce([_shift(h, 1, 0), _shift(h, -1, 0), _shift(h, 0, 1), _shift(h, 0, -1)])
    edge = np.clip((h - nb_min) / (texel * 0.9), 0.0, 1.0)
    cavity = np.clip((nb_max - h) / (texel * 0.9), 0.0, 1.0)
    # light from the upper left (the painter's key): a hint of modelling
    gy = (_shift(h, 1, 0) - _shift(h, -1, 0)) / (2 * texel)      # +: rising toward the top
    gx = (_shift(h, 0, -1) - _shift(h, 0, 1)) / (2 * texel)      # +: rising toward the right
    key = np.clip((-gx * 0.6 + gy * 0.8) * 0.5, -1.0, 1.0)
    return {"ao": ao, "curv": curv, "edge": edge, "cavity": cavity, "key": key}


def shaded_preview(maps, albedo=None, light=(-0.5, 0.6, 0.62), scale=2):
    """Quick numpy render of a relief (Lambert + AO), for iteration."""
    h = maps["height"]
    texel = maps["texel"]
    gy = (_shift(h, 1, 0) - _shift(h, -1, 0)) / (2 * texel)
    gx = (_shift(h, 0, -1) - _shift(h, 0, 1)) / (2 * texel)
    n = np.stack([-gx, gy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    L = np.array(light) / np.linalg.norm(light)
    lam = np.clip(n @ L, 0, 1)
    base = albedo if albedo is not None else np.full(h.shape + (3,), 0.82)
    img = base * (0.25 + 0.75 * lam[..., None]) * (0.55 + 0.45 * maps["ao"][..., None])
    img = np.repeat(np.repeat(img, scale, axis=0), scale, axis=1)
    return np.clip(img, 0, 1)
