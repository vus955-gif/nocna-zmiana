"""Greek kit: the orders and their fallen pieces (64 px/m).

  gr_column_doric    the Parthenon order at gallery scale: 8.2 m on a
                     0.2 m stylobate block, lower diameter 1.5 m, entasis,
                     20 sharp-edged flutes, drum joints every ~1.15 m,
                     three annulets, a wide cushion echinus and a square
                     abacus 1.8 m. No base (Doric). Origin = centre of the
                     block's underside; scale uniformly (Y alone also
                     works: the capital stretches a little).
  gr_column_ionic    7.0 m: square plinth, Attic base (torus, scotia,
                     torus), 24 flutes with flat fillets, an egg-and-dart
                     echinus, two volutes on the front and two on the back
                     joined by the side bolsters (pulvini, with a belt),
                     thin abacus. Origin = centre of the plinth's underside.
  gr_drum            a fallen Doric drum lying on its side (1.4 m tall):
                     fluted, chipped arrises, a lifting boss left on, the
                     fresh fracture on one end. Cover in the galleries.
  gr_capital_doric   a Parthenon capital displayed on the floor (echinus and
                     abacus, 1.75 x 0.95 x 1.75), a chunk off one corner.

Front = Godot -Z as the kit (turned symmetric pieces: it hardly matters).
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import greek as GK
from artlib import greek_ornament as O
from artlib.archkit import kit
from artlib.geo import Part
from artlib import kit as K

DORIC_FLUTES = 20
IONIC_FLUTES = 24


def _doric_scale(i, j, last):
    if j in last:
        return 1.0
    return 1.0 if i % 3 == 0 else 0.955


def doric():
    p = Part("gr_column_doric")
    p.box((0, 0, 0.1), (2.0, 2.0, 0.2), "grey", bevel=0.015)
    z0, z1 = 0.2, 7.3
    rings = 10
    prof = []
    for k in range(rings):
        t = k / (rings - 1)
        r = 0.75 - 0.15 * t * t + 0.02 * math.sin(t * math.pi)
        prof.append((r, z0 + (z1 - z0) * t))
    segs = DORIC_FLUTES * 3
    p.lathe(prof, "shaft", segments=segs, cap_bottom=False, cap_top=False, smooth=False,
            ring_scale=lambda i, j: _doric_scale(i, j, ()))
    # annulets and necking, echinus, abacus
    p.lathe([(0.6, 7.3), (0.61, 7.32), (0.6, 7.34), (0.615, 7.36), (0.605, 7.38), (0.62, 7.4), (0.64, 7.42),
             (0.74, 7.5), (0.84, 7.6), (0.9, 7.7), (0.91, 7.78), (0.88, 7.82)], "marble", segments=40,
            cap_bottom=False, cap_top=True, smooth=True)
    p.box((0, 0, 8.0), (1.8, 1.8, 0.36), "marble", bevel=0.02)
    return p


def _ionic_scale(i, j, last):
    if j in last:
        return 1.0
    return 1.0 if i % 4 in (0, 1) else 0.93


def _volute(p, center, face, r0=0.13, turns=2.4, tube=0.032, pts=30, mat="volute", sides=6, disc_segs=14):
    """A scroll on the capital's face: a tube along a shrinking spiral in
    the XZ plane at y = center.y, plus the flat disc behind it; ``face``
    -1 = the front (looks at -Y), +1 = the back."""
    cx, cy, cz = center
    path = []
    sense = 1 if cx > 0 else -1
    for i in range(pts + 1):
        t = i / pts
        a = math.pi / 2 + sense * t * turns * math.tau
        r = r0 * (1.0 - 0.78 * t)
        path.append((cx + r * math.cos(a), cy, cz + r * math.sin(a)))
    p.tube([(x, cy + face * 0.012, z) for x, _, z in path], lambda t: tube * (1.0 - 0.45 * t), mat, sides=sides)
    disc = p.lathe([(0.0, -0.02), (r0 * 0.98, -0.02), (r0 * 0.98, 0.02), (0.0, 0.02)], "volute_disc",
                   segments=disc_segs)
    p.move(disc, Matrix.Translation((cx, cy - face * 0.02, cz)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    K.sphere(p, (cx, cy + face * 0.03, cz), 0.028, mat, segments=8, rings=4)      # the eye


def ionic(light=False):
    """``light``: fewer flutes and segments (the Nereid temple's six columns)."""
    p = Part("gr_column_ionic")
    H = 7.0
    segs = 20 if light else 32
    p.box((0, 0, 0.09), (1.0, 1.0, 0.18), "grey", bevel=0.012)
    # Attic base
    p.lathe([(0.47, 0.18), (0.48, 0.2), (0.48, 0.26), (0.46, 0.29), (0.42, 0.3), (0.4, 0.33), (0.385, 0.37),
             (0.395, 0.4), (0.42, 0.42), (0.43, 0.45), (0.42, 0.48), (0.39, 0.5), (0.37, 0.52)], "marble",
            segments=segs, cap_bottom=False, cap_top=False)
    z0, z1 = 0.52, H - 0.5
    rings = 6 if light else 10
    prof = []
    for k in range(rings):
        t = k / (rings - 1)
        prof.append((0.37 - 0.055 * t * t + 0.008 * math.sin(t * math.pi), z0 + (z1 - z0) * t))
    if light:
        p.lathe(prof, "shaft", segments=16 * 3, cap_bottom=False, cap_top=False, smooth=False,
                ring_scale=lambda i, j: 1.0 if i % 3 == 0 else 0.93)
    else:
        p.lathe(prof, "shaft", segments=IONIC_FLUTES * 4, cap_bottom=False, cap_top=False, smooth=False,
                ring_scale=lambda i, j: _ionic_scale(i, j, ()))
    # astragal, egg-and-dart echinus
    p.lathe([(0.315, z1), (0.335, z1 + 0.02), (0.315, z1 + 0.045), (0.33, z1 + 0.07), (0.38, z1 + 0.13),
             (0.4, z1 + 0.2), (0.38, z1 + 0.24)], "echinus", segments=segs, cap_bottom=False, cap_top=True)
    # the volute member: a cushion slab across, scrolls front and back,
    # bolsters on the sides
    zc = z1 + 0.22
    p.box((0, 0, zc + 0.06), (0.86, 0.62, 0.12), "marble", bevel=0.025)
    for face in (-1, 1):
        for sx in (-1, 1):
            if light:
                _volute(p, (sx * 0.4, face * 0.315, zc - 0.03), face, pts=16, sides=5, disc_segs=10)
            else:
                _volute(p, (sx * 0.4, face * 0.315, zc - 0.03), face)
    for sx in (-1, 1):
        bol = p.lathe([(0.15, -0.31), (0.14, -0.2), (0.105, -0.05), (0.12, -0.02), (0.12, 0.02), (0.105, 0.05),
                       (0.14, 0.2), (0.15, 0.31)], "marble", segments=8 if light else 12, cap_bottom=False,
                      cap_top=False)
        p.move(bol, Matrix.Translation((sx * 0.4, 0.0, zc - 0.02)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    p.box((0, 0, H - 0.08), (0.92, 0.92, 0.16), "marble", bevel=0.02)
    return p


def drum():
    """A fallen drum lying along X, fluted, 1.0 m long, r 0.7."""
    p = Part("gr_drum")
    segs = DORIC_FLUTES * 3
    prof = [(0.68, -0.5), (0.69, -0.2), (0.7, 0.2), (0.7, 0.5)]
    faces = p.lathe(prof, "shaft", segments=segs, cap_bottom=True, cap_top=True, smooth=False,
                    ring_scale=lambda i, j: _doric_scale(i, j, ()))
    # a lifting boss left on the side (masons' handling knob)
    boss = p.box((0.0, 0.72, 0.1), (0.18, 0.12, 0.16), "marble", bevel=0.02)
    p.move(faces + boss, Matrix.Translation((0, 0, 0.66)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))
    return p


def capital():
    p = Part("gr_capital_doric")
    p.lathe([(0.58, 0.0), (0.6, 0.04), (0.62, 0.08), (0.74, 0.18), (0.84, 0.3), (0.9, 0.42), (0.91, 0.5),
             (0.88, 0.54)], "marble", segments=40, cap_bottom=False, cap_top=True)
    p.box((0, 0, 0.72), (1.75, 1.75, 0.36), "marble", bevel=0.02)
    # a chunk off one corner of the abacus: cut by a plane, the hole capped
    # with a fresh fracture
    import bmesh
    from mathutils import Vector
    n = Vector((1.0, -1.0, 0.7)).normalized()
    geom = p.bm.verts[:] + p.bm.edges[:] + p.bm.faces[:]
    res = bmesh.ops.bisect_plane(p.bm, geom=geom, plane_co=(0.55, -0.55, 0.75), plane_no=n, clear_outer=True)
    edges = [e for e in p.bm.edges if e.is_boundary]
    fill = bmesh.ops.holes_fill(p.bm, edges=edges, sides=0)
    for f in fill["faces"]:
        f.material_index = p.slot("break")
        f.smooth = False
    return p


# --------------------------------------------------------------------------

def _shaft(ctx, drums=1.15):
    s = GK.pentelic(ctx, seed=811, center=7.9, veins=0.5, patina=0.9, ao=3.5, cavity=0.8, grime=False)
    z = ctx.p[:, 2]
    joint = (np.abs(np.mod(z - 0.2, drums) - drums) < ctx.texel * 0.8) | (np.mod(z - 0.2, drums) < ctx.texel * 0.6)
    s.shade -= joint * 2.4
    s.height = -joint.astype(float) * 0.003
    # chipped arrises: lighter fresh marble in small bites along the flutes
    bite = (ctx.fbm(6.0, 3, 813) > 0.42) & (ctx.rand(814) > 0.3)
    s.shade += bite * 0.8
    return s


def _drum_shaft(ctx):
    s = GK.pentelic(ctx, seed=821, center=7.6, veins=0.5, patina=1.1, ao=3.5, cavity=0.8, grime=False)
    end = np.abs(ctx.n[:, 0]) > 0.9
    fresh = end & (ctx.p[:, 0] > 0)
    s.use_ramp(GK.P["gr_break"], mask=fresh, shade=3.5 + (ctx.rand(822) - 0.5) * 2.2 + ctx.fbm(9.0, 2, 823) * 1.2)
    s.height = np.where(fresh, ctx.fbm(14.0, 3, 824) * 0.01, 0.0)
    s.rough = np.where(fresh, 0.9, s.rough)
    return s


def _echinus(ctx):
    z = ctx.p[:, 2]
    u = ctx.uvm[:, 0]
    v = ctx.uvm[:, 1]
    band = (v > 0.07) & (v < 0.2)
    h, egg, shell, dart = O.egg_dart(u, np.clip(v - 0.07, 0, None), 0.13, period=0.16, depth=0.012)
    h = np.where(band, h, 0.0)
    s = O.carved_marble(ctx, h, 831, center=7.8)
    s.shade += (egg & band) * 1.0 - (shell & band) * 1.4
    GK.paint_traces(ctx, s, "gr_blue", (shell | dart) & band, 833, center=2.8, density=0.7, freq=2.0)
    return s


def _volute_paint(ctx):
    s = GK.pentelic(ctx, seed=841, center=8.0, veins=0.3, patina=0.8, ao=4.0, grime=False)
    return s


def _volute_disc(ctx):
    """The scroll's channel: recessed, in shadow, a trace of ochre."""
    s = GK.pentelic(ctx, seed=845, center=5.8, veins=0.3, patina=0.8, ao=4.0, grime=False)
    GK.paint_traces(ctx, s, "gr_ochre", np.ones(ctx.N, bool), 843, center=3.4, density=0.5, freq=4.0)
    return s


def _marble(ctx):
    return GK.pentelic(ctx, seed=851, center=7.8, veins=0.5, patina=0.9, ao=3.5, cavity=1.2, grime=False)


def _grey(ctx):
    return GK.grey_marble(ctx, seed=861, center=4.6)


def _break(ctx):
    s = GK.pentelic(ctx, seed=871, center=7.0, veins=0.2, patina=0.0, ao=3.0)
    s.use_ramp(GK.P["gr_break"], shade=3.5 + (ctx.rand(872) - 0.5) * 2.4 + ctx.fbm(9.0, 2, 873) * 1.0)
    s.rough[:] = 0.9
    s.height = ctx.fbm(14.0, 3, 874) * 0.008
    return s


def build():
    fns = {"shaft": _shaft, "marble": _marble, "grey": _grey, "echinus": _echinus, "volute": _volute_paint, "volute_disc": _volute_disc,
           "break": _break}
    return [
        kit("gr_column_doric", [doric()], fns, ao_dist=0.6, preview_extra=[("capital", (0, 0, 7.6), 1.4, 20.0, -10.0)]),
        kit("gr_column_ionic", [ionic()], fns, ao_dist=0.4, preview_extra=[("capital", (0, 0, 6.5), 0.75, 25.0, -5.0)]),
        kit("gr_drum", [drum()], dict(fns, shaft=_drum_shaft), ao_dist=0.5),
        kit("gr_capital_doric", [capital()], fns, ao_dist=0.5),
    ]
