"""Old-master paintings for the gallery, painted procedurally in 2D.

Six period portraits whose eyes sit at the same place on every canvas (the
portrait enemy moves them, see models/portrait.py) and four harmless
pictures (a landscape, a seascape, two still lifes).

How a painting is made (no Blender needed, numpy only):
  * Every figure or object is a stack of LAYERS: a shape (signed distance,
    soft painterly edge) with a relief (height in metres: a dome, or a
    sculpted face) and a colour ramp. One light from the upper left shades
    all of them together: form shading from the relief's normals, CAST
    SHADOWS marched through the combined relief (the nose on the cheek,
    the jaw on the neck, the hair on the brow, a lemon on the cloth) and
    occlusion in the hollows. Chiaroscuro falls out of the geometry.
  * Brush strokes jitter the tone along each layer's direction; accents
    (eyes, lids, brows, lace, glints) are painted on top.
  * Finishing: each painting gets its own palette of ~40 colours and a 4x4
    ordered dither (painterly gradients, crisp texels), then varnish
    (warm yellowing, darker corners) and fine, sparse craquelure. Brush
    relief, impasto on the lights, canvas weave and cracks -> normal map;
    varnish sheen -> roughness.

    paint(name) -> {"albedo", "normal", "orm"}    (row 0 = top)

Canvas space: x right, y up, metres, origin at the canvas centre.
Portraits are designed in "figure space" (eyes at y = 0.145) and shifted
up by FIG_OY on the canvas.
"""
import math

import numpy as np

from . import noise
from .painter import normal_from_height

CANVAS_W, CANVAS_H = 0.72, 0.9
PPM = 384
FIG_OY = 0.05
DESIGN_EYE_Y = 0.145
# the eyes of every portrait (canvas metres): the eyes part of the model sits here
EYE_DX, EYE_Y = 0.034, DESIGN_EYE_Y + FIG_OY
EYE_W, EYE_H = 0.03, 0.0135
EYE_TEX_W, EYE_TEX_H = 0.0625, 0.03125      # area covered by the eye texture (24 x 12 texels)
LIGHT = np.array([-0.55, 0.62, 0.56])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
FACE = dict(cx=0.0, cy=0.118, rx=0.077, ry=0.1)

PORTRAITS = ["aristocrat", "lady_fan", "general", "child_dog", "bishop", "merchant"]
SCENES = ["landscape", "seascape", "still_life", "flowers"]
ALL = PORTRAITS + SCENES
TITLES = {
    "aristocrat": "Portret szlachcica", "lady_fan": "Dama z wachlarzem", "general": "Generał",
    "child_dog": "Dziecko z psem", "bishop": "Biskup", "merchant": "Kupiec",
    "landscape": "Pejzaż z ruinami", "seascape": "Burza na morzu", "still_life": "Martwa natura z cytryną",
    "flowers": "Kwiaty w wazonie",
}


def hexcol(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)])


def ramp(stops, t):
    """Colour at t (0..1, any shape) along hex stops, linear in sRGB."""
    cols = np.array([hexcol(s) for s in stops])
    t = np.clip(np.asarray(t, dtype=np.float64), 0.0, 1.0) * (len(cols) - 1)
    i = np.clip(np.floor(t).astype(np.int64), 0, len(cols) - 2)
    f = (t - i)[..., None]
    return cols[i] * (1 - f) + cols[i + 1] * f


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def shift(a, dx, dy):
    """result[r, c] = a[r + dy, c + dx] with clamped edges (integer pixels)."""
    H, W = a.shape[:2]
    rows = np.clip(np.arange(H) + dy, 0, H - 1)
    cols = np.clip(np.arange(W) + dx, 0, W - 1)
    return a[rows][:, cols]


def blur(a, r, passes=2):
    """Separable box blur, ``r`` pixels, clamped edges."""
    out = a.astype(np.float64)
    for _ in range(passes):
        for axis in (0, 1):
            pad = [(0, 0)] * out.ndim
            pad[axis] = (r + 1, r)
            c = np.cumsum(np.pad(out, pad, mode="edge"), axis=axis)
            n = out.shape[axis]
            hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
            lo = np.take(c, np.arange(0, n), axis=axis)
            out = (hi - lo) / (2 * r + 1)
    return out


class Painter:
    def __init__(self, w=CANVAS_W, h=CANVAS_H, ppm=PPM, seed=0):
        self.W = int(round(w * ppm))
        self.H = int(round(h * ppm))
        self.px = 1.0 / ppm
        xs = (np.arange(self.W) + 0.5) / ppm - w / 2
        ys = h / 2 - (np.arange(self.H) + 0.5) / ppm
        self.X, self.Y = np.meshgrid(xs, ys)
        self.img = np.zeros((self.H, self.W, 3))
        self.hgt = np.zeros((self.H, self.W))
        self.seed = seed

    def fbm(self, freq, seed=0, octaves=3, angle=None, stretch=1.0, X=None, Y=None):
        """fbm over the canvas; ``angle`` (radians, scalar or field) and
        ``stretch`` make it streaky along that direction."""
        X = self.X if X is None else X
        Y = self.Y if Y is None else Y
        if angle is not None:
            c, s = np.cos(angle), np.sin(angle)
            X, Y = (X * c + Y * s) / stretch, -X * s + Y * c
        p = np.stack([np.ravel(X) * freq, np.ravel(Y) * freq, np.zeros(np.size(X))], axis=1)
        return noise.fbm(p, octaves, self.seed * 131 + seed).reshape(np.shape(X))

    def strokes(self, angle, seed=0, freq=60.0, stretch=5.0):
        return self.fbm(freq, seed, 2, angle=angle, stretch=stretch)

    def put(self, mask, col, relief=None, alpha=1.0):
        a = mask.astype(np.float64) * alpha
        col = np.asarray(col, dtype=np.float64)
        if col.ndim == 1:
            col = np.broadcast_to(col, self.img.shape)
        self.img = self.img * (1 - a[..., None]) + col * a[..., None]
        if relief is not None:
            self.hgt = self.hgt * (1 - a) + relief * a


# --------------------------------------------------------------------------
# shapes (signed distance: negative inside, metres)
# --------------------------------------------------------------------------

def ellipse(P, cx, cy, rx, ry, rot=0.0):
    dx, dy = P.X - cx, P.Y - cy
    if rot:
        c, s = math.cos(rot), math.sin(rot)
        dx, dy = dx * c + dy * s, -dx * s + dy * c
    k = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
    return (k - 1.0) * min(rx, ry)


def seg_dist(P, a, b):
    ax, ay = a
    bx, by = b
    vx, vy = bx - ax, by - ay
    L2 = max(vx * vx + vy * vy, 1e-12)
    t = np.clip(((P.X - ax) * vx + (P.Y - ay) * vy) / L2, 0.0, 1.0)
    return np.hypot(P.X - ax - t * vx, P.Y - ay - t * vy)


def polyline_dist(P, pts):
    d = np.full(P.X.shape, np.inf)
    for a, b in zip(pts[:-1], pts[1:]):
        d = np.minimum(d, seg_dist(P, a, b))
    return d


def polygon(P, pts):
    """Signed distance to a closed polygon (even-odd inside)."""
    pts = list(pts)
    inside = np.zeros(P.X.shape, dtype=bool)
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if y1 == y2:
            continue
        cond = (y1 > P.Y) != (y2 > P.Y)
        xint = (x2 - x1) * (P.Y - y1) / (y2 - y1) + x1
        inside ^= cond & (P.X < xint)
    d = polyline_dist(P, pts + [pts[0]])
    return np.where(inside, -d, d)


def bezier(pts, n=16):
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


def union(*ds):
    return np.minimum.reduce(list(ds))


def dome_z(d, r):
    """Relief of a soft dome over a shape (height ``r`` metres at depth >= r)."""
    return np.sqrt(np.clip(1.0 - (1.0 - np.clip(-d / r, 0, 1)) ** 2, 0, 1)) * r


def normals(z, px):
    g_row, g_col = np.gradient(z, px)
    n = np.stack([-g_col, g_row, np.ones_like(z)], axis=-1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


# --------------------------------------------------------------------------
# the relief-lit figure compositor
# --------------------------------------------------------------------------

class Layer:
    def __init__(self, alpha, z, stops, tone, gloss, subs, wrap, amb, relief):
        self.alpha, self.z, self.stops, self.tone = alpha, z, stops, tone
        self.gloss, self.subs, self.wrap, self.amb, self.relief = gloss, subs, wrap, amb, relief


class Figure:
    """Layers (back to front) lit together; see the module docstring."""

    def __init__(self, P, light=LIGHT):
        self.P = P
        self.layers = []
        self.light = light

    def add(self, d, stops, base=0.0, round_=0.03, z=None, soft=1.1, tone=0.0, gloss=0.0, bump=0.0, subs=(),
            wrap=0.2, amb=0.12, relief=0.0002, stroke=None, stroke_amt=0.05):
        """``d``: signed distance of the shape; ``z``: relief (default: a
        dome of ``round_``) on top of ``base``; ``bump``: extra relief (folds,
        strands); ``tone``: extra tone (on the 0..1 ramp); ``subs``:
        [(mask, stops)] regions painted with another ramp under the same
        light (lips in a face); ``stroke``: brush direction (radians)."""
        P = self.P
        alpha = np.clip(0.5 - d / (soft * P.px), 0.0, 1.0)
        zz = (dome_z(d, round_) if z is None else z) + bump + base
        t = np.asarray(tone, dtype=np.float64) + np.zeros(P.X.shape)
        if stroke is not None:
            t = t + P.strokes(stroke, len(self.layers) * 7 + 3, 45.0, 3.0) * stroke_amt * 0.6
        self.layers.append(Layer(alpha, zz, stops, t, gloss, subs, wrap, amb, relief))
        return alpha

    def render(self, shadow_len=0.09, ao=1.0):
        P = self.P
        H, W = P.X.shape
        Z = np.full((H, W), -0.02)
        for L in self.layers:
            Z = np.where(L.alpha > 0.5, L.z, Z)
        # cast shadows: march toward the light through the combined relief
        lx, ly, lz = self.light
        lxy = math.hypot(lx, ly)
        sx, sy = lx / lxy, -ly / lxy
        slope = lz / lxy
        S = np.zeros((H, W))
        for k in range(1, int(shadow_len / P.px)):
            Zs = shift(Z, int(round(k * sx)), int(round(k * sy)))
            S = np.maximum(S, np.clip((Zs - Z - k * P.px * slope) / 0.004, 0.0, 1.0))
        S = blur(S, 1, 1)
        occl = np.clip((blur(Z, 6) - Z) * 28.0, 0.0, 0.55) * ao
        half = self.light + np.array([0.0, 0.0, 1.0])
        half = half / np.linalg.norm(half)
        for L in self.layers:
            n = normals(L.z, P.px)
            diff = np.clip((n @ self.light + L.wrap) / (1.0 + L.wrap), 0.0, 1.0)
            spec = np.clip(n @ half - 0.9, 0, 1) * 10.0
            lit = diff * (1.0 - 0.82 * S)
            t = L.amb + lit * (1.0 - L.amb) - occl + L.tone + spec * L.gloss * (1.0 - S)
            col = ramp(L.stops, t)
            for mask, stops in L.subs:
                m = np.asarray(mask, dtype=np.float64)
                col = col * (1 - m[..., None]) + ramp(stops, t) * m[..., None]
            P.put(L.alpha > 0, col, relief=L.relief + np.clip(t, 0, 1) * 0.0004, alpha=L.alpha)
        return S


# --------------------------------------------------------------------------
# figure parts
# --------------------------------------------------------------------------

def background(P, stops, halo=(-0.06, 0.26), reach=0.5, seed=1, angle=0.7):
    """Studio ground: dark, lighter behind the head on the lit side, loose
    diagonal brushwork."""
    d = np.hypot(P.X - halo[0], (P.Y - halo[1]) * 0.85)
    t = np.clip(1.0 - d / reach, 0, 1) ** 1.6
    br = P.strokes(angle, seed + 1, 26.0, 4.0)
    t = t + P.fbm(3.5, seed, 3) * 0.12 + br * 0.05
    P.put(np.ones(P.X.shape, bool), ramp(stops, np.clip(t, 0, 1)), relief=br * 0.00015)


def torso_d(P, sw=0.21, top=0.02, neck_w=0.045, slope=0.07, bottom=-0.52):
    """Shoulders and chest of a bust portrait: trapezius slope, round
    deltoids, arms going down to the frame."""
    def side(s):
        return bezier([(s * neck_w, top), (s * (neck_w + 0.03), top - 0.022), (s * (sw - 0.1), top - slope + 0.004),
                       (s * (sw - 0.035), top - slope - 0.004), (s * (sw + 0.006), top - slope - 0.012),
                       (s * (sw + 0.018), top - slope - 0.045), (s * (sw + 0.02), top - slope - 0.09),
                       (s * (sw + 0.024), top - slope - 0.2), (s * (sw + 0.035), bottom + 0.1),
                       (s * (sw + 0.04), bottom)], n=10)
    return polygon(P, side(-1)[::-1] + side(1))


def neck_d(P, w=0.04, top=0.07, bottom=-0.02):
    return polygon(P, [(-w, top), (w, top), (w * 1.18, bottom), (-w * 1.18, bottom)])


def face_relief(P, rx=None, taper=0.22, age=0.0, fat=0.0):
    """Sculpted relief of a frontal face (figure space): egg-shaped head,
    brow ridge, eye sockets and eyeballs, a nose with its ridge, wings and
    tip, lips, cheekbones, chin; ``age`` adds folds and bags. Returns (z, d)."""
    cx, cy, ry = FACE["cx"], FACE["cy"], FACE["ry"]
    rx = rx or FACE["rx"]
    fx, fy = P.X - cx, P.Y - cy
    t = fy / ry
    rxe = rx * (1.0 + taper * np.clip(t, -1, 0)) * (1.0 + 0.05 * np.exp(-((t + 0.1) / 0.35) ** 2)
                                                     + fat * 0.08 * np.exp(-((t + 0.5) / 0.3) ** 2))
    nx, ny = fx / rxe, t
    r2 = nx * nx + ny * ny
    d = (np.sqrt(r2) - 1.0) * np.minimum(rxe, ry)
    z = 0.075 * np.sqrt(np.clip(1.0 - r2, 0, 1))

    def g(x, y, sx, sy, amp):
        return amp * np.exp(-((fx - x) / sx) ** 2 - ((fy - y) / sy) ** 2)

    ey = DESIGN_EYE_Y - cy
    z += g(0.0, ey + 0.02, 0.052, 0.008, 0.005)                      # brow ridge
    for s in (-1, 1):
        z += g(s * EYE_DX, ey + 0.001, 0.018, 0.012, -0.012)          # socket
        z += g(s * EYE_DX, ey - 0.001, 0.0115, 0.0065, 0.006)         # eyeball
        z += g(s * 0.047, -0.004, 0.02, 0.016, 0.005 + fat * 0.004)   # cheekbone / cheek
        z += g(s * 0.0125, -0.023, 0.0068, 0.006, 0.006)              # nostril wing
    tn = np.clip((ey - fy) / (ey + 0.02), 0, 1)
    ridge = (0.003 + 0.017 * tn ** 1.3) * np.exp(-(fx / (0.0055 + 0.004 * tn)) ** 2)
    ridge *= np.exp(-np.clip(-(fy + 0.021) / 0.0035, 0, None) ** 2) * np.exp(-np.clip((fy - ey) / 0.008, 0, None) ** 2)
    z += ridge
    z += g(0.0, -0.02, 0.0085, 0.0065, 0.006)                         # nose tip
    z += g(0.0, -0.036, 0.0055, 0.008, 0.0012)                        # philtrum
    z += g(0.0, -0.047, 0.019, 0.0042, 0.0038)                        # upper lip
    z += g(0.0, -0.058, 0.016, 0.0048, 0.0048)                        # lower lip
    z -= 0.0032 * np.exp(-((fy + 0.0525) / 0.0015) ** 2) * smooth(0.026, 0.02, np.abs(fx))   # mouth line
    z -= g(0.0, -0.068, 0.018, 0.004, 0.0025)                         # hollow under the lip
    z += g(0.0, -0.084, 0.022, 0.012, 0.005)                          # chin
    if age > 0:
        for s in (-1, 1):
            fold = polyline_dist(P, [(cx + s * 0.019, cy - 0.024), (cx + s * 0.029, cy - 0.042),
                                     (cx + s * 0.033, cy - 0.062)])
            z -= age * 0.0032 * np.exp(-(fold / 0.0022) ** 2)
            z += g(s * EYE_DX, ey - 0.013, 0.014, 0.0035, 0.0025 * age)    # bags
            z -= g(s * EYE_DX, ey - 0.018, 0.014, 0.0015, 0.0018 * age)
        for k in range(3):
            line = np.abs(fy - (ey + 0.038 + k * 0.009) - 0.002 * np.sin(fx * 70))
            z -= age * 0.0012 * np.exp(-(line / 0.0013) ** 2) * smooth(0.05, 0.03, np.abs(fx))
    return z, d


def face(fig, P, skin, lips="#8e4a3e", base=0.06, rx=None, taper=0.22, age=0.0, fat=0.0, blush=0.25,
         stubble=0.0):
    z, d = face_relief(P, rx, taper, age, fat)
    cx, cy = FACE["cx"], FACE["cy"]
    fx, fy = P.X - cx, P.Y - cy
    lip_up = (np.abs(fx) < 0.021 - np.abs(fy + 0.049) * 0.9) & (fy > -0.0525) & (fy < -0.043 - np.abs(fx) * 0.12)
    lip_lo = (np.abs(fx) < 0.018) & (fy < -0.0525) & (fy > -0.063 + (fx / 0.018) ** 2 * 0.006)
    subs = [(lip_up | lip_lo, ["#2a0e0a", "#5a2a20", lips, "#c49080"])]
    tone = np.zeros(P.X.shape)
    for s in (-1, 1):
        tone += np.exp(-(((fx - s * 0.045) / 0.022) ** 2 + ((fy + 0.012) / 0.02) ** 2)) * blush * 0.08
    tone += np.exp(-((fx / 0.01) ** 2 + ((fy + 0.02) / 0.008) ** 2)) * blush * 0.05
    if stubble > 0:
        jaw = smooth(-0.03, -0.075, fy) * smooth(0.03, 0.06, np.abs(fx) + (fy + 0.1) * 0.3)
        tone -= stubble * 0.1 * (np.exp(-((fy + 0.075) / 0.03) ** 2) + jaw * 0.3)
    return fig.add(d, skin, base=base, z=z, tone=tone, subs=subs, wrap=0.4, amb=0.14, stroke=1.3, stroke_amt=0.03,
                   relief=0.0003)


def ears(fig, P, skin, base=0.045, y=None):
    y = DESIGN_EYE_Y - 0.012 if y is None else y
    for s in (-1, 1):
        d = ellipse(P, s * (FACE["rx"] - 0.001), y, 0.008, 0.02, rot=-0.15 * s)
        fig.add(d, skin, base=base, round_=0.006, tone=-0.08)


def paint_eye(P, ex, ey, eye_col=("#2a1a10", "#6b4a2a"), lid=0.85, light=1.0):
    """The eye as painted on the canvas: almond opening, dark upper lid,
    off-white sclera shaded at the corners, iris, pupil, a catchlight."""
    X, Y = P.X, P.Y
    dx = (X - ex) / (EYE_W / 2)
    top = ey + EYE_H / 2 * (1 - dx ** 2) * 1.05
    bot = ey - EYE_H / 2 * (1 - dx ** 2) * 0.85
    opening = (np.abs(dx) < 1) & (Y < top) & (Y > bot)
    sclera = ramp(["#5a4638", "#9a8a78", "#c8baa4", "#dcd2c0"],
                  (1.0 - np.abs(dx) * 0.55 - (Y > ey + 0.003) * 0.3) * light)
    P.put(opening, sclera)
    r = np.hypot(X - ex, Y - ey)
    P.put(opening & (r < 0.0062), ramp(list(eye_col), (0.3 - (Y - ey) * 60) * light))
    P.put(opening & (r < 0.0027), hexcol("#0c0806"))
    glint = (np.abs(X - ex + 0.0022) < P.px * 0.6) & (np.abs(Y - ey - 0.0022) < P.px * 0.6)
    P.put(opening & glint, hexcol("#f0e8da"))
    P.put((np.abs(dx) < 1.12) & (np.abs(Y - top) < 0.0019), hexcol("#221208"), alpha=lid)
    P.put((np.abs(dx) < 0.9) & (np.abs(Y - bot) < 0.0009), hexcol("#5a3424"), alpha=0.45)
    crease = (np.abs(dx) < 0.95) & (np.abs(Y - top - 0.0045 + dx ** 2 * 0.002) < 0.0009)
    P.put(crease, hexcol("#5a3424"), alpha=0.35)
    return opening


def eyes_and_brows(P, eye_col=("#2a1a10", "#6b4a2a"), brow=("#1e120c", "#4a3424"), tilt=0.0, arch=0.0,
                   thick=1.0):
    for s in (-1, 1):
        lightness = 1.0 if s < 0 else 0.8
        paint_eye(P, s * EYE_DX, DESIGN_EYE_Y, eye_col, lid=0.85, light=lightness)
        inner = (s * 0.012, DESIGN_EYE_Y + 0.015 - tilt * 0.006)
        mid = (s * 0.031, DESIGN_EYE_Y + 0.021 + arch * 0.003 + tilt * 0.001)
        outer = (s * 0.049, DESIGN_EYE_Y + 0.015 + arch * 0.001)
        d = polyline_dist(P, bezier([inner, mid, mid, outer], 8))
        th = (0.0032 - np.abs(P.X - s * 0.028) * 0.035) * thick
        tone = 0.35 * lightness + P.fbm(220, 7 + s, 1) * 0.25
        P.put(d < np.maximum(th, 0.0008), ramp(list(brow), tone), relief=np.full(P.X.shape, 0.0005), alpha=0.92)


def nose_mouth_accents(P, frown=0.0, smile=0.0):
    cx, cy = FACE["cx"], FACE["cy"]
    for s, a in ((-1, 0.55), (1, 0.85)):
        n = np.exp(-(((P.X - cx - s * 0.0105) / 0.0042) ** 2 + ((P.Y - cy + 0.0275) / 0.0026) ** 2))
        P.put(n > 0.35, hexcol("#2a120a"), alpha=a)
    my = cy - 0.0525
    curve = (smile - frown) * ((P.X / 0.024) ** 2) * 0.004
    line = (np.abs(P.Y - my - curve) < 0.0011) & (np.abs(P.X - cx) < 0.022)
    P.put(line, hexcol("#2a0c08"), alpha=0.85)
    for s in (-1, 1):
        corner = np.hypot(P.X - cx - s * 0.023, P.Y - my - (smile - frown) * 0.004) < 0.0016
        P.put(corner, hexcol("#3a1410"), alpha=0.7)


def hair(fig, P, d, stops, flow, base=0.07, round_=0.04, sheen=0.3, seed=0, curls=0.0):
    """Hair, a wig or a beard: dome relief with strands along ``flow``."""
    st = P.strokes(flow, seed + 21, 150.0, 7.0)
    cl = P.strokes(flow, seed + 22, 45.0, 4.0)
    bump = st * 0.0012 + cl * 0.003
    if curls > 0:
        cu = P.fbm(95.0, seed + 23, 2)
        bump = bump + np.sin(cu * 9.0) * 0.003 * curls
    return fig.add(d, stops, base=base, round_=round_, bump=bump, tone=st * 0.06, gloss=sheen, wrap=0.3, amb=0.1,
                   relief=0.0005 + st * 0.0003)


def folds(P, angle, freq=26.0, seed=0, amt=0.012):
    """Cloth folds: a relief of a few long soft ridges along ``angle``."""
    return P.fbm(freq * 0.42, seed, 2, angle=angle, stretch=3.0) * amt * 1.3


def buttons(fig, P, pts, r, stops, base):
    for x, y in pts:
        fig.add(ellipse(P, x, y, r, r), stops, base=base, round_=r * 0.8, gloss=0.8, soft=0.8)


# --------------------------------------------------------------------------
# portraits (figure space: eyes at DESIGN_EYE_Y; FIG_OY shifts them up)
# --------------------------------------------------------------------------

SKIN_PALE = ["#1e100a", "#4a2a1e", "#7e4e3a", "#aa7458", "#cc9a7c", "#e4bea0", "#f4dcc4"]
SKIN_RUDDY = ["#1c0e08", "#48261a", "#7c4432", "#a8664c", "#c88a6a", "#e0ac8c", "#f0cdb0"]
SKIN_OLD = ["#1e0f0a", "#4a2a1e", "#7c5038", "#a67658", "#c49a7a", "#dcbc9c", "#eed8c0"]
SKIN_CHILD = ["#20100c", "#4e2c22", "#86543e", "#b47e62", "#d6a488", "#ecc8ae", "#f8e4d2"]
GOLD = ["#241404", "#5e400e", "#a07a24", "#dcb44e", "#fff0b0"]


def p_aristocrat(P):
    background(P, ["#070605", "#16120c", "#2c2418", "#4a3c26"], halo=(-0.08, 0.24), seed=3)
    fig = Figure(P)
    # red velvet drapery in the upper left, a stone column on the right
    cur = polygon(P, bezier([(-0.4, 0.52), (-0.25, 0.5), (-0.2, 0.36), (-0.24, 0.24), (-0.3, 0.1), (-0.36, 0.0),
                             (-0.4, -0.06)]) + [(-0.4, 0.52)])
    fig.add(cur, ["#140202", "#3a0606", "#6a0e0c", "#9a2016", "#c8442c"], round_=0.06,
            bump=folds(P, 1.25, 30.0, 4, 0.02), gloss=0.2, base=-0.01)
    cyl = np.sqrt(np.clip(1.0 - ((P.X - 0.33) / 0.085) ** 2, 0, 1)) * 0.085
    col = polygon(P, [(0.245, -0.6), (0.415, -0.6), (0.415, 0.24), (0.245, 0.24)])
    fig.add(col, ["#0a0908", "#221e18", "#3e382c", "#5e5646", "#7e7460"], z=cyl, bump=P.fbm(12, 6, 2) * 0.003,
            base=-0.01, wrap=0.1)
    fig.add(polygon(P, [(0.23, 0.24), (0.43, 0.24), (0.43, 0.27), (0.23, 0.27)]),
            ["#0a0908", "#221e18", "#3e382c", "#5e5646"], base=0.0, round_=0.012)
    # coat: dark green velvet, gold braid at the opening, gilt buttons
    body = torso_d(P, sw=0.215)
    fig.add(body, ["#030504", "#0a140e", "#152a1e", "#24402e", "#3e5e44"], round_=0.14,
            bump=folds(P, 1.4, 22.0, 7, 0.018), gloss=0.35, stroke=1.4)
    for s in (-1, 1):
        braid = polyline_dist(P, bezier([(s * 0.05, -0.02), (s * 0.07, -0.12), (s * 0.085, -0.3), (s * 0.09, -0.52)]))
        fig.add(braid - 0.007, GOLD, base=0.02, round_=0.004, bump=np.sin(P.Y * 900) * 0.0008, gloss=1.0, soft=0.8)
    buttons(fig, P, [(s * 0.12, -0.1 - k * 0.075) for s in (-1, 1) for k in range(5)], 0.0085, GOLD, 0.025)
    # neck, lace jabot
    fig.add(neck_d(P), SKIN_PALE, base=0.03, round_=0.03, tone=-0.05)
    jab = polygon(P, bezier([(-0.038, 0.035), (-0.075, -0.02), (-0.07, -0.13), (0.0, -0.2), (0.07, -0.13),
                             (0.075, -0.02), (0.038, 0.035)]) + [(0.0, 0.04)])
    lace_b = P.fbm(120.0, 12, 2) * 0.002 + np.sin(P.Y * 520 + P.fbm(40, 13, 2) * 5) * 0.0025
    fig.add(jab, ["#2e2c28", "#6e6a60", "#b0aa9c", "#e0dacc", "#fbf8f0"], base=0.035, round_=0.03, bump=lace_b,
            stroke=1.2)
    # the powdered wig: back mass, the face, the top, rolls over the ears
    back = union(ellipse(P, 0.0, 0.19, 0.1, 0.1), ellipse(P, 0.0, 0.1, 0.105, 0.075))
    WIG = ["#2e2a26", "#5e5850", "#908a80", "#bcb6aa", "#dcd6ca", "#f2eee6"]
    flow = np.arctan2(P.Y - 0.14, P.X) + math.pi / 2
    hair(fig, P, back, WIG, flow, base=0.02, round_=0.05, seed=15)
    face(fig, P, SKIN_PALE, base=0.06, age=0.5, blush=0.35, lips="#8a4a40")
    ears(fig, P, SKIN_PALE)
    top = np.maximum(ellipse(P, 0.0, 0.215, 0.09, 0.07), -(P.Y - 0.198 + 0.02 * np.cos(P.X / 0.09 * 1.4)))
    hair(fig, P, top, WIG, flow, base=0.075, round_=0.035, seed=16, sheen=0.4)
    for s in (-1, 1):
        for k, (yy, ww) in enumerate(((0.162, 0.034), (0.128, 0.036))):
            roll = ellipse(P, s * 0.086, yy, ww, 0.0165, rot=0.12 * s)
            hair(fig, P, roll, WIG, np.full(P.X.shape, 0.0), base=0.08, round_=0.016, seed=17 + k + s, sheen=0.4)
    fig.render()
    eyes_and_brows(P, ("#1a1410", "#4e3a2a"), ("#4a443c", "#8a847a"), tilt=1.0, thick=1.1)
    nose_mouth_accents(P, frown=0.6)


def p_lady_fan(P):
    background(P, ["#080605", "#1a130c", "#34281a", "#54432c"], halo=(-0.06, 0.25), seed=21)
    # evening sky and trees through a gap in the upper right (Gainsborough)
    vista = np.clip((P.X - 0.12) * 5.0, 0, 1) * np.clip(1.0 - np.abs(P.Y + 0.02) / 0.2, 0, 1)
    t = smooth(-0.12, 0.2, P.Y) + P.fbm(6, 22, 3) * 0.25
    P.put(vista > 0.05, ramp(["#3a3226", "#7a6c50", "#b0a27c", "#8a948a"], t), alpha=np.clip(vista * 1.3, 0, 0.9))
    trees = P.fbm(10, 23, 4) + (0.06 - P.Y) * 3.0 + (0.3 - P.X) * 1.2
    P.put((vista > 0.05) & (trees > 0.35), ramp(["#0a0d07", "#1a2012", "#2e361e"], P.fbm(40, 24, 2) + 0.4),
          alpha=np.clip(vista * 1.5, 0, 1))
    fig = Figure(P)
    body = torso_d(P, sw=0.2, top=-0.005, slope=0.06)
    edge = bezier([(-0.19, -0.075), (-0.12, -0.06), (-0.05, -0.08), (0.0, -0.095), (0.05, -0.08), (0.12, -0.06),
                   (0.19, -0.075)])
    chest = polygon(P, edge + [(0.19, 0.2), (-0.19, 0.2)])
    fig.add(neck_d(P, w=0.036, top=0.07, bottom=-0.04), SKIN_PALE, base=0.03, round_=0.03)
    fig.add(np.maximum(body, chest), SKIN_PALE, base=0.01, round_=0.08, tone=0.02)
    fig.add(np.maximum(body, -chest), ["#02040a", "#081630", "#12305a", "#2a5486", "#6a96bc", "#c0d8e6"], base=0.012,
            round_=0.12, bump=folds(P, 1.15, 24.0, 25, 0.02), gloss=0.9, stroke=1.2)
    lace = polyline_dist(P, edge) - 0.007 - np.abs(np.sin(P.X * 380)) * 0.003
    fig.add(np.maximum(lace, P.Y), ["#4a463c", "#9a9486", "#dcd6c8", "#fbf8f0"], base=0.02, round_=0.004,
            bump=P.fbm(200, 26, 1) * 0.001, soft=0.9)
    for k in range(13):
        a = -0.95 + k * 0.158
        px_, py_ = 0.043 * math.sin(a), 0.012 - 0.03 * math.cos(a) * 0.9
        fig.add(ellipse(P, px_, py_, 0.0048, 0.0048), ["#3a3834", "#8a8680", "#d8d4cc", "#ffffff"], base=0.045,
                round_=0.004, gloss=1.2, soft=0.7)
    HAIR = ["#050303", "#140c08", "#2a1a10", "#4a3020", "#6e4a30"]
    flow = np.arctan2(P.Y - 0.14, P.X) + math.pi / 2
    hair(fig, P, union(ellipse(P, 0.0, 0.2, 0.09, 0.08), ellipse(P, 0.0, 0.285, 0.05, 0.036)), HAIR, flow, base=0.02,
         seed=27, sheen=0.5)
    face(fig, P, SKIN_PALE, base=0.06, rx=0.069, taper=0.34, blush=0.7, lips="#b4524a")
    ears(fig, P, SKIN_PALE)
    front = np.maximum(ellipse(P, 0.0, 0.232, 0.085, 0.05), -(P.Y - 0.2 + 0.025 * np.cos(P.X / 0.085 * 1.5)))
    hair(fig, P, front, HAIR, flow, base=0.075, round_=0.03, seed=28, sheen=0.5)
    curls = union(*[ellipse(P, s * 0.077, 0.15 - k * 0.026, 0.014, 0.012) for s in (-1, 1) for k in range(3)])
    hair(fig, P, curls, HAIR, flow, base=0.08, round_=0.012, seed=29, sheen=0.6, curls=1.0)
    for s in (-1, 1):
        fig.add(ellipse(P, s * 0.074, 0.098, 0.0055, 0.007), ["#4a4640", "#bcb8b0", "#ffffff"], base=0.09,
                round_=0.005, gloss=1.2, soft=0.7)
    # the fan, held low on the right, and the hand
    cx_, cy_ = 0.115, -0.25
    ang = np.arctan2(P.Y - cy_, P.X - cx_)
    r = np.hypot(P.X - cx_, P.Y - cy_)
    fan_d = np.maximum(np.maximum(r - 0.17, 0.028 - r), np.maximum(0.4 - ang, ang - 2.55) * 0.05)
    pleats = np.abs(np.mod((ang - 0.4) / (2.15 / 16), 1.0) - 0.5) * 0.004
    motif = (np.abs(r - 0.115) < 0.028) & (P.fbm(80, 30, 2) > 0.15)
    fig.add(fan_d, ["#3a2420", "#8a5a4e", "#d0a898", "#f0dcd0", "#fcf4ee"], base=0.06, round_=0.01, bump=pleats,
            subs=[(motif, ["#2a0e14", "#6a2432", "#a04858", "#d88a94"])])
    fig.add(ellipse(P, cx_ + 0.004, cy_ - 0.012, 0.045, 0.028, rot=0.3), SKIN_PALE, base=0.075, round_=0.02)
    fig.render()
    eyes_and_brows(P, ("#140e0a", "#3e2e22"), ("#140c08", "#3a281c"), tilt=-0.4, arch=1.0, thick=0.8)
    nose_mouth_accents(P, smile=0.35)


def p_general(P):
    background(P, ["#080808", "#1a1916", "#34322c", "#54504a"], halo=(-0.06, 0.25), seed=41)
    smoke = P.fbm(5.0, 42, 4) + (-0.12 - P.Y) * 1.3 - (P.X + 0.12) * 0.9
    P.put(smoke > 0.05, ramp(["#1e1a16", "#4e3e30", "#8a6040", "#c89058"], np.clip(smoke, 0, 1) * 0.9
                             + P.fbm(18, 43, 2) * 0.15), alpha=np.clip(smoke * 1.4, 0, 0.85))
    fig = Figure(P)
    body = torso_d(P, sw=0.22, slope=0.065)
    COAT = ["#010208", "#050a1a", "#0c1834", "#18305a", "#2e4c80"]
    RED = ["#1a0202", "#4a0606", "#8a1410", "#c0301e", "#e86040"]
    fig.add(body, COAT, round_=0.14, bump=folds(P, 1.3, 22.0, 45, 0.016), gloss=0.3, stroke=1.3)
    plast = polygon(P, [(-0.07, 0.0), (0.07, 0.0), (0.075, -0.1), (0.052, -0.3), (-0.052, -0.3), (-0.075, -0.1)])
    fig.add(np.maximum(plast, body) - 0.004, GOLD, base=0.011, round_=0.004, gloss=0.8)
    fig.add(np.maximum(plast, body) + 0.0035, RED, base=0.012, round_=0.04, bump=folds(P, 1.5, 30, 46, 0.006))
    buttons(fig, P, [(s * (0.05 - k * 0.004), -0.035 - k * 0.055) for s in (-1, 1) for k in range(5)], 0.0072, GOLD,
            0.03)
    fig.add(neck_d(P, w=0.04, top=0.07, bottom=0.0), SKIN_RUDDY, base=0.03, round_=0.03, tone=-0.05)
    collar = polygon(P, [(-0.058, 0.045), (0.058, 0.045), (0.062, -0.01), (-0.062, -0.01)])
    fig.add(collar, RED, base=0.05, round_=0.015)
    fig.add(np.maximum(collar, np.abs(P.Y - 0.041) - 0.004), GOLD, base=0.058, round_=0.003, gloss=1.0)
    for s in (-1, 1):
        ep = ellipse(P, s * 0.18, -0.04, 0.075, 0.028, rot=-0.3 * s)
        fig.add(ep, GOLD, base=0.04, round_=0.02, bump=P.fbm(200, 47 + s, 1) * 0.001, gloss=1.0)
        lean = (P.X * s - 0.18) * 0.3
        fr = (np.abs(P.X - s * 0.18) < 0.07) & (P.Y < -0.05 - lean) & (P.Y > -0.11 - lean)
        strands = np.abs(np.mod(P.X * 330, 1.0) - 0.5) * 0.004
        fig.add(np.where(fr, -0.001, 0.001), GOLD, base=0.035, z=strands, tone=-0.05, gloss=0.8, soft=0.6)
    sash = np.abs((P.Y + 0.12) + P.X * 0.95) - 0.034
    fig.add(np.maximum(np.maximum(sash, body), P.Y + 0.06), ["#1a0a1a", "#2a3a7a", "#4a6ab0", "#9ab4e0", "#e8f0f8"],
            base=0.02, round_=0.02, bump=folds(P, -0.8, 40, 49, 0.004), gloss=0.6)
    star_r = np.hypot(P.X - 0.14, P.Y + 0.22)
    star_a = np.arctan2(P.Y + 0.22, P.X - 0.14)
    fig.add(star_r - 0.03 * (0.55 + 0.45 * np.abs(np.cos(star_a * 4))), ["#3a3834", "#8a8680", "#d8d4cc", "#ffffff"],
            base=0.03, round_=0.006, bump=np.cos(star_a * 16) * 0.0008, gloss=1.2, soft=0.7)
    for k, x in enumerate((-0.155, -0.12, -0.085)):
        rib = polygon(P, [(x - 0.012, -0.11), (x + 0.012, -0.11), (x + 0.012, -0.14), (x - 0.012, -0.14)])
        stripes = [["#3a0808", "#a02020", "#e0e0e0"], ["#101a3a", "#e8e8e8", "#c02020"],
                   ["#1a3a1a", "#e0c040", "#1a3a1a"]][k]
        fig.add(rib, stripes, base=0.025, round_=0.003, tone=(np.mod(P.X * 180, 1.0) < 0.4) * 0.3)
        fig.add(ellipse(P, x, -0.155, 0.01, 0.01), GOLD, base=0.028, round_=0.006, gloss=1.2, soft=0.7)
    GREY = ["#141210", "#3a3630", "#6a665e", "#9e9a90", "#cecabe"]
    flow = np.arctan2(P.Y - 0.1, P.X) + math.pi / 2 + 0.35
    hair(fig, P, ellipse(P, 0.0, 0.18, 0.093, 0.085), GREY, flow, base=0.02, seed=50)
    face(fig, P, SKIN_RUDDY, base=0.06, age=0.75, blush=0.45, stubble=0.3)
    ears(fig, P, SKIN_RUDDY)
    locks = 0.006 * np.sin(P.X * 260 + P.fbm(30, 54, 2) * 3) + P.fbm(40, 55, 2) * 0.01
    top = np.maximum(ellipse(P, 0.0, 0.22, 0.09, 0.07), -(P.Y - 0.196 + 0.016 * np.cos(P.X / 0.09 * 1.4) + locks))
    hair(fig, P, top, GREY, flow - 0.6, base=0.075, round_=0.03, seed=51, sheen=0.3)
    for s in (-1, 1):
        burn = polygon(P, [(s * 0.071, 0.15), (s * 0.08, 0.15), (s * 0.074, 0.085), (s * 0.066, 0.09)])
        hair(fig, P, burn + P.fbm(90, 56 + s, 1) * 0.002, GREY, np.full(P.X.shape, 1.5), base=0.085, round_=0.004,
             seed=52 + s)
    mou = polygon(P, bezier([(-0.036, 0.064), (-0.028, 0.08), (-0.01, 0.078), (0.0, 0.074)])
                  + bezier([(0.0, 0.074), (0.01, 0.078), (0.028, 0.08), (0.036, 0.064)]) + [(0.0, 0.068)])
    hair(fig, P, mou, GREY, np.sign(P.X) * 0.35, base=0.1, round_=0.006, seed=53, sheen=0.2)
    fig.render()
    eyes_and_brows(P, ("#141a22", "#3e5266"), ("#3a3630", "#8a867c"), tilt=1.3, thick=1.3)
    nose_mouth_accents(P, frown=0.4)


def p_child_dog(P):
    background(P, ["#060805", "#12160c", "#262a18", "#3e4026"], halo=(-0.05, 0.24), seed=61)
    sky = (P.X > 0.12) & (P.Y > -0.02) & (P.Y < 0.34)
    t = P.fbm(9, 62, 3) + (P.X - 0.12) * 2.2 - np.abs(P.Y - 0.14) * 2.8
    P.put(sky & (t > 0.1), ramp(["#3a3c2e", "#7a7c62", "#b4ae8a"], t), alpha=np.clip(t * 2, 0, 0.85))
    foliage = P.fbm(13, 63, 4) * 0.7 + (np.abs(P.X) - 0.24) * 2.4 + (P.Y - 0.12) * 0.7
    P.put(foliage > 0.25, ramp(["#050704", "#101a0c", "#223016", "#3c4a24"], P.fbm(40, 64, 2) * 0.5 + 0.35
                               + P.Y * 0.4), relief=P.fbm(90, 65, 1) * 0.0004)
    fig = Figure(P)
    body = torso_d(P, sw=0.17, top=0.01, neck_w=0.038, slope=0.05)
    WHITE = ["#1e1c1a", "#4e4a44", "#8a867c", "#c4beb2", "#e8e4da", "#fcfaf4"]
    fig.add(body, WHITE, round_=0.12, bump=folds(P, 1.5, 26.0, 66, 0.018), gloss=0.3, stroke=1.5)
    sash = np.abs(P.Y + 0.24 + P.X * 0.1) - 0.028
    fig.add(np.maximum(sash, body), ["#2a0c12", "#6a2a36", "#b0606e", "#e4a0aa"], base=0.012, round_=0.02,
            bump=folds(P, 0.1, 40, 67, 0.004), gloss=0.5)
    fig.add(neck_d(P, w=0.034, top=0.07, bottom=-0.01), SKIN_CHILD, base=0.03, round_=0.03)
    scal = np.sin(np.arctan2(P.Y + 0.02, P.X) * 26) * 0.0025
    collar = np.maximum(ellipse(P, 0.0, -0.02, 0.1, 0.048), -ellipse(P, 0.0, 0.004, 0.046, 0.034))
    fig.add(collar + np.maximum(scal, 0) * 0.5, WHITE, base=0.04, round_=0.012, bump=scal * 0.4)
    HAIR = ["#1e1408", "#4e3614", "#8a6428", "#c49a48", "#ecd08a", "#fbeec0"]
    flow = np.arctan2(P.Y - 0.13, P.X) + math.pi / 2 + P.fbm(28, 69, 2) * 1.2
    bob = ellipse(P, 0.0, 0.175, 0.1, 0.095) + P.fbm(60, 76, 2) * 0.008
    bob = np.maximum(bob, 0.075 - P.Y)
    hair(fig, P, bob, HAIR, flow, base=0.02, seed=70, sheen=0.6, curls=1.0)
    face(fig, P, SKIN_CHILD, base=0.06, rx=0.068, taper=0.18, fat=1.0, blush=0.9, lips="#c0625a")
    fringe = np.maximum(ellipse(P, 0.0, 0.225, 0.08, 0.042), -(P.Y - 0.193 + 0.012 * np.cos(P.X * 50)))
    hair(fig, P, fringe, HAIR, flow, base=0.075, round_=0.025, seed=71, sheen=0.6, curls=1.0)
    # the spaniel in the child's arms, lower right
    dog_body = ellipse(P, 0.11, -0.3, 0.1, 0.075, rot=0.25)
    dog_head = ellipse(P, 0.13, -0.17, 0.058, 0.052)
    snout = ellipse(P, 0.136, -0.2, 0.03, 0.022)
    patch = P.fbm(11, 73, 2) + (P.X - 0.1) * 3.0 > -0.05
    FUR_W = ["#1e1a14", "#4e463a", "#948a78", "#d4ccba", "#f6f0e2"]
    FUR_B = ["#140804", "#3a1a0a", "#6e3a18", "#a8662e", "#d49a58"]
    fur = P.strokes(-1.2, 74, 160, 5.0)
    fig.add(dog_body, FUR_W, base=0.06, round_=0.08, bump=fur * 0.002, subs=[(patch, FUR_B)], stroke=-1.2)
    fig.add(ellipse(P, 0.0, -0.3, 0.05, 0.03, rot=0.3), SKIN_CHILD, base=0.09, round_=0.02)
    fig.add(union(dog_head, snout), FUR_W, base=0.1, round_=0.04, bump=fur * 0.0015,
            subs=[((P.X > 0.14) | (P.Y > -0.14), FUR_B)])
    for s in (-1, 1):
        ear = ellipse(P, 0.13 + s * 0.052, -0.19, 0.026, 0.055, rot=0.25 * s)
        fig.add(ear, FUR_B, base=0.12, round_=0.012, bump=P.strokes(-1.5, 75 + s, 180, 6.0) * 0.002, stroke=-1.5)
    fig.render()
    eyes_and_brows(P, ("#16202c", "#46688a"), ("#6a4e24", "#a8844a"), tilt=-0.6, arch=1.0, thick=0.6)
    nose_mouth_accents(P, smile=0.25)
    for s in (-1, 1):
        e = np.hypot(P.X - 0.13 - s * 0.02, P.Y + 0.158) < 0.0068
        P.put(e, hexcol("#080402"))
        P.put(e & (np.hypot(P.X - 0.13 - s * 0.02 + 0.0022, P.Y + 0.155) < 0.0022), hexcol("#d8d0c0"))
    P.put(ellipse(P, 0.136, -0.186, 0.011, 0.0075) < 0, ramp(["#050302", "#3a2a24"], 0.3 + (P.Y + 0.183) * 50))


def p_bishop(P):
    background(P, ["#080404", "#1c0c08", "#361a12", "#522c1e"], halo=(-0.06, 0.26), seed=81)
    u, v = P.X / 0.08, P.Y / 0.11
    dam = np.cos(u * math.pi * 2) * np.cos(v * math.pi * 2) + np.cos((u + 0.5) * math.pi * 4) * 0.3
    P.put(dam > 0.8, hexcol("#4a2218"), alpha=0.22)
    fig = Figure(P)
    body = torso_d(P, sw=0.23, slope=0.075)
    COPE = ["#100202", "#360606", "#6a100c", "#a0261a", "#d0543a", "#f09070"]
    fig.add(body, COPE, round_=0.15, bump=folds(P, 1.35, 20.0, 85, 0.02), gloss=0.5, stroke=1.4)
    for s in (-1, 1):
        band = np.abs(P.X - s * (0.075 + (-P.Y) * 0.1)) - 0.034
        emb = P.fbm(110, 86 + s, 2) * 0.0015 + np.sin(P.Y * 240) * 0.0008
        fig.add(np.maximum(np.maximum(band, body), P.Y + 0.02), GOLD, base=0.015, round_=0.01, bump=emb, gloss=0.9)
    fig.add(neck_d(P, w=0.04, top=0.07, bottom=0.0), SKIN_OLD, base=0.03, round_=0.03, tone=-0.05)
    alb = np.maximum(ellipse(P, 0.0, 0.0, 0.07, 0.042), -ellipse(P, 0.0, 0.028, 0.046, 0.03))
    fig.add(alb, ["#2a2824", "#6a665e", "#aaa498", "#dcd6ca", "#f6f2ea"], base=0.04, round_=0.015)
    chain = polyline_dist(P, bezier([(-0.05, 0.0), (-0.04, -0.1), (-0.012, -0.13), (0.0, -0.14),
                                     (0.012, -0.13), (0.04, -0.1), (0.05, 0.0)]))
    fig.add(chain - 0.002, GOLD, base=0.03, round_=0.002, bump=np.sin(P.Y * 900) * 0.0006, gloss=1.0, soft=0.7)
    cross = np.minimum(polygon(P, [(-0.009, -0.14), (0.009, -0.14), (0.009, -0.25), (-0.009, -0.25)]),
                       polygon(P, [(-0.033, -0.162), (0.033, -0.162), (0.033, -0.18), (-0.033, -0.18)]))
    fig.add(cross, GOLD, base=0.035, round_=0.006, gloss=1.2, soft=0.8)
    fig.add(ellipse(P, 0.0, -0.171, 0.0065, 0.0065), ["#1a0206", "#6a0a14", "#c02838", "#ff8090"], base=0.043,
            round_=0.004, gloss=1.5, soft=0.7)
    WHITE_H = ["#221e1a", "#5a544c", "#948e84", "#c8c2b8", "#eeeae2"]
    for s in (-1, 1):
        side = ellipse(P, s * 0.072, 0.13, 0.024, 0.05)
        hair(fig, P, side, WHITE_H, np.full(P.X.shape, 1.5 + 0.3 * s), base=0.07, round_=0.015, seed=88 + s,
             curls=0.6)
    face(fig, P, SKIN_OLD, base=0.06, age=1.0, blush=0.35, stubble=0.15, lips="#8a5446")
    mitre = polygon(P, [(-0.086, 0.205), (0.086, 0.205), (0.078, 0.33), (0.0, 0.44), (-0.078, 0.33)])
    fig.add(mitre, ["#2a2824", "#6a665e", "#aaa498", "#dcd6ca", "#fcfaf4"], base=0.08, round_=0.05,
            bump=folds(P, 1.57, 18, 90, 0.004))
    fig.add(np.maximum(mitre, np.abs(P.X) - 0.016), GOLD, base=0.09, round_=0.005,
            bump=P.fbm(150, 91, 1) * 0.001, gloss=1.0)
    fig.add(np.maximum(mitre, P.Y - 0.228), GOLD, base=0.09, round_=0.008, bump=P.fbm(150, 92, 1) * 0.001, gloss=1.0)
    fig.add(ellipse(P, 0.0, 0.265, 0.009, 0.011), ["#0a0418", "#2a1a6a", "#5a4ab0", "#b0a0f0"], base=0.1,
            round_=0.006, gloss=1.5, soft=0.7)
    fig.render()
    eyes_and_brows(P, ("#1a1612", "#4a3e32"), ("#6a665e", "#c8c2b8"), tilt=0.3, thick=1.2)
    nose_mouth_accents(P, frown=0.15)


def p_merchant(P):
    background(P, ["#070605", "#191510", "#342c20", "#564a36"], halo=(-0.08, 0.2), seed=101)
    fig = Figure(P)
    body = torso_d(P, sw=0.215, slope=0.07)
    BLACK = ["#010101", "#060605", "#0e0d0b", "#1c1a16", "#34302a", "#524c42"]
    fig.add(body, BLACK, round_=0.14, bump=folds(P, 1.45, 22.0, 105, 0.02), gloss=0.3, stroke=1.4)
    fig.add(neck_d(P, w=0.04, top=0.07, bottom=0.0), SKIN_RUDDY, base=0.03, round_=0.03, tone=-0.05)
    ang = np.arctan2((P.Y - 0.012) / 0.05, P.X / 0.135)
    rr = np.hypot(P.X / 0.135, (P.Y - 0.012) / 0.05)
    ruff_d = (rr - 1.0) * 0.05 + np.abs(np.sin(ang * 17)) * 0.004
    fig.add(ruff_d, ["#2a2824", "#6a665e", "#aaa498", "#dcd6ca", "#fbf9f2"], base=0.045, round_=0.02,
            bump=np.abs(np.sin(ang * 17)) * 0.006)
    BEARD = ["#0a0604", "#24160c", "#4a2e18", "#724a2a", "#9a6a40"]
    face(fig, P, SKIN_RUDDY, base=0.06, age=0.45, blush=0.55, stubble=0.2)
    beard = polygon(P, bezier([(-0.062, 0.085), (-0.062, 0.035), (-0.035, 0.002), (0.0, -0.008), (0.035, 0.002),
                               (0.062, 0.035), (0.062, 0.085)]) + [(0.028, 0.062), (0.0, 0.056), (-0.028, 0.062)])
    hair(fig, P, beard, BEARD, np.full(P.X.shape, math.pi / 2) + P.X * 7, base=0.09, round_=0.02, seed=108,
         sheen=0.2, curls=0.4)
    mou = polygon(P, bezier([(-0.032, 0.062), (-0.024, 0.08), (-0.008, 0.078), (0.0, 0.074)])
                  + bezier([(0.0, 0.074), (0.008, 0.078), (0.024, 0.08), (0.032, 0.062)]) + [(0.0, 0.068)])
    hair(fig, P, mou, BEARD, np.sign(P.X) * 0.3, base=0.1, round_=0.006, seed=109, sheen=0.2)
    for s in (-1, 1):
        lock = polygon(P, [(s * 0.068, 0.2), (s * 0.084, 0.2), (s * 0.08, 0.1), (s * 0.068, 0.085)])
        hair(fig, P, lock + P.fbm(90, 114 + s, 1) * 0.003, ["#050302", "#140c06", "#2e1c0e", "#4a2e18"],
             np.full(P.X.shape, 1.6), base=0.07, round_=0.006, seed=110 + s)
    brim = ellipse(P, 0.0, 0.212, 0.165, 0.028)
    crown = polygon(P, [(-0.086, 0.205), (0.086, 0.205), (0.078, 0.31), (-0.074, 0.316)])
    HAT = ["#010101", "#070706", "#12110f", "#24211c", "#3e3a32"]
    fig.add(crown, HAT, base=0.085, round_=0.05, gloss=0.3)
    fig.add(brim, HAT, base=0.1, round_=0.015, gloss=0.3)
    fig.add(np.maximum(crown, np.abs(P.Y - 0.226) - 0.008), ["#010101", "#0a0908", "#1a1714"], base=0.087,
            round_=0.003)
    letter = polygon(P, [(-0.2, -0.3), (-0.07, -0.265), (-0.052, -0.36), (-0.18, -0.405)])
    fig.add(letter, ["#3a3428", "#7a705c", "#bcb298", "#e8e0c8"], base=0.08, round_=0.006,
            bump=P.fbm(50, 112, 2) * 0.0015)
    fig.add(ellipse(P, -0.095, -0.335, 0.012, 0.012), ["#1a0202", "#5a0808", "#a01a14", "#d0503a"], base=0.088,
            round_=0.004, gloss=0.6, soft=0.8)
    fig.add(ellipse(P, -0.095, -0.385, 0.05, 0.03, rot=0.3), SKIN_RUDDY, base=0.09, round_=0.02)
    fig.add(ellipse(P, -0.16, -0.405, 0.036, 0.03, rot=0.3), ["#2a2824", "#8a867c", "#e2ddd0"], base=0.085,
            round_=0.012, bump=P.fbm(120, 113, 1) * 0.002)
    fig.render()
    for k in range(3):
        ln = polyline_dist(P, [(-0.185, -0.325 - k * 0.018), (-0.115, -0.305 - k * 0.018)])
        P.put(ln < 0.0011, hexcol("#4a3c2a"), alpha=0.75)
    eyes_and_brows(P, ("#140e0a", "#4e3420"), ("#140c06", "#4a2e18"), tilt=0.5, thick=1.2)
    nose_mouth_accents(P)


# --------------------------------------------------------------------------
# the harmless pictures
# --------------------------------------------------------------------------

def _foliage(fig, P, blobs, stops, base, seed, rough=0.05):
    d = union(*[ellipse(P, x, y, rx, ry) for x, y, rx, ry in blobs])
    d = d + P.fbm(38.0, seed, 3) * 0.018
    leaves = P.fbm(110.0, seed + 1, 2)
    fig.add(d, stops, base=base, round_=rough, bump=leaves * 0.004, tone=leaves * 0.06, wrap=0.35, amb=0.08)


def _canopy(P, cx, cy, rx, ry, seed, lit=(-0.6, 0.6)):
    """A tree crown as painters mass it: a ragged dark silhouette with a
    few lighter leaf clusters toward the light. Returns (mask, colour)."""
    dx, dy = (P.X - cx) / rx, (P.Y - cy) / ry
    dens = 1.0 - np.hypot(dx, dy) + P.fbm(9.0 / rx * 0.1, seed, 4) * 0.55 + P.fbm(60.0, seed + 1, 2) * 0.12
    mask = dens > 0.25
    light = np.clip(-(dx * lit[0] + dy * lit[1]) * 0.5 + 0.5, 0, 1)
    cl = P.fbm(28.0, seed + 2, 3)
    t = 0.18 + light * 0.35 + cl * 0.25 + np.clip(dens - 0.25, 0, 0.3) * 0.2
    t += (cl > 0.25) * light * 0.25
    return mask, ramp(["#030402", "#0c1208", "#1c2610", "#34401e", "#5e6634", "#8a8646"], t)


def p_landscape(P):
    """Evening landscape in the manner of Claude Lorrain: a ruined tower on
    a far hill, a river winding toward the sunset, dark framing trees."""
    X, Y = P.X, P.Y
    t = np.clip((Y + 0.08) / 0.55, 0, 1)
    sky = ramp(["#e8bc74", "#d4a06a", "#9a8474", "#566478", "#26324a", "#141c2c"], t ** 0.8)
    sun = np.exp(-(((X - 0.1) / 0.16) ** 2 + ((Y + 0.05) / 0.08) ** 2))
    sky = sky + sun[..., None] * (hexcol("#fce8b0") - sky) * 0.75
    cl = np.clip(P.fbm(4.0, 121, 4, angle=0.05, stretch=2.8) * 1.9 - 0.1 + (Y - 0.15) * 0.6, 0, 1)
    ccol = ramp(["#2e2a36", "#6e5a5a", "#c49470", "#f0c890"], np.clip(1.0 - t * 1.1 + sun * 0.5
                                                                     + P.fbm(12, 122, 2) * 0.25, 0, 1))
    sky = sky * (1 - cl[..., None] * 0.65) + ccol * cl[..., None] * 0.65
    P.put(np.ones(X.shape, bool), sky, relief=P.strokes(0.08, 123, 28, 4) * 0.00015)
    # far hills: flat, hazy, bluer with distance
    far_top = -0.07 + P.fbm(2.2, 124, 3) * 0.03 + np.exp(-((X + 0.05) / 0.1) ** 2) * 0.05
    far = Y < far_top
    P.put(far, ramp(["#4a4e5e", "#6a6a74", "#8e8682", "#b8a28a"], 0.35 + sun * 0.6 + (Y - far_top) * 2.0
                    + P.fbm(18, 125, 2) * 0.08), relief=np.full(X.shape, 0.0001))
    # the ruined tower on the far ridge, lit from the sunset side
    tx = -0.05
    tower = (np.abs(X - tx) < 0.011) & (Y < far_top.max() * 0 + 0.055 - (np.abs(X - tx) < 0.004) * 0.008) & (Y > -0.05)
    P.put(tower, ramp(["#2a2622", "#5a5046", "#9a8870"], 0.35 + (X > tx) * 0.35))
    wall = (X > tx) & (X < tx + 0.045) & (Y > -0.05) & (Y < 0.005 + (np.mod(X * 300, 1) < 0.5) * 0.004)
    P.put(wall, ramp(["#2a2622", "#5a5046", "#9a8870"], 0.4))
    # middle distance: olive fields, tree clumps, lit rims toward the sun
    mid_top = -0.12 + P.fbm(3.0, 126, 3) * 0.035 + X * 0.06
    mid = Y < mid_top
    t = 0.45 + (Y - mid_top) * 1.5 + P.fbm(9, 127, 3) * 0.2 + sun * 0.3
    clumps = P.fbm(22, 128, 3) > 0.2
    P.put(mid, ramp(["#141408", "#2a2a14", "#4a4622", "#76683a", "#a08a52"], t - clumps * 0.25),
          relief=P.fbm(60, 129, 2) * 0.0003)
    # the river: dark, mirroring the sky, a few bright ripple strokes
    riv_x = 0.04 + np.sin((Y + 0.5) * 6.0) * 0.06 * np.clip(-Y - 0.12, 0, 1) * 3.2
    width = 0.004 + np.clip(-Y - 0.13, 0, 1) * 0.3
    river = (np.abs(X - riv_x) < width + P.fbm(30, 130, 2) * 0.004) & (Y < mid_top - 0.004)
    refl = ramp(["#1e242c", "#44464a", "#8a7a66", "#e0bc86"], 0.35 + sun * 0.5 + np.clip(-Y - 0.3, 0, 1) * -0.6)
    ripple = P.fbm(80, 131, 2, angle=0.0, stretch=8.0) > 0.3
    P.put(river, refl)
    P.put(river & ripple, ramp(["#8a7a66", "#f0d09a"], 0.6 + sun * 0.4), alpha=0.8)
    # foreground bank and path
    bank_top = -0.36 + P.fbm(5, 132, 2) * 0.03 - X * 0.08
    P.put(Y < bank_top, ramp(["#050403", "#120e08", "#241c10", "#3a2e1a"], 0.4 + P.fbm(25, 133, 3) * 0.35
                             + (Y - bank_top) * 1.5), relief=P.fbm(50, 134, 2) * 0.0004)
    # framing trees: a big one filling the upper left, a slimmer one right
    for x0, x1, y1 in ((-0.29, -0.26, 0.2), (-0.2, -0.19, 0.0), (0.31, 0.3, 0.1)):
        trunk = (np.abs(X - (x0 + (x1 - x0) * (Y + 0.45) / (y1 + 0.45))) < 0.011 + (y1 - Y) * 0.006) & (Y < y1)
        P.put(trunk, ramp(["#030201", "#120c06", "#2a1e12"], 0.25 + (X < x0) * 0.3 + P.fbm(60, 135, 1) * 0.1))
    for cx, cy, rx, ry, sd in ((-0.26, 0.34, 0.22, 0.2, 140), (-0.3, 0.12, 0.13, 0.12, 141), (-0.15, 0.2, 0.1, 0.1, 142),
                               (0.33, 0.25, 0.12, 0.16, 143), (0.36, 0.06, 0.08, 0.08, 144)):
        mask, col = _canopy(P, cx, cy, rx, ry, sd)
        P.put(mask, col, relief=0.0004 + P.fbm(90, sd + 3, 1) * 0.0003)
    # two figures on the bank, one in a red cloak
    for x0, c in ((0.12, "#8a1a14"), (0.145, "#2a2a3a")):
        P.put((np.abs(X - x0) < 0.0045) & (Y > bank_top.mean() - 0.03) & (Y < bank_top.mean() - 0.005), hexcol(c))
        P.put(np.hypot(X - x0, Y - bank_top.mean() + 0.0) < 0.004, hexcol("#9a7458"))


def p_seascape(P):
    """A three-master heeling in a storm, light breaking through the clouds
    onto the waves."""
    X, Y = P.X, P.Y
    t = np.clip((Y + 0.1) / 0.55, 0, 1)
    sky = ramp(["#7a7462", "#46443c", "#202224", "#0c0e10"], t)
    brk = np.exp(-(((X - 0.14) / 0.13) ** 2 + ((Y - 0.2) / 0.11) ** 2))
    sky = sky + (brk * (0.55 + P.fbm(10, 141, 3) * 0.4))[..., None] * (hexcol("#e8dcb0") - sky)
    cl = np.clip(P.fbm(3.5, 142, 4), 0, 1)
    sky = sky * (1 - cl[..., None] * 0.45)
    P.put(np.ones(X.shape, bool), sky, relief=P.strokes(0.5, 143, 28, 4) * 0.0002)
    fig = Figure(P)
    horizon = -0.07
    wave = P.fbm(8, 144, 4, angle=0.18, stretch=3.0)
    sea_z = wave * 0.03 + P.fbm(26, 145, 2, angle=0.18, stretch=3.0) * 0.008
    sea = Y - (horizon + wave * 0.025)
    fig.add(sea, ["#030808", "#0c1c1e", "#1e3836", "#46645e", "#98aca0", "#e0e6d8"], base=0.0, z=sea_z,
            tone=brk * 0.35 + (Y - horizon) * 0.8, wrap=0.4, amb=0.1)
    rot = -0.2
    c, s = math.cos(rot), math.sin(rot)
    hx, hy = 0.02, -0.13

    def ship(u, v):
        return (hx + u * c - v * s, hy + u * s + v * c)
    hull = polygon(P, [ship(-0.13, 0.03), ship(0.14, 0.035), ship(0.1, -0.03), ship(-0.1, -0.035)])
    fig.add(hull, ["#050302", "#1a0e06", "#3e2412", "#6a4222"], base=0.05, round_=0.015)
    fig.add(np.maximum(hull, np.abs(-(X - hx) * s + (Y - hy) * c - 0.012) - 0.003), ["#3a2a10", "#a08040"],
            base=0.06, round_=0.002)
    for mx, h in ((-0.07, 0.24), (0.0, 0.31), (0.07, 0.22)):
        a0, a1 = ship(mx, 0.03), ship(mx, h)
        fig.add(seg_dist(P, a0, a1) - 0.0028, ["#050302", "#1a120a"], base=0.07, round_=0.002)
        for w, y0 in ((0.05, 0.05), (0.042, 0.12), (0.033, 0.19)):
            if y0 + 0.05 > h:
                continue
            sail = polygon(P, [ship(mx - w, y0), ship(mx + w, y0), ship(mx + w * 0.85, y0 + 0.055),
                               ship(mx - w * 0.85, y0 + 0.055)])
            fig.add(sail, ["#2a2618", "#6a604a", "#b0a484", "#e8dec0"], base=0.075, round_=0.02,
                    bump=np.sin((X - hx) * 150) * 0.002, tone=brk * 0.3)
    fig.render(shadow_len=0.04)
    foam = (Y < horizon + 0.01) & (P.fbm(28, 147, 2, angle=0.18, stretch=3.0) > 0.4 - (Y + 0.45) * 0.3)
    P.put(foam, ramp(["#8a9a90", "#e8ece2"], 0.6 + P.fbm(80, 148, 1) * 0.4), relief=np.full(X.shape, 0.0006),
          alpha=0.85)
    spray = (P.fbm(40, 149, 2) > 0.28) & (np.hypot(X - 0.15, Y + 0.1) < 0.07)
    P.put(spray, hexcol("#d8e0d6"), alpha=0.65)


def p_still_life(P):
    """Dutch breakfast piece: a table half covered by a white cloth, a
    pewter plate with a half-peeled lemon and grapes, a roemer of white
    wine, a bread roll, a knife jutting over the table edge."""
    X, Y = P.X, P.Y
    background(P, ["#050403", "#110e0a", "#231c14", "#3a2e20"], halo=(-0.12, 0.1), reach=0.6, seed=151)
    fig = Figure(P)
    TOP, EDGE = -0.06, -0.3                   # far edge of the table top, its front edge
    top = np.maximum(Y - TOP, EDGE - Y)
    fig.add(top, ["#050302", "#140c06", "#2c1a0e", "#4a2e18", "#6a4428"], z=np.zeros(X.shape),
            tone=0.3 + P.fbm(18, 152, 2, angle=0.0, stretch=6) * 0.12 + (Y - EDGE) * 0.8, wrap=1.0, amb=0.2)
    front = np.maximum(Y - EDGE, -0.45 - Y)
    fig.add(front, ["#020101", "#0a0604", "#1a0e08", "#2c1a0e"], z=np.zeros(X.shape), tone=0.2, wrap=1.0, amb=0.2)
    cloth_d = polygon(P, bezier([(-0.4, TOP - 0.005), (-0.2, TOP - 0.01), (-0.05, TOP - 0.012), (0.02, TOP - 0.02),
                                 (0.04, -0.15), (0.06, -0.25), (0.05, EDGE), (0.07, -0.36), (0.05, -0.45),
                                 (0.06, -0.52)]) + [(-0.4, -0.52)])
    fig.add(cloth_d, ["#1a1814", "#4a463e", "#8a857a", "#c8c2b4", "#eeeae0", "#fdfbf6"], base=0.004, round_=0.03,
            bump=folds(P, 1.3, 16, 153, 0.02) + np.clip(EDGE - Y, 0, 1) * 0.0 + (Y < EDGE) * folds(P, 1.57, 30, 157, 0.02),
            stroke=1.2)
    # roemer at the back left: foot, prunted stem, bowl of pale wine
    GLASS = ["#030604", "#0e1a10", "#24402a", "#5a7a58", "#b8d0b0"]
    rx0 = -0.2
    fig.add(ellipse(P, rx0, TOP - 0.01, 0.05, 0.012), GLASS, base=0.03, round_=0.008, gloss=1.2)
    stem = polygon(P, [(rx0 - 0.03, TOP - 0.008), (rx0 + 0.03, TOP - 0.008), (rx0 + 0.032, TOP + 0.09),
                       (rx0 - 0.032, TOP + 0.09)])
    prunts = np.sin((X - rx0) * 160) * np.sin(Y * 140) * 0.003
    fig.add(stem, GLASS, base=0.03, z=np.sqrt(np.clip(1 - ((X - rx0) / 0.032) ** 2, 0, 1)) * 0.03, bump=prunts,
            gloss=1.6, wrap=0.1)
    bowl = ellipse(P, rx0, TOP + 0.15, 0.07, 0.065)
    fig.add(np.maximum(bowl, TOP + 0.09 - Y), ["#0c0204", "#2a0610", "#58101e", "#8a2a34", "#d0909a"], base=0.03,
            round_=0.05, gloss=1.8, wrap=0.3)
    # plate with grapes, a lemon, the peel over the rim; bread roll; knife
    plate = ellipse(P, 0.0, -0.17, 0.17, 0.055)
    fig.add(plate, ["#0e1012", "#2e3032", "#5a5c5c", "#9a9a96", "#dcdcd4"], base=0.01, round_=0.01,
            tone=(np.abs(plate + 0.012) < 0.006) * 0.2, gloss=0.8)
    rng = np.random.default_rng(154)
    grapes = sorted([(-0.07 + rng.uniform(-0.05, 0.04), -0.15 + rng.uniform(-0.02, 0.05)) for _ in range(14)],
                    key=lambda g: g[1], reverse=True)
    for gx, gy in grapes:
        fig.add(ellipse(P, gx, gy, 0.018, 0.018), ["#040308", "#16122a", "#34284e", "#6a5a86", "#c0b4d4"],
                base=0.02 + (0.0 - gy) * 0.1, round_=0.017, gloss=1.4, soft=0.8)
    fig.add(ellipse(P, 0.07, -0.155, 0.052, 0.04, rot=0.2), ["#281c02", "#6a4c06", "#b88c12", "#e8c438", "#fcee9a"],
            base=0.03, round_=0.04, bump=P.fbm(200, 155, 1) * 0.0006, gloss=0.6)
    fig.add(np.maximum(ellipse(P, 0.1, -0.165, 0.03, 0.028), -ellipse(P, 0.095, -0.16, 0.035, 0.03)) - 0.002,
            ["#b8a06a", "#f4ecc8"], base=0.07, round_=0.01)
    peel = polyline_dist(P, bezier([(0.11, -0.19), (0.17, -0.21), (0.17, -0.27), (0.14, -0.3), (0.12, -0.33),
                                    (0.15, -0.37), (0.16, -0.4)]))
    fig.add(peel - 0.008, ["#4a3204", "#a07a10", "#dcb02a", "#f8e080"], base=0.05, round_=0.006,
            bump=np.sin(Y * 180) * 0.002)
    fig.add(ellipse(P, 0.24, -0.09, 0.075, 0.048, rot=-0.1), ["#1a0e04", "#4a2a10", "#8a5a28", "#c8904a", "#ecc07a"],
            base=0.02, round_=0.045, bump=P.fbm(90, 156, 2) * 0.002)
    knife = polygon(P, [(0.02, -0.25), (0.2, -0.28), (0.2, -0.295), (0.03, -0.265)])
    fig.add(knife, ["#101214", "#3a3c3e", "#8a8c8a", "#e0e0d8"], base=0.035, round_=0.004, gloss=1.2)
    fig.add(polygon(P, [(0.2, -0.279), (0.33, -0.3), (0.33, -0.318), (0.2, -0.296)]),
            ["#0a0402", "#2a140a", "#5a3218", "#7a4a28"], base=0.035, round_=0.006)
    fig.render(shadow_len=0.08)
    P.put((bowl < 0) & (np.abs(X - rx0 + 0.035) < 0.006) & (Y > TOP + 0.13) & (Y < TOP + 0.18), hexcol("#f4efe0"),
          alpha=0.9)
    P.put((np.abs(bowl) < 0.0016) & (Y > TOP + 0.09), hexcol("#aab8a0"), alpha=0.5)


def p_flowers(P):
    """Flower piece: a dense bouquet of roses, tulips and lilies in a
    bronze urn on a stone ledge, a fallen petal and a butterfly."""
    X, Y = P.X, P.Y
    background(P, ["#040403", "#0e0d0a", "#1e1b14", "#302a1e"], halo=(-0.05, 0.1), reach=0.55, seed=161)
    fig = Figure(P)
    ledge = np.maximum(Y + 0.3, -(Y + 0.5))
    fig.add(ledge, ["#0e0c0a", "#2a2620", "#4e483e", "#7a7264"], base=0.0, z=np.zeros(X.shape),
            tone=P.fbm(18, 162, 3) * 0.15 + 0.35 + (Y + 0.3) * 1.5, wrap=1.0, amb=0.3)
    vase = polygon(P, bezier([(-0.06, -0.33), (-0.1, -0.24), (-0.1, -0.16), (-0.055, -0.12), (-0.04, -0.1),
                              (-0.07, -0.08), (-0.075, -0.07)])
                   + bezier([(0.075, -0.07), (0.07, -0.08), (0.04, -0.1), (0.055, -0.12), (0.1, -0.16), (0.1, -0.24),
                             (0.06, -0.33)]))
    fig.add(vase, ["#070604", "#1a150c", "#3e3018", "#705828", "#b09050"], base=0.04, round_=0.07, gloss=0.8)
    rng = np.random.default_rng(163)
    LEAF = ["#020401", "#0a1406", "#182a0e", "#2e4a1a", "#5a7430"]
    for k in range(16):
        a = rng.uniform(-2.6, -0.5)
        lx, ly = rng.uniform(-0.2, 0.2), rng.uniform(-0.08, 0.3)
        fig.add(ellipse(P, lx, ly, 0.05, 0.014, rot=a), LEAF, base=0.05, round_=0.012,
                bump=np.abs(-(X - lx) * math.sin(a) + (Y - ly) * math.cos(a)) * -0.08)
    blooms = []
    for k in range(22):
        ang = rng.uniform(0, math.tau)
        rad = math.sqrt(rng.uniform(0, 1))
        bx, by = rad * 0.19 * math.cos(ang), 0.12 + rad * 0.2 * math.sin(ang)
        blooms.append((by, bx, ["rose", "rose", "tulip", "rose", "lily", "peony"][k % 6], k))
    blooms.sort()
    for by, bx, kind, k in blooms[::-1]:
        base = 0.08 + (0.35 - by) * 0.05
        if kind in ("rose", "peony"):
            rr = 0.04 if kind == "rose" else 0.05
            ang = np.arctan2(Y - by, X - bx)
            r = np.hypot(X - bx, Y - by)
            petals = np.sin(r * 200 + ang * 3) * 0.003
            stops = (["#1a0206", "#5a0a18", "#a0203a", "#dc6070", "#f8c0c0"] if k % 2 else
                     ["#2a1a14", "#7a5448", "#c8948a", "#f0d0c4", "#fff4ee"])
            fig.add(ellipse(P, bx, by, rr, rr * 0.9), stops, base=base, round_=rr, bump=petals, gloss=0.3)
        elif kind == "tulip":
            d = polygon(P, bezier([(bx - 0.028, by + 0.03), (bx - 0.034, by - 0.02), (bx - 0.01, by - 0.035),
                                   (bx, by - 0.035)]) + bezier([(bx, by - 0.035), (bx + 0.01, by - 0.035),
                                                               (bx + 0.034, by - 0.02), (bx + 0.028, by + 0.03)])
                        + [(bx + 0.012, by + 0.014), (bx, by + 0.034), (bx - 0.012, by + 0.014)])
            flame = (np.sin((X - bx) * 260) > 0.3) & (Y > by - 0.01)
            fig.add(d, ["#2a0602", "#7a1c08", "#c84a18", "#f0a040", "#fce8a8"], base=base, round_=0.025,
                    subs=[(flame, ["#3a0404", "#8a1010", "#c83020", "#f06050", "#fcc0a0"])])
        else:
            for j in range(6):
                a = j * math.pi / 3 + 0.3 + k
                d = ellipse(P, bx + math.cos(a) * 0.03, by + math.sin(a) * 0.03, 0.036, 0.012, rot=a)
                fig.add(d, ["#2a2a20", "#7a786a", "#c8c4b4", "#f4f0e4", "#ffffff"], base=base + 0.004, round_=0.01)
            fig.add(ellipse(P, bx, by, 0.009, 0.009), ["#4a2a04", "#c88a1a", "#f0c040"], base=base + 0.01,
                    round_=0.006)
    fig.add(ellipse(P, 0.16, -0.36, 0.03, 0.014, rot=0.3), ["#2a0206", "#8a1428", "#d8505e", "#f8b0b0"], base=0.01,
            round_=0.008)
    for s in (-1, 1):
        fig.add(ellipse(P, -0.2 + s * 0.013, -0.38, 0.014, 0.009, rot=s * 0.5), ["#3a3830", "#b0ac9c", "#f4f0e2"],
                base=0.012, round_=0.004)
    fig.render(shadow_len=0.07)


PAINTINGS = {"aristocrat": p_aristocrat, "lady_fan": p_lady_fan, "general": p_general, "child_dog": p_child_dog,
             "bishop": p_bishop, "merchant": p_merchant, "landscape": p_landscape, "seascape": p_seascape,
             "still_life": p_still_life, "flowers": p_flowers}


# --------------------------------------------------------------------------
# finishing: palette, dither, age, maps
# --------------------------------------------------------------------------

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47


def palette_of(img, k=40, iters=12):
    """Deterministic k-means in sRGB: the painting's own limited palette."""
    px = img.reshape(-1, 3)
    lum = px @ np.array([0.3, 0.55, 0.15])
    order = np.argsort(lum, kind="stable")
    cent = px[order[np.linspace(0, len(order) - 1, k).astype(np.int64)]].copy()
    sub = px[:: max(1, len(px) // 24000)]
    for _ in range(iters):
        lab = np.argmin(((sub[:, None, :] - cent[None]) ** 2).sum(-1), axis=1)
        for c in range(k):
            m = lab == c
            if m.any():
                cent[c] = sub[m].mean(0)
    return cent


def quantize(img, pal, dither=0.04):
    H, W, _ = img.shape
    b = np.tile(BAYER4, (H // 4 + 1, W // 4 + 1))[:H, :W]
    v = img + b[..., None] * dither
    d = ((v.reshape(-1, 1, 3) - pal[None]) ** 2).sum(-1)
    return pal[np.argmin(d, axis=1)].reshape(H, W, 3)


def age(P, seed=0):
    """Varnish and time: warm yellowing, darker corners, fine sparse
    craquelure (mostly felt in the normal map)."""
    X, Y = P.X, P.Y
    img = P.img * np.array([1.0, 0.965, 0.87]) + np.array([0.012, 0.008, 0.0])
    vig = np.clip(1.0 - ((X / (CANVAS_W * 0.6)) ** 2 + (Y / (CANVAS_H * 0.6)) ** 2) * 0.4, 0.7, 1.0)
    # lift: gallery lamps are dim at night, the pictures must still read
    img = 1.0 - (1.0 - np.clip(img * 1.12, 0, 1)) ** 1.12
    P.img = np.clip(img * vig[..., None], 0, 1)
    p = np.stack([X.ravel() * 55.0, Y.ravel() * 42.0, np.zeros(X.size)], axis=1)
    f1, f2, _ = noise.worley(p, P.seed * 7 + 31 + seed)
    edge = (f2 - f1).reshape(X.shape) < 0.045
    crack = edge & (P.fbm(2.5, 33 + seed, 3) > 0.22)
    P.img[crack] *= 0.86
    P.hgt = P.hgt - crack * 0.0005
    return crack


def weave(P):
    H, W = P.X.shape
    yy, xx = np.mgrid[0:H, 0:W]
    return ((xx + yy) % 2) * 0.00008


def paint(name, seed=0):
    """-> {"albedo", "normal", "orm"} for painting ``name`` (see ALL)."""
    P = Painter(seed=seed + ALL.index(name) * 17 + 1)
    portrait = name in PORTRAITS
    if portrait:
        P.Y = P.Y - FIG_OY
    PAINTINGS[name](P)
    if portrait:
        P.Y = P.Y + FIG_OY
    crack = age(P, seed)
    pal = palette_of(P.img, 40)
    albedo = quantize(P.img, pal)
    lum = albedo @ np.array([0.3, 0.55, 0.15])
    height = P.hgt + weave(P) + lum * 0.0004
    normal = normal_from_height(height, P.px, 1.2)
    rough = np.clip(0.36 + P.fbm(6.0, 41, 2) * 0.06 + crack * 0.25, 0.05, 1.0)
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], axis=-1)
    return {"albedo": albedo, "normal": normal, "orm": orm}


def eye_texture():
    """The portraits' movable eye: flat sclera (sliding the UVs moves only
    the iris) with the iris, pupil and catchlight at the centre, the same
    colours and density as the painted eyes. The eye quads show the middle
    EYE_W x EYE_H; the game slides it with the material's uv1_offset."""
    P = Painter(EYE_TEX_W, EYE_TEX_H, PPM, seed=3)
    P.put(np.ones(P.X.shape, bool), ramp(["#8a7a68", "#b4a690", "#ccc0aa"], 0.55 + P.fbm(200, 1, 1) * 0.05))
    r = np.hypot(P.X, P.Y)
    P.put(r < 0.0062, ramp(["#2a1a10", "#6b4a2a"], 0.3 - P.Y * 60))
    P.put(r < 0.0027, hexcol("#0c0806"))
    P.put((np.abs(P.X + 0.0022) < P.px * 0.6) & (np.abs(P.Y - 0.0022) < P.px * 0.6), hexcol("#f0e8da"))
    img = P.img * np.array([1.0, 0.965, 0.87]) + np.array([0.012, 0.008, 0.0])
    shape = img.shape[:2]
    normal = normal_from_height(np.zeros(shape), P.px, 1.0)
    orm = np.stack([np.ones(shape), np.full(shape, 0.25), np.zeros(shape)], axis=-1)
    return {"albedo": np.clip(img, 0, 1), "normal": normal, "orm": orm}


def contact_sheet(imgs, names, scale=2, pad=8, cols=5):
    rows = (len(names) + cols - 1) // cols
    h, w = imgs[names[0]].shape[:2]
    sheet = np.full((rows * (h * scale + pad) + pad, cols * (w * scale + pad) + pad, 3), 0.1)
    for i, n in enumerate(names):
        r, c = divmod(i, cols)
        big = np.repeat(np.repeat(imgs[n], scale, 0), scale, 1)
        y0, x0 = pad + r * (h * scale + pad), pad + c * (w * scale + pad)
        sheet[y0:y0 + big.shape[0], x0:x0 + big.shape[1]] = big
    return sheet
