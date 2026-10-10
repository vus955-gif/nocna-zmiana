"""The plumed-serpent head of the Americas wing, sculpted in metaball clay:
one design for the heads at the foot of the temple stairs (carved stone),
the double-headed mosaic serpent in its case and the guardian (turquoise
mosaic, 14 m). Stylised in the manner of Mesoamerican serpent heads, not a
copy of any: a long squared upper jaw rising to bulging eye domes, a snout
with a nose scroll curled up and back, round eyes in raised rings, a wide
open mouth with two great fangs, and a ruff of feathers round the neck
like the petals of a flower.

Coordinates: the head looks along +Y, the origin is the neck joint (the
back of the skull, on the axis), ``L`` = length from the neck to the snout
tip. ``upper(L)`` and ``jaw(L, open_deg)`` return blob lists for
sculpt.metaball_mesh; the jaw is hinged at JAW_HINGE * L and opened by
``open_deg`` (the guardian's jaw is its own part: build it closed, turn
the part). ``eyes``, ``fangs``, ``teeth`` and ``tongue`` give inlays for
hard-surface parts; ``ruff`` the feather collar (its own blob list, so a
model can give it another material).
"""
import math

from mathutils import Matrix, Vector

from .clay import box
from .sculpt import blob, limb

JAW_HINGE = (0.0, 0.12, -0.06)       # in units of L


def _s(v, L):
    return tuple(c * L for c in v)


def _dir_euler(d):
    d = Vector(d).normalized()
    return tuple(math.degrees(a) for a in d.to_track_quat('Z', 'Y').to_euler('XYZ'))


def upper(L, nose=True):
    b = [
        box(_s((0.0, 0.46, 0.03), L), _s((0.24, 0.36, 0.12), L), 0.06 * L),                   # upper jaw
        box(_s((0.0, 0.86, 0.02), L), _s((0.19, 0.12, 0.11), L), 0.05 * L),                   # squared snout
        blob(_s((0.0, 0.3, 0.12), L), _s((0.22, 0.22, 0.14), L)),                            # crown
        blob(_s((0.0, 0.06, 0.02), L), _s((0.21, 0.14, 0.17), L)),                           # neck
    ]
    for sx in (-1, 1):
        b.append(blob(_s((sx * 0.19, 0.42, 0.15), L), _s((0.11, 0.15, 0.11), L)))           # eye domes
        b.append(blob(_s((sx * 0.17, 0.46, 0.23), L), _s((0.12, 0.17, 0.065), L), rot=(-15.0, 0.0, 0.0)))  # brow
        b.append(blob(_s((sx * 0.22, 0.68, -0.02), L), _s((0.05, 0.22, 0.06), L)))          # lip ridge
        b.append(blob(_s((sx * 0.12, 0.97, 0.04), L), _s((0.04, 0.04, 0.03), L), neg=True, stiff=1.5))  # nostril
    if nose:
        # the nose scroll: rises from the snout tip, curls up and back
        pts = []
        for k in range(10):
            a = math.pi * 1.35 * k / 9
            pts.append((0.0, 0.9 + 0.11 * math.sin(a), 0.1 + 0.12 * (1.0 - math.cos(a))))
        b += limb([_s(p, L) for p in pts], [0.055 * L * (1.0 - 0.4 * k / 9) for k in range(10)], spacing=0.6)
    return b


def ruff(L, petals=13, skip_bottom=False):
    """A collar of feather petals round the neck in two overlapping rows,
    fanning out and back."""
    b = []
    for row, (rad, length, width, back, phase) in enumerate(((0.2, 0.17, 0.085, 0.5, 0.0),
                                                              (0.15, 0.12, 0.07, 0.25, 0.5))):
        for k in range(petals):
            th = 2.0 * math.pi * (k + phase) / petals
            if skip_bottom and math.cos(th) < -0.6:
                continue
            r = Vector((math.sin(th), 0.0, math.cos(th)))
            base = Vector((0.0, 0.06 + 0.04 * row, 0.03)) + r * rad
            d = r + Vector((0.0, -back, 0.0))
            c = base + d.normalized() * length * 0.75
            b.append(blob(_s(c, L), _s((width, 0.03, length), L), rot=_dir_euler(d), stiff=2.2))
    return b


def _hinged(points, open_deg):
    rot = Matrix.Translation(Vector(JAW_HINGE)) @ Matrix.Rotation(math.radians(-open_deg), 4, 'X') \
        @ Matrix.Translation(-Vector(JAW_HINGE))
    return [rot @ Vector(p) for p in points]


def jaw(L, open_deg=0.0):
    """Lower jaw blobs, hinged at JAW_HINGE and turned down ``open_deg``."""
    spec = [((0.0, 0.44, -0.14), (0.22, 0.32, 0.055), "BOX"),
            ((0.0, 0.76, -0.15), (0.17, 0.1, 0.055), "BOX"),
            ((0.0, 0.18, -0.1), (0.18, 0.1, 0.08), "ELLIPSOID")]
    out = []
    cs = _hinged([c for c, _, _ in spec], open_deg)
    for (c0, semi, kind), c in zip(spec, cs):
        if kind == "BOX":
            out.append(box(tuple(c * L), _s(semi, L), 0.04 * L, rot=(-open_deg, 0.0, 0.0)))
        else:
            out.append(blob(tuple(c * L), _s(semi, L), kind=kind, stiff=2.0, rot=(-open_deg, 0.0, 0.0)))
    return out


def eyes(L):
    """Eye centres (left, right), eyeball radius and the ring's outward
    direction (sideways, a little forward and up)."""
    return [_s((sx * 0.25, 0.43, 0.16), L) for sx in (-1, 1)], 0.06 * L, [(sx * 1.0, 0.35, 0.3) for sx in (-1, 1)]


def fangs(L, open_deg=0.0):
    """(root, direction, length) of the two great upper fangs and the two
    lower ones (turned with the jaw)."""
    up = [(_s((sx * 0.15, 0.86, -0.08), L), (sx * 0.08, 0.2, -1.0), 0.2 * L) for sx in (-1, 1)]
    roots = _hinged([(sx * 0.13, 0.76, -0.11) for sx in (-1, 1)], open_deg)
    a = math.radians(-open_deg)
    d = (0.0, -math.sin(a), math.cos(a))
    lo = [(tuple(r * L), (sx * 0.06 + d[0], 0.15 + d[1], d[2]), 0.11 * L) for sx, r in zip((-1, 1), roots)]
    return up + lo


def teeth(L, n=5, open_deg=0.0):
    """Roots (and down/up direction) of the small teeth along both jaws."""
    out = []
    for sx in (-1, 1):
        for k in range(n):
            t = k / (n - 1)
            out.append((_s((sx * (0.2 - 0.05 * t), 0.38 + 0.36 * t, -0.08), L), (0.0, 0.1, -1.0)))
    lows = _hinged([(sx * (0.17 - 0.04 * (k / (n - 1))), 0.36 + 0.3 * (k / (n - 1)), -0.1)
                    for sx in (-1, 1) for k in range(n)], open_deg)
    a = math.radians(-open_deg)
    for c in lows:
        out.append((tuple(c * L), (0.0, -math.sin(a) + 0.1, math.cos(a))))
    return out


def tongue(L, open_deg=0.0):
    """Polyline of the forked tongue (centre line) and its two tips."""
    pts = _hinged([(0.0, 0.25, -0.1), (0.0, 0.5, -0.1), (0.0, 0.72, -0.11), (0.0, 0.86, -0.13)], open_deg * 0.85)
    tips = []
    end = pts[-1]
    for sx in (-1, 1):
        b = _hinged([(sx * 0.06, 0.98, -0.15)], open_deg * 0.85)[0]
        tips.append((tuple(end * L), tuple(b * L)))
    return [tuple(p * L) for p in pts], tips
