"""Compositions of the Assyrian relief slabs: each function returns a
``Relief`` covering a slab face (u -W/2 .. W/2 left -> right, v 0 .. H up),
drawn at the slab's texel density. They become texture sets of the panel
meshes (models/kit_asy_reliefs.py).

Layout grammar of the Nimrud and Nineveh slabs:
  * the slab face is the top plane (``TOP`` proud of the carved ground);
    register fields are sunk to 0, figures rise from them up to ~TOP;
  * two-register slabs (Nimrud throne room) carry the Standard Inscription
    in a band across the middle; single-figure slabs (genies) have it
    carved right across the figure, as in the originals;
  * a plain plinth band at the foot of every slab.

The lone spearman of ``spearman_1m`` and the big walking lion of ``lions``
are drawn exactly where the awakening slabs (asy_relief_wake*) carry the
figure that steps out as the flat enemy: same design, same place, scale 1.
"""
import numpy as np

from . import asy_figures as F
from . import asy_relief as rl

TOP = 0.032          # slab surface above the sunk ground of a register
PLINTH = 0.14        # plain band at the foot of every slab
PPM = 128

# where the flat enemies stand on their slabs (figure origin, slab coords)
WAKE_WARRIOR_AT = (-0.13, PLINTH + 0.02)          # 1 m slab, spearman facing +u
WAKE_LION_AT = (0.06, PLINTH + 0.02)              # 2 m slab, lion facing +u


def slab(W, H, ppm, seed):
    R = rl.Relief(W, H, ppm, u0=-W / 2, v0=0.0, seed=seed)
    R.base[:] = TOP
    return R


def field(R, v0, v1, margin=0.0, depth=TOP):
    """Sinks a register field (v0..v1, full width minus ``margin``)."""
    hw = R.w_m / 2 - margin
    d = R.box((0.0, (v0 + v1) / 2), hw, (v1 - v0) / 2)
    t = np.clip(-d / (1.5 * R.px), 0.0, 1.0)
    R.base = np.where(d < 0, TOP - depth * t, R.base)
    R.base_mat[d < 0] = rl.BG
    return d < 0


def text_band(R, v0, v1, line_h=0.075, seed=0, margin=0.03):
    """A band of cuneiform on the slab surface."""
    rl.cuneiform(R, -R.w_m / 2 + margin, v0, R.w_m / 2 - margin, v1, line_h, part=None, seed=seed, depth=0.004)


def text_over(R, v0, v1, line_h=0.075, seed=0, margin=0.03):
    """The Standard Inscription carved across a single-figure slab: through
    the background and over every part that crosses the band."""
    rl.cuneiform(R, -R.w_m / 2 + margin, v0, R.w_m / 2 - margin, v1, line_h, part=None, seed=seed, depth=0.0035)
    for name in R.order:
        rl.cuneiform(R, -R.w_m / 2 + margin, v0, R.w_m / 2 - margin, v1, line_h, part=name, seed=seed, depth=0.0035)


def rosette_band(R, v0, v1, seed=0):
    """A carved band of rosettes between two raised fillets (slab tops)."""
    R.base_cut(np.abs(R.Y - v0), R.px * 1.2, 0.004)
    R.base_cut(np.abs(R.Y - v1), R.px * 1.2, 0.004)
    h = v1 - v0
    r = h * 0.36
    n = int(R.w_m / (h * 1.1))
    for k in range(n):
        x = -R.w_m / 2 + (k + 0.5) * R.w_m / n
        c = (x, (v0 + v1) / 2)
        d = R.circle(c, r)
        R.base = np.where(d < 0, R.base + 0.004, R.base)
        for j in range(8):
            a = np.pi * 2 * j / 8
            R.base_cut(R.seg((c[0] + np.cos(a) * r * 0.3, c[1] + np.sin(a) * r * 0.3),
                             (c[0] + np.cos(a) * r * 0.95, c[1] + np.sin(a) * r * 0.95)), R.px, 0.002)
        R.base_cut(np.abs(np.hypot(R.X - c[0], R.Y - c[1]) - r), R.px, 0.003)


def _pen(R, x, y, s, facing=1, depth=0.9):
    return F.Pen(R, rl.Xf(x, y, s, facing), default="main", depth=depth)


# --------------------------------------------------------------------------
# 2 m slabs
# --------------------------------------------------------------------------

def genie(ppm=PPM, seed=31, facing=1, headgear="genie"):
    """A winged genie with cone and bucket, the Standard Inscription carved
    across him (Ashurnasirpal II, Nimrud)."""
    R = slab(2.0, 3.0, ppm, seed)
    field(R, PLINTH, 2.94, margin=0.04)
    F.genie(_pen(R, 0.1 * facing, PLINTH + 0.02, 1.24, facing, depth=1.0), headgear=headgear)
    text_over(R, 1.3, 1.62, line_h=0.08, seed=seed)
    text_over(R, 1.3, 1.62, line_h=0.08, seed=seed)
    return R


def warriors(ppm=PPM, seed=21):
    """Spearmen marching above, archers drawing below, the inscription
    between them."""
    R = slab(2.0, 3.0, ppm, seed)
    field(R, PLINTH, 1.36)
    field(R, 1.8, 2.94)
    text_band(R, 1.39, 1.77, seed=seed)
    for k in range(4):
        F.warrior(_pen(R, -0.8 + k * 0.5, 1.82, 0.56), stride=0.9 + 0.1 * (k % 2))
    for k in range(3):
        F.archer(_pen(R, -0.78 + k * 0.62, PLINTH + 0.02, 0.56), stride=0.95)
    return R


def chariot(ppm=PPM, seed=23):
    """The king's chariot at the gallop above, spearmen below."""
    R = slab(2.0, 3.0, ppm, seed)
    field(R, PLINTH, 1.36)
    field(R, 1.8, 2.94)
    text_band(R, 1.39, 1.77, seed=seed)
    F.chariot(_pen(R, 0.33, 1.84, 0.5))
    for k in range(4):
        F.warrior(_pen(R, -0.8 + k * 0.5, PLINTH + 0.02, 0.56), stride=1.0 - 0.1 * (k % 2))
    return R


def lionhunt(ppm=PPM, seed=25):
    """Ashurbanipal's lion hunt: above, a lion leaps at a spearman who
    meets it; below, the dying lioness with arrows in her back and a
    wounded lion crouching."""
    R = slab(2.0, 3.0, ppm, seed)
    field(R, PLINTH, 1.36)
    field(R, 1.8, 2.94)
    text_band(R, 1.39, 1.77, seed=seed)
    F.lion(_pen(R, -0.32, 1.84, 0.6), pose="leap", arrows=[(-0.15, 0.86, -45)])
    F.warrior(_pen(R, 0.72, 1.82, 0.56, facing=-1), stride=1.1, shield=True)
    F.lion(_pen(R, 0.16, PLINTH + 0.02, 0.74), pose="dying", mane=False,
           arrows=[(-0.2, 0.84, -60), (0.05, 0.8, -70), (-0.45, 0.82, -50)])
    return R


def lions(ppm=PPM, seed=27):
    """The Lion Room slab: a great lion walking (the one that steps out as
    the flat relief lion), a lion leaping above, the inscription between."""
    R = slab(2.0, 3.0, ppm, seed)
    field(R, PLINTH, 1.36)
    field(R, 1.8, 2.94)
    text_band(R, 1.39, 1.77, seed=seed)
    F.lion(F.Pen(R, rl.Xf(WAKE_LION_AT[0], WAKE_LION_AT[1], 1.0, 1), default="main", depth=1.0), pose="walk")
    F.lion(_pen(R, 0.0, 1.84, 0.82), pose="leap")
    return R


def inscription(ppm=PPM, seed=29, W=2.0):
    """A slab of the Standard Inscription: ruled lines of cuneiform in a
    sunk frame."""
    R = slab(W, 3.0, ppm, seed)
    field(R, PLINTH + 0.12, 2.86, margin=0.1, depth=0.006)
    rl.cuneiform(R, -W / 2 + 0.14, PLINTH + 0.16, W / 2 - 0.14, 2.82, 0.085, part=None, seed=seed, depth=0.0045)
    return R


def plain(ppm=PPM, seed=33, W=2.0):
    """A dressed slab: a band of rosettes along the top, otherwise smooth."""
    R = slab(W, 3.0, ppm, seed)
    rosette_band(R, 2.72, 2.92, seed=seed)
    R.base_cut(np.abs(R.Y - PLINTH), R.px * 1.2, 0.003)
    return R


# --------------------------------------------------------------------------
# 1 m slabs
# --------------------------------------------------------------------------

def spearman_1m(ppm=PPM, seed=41, figure=True):
    """A single spearman at life size (the awakening warrior's slab), the
    inscription above him. ``figure`` False leaves the field empty (the
    awakening slab carries the figure as its own mesh)."""
    R = slab(1.0, 3.0, ppm, seed)
    field(R, PLINTH, 2.5, margin=0.03)
    text_band(R, 2.54, 2.92, line_h=0.075, seed=seed)
    if figure:
        warrior_on(R, depth=1.0)
    return R


def warrior_on(R, depth=1.0, part=None, names=None):
    """The life-size spearman of the 1 m slab (also the flat enemy)."""
    pen = F.Pen(R, rl.Xf(WAKE_WARRIOR_AT[0], WAKE_WARRIOR_AT[1], 1.0, 1), names=names,
                default=part if part is not None else ("main" if names is None else None), depth=depth)
    F.warrior(pen)
    return pen


DESIGNS = {
    "genie": genie,
    "genie_l": lambda: genie(seed=35, facing=-1, headgear="diadem"),
    "warriors": warriors,
    "chariot": chariot,
    "lionhunt": lionhunt,
    "lions": lions,
    "text": inscription,
    "plain": plain,
    "spearman_1m": spearman_1m,
    "text_1m": lambda: inscription(seed=43, W=1.0),
}
