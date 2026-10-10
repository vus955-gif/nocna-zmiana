"""Assyrian relief figures drawn on an artlib.asy_relief.Relief.

Conventions of the originals, kept on purpose because they are what makes
the reliefs read as Assyrian at a glance:
  * heads in profile with a FRONTAL almond eye under a heavy brow;
  * long squared beards in tiers: rows of snail curls on the cheeks, wavy
    strands, a fringe of curls at the bottom; hair gathered at the nape in
    curls (black paint traces);
  * torsos shown broad, legs in profile, striding; calves as a double
    muscle bulge with incised lines, shins knife-straight;
  * hems and shawls edged with fringes and tassels; bracelets with rosettes.

Every figure is drawn in its own coordinates (metres, x forward = the way it
faces, y up from the ground line) through an ``Xf`` (position, scale,
facing). Shapes go into named PARTS (``names`` maps a figure's part to the
relief part; panels put everything into "main", the flat enemies keep the
parts apart). Heights ``z`` are metres above the slab's background.
"""
import math

import numpy as np

from . import asy_relief as rl
from .asy_relief import HAIR, PUPIL, RED, STONE, EYE, Xf, bezier, strip


class Pen:
    """Draws one figure: local coordinates through ``xf`` onto relief ``R``,
    parts renamed by ``names`` (missing names -> ``default``), heights
    scaled by ``depth`` (1 = enemy-size carving)."""

    def __init__(self, R, xf, names=None, default="main", depth=1.0):
        self.R, self.xf = R, xf
        self.names = names or {}
        self.default = default
        self.depth = depth

    def part(self, name):
        return self.names.get(name, self.default if self.default is not None else name)

    def at(self, xf):
        p = Pen(self.R, xf, self.names, self.default, self.depth)
        return p

    # --- shapes in local coordinates (signed distance in relief metres) ---
    def poly(self, pts, xf=None):
        xf = xf or self.xf
        return self.R.poly(xf.pts(pts))

    def ell(self, c, rx, ry, ang=0.0, xf=None):
        xf = xf or self.xf
        return self.R.ellipse(xf.pt(c), xf.len(rx), xf.len(ry), xf.ang(ang))

    def circ(self, c, r, xf=None):
        xf = xf or self.xf
        return self.R.circle(xf.pt(c), xf.len(r))

    def limb(self, a, b, ra, rb, xf=None):
        xf = xf or self.xf
        return self.R.capsule(xf.pt(a), xf.pt(b), xf.len(ra), xf.len(rb))

    def line(self, pts, xf=None):
        xf = xf or self.xf
        return self.R.polyline(xf.pts(pts))

    def stroke(self, pts, w0, w1=None, xf=None):
        return self.poly(strip(pts, w0, w1), xf)

    # --- carving -----------------------------------------------------------
    def put(self, d, z, part, mat=STONE, r=None):
        return self.R.put(d, z * self.depth, self.part(part), mat, r=self.xf.len(r) if r else None)

    def paint(self, d, mat, part):
        return self.R.paint(d, mat, self.part(part))

    def sink(self, d, depth, part):
        return self.R.sink(d, depth * self.depth, self.part(part))

    def cut(self, pts_or_d, part, w=None, depth=0.003, mat=None, xf=None):
        d = self.line(pts_or_d, xf) if isinstance(pts_or_d, list) else pts_or_d
        w = w if w is not None else self.R.px * 1.0
        return self.R.cut(d, w, depth * self.depth, self.part(part), mat)

    def bump(self, c, r, z, part, mat=None, xf=None):
        xf = xf or self.xf
        return self.R.bump(xf.pt(c), xf.len(r), z * self.depth, self.part(part), mat)

    def curls(self, region, spacing, r, z, part, mat=HAIR, xf=None, rows_only=None, ring=True):
        """Staggered rows of snail curls (small domes with a dark centre)
        filling the local polygon ``region``."""
        xf = xf or self.xf
        # never smaller than ~2.4 texels across: tiny curls only make noise
        k = max(1.0, 2.4 * self.R.px / xf.len(r))
        spacing, r = spacing * k, r * k
        xs = [p[0] for p in region]
        ys = [p[1] for p in region]
        inside = self.R.poly(xf.pts(region)) < 0
        k = 0
        y = max(ys) - spacing * 0.5
        while y > min(ys):
            x = min(xs) + (spacing * 0.5 if k % 2 else 0.0)
            while x < max(xs) + spacing:
                gx, gy = xf.pt((x, y))
                row, col = self.R.index(gx, gy)
                if inside[row, col]:
                    self.bump((x, y), r, z, part, mat, xf)
                    if ring and xf.len(r) > self.R.px * 1.6:
                        c = xf.pt((x, y))
                        dd = np.abs(np.hypot(self.R.X - c[0], self.R.Y - c[1]) - xf.len(r) * 0.45)
                        self.R.cut(dd, self.R.px * 0.8, 0.0012 * self.depth, self.part(part))
                x += spacing
            y -= spacing * 0.86
            k += 1

    def strands(self, top, bottom, x0, x1, n, part, wave=0.006, depth=0.0025, xf=None):
        """Vertical wavy strands (beards, hair falls) from y=top to y=bottom
        between x0 and x1."""
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            pts = []
            steps = 10
            for k in range(steps + 1):
                t = k / steps
                y = top + (bottom - top) * t
                pts.append((x + wave * math.sin(t * math.pi * 3.0 + i * 1.7), y))
            self.cut(pts, part, depth=depth, xf=xf)


# --------------------------------------------------------------------------
# heads
# --------------------------------------------------------------------------

def head(pen, c, part, z, kind="helmet", s=1.0, beard=True):
    """A profile head with a frontal eye. ``c`` = centre of the skull in the
    figure's coordinates, ``s`` = head scale (1 = a 1.9 m man). kinds:
    helmet (pointed soldier's helmet with a cheek flap), genie (horned cap),
    diadem (rosette band and ribbons), king (tall royal fez), bare
    (headband)."""
    hp = pen.at(_scaled(pen.xf, c, s))
    zf = z
    # skull and face: a straight nose continuing the brow, full cheek
    prof = [(0.03, 0.105), (0.08, 0.075), (0.104, 0.042), (0.112, 0.024), (0.122, 0.006), (0.152, -0.03),
            (0.158, -0.042), (0.15, -0.05), (0.136, -0.053), (0.132, -0.06), (0.12, -0.075), (0.02, -0.11)]
    face = rl.union(hp.ell((0.0, 0.0), 0.1, 0.112), hp.poly(prof))
    hp.put(face, zf, part, r=0.014)
    # ear
    hp.put(hp.ell((-0.022, -0.005), 0.019, 0.032), zf + 0.003, part, r=0.006)
    hp.cut([(-0.028, 0.014), (-0.034, -0.004), (-0.024, -0.024)], part, depth=0.002)
    # eye: frontal almond, white with a black pupil, incised lids, heavy brow
    e = EYE_AT
    almond = hp.poly([(e[0] - 0.028, e[1]), (e[0] - 0.012, e[1] + 0.011), (e[0] + 0.012, e[1] + 0.011),
                      (e[0] + 0.03, e[1] + 0.001), (e[0] + 0.012, e[1] - 0.01), (e[0] - 0.012, e[1] - 0.01)])
    hp.put(almond, zf + 0.001, part, mat=EYE, r=0.004)
    hp.paint(hp.circ((e[0] + 0.003, e[1] + 0.0005), 0.008), PUPIL, part)
    lid = hp.line([(e[0] - 0.03, e[1]), (e[0] - 0.012, e[1] + 0.012), (e[0] + 0.013, e[1] + 0.012),
                   (e[0] + 0.033, e[1] + 0.0), (e[0] + 0.012, e[1] - 0.011), (e[0] - 0.012, e[1] - 0.011),
                   (e[0] - 0.03, e[1])])
    hp.cut(lid, part, w=pen.R.px * 1.1, depth=0.002, mat=PUPIL)
    brow = hp.stroke([(e[0] - 0.036, e[1] + 0.02), (e[0] - 0.006, e[1] + 0.032), (e[0] + 0.034, e[1] + 0.027)],
                     0.013, 0.008)
    hp.put(brow, zf + 0.004, part, mat=HAIR, r=0.004)
    for k in range(5):
        x = e[0] - 0.03 + k * 0.014
        hp.cut([(x, e[1] + 0.02 + k * 0.002), (x + 0.008, e[1] + 0.03)], part, depth=0.0012)
    # nostril, the line of the cheek
    hp.cut([(0.128, -0.036), (0.142, -0.044)], part, depth=0.002)
    hp.cut([(0.112, -0.004), (0.098, -0.03)], part, depth=0.0012)
    if kind == "helmet":
        hair_back = [(-0.07, 0.03), (-0.106, 0.0), (-0.108, -0.1), (-0.096, -0.19), (-0.03, -0.2), (-0.035, -0.06),
                     (-0.03, 0.03)]
        hp.put(hp.poly(hair_back), zf + 0.003, part, mat=HAIR, r=0.008)
        hp.strands(0.02, -0.1, -0.1, -0.04, 3, part, wave=0.004)
        hp.curls([(-0.108, -0.1), (-0.03, -0.1), (-0.03, -0.2), (-0.1, -0.2)], 0.027, 0.0125, 0.005, part)
        cone = bezier([(0.104, 0.04), (0.09, 0.14), (0.05, 0.23), (0.012, 0.305)], 8) + \
            bezier([(-0.004, 0.305), (-0.04, 0.22), (-0.075, 0.13), (-0.1, 0.04)], 8)
        helmet = hp.poly(cone)
        hp.put(helmet, zf + 0.006, part, r=0.012)
        band = hp.poly([(-0.106, 0.03), (0.11, 0.03), (0.105, 0.075), (-0.095, 0.075)])
        hp.put(band, zf + 0.009, part, r=0.004)
        hp.cut([(-0.1, 0.075), (0.104, 0.075)], part, depth=0.002)
        for k in range(4):
            hp.bump((-0.07 + k * 0.05, 0.052), 0.008, 0.002, part)
        hp.cut([(0.006, 0.3), (0.0, 0.08)], part, depth=0.0015)            # the seam up the cone
        hp.put(hp.ell((0.004, 0.305), 0.012, 0.01), zf + 0.01, part, r=0.003)
        flap = hp.poly([(-0.066, 0.034), (-0.008, 0.034), (-0.002, -0.02), (-0.02, -0.05), (-0.058, -0.048),
                        (-0.072, -0.01)])
        hp.put(flap, zf + 0.008, part, r=0.006)
        hp.bump((-0.035, -0.012), 0.007, 0.002, part)
    elif kind in ("genie", "diadem", "bare", "king"):
        hair_back = [(-0.04, 0.1), (-0.1, 0.05), (-0.118, -0.08), (-0.11, -0.25), (-0.02, -0.26), (-0.03, -0.06)]
        hp.put(hp.poly(hair_back), zf + 0.002, part, mat=HAIR, r=0.008)
        hp.put(hp.poly([(-0.02, 0.108), (0.075, 0.072), (0.098, 0.05), (0.06, 0.044), (-0.03, 0.05)]),
               zf + 0.002, part, mat=HAIR, r=0.006)
        hp.strands(0.09, -0.12, -0.105, -0.035, 4, part, wave=0.004)
        hp.curls([(-0.12, -0.13), (-0.02, -0.13), (-0.02, -0.26), (-0.12, -0.26)], 0.027, 0.0125, 0.005, part)
        if kind == "genie":
            cap = hp.poly([(-0.088, 0.065), (0.092, 0.065), (0.078, 0.2), (-0.072, 0.2)])
            hp.put(cap, zf + 0.004, part, r=0.008)
            hp.put(hp.poly([(-0.092, 0.2), (0.088, 0.2), (0.072, 0.226), (-0.076, 0.226)]), zf + 0.006, part, r=0.004)
            for k in range(2):
                y0 = 0.085 + k * 0.055
                horn = bezier([(-0.078, y0), (0.0, y0 + 0.04), (0.06, y0 + 0.032), (0.098, y0 - 0.004)], 8)
                hp.put(hp.stroke(horn, 0.024, 0.008), zf + 0.008, part, r=0.005)
                hp.cut(horn, part, depth=0.0012)
            hp.bump((0.0, 0.238), 0.016, 0.006, part)
        elif kind == "diadem":
            band = hp.poly([(-0.1, 0.055), (0.095, 0.045), (0.098, 0.077), (-0.098, 0.09)])
            hp.put(band, zf + 0.005, part, mat=RED, r=0.004)
            for k in range(4):
                x = -0.07 + k * 0.05
                hp.bump((x, 0.069 - k * 0.002), 0.012, 0.003, part)
                hp.cut(np.abs(hp.circ((x, 0.069 - k * 0.002), 0.006)), part, depth=0.001)
            ribbon = hp.poly([(-0.1, 0.06), (-0.112, 0.072), (-0.2, -0.22), (-0.17, -0.23)])
            hp.put(ribbon, zf + 0.003, part, mat=RED, r=0.004)
            hp.cut([(-0.12, 0.05), (-0.185, -0.22)], part, depth=0.0012)
        elif kind == "king":
            fez = hp.poly([(-0.095, 0.06), (0.095, 0.06), (0.08, 0.25), (-0.08, 0.25)])
            hp.put(fez, zf + 0.004, part, r=0.008)
            hp.put(hp.poly([(-0.03, 0.25), (0.03, 0.25), (0.01, 0.3), (-0.01, 0.3)]), zf + 0.006, part, r=0.004)
            for y in (0.09, 0.13, 0.17, 0.21):
                hp.cut([(-0.09, y), (0.09, y)], part, depth=0.0015)
            for k in range(6):
                hp.bump((-0.075 + k * 0.03, 0.15), 0.007, 0.002, part)
            band = hp.poly([(-0.1, 0.05), (0.1, 0.05), (0.1, 0.075), (-0.1, 0.075)])
            hp.put(band, zf + 0.006, part, mat=RED, r=0.004)
            ribbon = hp.poly([(-0.095, 0.06), (-0.11, 0.07), (-0.2, -0.28), (-0.17, -0.29)])
            hp.put(ribbon, zf + 0.003, part, mat=RED, r=0.004)
        else:
            band = hp.poly([(-0.1, 0.055), (0.095, 0.045), (0.098, 0.07), (-0.098, 0.08)])
            hp.put(band, zf + 0.004, part, mat=RED, r=0.004)
        # earring under the hair
        hp.put(hp.ell((-0.02, -0.062), 0.008, 0.017), zf + 0.006, part, r=0.003)
    if beard:
        bd = [(0.133, -0.062), (0.134, -0.21), (0.124, -0.235), (0.0, -0.24), (-0.026, -0.22), (-0.03, -0.04),
              (0.0, -0.035), (0.04, -0.05), (0.09, -0.06), (0.11, -0.068)]
        hp.put(hp.poly(bd), zf + 0.006, part, mat=HAIR, r=0.01)
        # moustache over the beard, ending in a curl
        must = bezier([(0.14, -0.056), (0.115, -0.068), (0.085, -0.066), (0.068, -0.072)], 6)
        hp.put(hp.stroke(must, 0.016, 0.009), zf + 0.01, part, mat=HAIR, r=0.004)
        hp.bump((0.064, -0.074), 0.009, 0.003, part)
        # cheek curls, wavy strands, a fringe of curls along the bottom
        hp.curls([(-0.028, -0.04), (0.11, -0.075), (0.13, -0.08), (0.132, -0.125), (-0.03, -0.125)], 0.026, 0.0115,
                 0.005, part)
        hp.strands(-0.13, -0.205, -0.02, 0.128, 6, part, wave=0.004, depth=0.003)
        hp.curls([(-0.024, -0.2), (0.132, -0.2), (0.124, -0.237), (-0.02, -0.237)], 0.025, 0.011, 0.005, part)


# the eye in head coordinates (the flat enemy's weak point sits on it)
EYE_AT = (0.074, 0.012)


def _scaled(xf, c, s):
    """A frame for drawing a sub-figure (a head) centred at local ``c`` with
    scale ``s``: local unit coordinates of the sub-figure -> relief."""
    class _Sub(Xf):
        def __init__(self):
            self.f = xf.f
            self.s = xf.s * s
            self.a = getattr(xf, "a", 0.0)

        def pt(self, p):
            return xf.pt((c[0] + p[0] * s, c[1] + p[1] * s))

        def len(self, r):
            return xf.len(r * s)

        def ang(self, a):
            return xf.ang(a)

        def rot(self, deg, about):
            return rl._Joint(self, about, math.radians(deg))

        def move(self, dx, dy):
            return rl._Joint(self, (0.0, 0.0), 0.0, (dx, dy))
    return _Sub()


# --------------------------------------------------------------------------
# limbs and dress pieces
# --------------------------------------------------------------------------

def lower_leg(pen, knee, ankle, part, z, r_knee=0.055, r_calf=0.075, r_ankle=0.035, boot=True):
    """Shin and calf in profile (the calf bulging at the back, two incised
    muscle lines), then a sandal or laced boot. Facing +x: the calf is at
    -x of the shin line."""
    kx, ky = knee
    ax, ay = ankle
    dx, dy = ax - kx, ay - ky
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux          # left of the downward direction = +x side for a vertical shin
    def at(t, off):
        return (kx + dx * t + nx * off, ky + dy * t + ny * off)
    shin = [at(0.0, r_knee * 0.9), at(0.55, r_ankle * 1.25), at(1.0, r_ankle)]
    calf = [at(1.0, -r_ankle), at(0.62, -r_calf * 0.8), at(0.35, -r_calf), at(0.12, -r_calf * 0.9),
            at(0.0, -r_knee)]
    outline = shin + calf
    d = rl.union(pen.poly(outline), pen.circ(knee, r_knee))
    pen.put(d, z, part, r=0.012)
    pen.cut([at(0.18, -r_calf * 0.7), at(0.42, -r_calf * 0.55), at(0.62, -r_calf * 0.2)], part, depth=0.0025)
    pen.cut([at(0.25, -r_calf * 0.25), at(0.45, -r_calf * 0.1)], part, depth=0.002)
    pen.cut([at(0.08, r_knee * 0.4), at(0.2, r_knee * 0.1)], part, depth=0.0015)     # knee cap
    # foot
    foot = pen.poly([(ax - 0.04, ay + 0.02), (ax + 0.04, ay + 0.0), (ax + 0.16, ay - 0.05), (ax + 0.18, ay - 0.075),
                     (ax + 0.18, ay - 0.088), (ax - 0.055, ay - 0.088), (ax - 0.06, ay - 0.04)])
    pen.put(foot, z, part, r=0.01)
    pen.put(pen.poly([(ax - 0.06, ay - 0.074), (ax + 0.185, ay - 0.074), (ax + 0.185, ay - 0.09),
                      (ax - 0.06, ay - 0.09)]), z + 0.002, part, r=0.003)                   # sole
    if boot:
        pen.put(pen.poly([at(0.55, r_ankle * 1.3), at(1.0, r_ankle * 1.15), (ax + 0.1, ay - 0.04),
                          (ax + 0.16, ay - 0.06), (ax + 0.16, ay - 0.074), (ax - 0.058, ay - 0.074),
                          (ax - 0.058, ay - 0.02), at(1.0, -r_ankle * 1.15), at(0.6, -r_calf * 0.75)]),
                z + 0.003, part, r=0.006)
        pen.put(pen.poly([at(0.53, r_ankle * 1.35), at(0.6, r_ankle * 1.35), at(0.63, -r_calf * 0.74),
                          at(0.56, -r_calf * 0.8)]), z + 0.005, part, mat=RED, r=0.004)
        for k in range(5):
            t = 0.62 + k * 0.08
            pen.cut([at(t, -r_calf * 0.6), at(t + 0.05, r_ankle * 1.2)], part, depth=0.0015)
        pen.cut([at(0.58, -r_calf * 0.78), at(0.56, r_ankle * 1.3)], part, depth=0.002)
    else:
        pen.put(pen.poly([(ax - 0.06, ay - 0.074), (ax - 0.06, ay - 0.02), (ax - 0.02, ay - 0.02),
                          (ax - 0.02, ay - 0.074)]), z + 0.002, part, mat=RED, r=0.003)
        pen.cut([(ax - 0.03, ay + 0.0), (ax + 0.06, ay - 0.04)], part, depth=0.0015, mat=RED)


def arm(pen, shoulder, elbow, wrist, part, z, r_sh=0.06, r_el=0.045, r_wr=0.035, bracelet=True, hand=None,
        fist=True):
    """Upper arm and forearm as tapered capsules with incised muscles, a
    rosette bracelet; ``hand`` = (x, y) of the fist (default past the
    wrist)."""
    d = rl.union(pen.limb(shoulder, elbow, r_sh, r_el), pen.limb(elbow, wrist, r_el, r_wr))
    pen.put(d, z, part, r=0.012)
    mx, my = (shoulder[0] + elbow[0]) / 2, (shoulder[1] + elbow[1]) / 2
    ex, ey = elbow[0] - shoulder[0], elbow[1] - shoulder[1]
    L = math.hypot(ex, ey) or 1.0
    nx, ny = -ey / L, ex / L
    pen.cut([(mx + nx * r_sh * 0.3 - ex * 0.2, my + ny * r_sh * 0.3 - ey * 0.2),
             (mx + nx * r_sh * 0.45 + ex * 0.15, my + ny * r_sh * 0.45 + ey * 0.15)], part, depth=0.002)
    fx, fy = wrist[0] - elbow[0], wrist[1] - elbow[1]
    pen.cut([(elbow[0] + fx * 0.2, elbow[1] + fy * 0.2), (elbow[0] + fx * 0.55, elbow[1] + fy * 0.55)], part,
            depth=0.0018)
    if bracelet:
        Lf = math.hypot(fx, fy) or 1.0
        bx, by = wrist[0] - fx / Lf * 0.035, wrist[1] - fy / Lf * 0.035
        band = pen.limb((bx - fx / Lf * 0.012, by - fy / Lf * 0.012), (bx + fx / Lf * 0.012, by + fy / Lf * 0.012),
                        r_wr * 1.15, r_wr * 1.15)
        pen.put(band, z + 0.004, part, r=0.004)
        pen.bump((bx, by), 0.011, 0.003, part)
    if hand is not None:
        hx, hy = hand
        if fist:
            pen.put(rl.union(pen.ell((hx, hy), 0.04, 0.034), pen.limb(wrist, (hx, hy), r_wr, 0.032)), z + 0.002, part,
                    r=0.008)
            for k in range(3):
                pen.cut([(hx + 0.01, hy + 0.024 - k * 0.016), (hx + 0.04, hy + 0.02 - k * 0.016)], part, depth=0.0015)
            pen.put(pen.ell((hx + 0.012, hy + 0.026), 0.022, 0.012, 0.4), z + 0.004, part, r=0.004)   # thumb


def shield_round(pen, c, r, part, z):
    """Round convex shield seen from the front: rim with studs, a ring, the
    boss; the profile of the curve is in the height (a shallow dome)."""
    R = pen.R
    cx, cy = pen.xf.pt(c)
    rr = pen.xf.len(r)
    d = np.hypot(R.X - cx, R.Y - cy)
    disk = d - rr
    dome = np.sqrt(np.clip(1.0 - (d / rr) ** 2, 0.0, 1.0)) * 0.012 * pen.depth
    pen.put(disk, z, part, r=0.01)
    L = R.layer(pen.part(part))
    m = disk < 0
    L.h = np.where(m, L.h + dome, L.h)
    pen.put(pen.circ(c, r * 0.24), z + 0.022, part, r=0.02)                 # boss
    rim_w = pen.xf.len(0.035)
    pen.R.cut(np.abs(d - (rr - rim_w)), R.px * 1.2, 0.003 * pen.depth, pen.part(part))
    pen.R.cut(np.abs(d - rr * 0.55), R.px * 1.0, 0.0025 * pen.depth, pen.part(part))
    pen.R.cut(np.abs(d - rr * 0.3), R.px * 1.0, 0.002 * pen.depth, pen.part(part))
    n = 16
    for k in range(n):
        a = math.tau * k / n
        pen.bump((c[0] + math.cos(a) * (r - 0.018), c[1] + math.sin(a) * (r - 0.018)), 0.011, 0.004, part)
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        pen.cut([(c[0] + math.cos(a) * r * 0.3, c[1] + math.sin(a) * r * 0.3),
                 (c[0] + math.cos(a) * r * 0.55, c[1] + math.sin(a) * r * 0.55)], part, depth=0.0015)


def spear(pen, butt, tip, part, z, r=0.014):
    """A long spear: shaft, leaf-shaped blade, butt spike."""
    bx, by = butt
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    blade0 = (tx - ux * 0.24, ty - uy * 0.24)
    pen.put(pen.limb(butt, blade0, r, r), z, part, r=0.006)
    leaf = [(blade0[0] + nx * 0.012, blade0[1] + ny * 0.012), (blade0[0] + ux * 0.08 + nx * 0.032, blade0[1] + uy * 0.08 + ny * 0.032),
            (tx, ty), (blade0[0] + ux * 0.08 - nx * 0.032, blade0[1] + uy * 0.08 - ny * 0.032),
            (blade0[0] - nx * 0.012, blade0[1] - ny * 0.012)]
    pen.put(pen.poly(leaf), z + 0.002, part, r=0.008)
    pen.cut([(blade0[0], blade0[1]), (tx - ux * 0.02, ty - uy * 0.02)], part, depth=0.0015)     # midrib
    pen.put(pen.limb((blade0[0] - ux * 0.02, blade0[1] - uy * 0.02), (blade0[0] - ux * 0.06, blade0[1] - uy * 0.06),
                     r * 1.4, r * 1.4), z + 0.003, part, r=0.004)                                 # socket
    spike = [(bx + nx * r, by + ny * r), (bx - ux * 0.08, by - uy * 0.08), (bx - nx * r, by - ny * r)]
    pen.put(pen.poly(spike), z + 0.001, part, r=0.004)


# --------------------------------------------------------------------------
# the soldier
# --------------------------------------------------------------------------

WARRIOR_PARTS = ["arm_back", "leg_back", "torso", "head", "leg_front", "shield", "spear", "arm_front"]
HEAD_C, HEAD_S = (0.03, 1.635), 1.12
# joints of the spearman in figure coordinates (1.9 m, facing +x): the flat
# enemy's pivots sit on these
WARRIOR_JOINTS = {
    "torso": (0.0, 0.98), "head": (0.035, 1.47), "arm_front": (0.04, 1.37), "arm_back": (-0.02, 1.37),
    "leg_front": (0.04, 0.95), "leg_back": (-0.05, 0.95), "spear": (0.36, 1.12), "shield": (0.19, 1.21),
}
WARRIOR_EYE = (HEAD_C[0] + EYE_AT[0] * HEAD_S, HEAD_C[1] + EYE_AT[1] * HEAD_S)


def warrior(pen, z=0.018, stride=1.0, spear_up=True, shield=True, helmet="helmet"):
    """An Assyrian spearman of the Sennacherib-Ashurbanipal reliefs: pointed
    helmet with a cheek flap, scale shirt, short fringed tunic with a broad
    belt and a sword on the hip, laced boots, a round studded shield on the
    far arm, the spear held upright in the near fist. Ground at y = 0, 1.9 m
    to the helmet tip, facing +x."""
    s = stride
    R = pen.R
    # far side first (lowest relief)
    arm(pen, (-0.02, 1.37), (0.05, 1.16), (0.16, 1.2), "arm_back", z - 0.008, hand=(0.19, 1.21))
    pen.put(pen.limb((-0.05, 0.92), (-0.12 * s, 0.55), 0.085, 0.06), z - 0.006, "leg_back", r=0.012)
    lower_leg(pen, (-0.12 * s, 0.53), (-0.22 * s, 0.11), "leg_back", z - 0.006)
    # tunic and torso
    torso = pen.poly([(0.03, 1.47), (0.12, 1.44), (0.17, 1.36), (0.175, 1.18), (0.16, 1.02), (0.185, 0.6),
                      (0.0, 0.57), (-0.21, 0.6), (-0.175, 1.0), (-0.2, 1.22), (-0.17, 1.4), (-0.06, 1.47)])
    pen.put(torso, z, "torso", r=0.014)
    # scale shirt down to the belt
    shirt = pen.poly([(0.02, 1.45), (0.16, 1.37), (0.17, 1.08), (-0.18, 1.08), (-0.18, 1.4), (-0.05, 1.46)])
    shirt_m = shirt < 0
    arcs = np.full(R.shape, np.inf)
    for row in range(10):
        y = 1.42 - row * 0.034
        off = 0.0 if row % 2 else 0.018
        for k in range(12):
            x = -0.2 + off + k * 0.036
            c = pen.xf.pt((x, y))
            ri, ci = R.index(*c)
            if shirt_m[ri, ci]:
                arc = np.abs(np.hypot(R.X - c[0], R.Y - c[1] + pen.xf.len(0.012)) - pen.xf.len(0.02))
                arcs = np.minimum(arcs, np.where(R.Y < c[1] - pen.xf.len(0.012), arc, np.inf))
    R.cut(np.where(shirt_m, arcs, np.inf), R.px * 1.0, 0.002 * pen.depth, pen.part("torso"))
    pen.cut([(0.17, 1.08), (-0.18, 1.08)], "torso", depth=0.002)
    # belt and the fringed hem of the tunic
    belt = pen.poly([(-0.185, 0.98), (0.175, 0.98), (0.178, 1.09), (-0.19, 1.09)])
    pen.put(belt, z + 0.004, "torso", mat=RED, r=0.006)
    for y in (1.0, 1.035, 1.07):
        pen.cut([(-0.19, y), (0.18, y)], "torso", depth=0.0015)
    pen.cut([(0.16, 0.98), (0.185, 0.6)], "torso", depth=0.002)          # front edge of the wrap
    hem = pen.poly([(-0.215, 0.6), (0.19, 0.6), (0.192, 0.565), (-0.22, 0.565)])
    pen.put(hem, z + 0.002, "torso", r=0.004)
    for k in range(20):
        x = -0.21 + k * 0.021
        pen.cut([(x, 0.6), (x + 0.002, 0.565)], "torso", depth=0.0018)
    pen.cut([(0.0, 0.97), (-0.02, 0.62)], "torso", depth=0.0012)          # folds
    pen.cut([(0.08, 0.97), (0.09, 0.62)], "torso", depth=0.0012)
    # sword in its scabbard, slung at the back hip, with a lion-headed chape
    sc = [(-0.12, 1.02), (-0.36, 0.78)]
    pen.put(pen.stroke(sc, 0.045, 0.036), z + 0.006, "torso", r=0.006)
    pen.put(pen.circ((-0.36, 0.78), 0.03), z + 0.008, "torso", r=0.006)
    pen.put(pen.stroke([(-0.08, 1.06), (-0.12, 1.02)], 0.06, 0.06), z + 0.009, "torso", r=0.004)
    pen.cut([(-0.16, 0.98), (-0.33, 0.81)], "torso", depth=0.0015)
    # near leg
    pen.put(pen.limb((0.04, 0.92), (0.12 * s, 0.55), 0.085, 0.06), z + 0.002, "leg_front", r=0.012)
    lower_leg(pen, (0.12 * s, 0.53), (0.2 * s, 0.11), "leg_front", z + 0.002)
    # head on its neck
    pen.put(pen.limb((0.02, 1.46), (0.05, 1.56), 0.052, 0.052), z, "head", r=0.01)
    head(pen, HEAD_C, "head", z + 0.002, kind=helmet, s=HEAD_S)
    # shield (far arm), spear and the near arm in front of both
    if shield:
        shield_round(pen, (0.2, 1.15), 0.29, "shield", z + 0.006)
    if spear_up:
        spear(pen, (0.39, 0.1), (0.35, 2.2), "spear", z + 0.022)
    arm(pen, (0.04, 1.37), (0.1, 1.13), (0.31, 1.1), "arm_front", z + 0.026, hand=(0.36, 1.12))
    # the shoulder of the near arm sits on the torso
    pen.put(pen.ell((0.03, 1.36), 0.075, 0.06), z + 0.024, "arm_front", r=0.012)
    pen.cut([(-0.03, 1.31), (0.01, 1.29), (0.08, 1.31)], "arm_front", depth=0.0015)


# --------------------------------------------------------------------------
# wings, fringes, small things
# --------------------------------------------------------------------------

def wing(pen, outline, root, tip, part, z, covert=0.38, feather=0.05, scale=0.045):
    """A wing in the Assyrian manner: the outline (local polygon) raised to
    ``z``; from the root to ``covert`` of the way along the axis root -> tip
    rows of scale-like coverts, then long flight feathers as parallel
    grooves along the axis."""
    R = pen.R
    d = pen.poly(outline)
    inside = pen.put(d, z, part, r=0.014)
    A = np.array(pen.xf.pt(root))
    B = np.array(pen.xf.pt(tip))
    ax = B - A
    L = float(np.linalg.norm(ax))
    u = ax / L
    n = np.array([-u[1], u[0]])
    a = (R.X - A[0]) * u[0] + (R.Y - A[1]) * u[1]
    c = (R.X - A[0]) * n[0] + (R.Y - A[1]) * n[1]
    t = a / L
    wf = pen.xf.len(feather)
    line = np.abs(np.mod(c / wf + 0.5, 1.0) - 0.5) * wf
    fz = inside & (t > covert)
    R.cut(np.where(fz, line, np.inf), R.px * 1.1, 0.0035 * pen.depth, pen.part(part))
    # the shafts down the middle of each feather (fainter)
    shaft = np.abs(np.mod(c / wf, 1.0) - 0.5) * wf
    R.cut(np.where(fz & (t > covert + 0.08), shaft, np.inf), R.px * 0.7, 0.0012 * pen.depth, pen.part(part))
    # the edge between coverts and flight feathers
    R.cut(np.where(inside, np.abs(t - covert) * L, np.inf), R.px * 1.2, 0.004 * pen.depth, pen.part(part))
    # coverts: rows of scales opening toward the root
    sa = pen.xf.len(scale)
    sc = pen.xf.len(scale * 1.15)
    ai = np.floor(a / sa)
    off = np.mod(ai, 2) * 0.5
    ci = np.floor(c / sc + off)
    fa = a - ai * sa
    fc = c - (ci - off) * sc
    arc = np.abs(np.hypot(fa - sa, fc - sc * 0.5) - sa * 0.9)
    cz = inside & (t < covert) & (t > 0.02)
    R.cut(np.where(cz & (fa < sa * 0.95), arc, np.inf), R.px * 1.0, 0.0025 * pen.depth, pen.part(part))
    return inside


def fringe(pen, a, b, part, length=0.04, pitch=0.014, depth=0.0018):
    """A row of tassels hanging from the edge a -> b (local): short grooves
    perpendicular to the edge."""
    ax, ay = a
    bx, by = b
    L = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / L, (by - ay) / L
    nx, ny = uy, -ux
    k = int(L / pitch)
    for i in range(k + 1):
        x, y = ax + ux * i * pitch, ay + uy * i * pitch
        pen.cut([(x, y), (x + nx * length, y + ny * length)], part, depth=depth)


def rosette(pen, c, r, part, z, petals=8):
    """A carved rosette: a raised disc, petals as grooves, a centre boss."""
    pen.put(pen.circ(c, r), z, part, r=0.004)
    for k in range(petals):
        a = math.tau * k / petals
        pen.cut([(c[0] + math.cos(a) * r * 0.3, c[1] + math.sin(a) * r * 0.3),
                 (c[0] + math.cos(a) * r * 0.95, c[1] + math.sin(a) * r * 0.95)], part, depth=0.0015)
    pen.bump(c, r * 0.3, 0.002, part)


def cone_fruit(pen, c, part, z, s=1.0):
    """The 'purifier' (mullilu) held up by genies: a pine-cone with
    cross-hatched scales."""
    pts = [(c[0] - 0.02 * s, c[1] - 0.06 * s), (c[0] + 0.02 * s, c[1] - 0.06 * s), (c[0] + 0.035 * s, c[1] + 0.02 * s),
           (c[0], c[1] + 0.075 * s), (c[0] - 0.035 * s, c[1] + 0.02 * s)]
    pen.put(pen.poly(pts), z, part, r=0.008)
    R = pen.R
    cx, cy = pen.xf.pt(c)
    m = pen.poly(pts) < 0
    h1 = np.abs(np.mod((R.X - cx + R.Y - cy) / pen.xf.len(0.016), 1.0) - 0.5)
    h2 = np.abs(np.mod((R.X - cx - (R.Y - cy)) / pen.xf.len(0.016), 1.0) - 0.5)
    R.cut(np.where(m, np.minimum(h1, h2) * pen.xf.len(0.016), np.inf), R.px * 0.9, 0.002 * pen.depth, pen.part(part))


def bucket(pen, c, part, z, s=1.0):
    """The genie's small bucket (banduddu): flared body with bands, a loop
    handle (c = where the hand grips the handle)."""
    x, y = c
    body = [(x - 0.06 * s, y - 0.07 * s), (x + 0.06 * s, y - 0.07 * s), (x + 0.07 * s, y - 0.2 * s),
            (x - 0.07 * s, y - 0.2 * s)]
    pen.put(pen.poly(body), z, part, r=0.008)
    pen.put(pen.stroke(bezier([(x - 0.058 * s, y - 0.07 * s), (x - 0.05 * s, y + 0.02 * s),
                               (x + 0.05 * s, y + 0.02 * s), (x + 0.058 * s, y - 0.07 * s)], 8), 0.012 * s),
            z - 0.002, part, r=0.004)
    for k, yy in enumerate((0.09, 0.12, 0.17)):
        pen.cut([(x - 0.07 * s, y - yy * s), (x + 0.07 * s, y - yy * s)], part, depth=0.0018)
    for k in range(4):
        xx = x - 0.045 * s + k * 0.03 * s
        pen.cut([(xx, y - 0.125 * s), (xx + 0.008 * s, y - 0.165 * s)], part, depth=0.0012)


# --------------------------------------------------------------------------
# the winged genie (apkallu) of Ashurnasirpal's palace
# --------------------------------------------------------------------------

def _scallop(pts_a, pts_b, n):
    """The trailing edge of a wing from a to b with ``n`` feather tips."""
    out = []
    for k in range(n):
        t0, t1 = k / n, (k + 1) / n
        a = (pts_a[0] + (pts_b[0] - pts_a[0]) * t0, pts_a[1] + (pts_b[1] - pts_a[1]) * t0)
        b = (pts_a[0] + (pts_b[0] - pts_a[0]) * t1, pts_a[1] + (pts_b[1] - pts_a[1]) * t1)
        out.append(a)
        dx, dy = b[0] - a[0], b[1] - a[1]
        out.append((a[0] + dx * 0.5 + dy * 0.35, a[1] + dy * 0.5 - dx * 0.35))
    out.append(pts_b)
    return out


def genie(pen, z=0.016, headgear="genie", wings=True):
    """A human-headed winged genie striding to the right: two pairs of wings
    (one rising behind the head, one sweeping down behind the legs), a long
    robe with a fringed shawl wound diagonally, the far hand raising the
    cone, the near hand holding the bucket at the hip; bracelets, armlets,
    daggers in the sash, sandals. Man-scale coordinates (1.9 m to the top
    of the cap): panels draw it at ~1.25 x."""
    if wings:
        up = [(-0.06, 1.44), (-0.12, 1.6), (-0.24, 1.82), (-0.38, 2.02), (-0.52, 2.14), (-0.64, 2.2)] + \
            _scallop((-0.68, 2.14), (-0.3, 1.32), 9)[0:-1] + [(-0.16, 1.3)]
        wing(pen, up, (-0.14, 1.38), (-0.62, 2.16), "wing_up", z - 0.006, covert=0.34, feather=0.055)
        lo = [(-0.08, 1.36), (-0.3, 1.34), (-0.48, 1.2), (-0.6, 0.98), (-0.68, 0.72), (-0.68, 0.6)] + \
            _scallop((-0.62, 0.6), (-0.14, 1.12), 8)[1:]
        wing(pen, lo, (-0.14, 1.28), (-0.66, 0.64), "wing_lo", z - 0.008, covert=0.3, feather=0.055)
    # the far arm raises the cone forward
    arm(pen, (0.0, 1.38), (0.2, 1.3), (0.32, 1.47), "arm_back", z - 0.004, hand=(0.35, 1.5))
    cone_fruit(pen, (0.36, 1.6), "arm_back", z - 0.006, s=1.5)
    # back foot under the hem
    pen.put(pen.poly([(-0.32, 0.12), (-0.18, 0.12), (-0.08, 0.05), (-0.06, 0.0), (-0.34, 0.0), (-0.34, 0.06)]),
            z - 0.004, "robe", r=0.008)
    # robe: long, the front edge open from the knee; fringed hem
    robe = pen.poly([(0.0, 1.47), (0.14, 1.42), (0.18, 1.3), (0.17, 1.02), (0.14, 0.62), (0.1, 0.14), (0.06, 0.1),
                     (-0.3, 0.1), (-0.27, 0.6), (-0.22, 1.0), (-0.2, 1.3), (-0.12, 1.45)])
    pen.put(robe, z, "robe", r=0.014)
    fringe(pen, (0.08, 0.15), (-0.29, 0.15), "robe", length=0.045, pitch=0.016)
    pen.cut([(0.1, 0.15), (-0.3, 0.15)], "robe", depth=0.002)
    # the shawl: wound from the back shoulder down across to the front knee,
    # edged with a deep fringe
    shawl = pen.poly([(-0.2, 1.32), (-0.08, 1.4), (0.17, 0.98), (0.14, 0.62), (0.0, 0.42), (-0.24, 0.62),
                      (-0.22, 0.96)])
    pen.put(shawl, z + 0.004, "robe", r=0.008)
    fringe(pen, (0.14, 0.62), (-0.24, 0.62), "robe", length=0.06, pitch=0.016)
    pen.cut([(0.15, 0.64), (-0.25, 0.64)], "robe", depth=0.002)
    for k in range(6):
        a = (-0.19 + k * 0.03, 1.3 - k * 0.06)
        pen.cut([a, (a[0] + 0.2, a[1] - 0.3)], "robe", depth=0.0012)
    for k in range(9):
        x = -0.2 + k * 0.04
        pen.bump((x, 0.68), 0.008, 0.002, "robe")
    # sash with two daggers
    sash = pen.poly([(-0.21, 0.98), (0.17, 0.98), (0.18, 1.1), (-0.2, 1.1)])
    pen.put(sash, z + 0.007, "robe", mat=RED, r=0.006)
    for y in (1.02, 1.06):
        pen.cut([(-0.2, y), (0.18, y)], "robe", depth=0.0015)
    for dx in (0.02, 0.07):
        pen.put(pen.stroke([(dx, 1.06), (dx - 0.03, 1.25)], 0.028, 0.02), z + 0.009, "robe", r=0.004)
        pen.put(pen.circ((dx - 0.031, 1.26), 0.02), z + 0.01, "robe", r=0.004)
    # the striding calf through the opening, in a sandal
    lower_leg(pen, (0.15, 0.56), (0.2, 0.11), "robe", z + 0.006, boot=False)
    # torso: neckline
    pen.cut([(0.0, 1.45), (0.1, 1.38), (0.14, 1.3)], "robe", depth=0.0015)
    # head
    pen.put(pen.limb((0.02, 1.46), (0.05, 1.56), 0.052, 0.052), z, "head", r=0.01)
    head(pen, (0.03, 1.64), "head", z + 0.004, kind=headgear, s=1.18)
    # the near arm: down and forward, the bucket at the hip, armlet
    arm(pen, (0.02, 1.36), (0.0, 1.13), (0.13, 0.95), "arm_front", z + 0.016, hand=(0.16, 0.93))
    pen.put(pen.limb((0.0, 1.27), (0.0, 1.23), 0.068, 0.068), z + 0.02, "arm_front", r=0.004)
    rosette(pen, (0.0, 1.25), 0.026, "arm_front", z + 0.021)
    bucket(pen, (0.2, 0.93), "arm_front", z + 0.014, s=1.1)
    pen.put(pen.ell((0.02, 1.35), 0.075, 0.06), z + 0.014, "arm_front", r=0.012)


# --------------------------------------------------------------------------
# lions (Ashurbanipal's lion hunt, North Palace, Nineveh)
# --------------------------------------------------------------------------

LION_PARTS = ["leg_fr", "leg_br", "tail", "body", "leg_bl", "leg_fl", "head", "jaw"]
# pivots of the flat lion (1:1, facing +x): neck, jaw hinge, tail root,
# shoulders and hips
LION_JOINTS = {
    "body": (-0.12, 0.66), "head": (0.42, 0.8), "jaw": (0.6, 0.76), "tail": (-0.66, 0.8),
    "leg_fl": (0.27, 0.66), "leg_fr": (0.22, 0.68), "leg_bl": (-0.5, 0.7), "leg_br": (-0.46, 0.72),
}
LION_EYE = (0.69, 0.895)

_LION_POSES = {
    # joints: shoulder / hip, elbow / knee, wrist / hock, paw centre
    "walk": {
        "fl": [(0.27, 0.66), (0.2, 0.45), (0.3, 0.15), (0.38, 0.05)],
        "fr": [(0.22, 0.68), (0.1, 0.47), (0.04, 0.16), (0.1, 0.05)],
        "bl": [(-0.5, 0.7), (-0.4, 0.45), (-0.62, 0.22), (-0.55, 0.05)],
        "br": [(-0.46, 0.72), (-0.3, 0.46), (-0.4, 0.2), (-0.32, 0.05)],
        "lean": 0.0, "tail": -36.0,
    },
    "leap": {
        "fl": [(0.27, 0.66), (0.42, 0.58), (0.6, 0.66), (0.7, 0.7)],
        "fr": [(0.22, 0.68), (0.38, 0.52), (0.54, 0.54), (0.64, 0.56)],
        "bl": [(-0.5, 0.7), (-0.52, 0.42), (-0.78, 0.26), (-0.76, 0.06)],
        "br": [(-0.46, 0.72), (-0.36, 0.44), (-0.56, 0.24), (-0.52, 0.06)],
        "lean": 24.0, "tail": 20.0,
    },
    "dying": {
        "fl": [(0.27, 0.66), (0.26, 0.45), (0.36, 0.15), (0.44, 0.05)],
        "fr": [(0.22, 0.68), (0.14, 0.46), (0.16, 0.15), (0.24, 0.05)],
        "bl": [(-0.5, 0.7), (-0.7, 0.44), (-0.96, 0.32), (-1.08, 0.3)],
        "br": [(-0.46, 0.72), (-0.64, 0.4), (-0.92, 0.2), (-1.04, 0.14)],
        "lean": -9.0, "tail": -30.0,
    },
    "crouch": {
        "fl": [(0.27, 0.62), (0.3, 0.4), (0.38, 0.13), (0.46, 0.05)],
        "fr": [(0.22, 0.64), (0.2, 0.42), (0.24, 0.14), (0.32, 0.05)],
        "bl": [(-0.5, 0.66), (-0.36, 0.38), (-0.58, 0.16), (-0.5, 0.05)],
        "br": [(-0.46, 0.68), (-0.3, 0.4), (-0.46, 0.15), (-0.38, 0.05)],
        "lean": -4.0, "tail": -10.0,
    },
}


def _lion_leg(pen, pts, front, part, z, claws=False):
    """A lion's leg through its joints: a heavy upper limb (shoulder or
    thigh), the forearm / shin, the wrist / hock, a broad paw; tendons and
    muscles as grooves, toe grooves, claws when it strikes."""
    a, b, c, p = pts
    if front:
        radii = (0.095, 0.07, 0.05, 0.042)
    else:
        radii = (0.13, 0.075, 0.048, 0.04)
    d = rl.union(pen.limb(a, b, radii[0], radii[1]), pen.limb(b, c, radii[1], radii[2]),
                 pen.limb(c, p, radii[2], radii[3]))
    d = rl.union(d, pen.ell((p[0] + 0.012, p[1] - 0.005), 0.075, 0.042), pen.ell((p[0] + 0.05, p[1] - 0.02), 0.04, 0.03))
    pen.put(d, z, part, r=0.016)
    # muscles of the upper limb and a tendon down the lower one
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    pen.cut(bezier([(a[0] + 0.03, a[1] - 0.02), (mx + 0.04, my), (mx + 0.01, my - 0.04), (b[0] + 0.01, b[1] + 0.03)], 6),
            part, depth=0.0022)
    pen.cut([(b[0] * 0.75 + c[0] * 0.25 - 0.012, b[1] * 0.75 + c[1] * 0.25),
             (b[0] * 0.25 + c[0] * 0.75 - 0.012, b[1] * 0.25 + c[1] * 0.75)], part, depth=0.0018)
    for k in range(3):
        x = p[0] - 0.02 + k * 0.033
        pen.cut([(x, p[1] + 0.03), (x + 0.008, p[1] - 0.04)], part, depth=0.0018)
    if claws:
        for k in range(3):
            x = p[0] + 0.03 + k * 0.026
            pen.put(pen.poly([(x - 0.01, p[1] - 0.03), (x + 0.03, p[1] - 0.075), (x + 0.008, p[1] - 0.035)]),
                    z + 0.003, part, mat=EYE, r=0.003)


def _mane(pen, part, z, xf):
    """Flame-shaped locks of the mane, raised tongues overlapping from the
    back of the head down over the shoulders, with a jagged edge."""
    mp = pen.at(xf)
    outline = [(0.58, 1.02), (0.44, 1.07), (0.3, 1.02), (0.16, 0.95), (0.06, 0.84), (0.02, 0.7), (0.08, 0.58),
               (0.04, 0.5), (0.14, 0.46), (0.12, 0.38), (0.24, 0.4), (0.3, 0.33), (0.38, 0.42), (0.46, 0.4),
               (0.5, 0.52), (0.6, 0.62), (0.62, 0.78)]
    mp.put(mp.poly(outline), z, part, r=0.012)
    rng = np.random.default_rng(7)
    rows = [(1.0, 0.36, 0.56, 4), (0.92, 0.2, 0.6, 6), (0.83, 0.1, 0.58, 7), (0.73, 0.06, 0.56, 7),
            (0.63, 0.06, 0.52, 7), (0.54, 0.1, 0.48, 6), (0.46, 0.16, 0.44, 5)]
    for ri, (y, x0, x1, n) in enumerate(rows):
        for k in range(n):
            x = x0 + (x1 - x0) * (k + 0.5 * (ri % 2)) / n
            jit = (rng.random() - 0.5) * 0.02
            base = (x + jit, y + 0.035)
            tip = (x + jit - 0.05, y - 0.075)
            ctrl = (x + jit + 0.025, y - 0.03)
            pts = bezier([base, ctrl, (tip[0] + 0.04, tip[1] + 0.02), tip], 6)
            tongue = strip(pts, 0.05, 0.004)
            mp.put(mp.poly(tongue), z + 0.004 + 0.0015 * ri, part, r=0.008)
            mp.cut(bezier([(base[0] + 0.006, base[1] - 0.01), (ctrl[0], ctrl[1]), (tip[0] + 0.03, tip[1] + 0.03),
                           (tip[0] + 0.01, tip[1] + 0.012)], 5), part, depth=0.0015)


def lion(pen, z=0.016, pose="walk", jaw_open=1.0, arrows=(), mane=True):
    """A lion in profile, facing +x, ~1 m tall to the top of the mane (1:1
    scale = the flat relief lion). Body drawn as smooth curves with incised
    muscles and ribs, the mane in raised flame-shaped locks, the jaws open
    in a roar. Poses: walk, leap (rearing ~25 degrees, forelegs out, claws
    bared), dying (the lion hunt's lioness: hind legs dragging), crouch.
    ``arrows`` = (x, y, angle deg) shafts stuck in the body; ``mane`` False
    = a lioness."""
    P = _LION_POSES[pose]
    lean = P["lean"]
    body_xf = pen.xf.rot(lean, (-0.5, 0.42)) if lean else pen.xf
    bp = pen.at(body_xf)
    # the far legs (lowest)
    hind_xf = pen.xf if pose == "leap" else body_xf
    _lion_leg(bp, P["fr"], True, "leg_fr", z - 0.01, claws=pose == "leap")
    _lion_leg(pen.at(hind_xf), P["br"], False, "leg_br", z - 0.01)
    # tail: an S curve ending in a tuft (turned about its root by pose)
    txf = body_xf.rot(P["tail"], LION_JOINTS["tail"]) if P["tail"] else body_xf
    tp = pen.at(txf)
    tail = bezier([(-0.64, 0.8), (-0.8, 0.86), (-0.86, 0.68), (-0.98, 0.7), (-1.1, 0.72), (-1.12, 0.88),
                   (-1.06, 0.96)], 10)
    tp.put(tp.stroke(tail, 0.052, 0.03), z - 0.004, "tail", r=0.01)
    tp.put(tp.ell((-1.05, 0.98), 0.055, 0.036, 0.6), z - 0.002, "tail", r=0.008)
    for k in range(3):
        tp.cut([(-1.09 + k * 0.025, 0.95), (-1.06 + k * 0.025, 1.01)], "tail", depth=0.0015)
    # body: smooth back, deep chest, tucked loins, rounded rump
    outline = bezier([(0.44, 0.74), (0.4, 0.92), (0.2, 0.94), (0.0, 0.9),
                      (-0.22, 0.86), (-0.42, 0.88), (-0.6, 0.86),
                      (-0.76, 0.84), (-0.74, 0.6), (-0.62, 0.54),
                      (-0.48, 0.48), (-0.3, 0.52), (-0.1, 0.46),
                      (0.1, 0.38), (0.36, 0.38), (0.44, 0.74)], 8)
    bp.put(bp.poly(outline), z, "body", r=0.022)
    # ribs, flank and the great shoulder and haunch masses
    for k in range(5):
        x = -0.06 - k * 0.06
        bp.cut(bezier([(x + 0.03, 0.82), (x - 0.01, 0.74), (x - 0.02, 0.62), (x + 0.01, 0.53)], 6), "body",
               depth=0.0018)
    bp.cut(bezier([(-0.36, 0.56), (-0.3, 0.6), (-0.18, 0.58), (-0.1, 0.52)], 6), "body", depth=0.0016)
    bp.put(bp.ell((-0.54, 0.7), 0.17, 0.15, -0.4), z + 0.004, "body", r=0.03)          # haunch
    bp.cut(bezier([(-0.42, 0.84), (-0.56, 0.8), (-0.66, 0.68), (-0.6, 0.56)], 8), "body", depth=0.0024)
    # the near legs over the body
    hind = pen.at(hind_xf)
    _lion_leg(hind, P["bl"], False, "leg_bl", z + 0.006)
    hind.put(hind.ell((P["bl"][0][0] - 0.02, P["bl"][0][1] - 0.02), 0.13, 0.17, -0.5), z + 0.008, "leg_bl", r=0.03)
    hind.cut(bezier([(P["bl"][0][0] + 0.08, P["bl"][0][1] + 0.1), (P["bl"][0][0] - 0.06, P["bl"][0][1] + 0.06),
                     (P["bl"][0][0] - 0.12, P["bl"][0][1] - 0.06), (P["bl"][1][0] - 0.02, P["bl"][1][1] + 0.04)], 8),
               "leg_bl", depth=0.0024)
    _lion_leg(bp, P["fl"], True, "leg_fl", z + 0.008, claws=pose == "leap")
    bp.put(bp.ell((P["fl"][0][0] + 0.01, P["fl"][0][1] - 0.04), 0.1, 0.14, 0.25), z + 0.01, "leg_fl", r=0.026)
    bp.cut(bezier([(P["fl"][0][0] + 0.07, P["fl"][0][1] + 0.08), (P["fl"][0][0] - 0.06, P["fl"][0][1] + 0.02),
                   (P["fl"][0][0] - 0.06, P["fl"][0][1] - 0.1), (P["fl"][1][0] + 0.02, P["fl"][1][1] + 0.04)], 8),
           "leg_fl", depth=0.0024)
    # belly fringe of mane
    if mane:
        for k in range(8):
            x = 0.16 - k * 0.055
            y = 0.42 + (k / 7.0) * 0.07
            bp.put(bp.poly(strip(bezier([(x + 0.02, y + 0.04), (x + 0.0, y), (x - 0.02, y - 0.03), (x - 0.04, y - 0.07)],
                                        4), 0.035, 0.004)), z + 0.002, "body", r=0.006)
    # head (its own part, pivot at the neck), with the mane on it
    hxf = body_xf
    hp = pen.at(hxf)
    skull = bezier([(0.46, 0.84), (0.48, 0.99), (0.6, 1.02), (0.7, 0.99),
                    (0.78, 0.98), (0.84, 0.95), (0.87, 0.9),
                    (0.9, 0.86), (0.91, 0.8), (0.88, 0.76),
                    (0.8, 0.745), (0.66, 0.75), (0.6, 0.75),
                    (0.52, 0.73), (0.44, 0.76), (0.46, 0.84)], 8)
    if mane:
        _mane(pen, "head", z + 0.006, hxf)
    else:
        hp.put(hp.poly([(0.36, 0.9), (0.5, 1.0), (0.6, 0.86), (0.5, 0.62), (0.36, 0.56), (0.3, 0.7)]), z + 0.004,
               "head", r=0.03)
    hp.put(hp.poly(skull), z + 0.014, "head", r=0.016)
    hp.put(hp.ell((0.53, 0.99), 0.032, 0.026), z + 0.018, "head", r=0.006)               # ear
    hp.cut(np.abs(hp.ell((0.53, 0.99), 0.018, 0.013)), "head", depth=0.0015)
    # snarl: wrinkles across the nose bridge and the cheek, nostril, whisker pads
    for k in range(4):
        hp.cut(bezier([(0.72 + k * 0.025, 0.96 - k * 0.012), (0.74 + k * 0.025, 0.95 - k * 0.012),
                       (0.745 + k * 0.025, 0.92 - k * 0.012), (0.74 + k * 0.025, 0.9 - k * 0.012)], 5), "head",
               depth=0.0018)
    hp.cut(bezier([(0.86, 0.84), (0.84, 0.82), (0.8, 0.82), (0.77, 0.84)], 5), "head", depth=0.002)
    hp.cut(bezier([(0.64, 0.85), (0.66, 0.8), (0.72, 0.79), (0.78, 0.8)], 6), "head", depth=0.0018)
    for k in range(3):
        hp.bump((0.76 + k * 0.03, 0.81), 0.006, 0.0015, "head")
    # the eye under a heavy brow (the flat lion's weak point)
    e = LION_EYE
    hp.put(hp.stroke([(e[0] - 0.05, e[1] + 0.015), (e[0], e[1] + 0.035), (e[0] + 0.04, e[1] + 0.02)], 0.02, 0.01),
           z + 0.018, "head", r=0.005)
    hp.put(hp.ell(e, 0.026, 0.015, 0.2), z + 0.016, "head", mat=EYE, r=0.004)
    hp.paint(hp.circ((e[0] + 0.006, e[1]), 0.009), PUPIL, "head")
    hp.cut(np.abs(hp.ell(e, 0.028, 0.017, 0.2)), "head", w=pen.R.px * 1.1, depth=0.002, mat=PUPIL)
    # upper fangs
    hp.put(hp.poly([(0.86, 0.785), (0.868, 0.72), (0.84, 0.78)]), z + 0.016, "head", mat=EYE, r=0.003)
    hp.put(hp.poly([(0.7, 0.765), (0.71, 0.73), (0.69, 0.762)]), z + 0.016, "head", mat=EYE, r=0.003)
    # the jaw (its own part: the enemy snaps it), open by jaw_open
    jxf = hxf.rot(-24.0 * jaw_open, LION_JOINTS["jaw"])
    jp = pen.at(jxf)
    jaw = bezier([(0.56, 0.78), (0.66, 0.77), (0.8, 0.77), (0.86, 0.76), (0.88, 0.74), (0.86, 0.71), (0.8, 0.7),
                  (0.7, 0.69), (0.6, 0.7), (0.56, 0.78)], 6)
    jp.put(jp.poly(jaw), z + 0.012, "jaw", r=0.012)
    jp.put(jp.poly([(0.82, 0.765), (0.835, 0.82), (0.845, 0.765)]), z + 0.014, "jaw", mat=EYE, r=0.003)
    jp.cut([(0.62, 0.735), (0.84, 0.735)], "jaw", depth=0.0015)
    for (x, y, ang) in arrows:
        a = math.radians(ang)
        tip = (x, y)
        tail_end = (x - math.cos(a) * 0.36, y - math.sin(a) * 0.36)
        bp.put(bp.stroke([tip, tail_end], 0.016), z + 0.02, "body", r=0.004)
        fl_ = (tail_end[0] + math.cos(a) * 0.09, tail_end[1] + math.sin(a) * 0.09)
        bp.put(bp.poly([tail_end, (fl_[0] - math.sin(a) * 0.03, fl_[1] + math.cos(a) * 0.03), fl_,
                        (fl_[0] + math.sin(a) * 0.03, fl_[1] - math.cos(a) * 0.03)]), z + 0.021, "body", mat=RED,
               r=0.003)


# --------------------------------------------------------------------------
# archers, horses, chariots
# --------------------------------------------------------------------------

def bow(pen, grip, top, bottom, part, z, drawn=None):
    """A composite bow: the stave as a curve through top - grip - bottom
    (recurved tips), the string straight or ``drawn`` back to a point."""
    mid_top = ((grip[0] + top[0]) / 2 + 0.06, (grip[1] + top[1]) / 2)
    mid_bot = ((grip[0] + bottom[0]) / 2 + 0.06, (grip[1] + bottom[1]) / 2)
    stave = bezier([top, mid_top, mid_top, grip], 6) + bezier([grip, mid_bot, mid_bot, bottom], 6)[1:]
    pen.put(pen.stroke(stave, 0.026, 0.026), z, part, r=0.006)
    for tip, d in ((top, 1), (bottom, -1)):
        pen.put(pen.stroke([tip, (tip[0] + 0.03, tip[1] + 0.03 * d)], 0.02, 0.012), z, part, r=0.004)
    string = [top, drawn, bottom] if drawn is not None else [top, bottom]
    pen.put(pen.stroke(string, 0.008), z - 0.004, part, r=0.003)


def archer(pen, z=0.018, stride=1.0):
    """A bowman drawing: the far arm holds the bow out at eye height, the
    near hand draws the string to the cheek; pointed helmet, quiver on the
    back, short tunic, boots (the companion of the spearmen)."""
    s = stride
    # quiver behind the shoulders (far side), arrows sticking out
    pen.put(pen.stroke([(-0.18, 0.95), (-0.32, 1.62)], 0.11, 0.1), z - 0.01, "torso", r=0.01)
    for t in (0.12, 0.5, 0.88):
        a = (-0.18 - 0.14 * t, 0.95 + 0.67 * t)
        pen.put(pen.stroke([(a[0] - 0.055, a[1] - 0.012), (a[0] + 0.055, a[1] + 0.012)], 0.035), z - 0.006, "torso",
                mat=RED, r=0.004)
    for k in range(3):
        pen.put(pen.stroke([(-0.3 + k * 0.025, 1.6), (-0.34 + k * 0.025, 1.76)], 0.012), z - 0.012, "torso", r=0.003)
    for y in (1.12, 1.3, 1.48):
        pen.cut([(-0.24 + (y - 0.95) * 0.2 - 0.06, y), (-0.24 + (y - 0.95) * 0.2 + 0.05, y)], "torso", depth=0.0015)
    pen.put(pen.limb((-0.05, 0.92), (-0.12 * s, 0.55), 0.085, 0.06), z - 0.006, "leg_back", r=0.012)
    lower_leg(pen, (-0.12 * s, 0.53), (-0.22 * s, 0.11), "leg_back", z - 0.006)
    torso = pen.poly([(0.03, 1.47), (0.12, 1.44), (0.17, 1.36), (0.175, 1.18), (0.16, 1.02), (0.185, 0.6),
                      (0.0, 0.57), (-0.21, 0.6), (-0.175, 1.0), (-0.2, 1.22), (-0.17, 1.4), (-0.06, 1.47)])
    pen.put(torso, z, "torso", r=0.014)
    belt = pen.poly([(-0.185, 0.98), (0.175, 0.98), (0.178, 1.09), (-0.19, 1.09)])
    pen.put(belt, z + 0.004, "torso", mat=RED, r=0.006)
    pen.cut([(-0.19, 1.035), (0.18, 1.035)], "torso", depth=0.0015)
    hem = pen.poly([(-0.215, 0.6), (0.19, 0.6), (0.192, 0.565), (-0.22, 0.565)])
    pen.put(hem, z + 0.002, "torso", r=0.004)
    for k in range(20):
        x = -0.21 + k * 0.021
        pen.cut([(x, 0.6), (x + 0.002, 0.565)], "torso", depth=0.0018)
    pen.cut([(0.0, 0.97), (-0.02, 0.62)], "torso", depth=0.0012)
    pen.put(pen.limb((0.04, 0.92), (0.12 * s, 0.55), 0.085, 0.06), z + 0.002, "leg_front", r=0.012)
    lower_leg(pen, (0.12 * s, 0.53), (0.2 * s, 0.11), "leg_front", z + 0.002)
    pen.put(pen.limb((0.02, 1.46), (0.05, 1.56), 0.052, 0.052), z, "head", r=0.01)
    head(pen, HEAD_C, "head", z + 0.002, kind="helmet", s=HEAD_S)
    # far arm out with the bow, near arm drawing
    arm(pen, (0.02, 1.4), (0.28, 1.48), (0.5, 1.55), "arm_back", z - 0.006, hand=(0.53, 1.56))
    bow(pen, (0.55, 1.56), (0.46, 2.0), (0.5, 1.1), "arm_back", z - 0.004, drawn=(0.05, 1.63))
    pen.put(pen.stroke([(0.05, 1.63), (0.62, 1.58)], 0.012), z + 0.024, "arm_front", r=0.003)       # the arrow
    pen.put(pen.poly([(0.62, 1.6), (0.67, 1.578), (0.62, 1.56)]), z + 0.025, "arm_front", r=0.003)
    arm(pen, (0.03, 1.38), (-0.17, 1.56), (0.02, 1.63), "arm_front", z + 0.018, hand=(0.05, 1.63), bracelet=True)
    pen.put(pen.ell((0.02, 1.36), 0.075, 0.06), z + 0.016, "arm_front", r=0.012)


def horse(pen, z=0.016, gait="gallop", part="horse", tack=True, plume=True):
    """An Assyrian chariot horse facing +x (1:1, withers ~1.45 m): small
    straight-profiled head on a thick arched neck, cropped crest mane, a
    plume on the poll, the tail tied up, harness with rosettes and tassels.
    gait: gallop (the 'flying gallop' of the reliefs: forelegs reaching,
    hind legs stretched back), walk."""
    if gait == "gallop":
        legs = {
            "ff": [(0.4, 1.02), (0.56, 0.64), (0.76, 0.5), (0.82, 0.42)],
            "fn": [(0.46, 1.02), (0.68, 0.7), (0.9, 0.56), (0.96, 0.48)],
            "hf": [(-0.55, 1.04), (-0.86, 0.74), (-1.04, 0.56), (-1.08, 0.48)],
            "hn": [(-0.5, 1.02), (-0.76, 0.68), (-0.96, 0.48), (-1.0, 0.4)],
        }
    else:
        legs = {
            "ff": [(0.4, 1.02), (0.36, 0.6), (0.38, 0.17), (0.42, 0.05)],
            "fn": [(0.46, 1.02), (0.54, 0.6), (0.58, 0.17), (0.63, 0.05)],
            "hf": [(-0.55, 1.04), (-0.46, 0.66), (-0.56, 0.22), (-0.52, 0.05)],
            "hn": [(-0.5, 1.02), (-0.36, 0.66), (-0.4, 0.2), (-0.34, 0.05)],
        }

    def leg(pts, zz):
        a, b, c, d = pts
        dd = rl.union(pen.limb(a, b, 0.075, 0.045), pen.limb(b, c, 0.042, 0.03), pen.limb(c, d, 0.034, 0.03))
        pen.put(dd, zz, part, r=0.012)
        dx, dy = d[0] - c[0], d[1] - c[1]
        L = math.hypot(dx, dy) or 1.0
        pen.put(pen.ell((d[0] + dx / L * 0.02, d[1] + dy / L * 0.02), 0.04, 0.03, math.atan2(dy, dx)), zz + 0.002, part,
                r=0.006)                                                                     # hoof
        pen.bump(c, 0.03, 0.003, part)                                                      # fetlock
        pen.cut([(a[0] * 0.6 + b[0] * 0.4 - 0.015, a[1] * 0.6 + b[1] * 0.4), (b[0] - 0.01, b[1] + 0.02)], part,
                depth=0.0018)
    leg(legs["ff"], z - 0.012)
    leg(legs["hf"], z - 0.012)
    # tail: tied up in a loop, then falling in a fan
    pen.put(pen.stroke(bezier([(-0.72, 1.4), (-0.84, 1.44), (-0.92, 1.36), (-0.92, 1.24)], 8), 0.07, 0.06), z - 0.002,
            part, r=0.01)
    pen.put(pen.poly([(-0.95, 1.26), (-0.88, 1.24), (-0.94, 0.98), (-1.04, 1.0)]), z - 0.002, part, r=0.01)
    pen.put(pen.ell((-0.92, 1.28), 0.045, 0.03), z, part, mat=RED, r=0.004)
    for k in range(4):
        pen.cut([(-0.91 - k * 0.025, 1.22), (-0.93 - k * 0.03, 1.0)], part, depth=0.0015)
    # body
    body = bezier([(0.35, 1.46), (0.15, 1.42), (-0.1, 1.38),
                   (-0.35, 1.42), (-0.55, 1.46), (-0.72, 1.42),
                   (-0.84, 1.36), (-0.84, 1.1), (-0.72, 1.0),
                   (-0.5, 0.92), (-0.1, 0.9), (0.3, 0.94),
                   (0.52, 0.98), (0.68, 1.08), (0.66, 1.26),
                   (0.6, 1.4), (0.45, 1.48), (0.35, 1.46)], 8)
    pen.put(pen.poly(body), z, part, r=0.02)
    # neck and head
    neck = bezier([(0.3, 1.44), (0.42, 1.66), (0.56, 1.8), (0.74, 1.88),
                   (0.8, 1.8), (0.84, 1.66), (0.84, 1.58),
                   (0.76, 1.4), (0.7, 1.24), (0.64, 1.14)], 8)
    pen.put(pen.poly(neck), z + 0.002, part, r=0.018)
    head_ = bezier([(0.72, 1.9), (0.8, 1.92), (0.86, 1.86), (0.94, 1.76),
                    (1.0, 1.66), (1.06, 1.58), (1.08, 1.52),
                    (1.07, 1.46), (1.0, 1.46), (0.94, 1.5),
                    (0.86, 1.56), (0.8, 1.62), (0.74, 1.72)], 6)
    pen.put(pen.poly(head_), z + 0.005, part, r=0.014)
    pen.put(pen.ell((0.865, 1.775), 0.02, 0.012, -0.8), z + 0.007, part, mat=EYE, r=0.003)
    pen.paint(pen.circ((0.868, 1.774), 0.007), PUPIL, part)
    pen.cut(np.abs(pen.ell((0.865, 1.775), 0.022, 0.014, -0.8)), part, depth=0.0015)
    pen.cut([(1.05, 1.53), (1.02, 1.55)], part, depth=0.002)                               # nostril
    pen.cut([(1.07, 1.49), (1.0, 1.49)], part, depth=0.0015)                               # mouth
    pen.cut(bezier([(0.8, 1.7), (0.84, 1.62), (0.9, 1.58), (0.96, 1.56)], 5), part, depth=0.0015)   # cheek
    pen.put(pen.poly([(0.73, 1.88), (0.7, 1.98), (0.77, 1.9)]), z + 0.006, part, r=0.004)       # ear
    # cropped crest mane
    crest = bezier([(0.3, 1.46), (0.42, 1.7), (0.56, 1.84), (0.74, 1.9)], 8)
    pen.put(pen.stroke(crest, 0.07, 0.045), z + 0.007, part, mat=HAIR, r=0.006)
    for k in range(10):
        x, y = crest[min(k * 2 + 1, len(crest) - 1)]
        pen.cut([(x + 0.02, y - 0.03), (x - 0.02, y + 0.025)], part, depth=0.0015)
    # muscles: shoulder, forearm, haunch
    pen.cut(bezier([(0.46, 1.42), (0.36, 1.3), (0.36, 1.12), (0.46, 1.0)], 6), part, depth=0.0022)
    pen.cut(bezier([(-0.46, 1.42), (-0.6, 1.3), (-0.64, 1.12), (-0.56, 1.0)], 6), part, depth=0.0022)
    pen.cut(bezier([(0.1, 1.36), (0.05, 1.2), (0.0, 1.05), (0.05, 0.94)], 6), part, depth=0.0012)
    leg(legs["fn"], z + 0.006)
    leg(legs["hn"], z + 0.006)
    pen.put(pen.ell((0.48, 1.1), 0.1, 0.1), z + 0.004, part, r=0.02)
    pen.put(pen.ell((-0.56, 1.14), 0.14, 0.15, 0.4), z + 0.004, part, r=0.024)
    if tack:
        # bridle with a rosette on the cheek, reins, breastband with tassels, the girth
        pen.put(pen.stroke([(0.76, 1.88), (1.02, 1.5)], 0.018), z + 0.009, part, mat=RED, r=0.003)
        pen.put(pen.stroke([(0.82, 1.62), (0.94, 1.66), (1.02, 1.56)], 0.016), z + 0.009, part, mat=RED, r=0.003)
        rosette(pen, (0.88, 1.66), 0.028, part, z + 0.011)
        band = bezier([(0.4, 1.44), (0.56, 1.36), (0.66, 1.24), (0.64, 1.08)], 6)
        pen.put(pen.stroke(band, 0.035), z + 0.009, part, mat=RED, r=0.004)
        for k in range(5):
            x, y = band[min(3 + k * 3, len(band) - 1)]
            pen.put(pen.poly([(x - 0.01, y), (x + 0.012, y), (x + 0.008, y - 0.08), (x - 0.012, y - 0.08)]),
                    z + 0.01, part, mat=RED, r=0.003)
        pen.put(pen.stroke([(0.18, 1.44), (0.2, 0.92)], 0.06), z + 0.008, part, r=0.006)
        rosette(pen, (0.185, 1.38), 0.032, part, z + 0.011)
    if plume:
        pen.put(pen.stroke(bezier([(0.76, 1.9), (0.72, 1.98), (0.66, 2.02), (0.6, 2.0)], 6), 0.045, 0.02), z + 0.008,
                part, mat=RED, r=0.006)
        for k in range(4):
            pen.cut([(0.75 + k * 0.04, 2.0 + k * 0.02), (0.78 + k * 0.04, 2.06 + k * 0.01)], part, depth=0.0012)


def wheel(pen, c, r, part, z, spokes=6):
    """A chariot wheel: studded tyre, felloe, spokes, the hub."""
    pen.put(pen.circ(c, r), z, part, r=0.008)
    pen.sink(pen.circ(c, r * 0.78), 0.012, part)
    for k in range(spokes):
        a = math.tau * k / spokes + 0.26
        pen.put(pen.stroke([c, (c[0] + math.cos(a) * r * 0.8, c[1] + math.sin(a) * r * 0.8)], 0.035), z + 0.002, part,
                r=0.006)
    pen.put(pen.circ(c, r * 0.16), z + 0.006, part, r=0.008)
    for k in range(18):
        a = math.tau * k / 18
        pen.bump((c[0] + math.cos(a) * r * 0.9, c[1] + math.sin(a) * r * 0.9), 0.018, 0.003, part)


def chariot(pen, z=0.016, rider="king", horses=2):
    """A royal chariot at full gallop facing +x: two horses (the far one a
    step ahead), the box with a quiver slung at its front, a six-spoked
    wheel, the charioteer with the reins and the king drawing his bow.
    Spans x -2.05 .. 1.1 at 1:1 (1.0 m per metre of the drawing)."""
    for k in range(horses - 1, 0, -1):
        horse(pen.at(pen.xf.move(0.2 * k, 0.07 * k)), z - 0.01 * k, part="horse_far", tack=False)
    horse(pen, z, part="horse")
    # the pole from the box to the yoke on the withers
    pen.put(pen.stroke(bezier([(-1.32, 0.96), (-0.9, 0.98), (-0.2, 1.2), (0.3, 1.5)], 8), 0.04), z + 0.012, "car",
            r=0.006)
    pen.put(pen.ell((0.32, 1.52), 0.06, 0.03, 0.4), z + 0.014, "car", r=0.004)
    # driver (far side) first
    drv = pen.at(_scaled(pen.xf, (-1.82, 0.0), 1.0))
    drv.put(drv.poly([(-0.13, 1.3), (0.12, 1.3), (0.14, 1.6), (0.0, 1.66), (-0.14, 1.6)]), z - 0.002, "rider",
            r=0.012)
    head(drv, (0.0, 1.78), "rider", z, kind="bare", s=0.95)
    arm(drv, (0.04, 1.6), (0.18, 1.46), (0.36, 1.48), "rider", z + 0.004, hand=(0.39, 1.48))
    pen.put(pen.stroke([(-1.42, 1.48), (-0.7, 1.4), (0.2, 1.52), (0.96, 1.6)], 0.01), z + 0.016, "rider", mat=RED,
            r=0.003)
    # chariot box with its quiver
    box = [(-2.02, 0.86), (-1.32, 0.86), (-1.27, 1.0), (-1.3, 1.36), (-1.98, 1.36), (-2.05, 1.1)]
    pen.put(pen.poly(box), z + 0.008, "car", r=0.012)
    pen.cut([(-1.99, 1.28), (-1.32, 1.28)], "car", depth=0.002)
    for k in range(5):
        pen.cut([(-1.92 + k * 0.12, 0.9), (-1.92 + k * 0.12, 1.28)], "car", depth=0.0015)
    for k in range(6):
        pen.bump((-1.95 + k * 0.12, 1.32), 0.014, 0.003, "car")
    pen.put(pen.stroke([(-1.42, 0.92), (-1.24, 1.5)], 0.075, 0.065), z + 0.014, "car", mat=RED, r=0.006)
    for k in range(3):
        pen.put(pen.stroke([(-1.27 + k * 0.022, 1.48), (-1.22 + k * 0.022, 1.64)], 0.012), z + 0.012, "car", r=0.003)
    wheel(pen, (-1.66, 0.48), 0.44, "car", z + 0.016)
    # the king at the front of the box, drawing his bow
    kg = pen.at(_scaled(pen.xf, (-1.52, 0.0), 1.0))
    if rider == "king":
        kg.put(kg.poly([(-0.13, 1.32), (0.13, 1.32), (0.15, 1.62), (0.0, 1.68), (-0.15, 1.62)]), z + 0.01, "rider",
               r=0.012)
        for k in range(4):
            kg.bump((-0.08 + k * 0.05, 1.5), 0.012, 0.003, "rider")
        arm(kg, (0.02, 1.64), (0.26, 1.72), (0.46, 1.78), "rider", z + 0.006, hand=(0.49, 1.79))
        bow(kg, (0.51, 1.79), (0.44, 2.16), (0.46, 1.42), "rider", z + 0.008, drawn=(0.05, 1.82))
        head(kg, (0.0, 1.82), "rider", z + 0.012, kind="king", s=1.0)
        kg.put(kg.stroke([(0.05, 1.82), (0.62, 1.82)], 0.012), z + 0.024, "rider", r=0.003)
        kg.put(kg.poly([(0.62, 1.84), (0.67, 1.82), (0.62, 1.8)]), z + 0.025, "rider", r=0.003)
        arm(kg, (0.02, 1.6), (-0.16, 1.7), (0.02, 1.82), "rider", z + 0.02, hand=(0.05, 1.82))
