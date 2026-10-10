"""Bas-relief drawing in 2D for the Assyrian wing (asy_relief; the Greek wing has its own relief.py).

A ``Relief`` is a height field in metres over a rectangle of the panel face,
sampled at the model's texel density (texel centres sit where the atlas
packer puts them, so a baked face samples it 1:1, crisp). Coordinates: u to
the right, v up, metres.

How a relief is drawn
  * Shapes are signed distance fields (negative inside, metres): circles,
    ellipses, polygons, tapered capsules (limbs), boxes, strokes.
  * ``put(d, z, part, mat)`` raises a shape to height ``z`` with a rounded
    edge (quarter round of radius ``r``), composing by MAXIMUM: an arm at
    0.03 over a torso at 0.02 shows a rounded step, a far leg at 0.014
    only shows where nothing higher covers it. That is how layered low
    relief is carved.
  * Every shape belongs to a PART (a separate height map and mask): the
    flat enemies are cut along their parts (head, arms, legs, spear,
    shield), each part a slab with its own carving; a panel composes all
    parts over the ``base`` (frame bands stand proud, register fields are
    sunk).
  * ``cut`` incises lines (beard strands, fringes, muscles, wedges of
    cuneiform), ``bumps`` sets rows of curls; ``mat`` ids say which paint
    traces a texel carries (black hair, red ochre, white eyes).
  * ``outlines(part)`` traces a part's mask into simplified polygons
    (metres): the outline of a flat enemy limb, or of the figure pocket in
    an awakening panel.

Figures are drawn through ``Xf`` (a 2D similarity transform: position,
scale, facing, rotation about joints), so the same design serves a 1.9 m
enemy at 256 px/m and a 0.9 m soldier in a panel register at 128 px/m.
"""
import math

import numpy as np

from . import noise

# material ids (paint traces on the carved gypsum)
BG = 0          # background field of the slab (tooled flat)
STONE = 1       # carved surface (smoothed)
HAIR = 2        # black paint: hair, beards, brows
RED = 3         # red ochre traces: sandals, quivers, harness, bands
EYE = 4         # white of the eye
PUPIL = 5       # black pupil and eye outline
BLUE = 6        # faint blue traces
TEXT = 7        # inscription field
GLOW = 8        # (awakening panels) cracks that glow


# --------------------------------------------------------------------------
# 2D similarity transforms
# --------------------------------------------------------------------------

class Xf:
    """Local figure coordinates -> relief coordinates: x' = o + s * R(a) * (f * x, y).
    ``facing`` -1 mirrors the figure (it looks to the left)."""

    def __init__(self, ox=0.0, oy=0.0, s=1.0, facing=1, ang=0.0):
        self.ox, self.oy, self.s, self.f, self.a = ox, oy, s, facing, ang

    def pt(self, p):
        x, y = p[0] * self.f, p[1]
        c, s = math.cos(self.a), math.sin(self.a)
        return (self.ox + self.s * (c * x - s * y), self.oy + self.s * (s * x + c * y))

    def pts(self, ps):
        return [self.pt(p) for p in ps]

    def len(self, r):
        return r * self.s

    def ang(self, a):
        """A direction angle in local space -> relief space."""
        a = math.pi - a if self.f < 0 else a
        return a + self.a

    def rot(self, deg, about):
        """The same frame with its local geometry turned ``deg`` degrees about
        the local point ``about`` (a joint), e.g. a raised arm."""
        return _Joint(self, about, math.radians(deg))

    def move(self, dx, dy):
        return _Joint(self, (0.0, 0.0), 0.0, (dx, dy))


class _Joint(Xf):
    """A frame whose local points are first turned about a joint (and moved)."""

    def __init__(self, parent, about, rad, shift=(0.0, 0.0)):
        self.parent, self.about, self.rad, self.shift = parent, about, rad, shift
        self.s = parent.s
        self.f = parent.f

    def pt(self, p):
        bx, by = self.about
        x, y = p[0] - bx, p[1] - by
        c, s = math.cos(self.rad), math.sin(self.rad)
        q = (bx + c * x - s * y + self.shift[0], by + s * x + c * y + self.shift[1])
        return self.parent.pt(q)

    def ang(self, a):
        return self.parent.ang(a + self.rad)

    def rot(self, deg, about):
        return _Joint(self, about, math.radians(deg))

    def move(self, dx, dy):
        return _Joint(self, (0.0, 0.0), 0.0, (dx, dy))


# --------------------------------------------------------------------------
# the canvas
# --------------------------------------------------------------------------

class Layer:
    def __init__(self, shape):
        self.h = np.zeros(shape)
        self.mat = np.full(shape, STONE, np.int16)
        self.mask = np.zeros(shape, bool)


class Relief:
    def __init__(self, w, h, ppm, u0=0.0, v0=0.0, seed=0):
        self.w_m, self.h_m, self.ppm = w, h, ppm
        self.px = 1.0 / ppm
        self.W = int(round(w * ppm))
        self.H = int(round(h * ppm))
        self.u0, self.v0 = u0, v0
        xs = u0 + (np.arange(self.W) + 0.5) / ppm
        ys = v0 + h - (np.arange(self.H) + 0.5) / ppm
        self.X, self.Y = np.meshgrid(xs, ys)
        self.shape = (self.H, self.W)
        self.base = np.zeros(self.shape)
        self.base_mat = np.full(self.shape, BG, np.int16)
        self.layers = {}
        self.order = []
        self.seed = seed
        self.emit = np.zeros(self.shape)

    # --- bookkeeping -------------------------------------------------------
    def layer(self, part):
        if part not in self.layers:
            self.layers[part] = Layer(self.shape)
            self.order.append(part)
        return self.layers[part]

    def index(self, u, v):
        """Row/column of the texel holding (u, v) (arrays), clipped."""
        col = np.clip(np.floor((np.asarray(u) - self.u0) * self.ppm).astype(np.int64), 0, self.W - 1)
        row = np.clip(np.floor((self.v0 + self.h_m - np.asarray(v)) * self.ppm).astype(np.int64), 0, self.H - 1)
        return row, col

    # --- raising, cutting, painting -----------------------------------------
    def put(self, d, z, part="main", mat=STONE, r=None, flat=False):
        """Raises shape ``d`` to height ``z`` (metres) with a quarter-round edge
        of radius ``r`` (default 1.5 texels); ``flat`` = a chamfer instead."""
        r = r if r is not None else 1.5 * self.px
        L = self.layer(part)
        inside = d < 0.0
        t = np.clip(-d / max(r, 1e-6), 0.0, 1.0)
        prof = z * (t if flat else np.sqrt(1.0 - (1.0 - t) ** 2))
        prof = np.where(inside, prof, -1.0)
        take = inside & (prof >= L.h - 1e-7)
        L.h = np.where(inside, np.maximum(L.h, prof), L.h)
        L.mat[take] = mat
        L.mask |= inside
        return inside

    def paint(self, d, mat, part="main", only_on=None):
        """Sets the paint id inside ``d`` on texels the part already covers."""
        L = self.layer(part)
        m = (d < 0.0) & L.mask
        if only_on is not None:
            m &= np.isin(L.mat, only_on)
        L.mat[m] = mat
        return m

    def cut(self, dist, width, depth, part="main", mat=None, vee=True, inside_only=True):
        """Incises a line: ``dist`` = distance (metres) to the stroke's centre
        line; texels closer than width/2 sink by up to ``depth`` (V-shaped)."""
        L = self.layer(part)
        hw = max(width * 0.5, 0.5 * self.px)
        m = dist < hw
        if inside_only:
            m &= L.mask
        k = (1.0 - dist / hw) if vee else np.ones(self.shape)
        L.h = np.where(m, L.h - depth * np.clip(k + 0.35, 0.0, 1.0), L.h)
        if mat is not None:
            L.mat[m] = mat
        return m

    def bump(self, c, r, z, part="main", mat=None):
        """Adds a small dome (a curl, a stud) on top of whatever is there."""
        L = self.layer(part)
        d = np.hypot(self.X - c[0], self.Y - c[1])
        m = (d < r) & L.mask
        dome = z * np.sqrt(np.clip(1.0 - (d / r) ** 2, 0.0, 1.0))
        L.h = np.where(m, L.h + dome, L.h)
        if mat is not None:
            L.mat[m] = mat
        return m

    def sink(self, d, depth, part="main", r=None):
        """Lowers the part inside ``d`` by ``depth`` (a recess, a hollow)."""
        r = r if r is not None else 1.0 * self.px
        L = self.layer(part)
        t = np.clip(-d / max(r, 1e-6), 0.0, 1.0)
        m = (d < 0) & L.mask
        L.h = np.where(m, L.h - depth * t, L.h)
        return m

    def base_put(self, d, z, mat=BG, r=None):
        """Raises the panel base (frames, bands, ground lines) inside ``d``."""
        r = r if r is not None else 1.0 * self.px
        t = np.clip(-d / max(r, 1e-6), 0.0, 1.0)
        prof = np.where(d < 0, z * t, -1.0)
        take = prof > self.base
        self.base = np.maximum(self.base, prof)
        self.base_mat[take] = mat
        return d < 0

    def base_cut(self, dist, width, depth, mat=None):
        hw = max(width * 0.5, 0.5 * self.px)
        m = dist < hw
        self.base = np.where(m, self.base - depth * np.clip(1.0 - dist / hw + 0.35, 0, 1), self.base)
        if mat is not None:
            self.base_mat[m] = mat
        return m

    # --- composition --------------------------------------------------------
    def compose(self, parts=None, base=True):
        """(height, material, covered) of the chosen parts (all by default)
        over the base."""
        h = self.base.copy() if base else np.zeros(self.shape)
        mat = self.base_mat.copy() if base else np.full(self.shape, BG, np.int16)
        cov = np.zeros(self.shape, bool)
        for name in self.order:
            if parts is not None and name not in parts:
                continue
            L = self.layers[name]
            top = L.mask & (L.h >= h - 1e-7)
            h = np.where(L.mask, np.maximum(h, L.h), h)
            mat = np.where(top, L.mat, mat)
            cov |= L.mask
        return h, mat, cov

    def own(self, part):
        """(height, material, mask) of one part alone (no base)."""
        L = self.layers[part]
        return np.where(L.mask, L.h, 0.0), L.mat, L.mask

    def mask(self, parts=None):
        m = np.zeros(self.shape, bool)
        for name in self.order:
            if parts is None or name in parts:
                m |= self.layers[name].mask
        return m

    # --- shape helpers bound to the grid -----------------------------------
    def circle(self, c, r):
        return np.hypot(self.X - c[0], self.Y - c[1]) - r

    def ellipse(self, c, rx, ry, ang=0.0):
        dx, dy = self.X - c[0], self.Y - c[1]
        if ang:
            ca, sa = math.cos(ang), math.sin(ang)
            dx, dy = dx * ca + dy * sa, -dx * sa + dy * ca
        k = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
        return (k - 1.0) * min(rx, ry)

    def seg(self, a, b):
        ax, ay = a
        bx, by = b
        vx, vy = bx - ax, by - ay
        L2 = max(vx * vx + vy * vy, 1e-12)
        t = np.clip(((self.X - ax) * vx + (self.Y - ay) * vy) / L2, 0.0, 1.0)
        return np.hypot(self.X - ax - t * vx, self.Y - ay - t * vy)

    def polyline(self, pts):
        d = np.full(self.shape, np.inf)
        for a, b in zip(pts[:-1], pts[1:]):
            d = np.minimum(d, self.seg(a, b))
        return d

    def poly(self, pts):
        """Signed distance to a closed polygon (even-odd inside)."""
        pts = list(pts)
        inside = np.zeros(self.shape, dtype=bool)
        n = len(pts)
        X, Y = self.X, self.Y
        for i in range(n):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % n]
            if y1 == y2:
                continue
            cond = (y1 > Y) != (y2 > Y)
            xint = (x2 - x1) * (Y - y1) / (y2 - y1) + x1
            inside ^= cond & (X < xint)
        d = self.polyline(pts + [pts[0]])
        return np.where(inside, -d, d)

    def capsule(self, a, b, ra, rb):
        """Tapered capsule (a limb) from a (radius ra) to b (radius rb)."""
        ax, ay = a
        bx, by = b
        px, py = self.X - ax, self.Y - ay
        vx, vy = bx - ax, by - ay
        L = max(math.hypot(vx, vy), 1e-9)
        ux, uy = vx / L, vy / L
        # local frame: along / across
        x = px * ux + py * uy
        y = np.abs(-px * uy + py * ux)
        # uneven capsule (Inigo Quilez): across = y, along = x
        b_ = (ra - rb) / L
        a_ = math.sqrt(max(1.0 - b_ * b_, 0.0))
        kd = y * (-b_) + x * a_
        d1 = np.hypot(y, x) - ra
        d2 = np.hypot(y, x - L) - rb
        d3 = y * a_ + x * b_ - ra
        return np.where(kd < 0.0, d1, np.where(kd > a_ * L, d2, d3))

    def box(self, c, hw, hh, ang=0.0, r=0.0):
        dx, dy = self.X - c[0], self.Y - c[1]
        if ang:
            ca, sa = math.cos(ang), math.sin(ang)
            dx, dy = dx * ca + dy * sa, -dx * sa + dy * ca
        qx = np.abs(dx) - hw + r
        qy = np.abs(dy) - hh + r
        out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
        return out + np.minimum(np.maximum(qx, qy), 0.0) - r

    def ring(self, c, r, w):
        return np.abs(np.hypot(self.X - c[0], self.Y - c[1]) - r) - w * 0.5

    # --- noise ---------------------------------------------------------------
    def fbm(self, freq, seed=0, octaves=3):
        p = np.stack([self.X.ravel() * freq, self.Y.ravel() * freq, np.zeros(self.X.size)], axis=1)
        return noise.fbm(p, octaves, self.seed * 131 + seed).reshape(self.shape)

    def rand(self, seed=0):
        return noise.white(self.shape, self.seed * 7919 + seed)


# --------------------------------------------------------------------------
# shape algebra
# --------------------------------------------------------------------------

def union(*ds):
    return np.minimum.reduce(list(ds))


def inter(*ds):
    return np.maximum.reduce(list(ds))


def minus(a, b):
    return np.maximum(a, -b)


def bezier(pts, n=12):
    """Points along a chain of cubic Beziers [p0, c1, c2, p1, c1, c2, p2, ...]."""
    pts = [np.array(p, dtype=np.float64) for p in pts]
    out = []
    for i in range(0, len(pts) - 3, 3):
        p0, p1, p2, p3 = pts[i:i + 4]
        for k in range(n):
            t = k / n
            out.append(tuple((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3))
    out.append(tuple(pts[-1]))
    return out


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def offset_curve(pts, d):
    """A polyline offset sideways by d (left of the direction of travel)."""
    out = []
    n = len(pts)
    for i in range(n):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1.0
        out.append((pts[i][0] - ty / L * d, pts[i][1] + tx / L * d))
    return out


def strip(pts, w0, w1=None):
    """Closed polygon of a stroke of width w0 -> w1 along the polyline pts."""
    w1 = w0 if w1 is None else w1
    n = len(pts)
    left, right = [], []
    for i, p in enumerate(pts):
        w = w0 + (w1 - w0) * i / max(n - 1, 1)
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / L, tx / L
        left.append((p[0] + nx * w / 2, p[1] + ny * w / 2))
        right.append((p[0] - nx * w / 2, p[1] - ny * w / 2))
    return left + right[::-1]


# --------------------------------------------------------------------------
# cuneiform
# --------------------------------------------------------------------------

# sign templates: wedges as (kind, x, y, length) in a unit sign cell
# (x 0..1 left -> right, y 0..1 bottom -> top); kinds: h horizontal (head
# left), v vertical (head on top), d diagonal (head top-left), w corner
# wedge (Winkelhaken, a "<" head only)
_SIGNS = [
    [("h", 0.0, 0.5, 0.9)],
    [("h", 0.0, 0.72, 0.8), ("h", 0.0, 0.3, 0.8)],
    [("h", 0.0, 0.5, 0.55), ("v", 0.7, 0.95, 0.85)],
    [("v", 0.2, 0.95, 0.9), ("v", 0.55, 0.95, 0.9)],
    [("h", 0.0, 0.5, 0.4), ("v", 0.45, 0.95, 0.85), ("v", 0.75, 0.95, 0.85)],
    [("w", 0.1, 0.5, 0.0), ("h", 0.35, 0.5, 0.6)],
    [("w", 0.05, 0.72, 0.0), ("w", 0.05, 0.28, 0.0), ("v", 0.5, 0.95, 0.9)],
    [("d", 0.05, 0.95, 0.6), ("h", 0.3, 0.35, 0.65)],
    [("h", 0.0, 0.8, 0.9), ("h", 0.0, 0.5, 0.9), ("h", 0.0, 0.2, 0.9), ("v", 0.92, 0.95, 0.9)],
    [("v", 0.1, 0.95, 0.9), ("h", 0.25, 0.5, 0.7)],
    [("w", 0.0, 0.5, 0.0), ("w", 0.3, 0.5, 0.0), ("w", 0.6, 0.5, 0.0)],
    [("h", 0.0, 0.62, 0.45), ("h", 0.5, 0.62, 0.45), ("v", 0.35, 0.4, 0.4)],
    [("d", 0.0, 0.95, 0.5), ("d", 0.35, 0.95, 0.5), ("h", 0.1, 0.25, 0.8)],
    [("v", 0.15, 0.95, 0.5), ("v", 0.15, 0.45, 0.45), ("h", 0.3, 0.7, 0.6)],
    [("h", 0.0, 0.5, 0.9), ("w", 0.55, 0.85, 0.0), ("w", 0.55, 0.15, 0.0)],
    [("v", 0.5, 0.95, 0.9)],
    [("h", 0.0, 0.75, 0.6), ("v", 0.7, 0.95, 0.9), ("h", 0.0, 0.25, 0.6)],
    [("w", 0.0, 0.7, 0.0), ("h", 0.25, 0.7, 0.7), ("w", 0.0, 0.3, 0.0), ("h", 0.25, 0.3, 0.7)],
]


def cuneiform(R, x0, y0, x1, y1, line_h, part=None, seed=0, depth=0.004, rule=True, on_base=False,
              width_scale=1.0):
    """Lines of cuneiform incised into the box (x0, y0) - (x1, y1) (metres),
    top line first, with ruled lines between them. ``part`` = None cuts
    into the base (the slab), else into that part's layer."""
    rng = np.random.default_rng(seed)
    px = R.px
    n_lines = max(1, int((y1 - y0 + 1e-6) // line_h))
    dist_head = np.full(R.shape, np.inf)
    dist_tail = np.full(R.shape, np.inf)
    rules = np.full(R.shape, np.inf)
    hs = line_h * 0.34              # wedge head size
    tw = max(px * 0.6, line_h * 0.07)
    for li in range(n_lines):
        top = y1 - li * line_h
        bot = top - line_h
        if rule and li > 0:
            rules = np.minimum(rules, np.abs(R.Y - top) + np.where((R.X > x0) & (R.X < x1), 0.0, np.inf))
        x = x0 + line_h * 0.1 + rng.random() * line_h * 0.2
        cy0 = bot + line_h * 0.14
        ch = line_h * 0.72
        while x < x1 - line_h * 0.5:
            sign = _SIGNS[rng.integers(len(_SIGNS))]
            sw = line_h * (0.65 + 0.5 * rng.random()) * width_scale
            if x + sw > x1:
                break
            for kind, sx, sy, ln in sign:
                hx = x + sx * sw
                hy = cy0 + sy * ch
                if kind == "h":
                    head = [(hx, hy + hs * 0.5), (hx, hy - hs * 0.5), (hx + hs * 0.9, hy)]
                    tail = ((hx + hs * 0.6, hy), (hx + max(ln * sw, hs * 1.2), hy))
                elif kind == "v":
                    head = [(hx - hs * 0.5, hy), (hx + hs * 0.5, hy), (hx, hy - hs * 0.9)]
                    tail = ((hx, hy - hs * 0.6), (hx, hy - max(ln * ch, hs * 1.2)))
                elif kind == "d":
                    head = [(hx, hy - hs * 0.15), (hx + hs * 0.15, hy), (hx + hs * 0.75, hy - hs * 0.75)]
                    tail = ((hx + hs * 0.5, hy - hs * 0.5), (hx + ln * sw * 0.7, hy - ln * ch * 0.7))
                else:
                    head = [(hx + hs * 0.9, hy + hs * 0.55), (hx, hy), (hx + hs * 0.9, hy - hs * 0.55)]
                    tail = None
                dist_head = np.minimum(dist_head, np.maximum(R.poly(head), -np.inf))
                if tail is not None:
                    dist_tail = np.minimum(dist_tail, R.seg(*tail))
            x += sw + line_h * (0.12 + 0.1 * rng.random())
    head_in = np.clip(-dist_head / (hs * 0.25), 0.0, 1.0)
    head_m = dist_head < 0.25 * px
    tail_m = dist_tail < tw * 0.5
    if on_base or part is None:
        R.base = np.where(head_m, R.base - depth * (0.55 + 0.45 * head_in), R.base)
        R.base = np.where(tail_m & ~head_m, R.base - depth * 0.55, R.base)
        if rule:
            R.base_cut(rules, px * 0.8, depth * 0.35)
    else:
        L = R.layer(part)
        m = (head_m | tail_m) & L.mask
        L.h = np.where(head_m & L.mask, L.h - depth * (0.55 + 0.45 * head_in), L.h)
        L.h = np.where(tail_m & ~head_m & L.mask, L.h - depth * 0.55, L.h)
        if rule:
            R.cut(rules, px * 0.8, depth * 0.35, part)
        return m
    return head_m | tail_m


# --------------------------------------------------------------------------
# shading in texture space (hand-painted pixel conventions)
# --------------------------------------------------------------------------

def box_blur(a, r):
    if r <= 0:
        return a
    k = 2 * r + 1
    p = np.pad(a, r, mode="edge")
    c = np.cumsum(np.cumsum(p, axis=0), axis=1)
    c = np.pad(c, ((1, 0), (1, 0)))
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)


def relief_terms(h, px):
    """(cavity, rim, slope_x, slope_y) of a height field: cavity 0..1 where
    the surface sits below its surroundings (crevices, feet of figures), rim
    0..1 on raised edges, slopes per metre (u right, v up)."""
    b1 = box_blur(h, 1)
    b3 = box_blur(h, 3)
    cav = np.clip((b3 - h) / 0.006, 0.0, 1.0) * 0.6 + np.clip((b1 - h) / 0.003, 0.0, 1.0) * 0.4
    rim = np.clip((h - b1) / 0.003, 0.0, 1.0)
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) / (2 * px)
    gy = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) / (2 * px)
    return cav, rim, gx, gy


def preview(h, albedo, px, light=(-0.75, 0.45, 0.48), ambient=0.18):
    """A quick 2D render of a relief lit by one low light (default: raking
    from the upper left): albedo * (ambient + lambert), with cast shadows
    marched through the height field."""
    L = np.array(light, dtype=np.float64)
    L /= np.linalg.norm(L)
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) / (2 * px)
    gy = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) / (2 * px)
    n = np.stack([-gx, -gy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    lam = np.clip((n * L).sum(-1), 0.0, 1.0)
    # shadows: march toward the light
    shadow = np.ones_like(h)
    dirx, diry = L[0], L[1]
    horiz = math.hypot(dirx, diry)
    rise = L[2] / max(horiz, 1e-6) * px          # height gained per texel step
    sx, sy = dirx / horiz, -diry / horiz         # image steps (rows grow downward)
    H, W = h.shape
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    for k in range(1, 40):
        x2 = np.clip(np.round(xx + sx * k).astype(np.int64), 0, W - 1)
        y2 = np.clip(np.round(yy + sy * k).astype(np.int64), 0, H - 1)
        shadow = np.where(h[y2, x2] > h + rise * k + 1e-4, 0.35, shadow)
    shade = ambient + (1.0 - ambient) * lam * shadow
    return np.clip(albedo * shade[..., None], 0.0, 1.0)


# --------------------------------------------------------------------------
# outlines: part masks -> polygons (metres)
# --------------------------------------------------------------------------

def fill_holes(mask):
    """Fills enclosed holes of a boolean mask (4-connected flood from the border)."""
    H, W = mask.shape
    outside = np.zeros((H + 2, W + 2), bool)
    free = np.pad(~mask, 1, constant_values=True)
    outside[0, :] = outside[-1, :] = True
    outside[:, 0] = outside[:, -1] = True
    outside &= free
    while True:
        grown = outside.copy()
        grown[1:, :] |= outside[:-1, :]
        grown[:-1, :] |= outside[1:, :]
        grown[:, 1:] |= outside[:, :-1]
        grown[:, :-1] |= outside[:, 1:]
        grown &= free
        if (grown == outside).all():
            break
        outside = grown
    return ~outside[1:-1, 1:-1]


def components(mask):
    """Labels 4-connected components (small masks: iterative flood)."""
    lab = np.zeros(mask.shape, np.int32)
    n = 0
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        if lab[y, x]:
            continue
        n += 1
        stack = [(y, x)]
        lab[y, x] = n
        while stack:
            cy, cx = stack.pop()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = cy + dy, cx + dx
                if 0 <= yy < mask.shape[0] and 0 <= xx < mask.shape[1] and mask[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n
                    stack.append((yy, xx))
    return lab, n


def _trace(mask):
    """Boundary loops of a hole-free mask along pixel edges, inside on the
    left (counter-clockwise in image-up coordinates). Corners as (col, row)."""
    H, W = mask.shape
    m = np.pad(mask, 1)
    edges = {}
    # directed edges with the inside on the left, in (x, y_up) corner coords:
    # corner (i, j) = column i, row j from the top of the padded image
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        if not m[y - 1, x]:      # top edge: walk right-to-left (inside below = left when going -x? see below)
            edges.setdefault((x + 1, y), []).append((x, y))
        if not m[y + 1, x]:      # bottom edge
            edges.setdefault((x, y + 1), []).append((x + 1, y + 1))
        if not m[y, x - 1]:      # left edge
            edges.setdefault((x, y), []).append((x, y + 1))
        if not m[y, x + 1]:      # right edge
            edges.setdefault((x + 1, y + 1), []).append((x + 1, y))
    loops = []
    while edges:
        start = next(iter(edges))
        loop = [start]
        cur = start
        prev_dir = None
        while True:
            outs = edges.get(cur)
            if not outs:
                break
            if len(outs) == 1:
                nxt = outs.pop()
            else:
                # saddle: prefer the turn that keeps diagonal pixels apart
                def turn(o):
                    d = (o[0] - cur[0], o[1] - cur[1])
                    if prev_dir is None:
                        return 0
                    cross = prev_dir[0] * d[1] - prev_dir[1] * d[0]
                    return cross
                outs.sort(key=turn)
                nxt = outs.pop(0)
            if not outs:
                del edges[cur]
            prev_dir = (nxt[0] - cur[0], nxt[1] - cur[1])
            cur = nxt
            if cur == start:
                break
            loop.append(cur)
        if len(loop) >= 4:
            loops.append(loop)
    # back to unpadded corner coordinates
    return [[(x - 1, y - 1) for x, y in lp] for lp in loops]


def _rdp(pts, tol):
    if len(pts) < 3:
        return pts
    a, b = np.array(pts[0]), np.array(pts[-1])
    ab = b - a
    L = np.linalg.norm(ab)
    P = np.array(pts[1:-1])
    if L < 1e-12:
        d = np.linalg.norm(P - a, axis=1)
    else:
        d = np.abs(ab[0] * (P[:, 1] - a[1]) - ab[1] * (P[:, 0] - a[0])) / L
    i = int(np.argmax(d))
    if d[i] > tol:
        left = _rdp(pts[:i + 2], tol)
        right = _rdp(pts[i + 1:], tol)
        return left[:-1] + right
    return [pts[0], pts[-1]]


def simplify_loop(loop, tol):
    """RDP on a closed loop: split at the two mutually farthest points."""
    P = np.array(loop, dtype=np.float64)
    i0 = 0
    i1 = int(np.argmax(np.linalg.norm(P - P[0], axis=1)))
    a = loop[i0:i1 + 1]
    b = loop[i1:] + [loop[0]]
    sa = _rdp(a, tol)
    sb = _rdp(b, tol)
    return sa[:-1] + sb[:-1]


def area(poly):
    s = 0.0
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        s += x1 * y2 - x2 * y1
    return s * 0.5


def outlines(R, mask, tol=None, min_area=None, fill=True):
    """Polygons (lists of (u, v) in metres, counter-clockwise) outlining the
    connected pieces of ``mask``; holes are filled. ``tol`` = simplification
    tolerance in metres (default 1 texel)."""
    tol = tol if tol is not None else R.px * 1.0
    min_area = min_area if min_area is not None else (4 * R.px) ** 2
    m = fill_holes(mask) if fill else mask
    out = []
    for loop in _trace(m):
        # pixel corners -> metres (u right, v up)
        pts = [(R.u0 + x * R.px, R.v0 + R.h_m - y * R.px) for x, y in loop]
        simp = simplify_loop(pts, tol)
        if len(simp) < 3:
            continue
        a = area(simp)
        if abs(a) < min_area:
            continue
        if a < 0:
            simp = simp[::-1]
        out.append(simp)
    out.sort(key=lambda p: -abs(area(p)))
    return out
