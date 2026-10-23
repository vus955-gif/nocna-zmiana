"""Floor I's roof: the lantern on the Reading Room's leaded outer dome (the
roof's landmark under its red warning lamp).

  rr_dome_lantern        a lead-covered curb on the dome's crown, sixteen
                         cast-iron mullions round a glazed drum with a
                         transom ring, a moulded iron entablature with
                         brackets under a bell-shaped lead cupola with its
                         seams rolled, a ball finial and the lightning
                         rod's spire; inside, the oculus' glass lit warm
                         from the Reading Room below (a faint emission).
  rr_dome_lantern_glass  the drum's panes (exported as "glass").

3.6 x 2.45 x 3.6 m (Godot x, y, z), the origin on the dome's crown (the
roof module stands it there, under the greybox lantern's box: that box is
only its unreachable collision). 64 px/m: it is seen from the catwalks,
8-25 m off.
"""
import math

import numpy as np
from mathutils import Matrix

from artlib import court_materials as CM
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part
from artlib.materials import P, _dither, smoothstep

R = 1.55                 # the mullions' circle
POSTS = 16
CURB = 0.22
GLASS_TOP = 1.46
ENT = 1.66               # the entablature's top
EAVE = 1.8               # the cupola's eave radius
SPIRE = 2.5              # under the warning lamp (2.65 over the crown)


def _ring(p, prof, mat, segments=32):
    return p.lathe(prof, mat, segments=segments, cap_bottom=False, cap_top=False, smooth=False)


def lantern():
    p = Part("rr_dome_lantern")
    g = Part("rr_dome_lantern_glass")
    # the curb on the crown: lead over timber, a roll at its top
    _ring(p, [(R + 0.12, 0.0), (R + 0.12, CURB - 0.04), (R + 0.15, CURB - 0.02), (R + 0.12, CURB), (R - 0.05, CURB)],
          "lead")
    # the lantern's ceiling over the drum, lit warm from the Reading Room
    # below (what the panes show from the catwalks); a dark floor
    for z, mat, up in ((GLASS_TOP + 0.005, "glow", False), (CURB - 0.02, "iron", True)):
        disc = p.lathe([(R - 0.035, z), (0.0, z)], mat, segments=16, cap_bottom=False, cap_top=False)
        for f in disc:
            f.normal_update()
            if (f.normal.z > 0) != up:
                f.normal_flip()
    # mullions with a sill and a transom ring between them
    for k in range(POSTS):
        a = math.tau * k / POSTS
        x, y = R * math.cos(a), R * math.sin(a)
        f = p.box((0.0, 0.0, (CURB + ENT - 0.18) / 2), (0.07, 0.09, ENT - 0.18 - CURB), "iron")
        p.move(f, Matrix.Translation((x, y, 0.0)) @ Matrix.Rotation(a, 4, 'Z'))
        # a bracket under the eaves over each mullion
        f = p.box((0.0, 0.0, 0.0), (0.14, 0.06, 0.1), "iron")
        p.move(f, Matrix.Translation(((R + 0.12) * math.cos(a), (R + 0.12) * math.sin(a), ENT - 0.02))
               @ Matrix.Rotation(a, 4, 'Z'))
    _ring(p, [(R + 0.05, CURB), (R + 0.05, CURB + 0.06), (R - 0.03, CURB + 0.06)], "iron")
    _ring(p, [(R + 0.045, 0.8), (R + 0.045, 0.85), (R - 0.03, 0.85), (R - 0.03, 0.8), (R + 0.045, 0.8)], "iron")
    # the entablature: architrave, frieze, cornice
    _ring(p, [(R - 0.04, GLASS_TOP), (R + 0.06, GLASS_TOP), (R + 0.06, GLASS_TOP + 0.08), (R + 0.04, GLASS_TOP + 0.09),
              (R + 0.04, ENT - 0.06), (R + 0.16, ENT - 0.02), (R + 0.2, ENT)], "iron")
    # the bell cupola in lead: from the eave up to the finial's neck
    bell = [(R + 0.2, ENT), (EAVE, ENT + 0.02), (EAVE - 0.05, ENT + 0.06)]
    for k in range(1, 7):
        t = k / 6.0
        r = (EAVE - 0.05) * (1.0 - t) ** 1.25 + 0.12 * t
        z = ENT + 0.06 + 0.48 * (math.sin(t * math.pi * 0.5)) ** 0.8
        bell.append((r, z))
    p.lathe(bell + [(0.0, bell[-1][1] + 0.01)], "cupola", segments=32, cap_bottom=False, cap_top=False, smooth=True)
    zt = bell[-1][1]
    # the finial: a neck, a ball, the spire (the lightning rod)
    K.seg(p, (0.0, 0.0, zt - 0.02), (0.0, 0.0, zt + 0.08), [(0.12, 0.0), (0.06, 0.5), (0.08, 1.0)], "iron", segments=10)
    K.sphere(p, (0.0, 0.0, zt + 0.15), 0.08, "gilt", segments=10, rings=6)
    K.seg(p, (0.0, 0.0, zt + 0.21), (0.0, 0.0, SPIRE), [(0.02, 0.0), (0.01, 0.8), (0.0, 1.0)], "iron", segments=6)
    # the panes, a hair inside the mullions
    for k in range(POSTS):
        a0, a1 = math.tau * k / POSTS, math.tau * (k + 1) / POSTS
        r = R - 0.01
        vs = [g.bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a, z in
              ((a0, CURB + 0.06), (a1, CURB + 0.06), (a1, GLASS_TOP), (a0, GLASS_TOP))]
        f = g._face(vs, "glass")
        f.normal_update()
        c = f.calc_center_median()
        if f.normal.dot(c.to_2d().to_3d()) < 0:
            f.normal_flip()
    return [p, g]


# --------------------------------------------------------------------------
# paint
# --------------------------------------------------------------------------

def cupola(ctx):
    """Lead in bays with rolled seams every sixteenth, white oxide bloom
    washed down from the rolls, darker toward the eave."""
    s = CM.lead(ctx, 1311)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    a = np.mod(np.arctan2(y, x) / (math.tau / POSTS), 1.0)
    roll = np.abs(a - 0.5) > 0.47
    shadow = (a > 0.03) & (a < 0.08)
    s.shade = np.where(roll, s.shade + 1.8, np.where(shadow, s.shade - 1.2, s.shade))
    s.height = s.height + roll * 0.002
    bloom = (ctx.fbm(np.array([14.0, 14.0, 2.0]), 2, 1313) > 0.3) & ~roll
    s.shade = np.where(bloom, s.shade + 1.0, s.shade)
    s.shade -= smoothstep(ENT + 0.25, ENT, z) * 0.8
    return s


def iron(ctx):
    """Painted cast iron gone dull, rust at the joints, bird lime."""
    s = CM.cast_iron(ctx, 1321, center=4.0)
    from artlib import roof_materials as RM
    RM.droppings(ctx, s, amount=0.6, seed=1323)
    return s


def glow(ctx):
    """The lantern's ceiling seen through the panes: painted boards in a
    faint warm light from the oculus below, the iron ribs dark."""
    s = M.glow(ctx, "lamp_warm", 2.2, strength=0.45, seed=1331)
    x, y = ctx.p[:, 0], ctx.p[:, 1]
    a = np.mod(np.arctan2(y, x) / (math.tau / POSTS), 1.0)
    rib = (np.abs(a - 0.5) > 0.46) | (np.abs(np.hypot(x, y) - 0.6) < 0.03)
    s.use_ramp(P["lead"], mask=rib, shade=np.full(ctx.N, 1.0))
    s.emit = np.where(rib[:, None], 0.0, s.emit)
    return s


LANTERN_FNS = {
    "lead": lambda c: CM.lead(c, 1341), "cupola": cupola, "iron": iron, "glow": glow,
    "gilt": lambda c: M.gold(c, 1343),
}


def build():
    return [kit("rr_dome_lantern", lantern(), LANTERN_FNS, kinds={"glass": "glass"}, ppm=64, built_final=True,
                ground=None, ao_dist=0.4, ao_rays=10, ao_stride=2, preview_yaws=(-35.0, 35.0, 145.0, 215.0),
                preview_elevation=20.0)]
