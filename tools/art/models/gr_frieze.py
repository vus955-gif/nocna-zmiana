"""Greek kit: the Parthenon frieze as a wall band.

The frieze (1 m of relief, about 5 cm deep at most) runs round the walls of
the Parthenon Gallery at eye level and above. Each module is a marble slab
standing 12 cm proud of the wall on a small fillet, with a crown moulding;
the relief itself is carved in 2D layers (artlib/relief.py, figures in
artlib/greek_figures.py), baked into the slab face at 128 px/m with its
height in the normal map: horsemen of the cavalcade, a youth with a rearing
horse, a chariot with an armed apobates, heifers led to sacrifice, water
carriers and lyre players, maidens with phialai. The damage of the
originals is carved too: lost heads, broken legs, chipped arrises, slab
joints, and the traces of paint (Egyptian blue on the background, ochre on
manes and harness, red in the folds).

  gr_frieze_4m           4 m module; texture sets gr_frieze_4m (cavalcade),
                         _b (preparation: rearing horse, marshal), _c
                         (chariot), _d (heifers to sacrifice), _e (water
                         carriers and kitharists), _f (maidens, marshals)
  gr_frieze_2m           2 m module; sets gr_frieze_2m (two riders), _b (a
                         youth holding his horse), _c (elders talking)
  gr_frieze_1m           1 m / 0.5 m: a plain slab (a lost piece of the
  gr_frieze_05m          frieze), for fitting runs

Run convention (as the lobby kit): x = -W/2 .. W/2, wall plane z = 0,
decoration on the room side (-Z); origin = bottom edge of the band (place it
at the frieze height, 1.45 m in the gallery). Band 1.19 m tall: fillet
0..0.06, relief 0.06..1.06, crown to 1.19; 0.18 m deep at the crown.
"""
import numpy as np

from artlib import greek as GK
from artlib import greek_figures as G
from artlib import relief as RL
from artlib.archkit import kit
from artlib.geo import Part
from artlib.relief import Frame

PPM = 128
RELIEF_H = 1.0
Z0 = 0.06                 # bottom of the relief face above the band's origin
D = 0.12                  # slab face in front of the wall
GROUND = 0.035            # figures stand on this line of the relief


# --------------------------------------------------------------------------
# compositions (relief metres: x right, y up, 0..W x 0..1)
# --------------------------------------------------------------------------

def _damage(R, seed, heads=(), limbs=(), joints=(), chips=10):
    for (x, y, r) in heads:
        R.break_off(R.ell((x, y + 0.01), r * 1.05, r * 1.15), seed=seed + int(x * 10), frac=0.3, jag=0.4)
    for (x, y, rx, ry, rot) in limbs:
        R.break_off(R.ell((x, y), rx, ry, rot), seed=seed + int(y * 10), frac=0.15, jag=0.5)
    R.chips(chips, seed=seed, y_band=(0.1, 0.98))
    R.joints(joints, seed=seed)


def cavalcade(W=4.0, seed=1):
    """Five riders overlapping in depth, the nearest the most raised."""
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    riders = [(0.42, 0.026, "canter", dict(hat=True)), (0.98, 0.034, "gallop", {}),
              (1.62, 0.042, "canter", dict(beard=True)), (2.38, 0.05, "gallop", dict(hat=True)),
              (3.12, 0.055, "canter", {})]
    for k, (x, z, gait, kw) in enumerate(riders):
        G.horse(R, Frame(x, GROUND, 1.0), gait=gait, z=z, head_up=0.015 * (k % 2), tail_up=0.03 * (k % 3),
                rider=G.rider(z=z * 1.2, **kw))
    _damage(R, seed, heads=[(1.0, 0.88, 0.055)], limbs=[(3.5, 0.18, 0.06, 0.12, 30)], joints=[1.31, 2.66])
    return R.finish()


def preparation(W=4.0, seed=2):
    """West frieze: a youth restrains a rearing horse, a marshal in his
    mantle gives a sign, a rider waits on a standing horse."""
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.horse(R, Frame(0.55, GROUND, 1.0), gait="stand", z=0.035, rider=G.rider(z=0.045, beard=True,
                                                                               pose_kw=dict(sh_n=10, el_n=60)))
    G.human(R, Frame(1.25, GROUND, 1.0), G.walk(0.3, sh_n=-160, el_n=-170, lean=-4), z=0.05, dress="himation",
            beard=True, extra=G.staff)
    G.horse(R, Frame(2.15, GROUND, 1.0), gait="rear", pitch=26, z=0.045, head_up=0.03)
    G.human(R, Frame(2.78, GROUND, 1.0, face=-1), G.walk(1.2, lean=-16, sh_n=125, el_n=100, sh_f=110, el_f=95),
            z=0.058, dress="chlamys")
    G.human(R, Frame(3.55, GROUND, 1.0), G.walk(0.5, sh_n=40, el_n=95), z=0.05, dress="chiton")
    _damage(R, seed, heads=[(3.55, 0.86, 0.05)], limbs=[(2.6, 0.62, 0.05, 0.04, 0)], joints=[1.05, 2.45])
    return R.finish()


def chariot_scene(W=4.0, seed=3):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.human(R, Frame(0.3, GROUND, 1.0), G.walk(0.6, sh_n=30, el_n=70), z=0.04, dress="himation", beard=True)
    G.chariot(R, Frame(1.2, GROUND, 1.0), z=0.05)
    G.human(R, Frame(2.95, GROUND, 1.0, face=-1), G.walk(0.4, sh_n=120, el_n=150), z=0.052, dress="himation",
            beard=True)
    G.horse(R, Frame(3.55, GROUND, 1.0), gait="walk", z=0.04, rider=G.rider(z=0.05, hat=True))
    _damage(R, seed, heads=[(1.21, 0.86, 0.05)], limbs=[(1.75, 0.35, 0.05, 0.08, 20)], joints=[1.45, 2.78])
    return R.finish()


def sacrifice(W=4.0, seed=4):
    """Heifers led to sacrifice; the second raises her head and lows."""
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.human(R, Frame(0.3, GROUND, 1.0), G.walk(0.7), z=0.04, dress="himation")
    G.cow(R, Frame(0.88, GROUND, 1.0), z=0.042)
    G.human(R, Frame(1.12, GROUND, 1.0), G.walk(0.9, lean=6, sh_n=40, el_n=70), z=0.03, dress="himation")
    G.human(R, Frame(1.68, GROUND, 1.0), G.walk(1.1, lean=8, sh_n=-40, el_n=-20, sh_f=60, el_f=40), z=0.055,
            dress="chlamys")
    G.cow(R, Frame(2.45, GROUND, 1.0), z=0.048, head_up=True)
    G.human(R, Frame(3.2, GROUND, 1.0, face=-1), G.walk(1.3, lean=-16, sh_n=95, el_n=80, sh_f=75, el_f=60),
            z=0.055, dress="chlamys")
    G.human(R, Frame(3.7, GROUND, 1.0), G.walk(0.5), z=0.035, dress="himation", beard=True)
    _damage(R, seed, heads=[(1.68, 0.87, 0.05), (3.7, 0.86, 0.05)], limbs=[(0.85, 0.18, 0.08, 0.05, 0)],
            joints=[1.4, 2.62, 3.48])
    return R.finish()


def carriers(W=4.0, seed=5):
    """Water carriers with hydriai on their shoulders, then two kitharists."""
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    for k, x in enumerate((0.3, 0.75, 1.2, 1.65)):
        G.human(R, Frame(x, GROUND, 1.0), G.walk(0.6 + 0.2 * (k % 2), sh_n=168, el_n=232, lean=-3),
                z=0.04 + 0.006 * k, dress="himation" if k % 2 else "chiton", extra=G.carry_vase)
    for k, x in enumerate((2.35, 2.9)):
        G.human(R, Frame(x, GROUND, 1.0), G.walk(0.4, sh_n=10, el_n=60, sh_f=40, el_f=110), z=0.05,
                dress="long", extra=G.kithara)
    G.human(R, Frame(3.6, GROUND, 1.0, face=-1), G.walk(0.3, sh_n=100, el_n=120), z=0.05, dress="himation",
            beard=True, extra=G.staff)
    _damage(R, seed, heads=[(0.75, 0.86, 0.05), (2.9, 0.87, 0.05)], joints=[1.42, 3.2])
    return R.finish()


def maidens(W=4.0, seed=6):
    """East frieze: maidens in peplos carrying phialai and jugs, met by
    marshals."""
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    for k, x in enumerate((0.3, 0.74, 1.18, 1.62, 2.06, 2.5)):
        arm = dict(sh_n=12, el_n=75, sh_f=-8, el_f=5) if k % 2 else dict(sh_n=-5, el_n=40, sh_f=10, el_f=60)
        G.human(R, Frame(x, GROUND, 1.0), G.walk(0.35, head=-8, **arm),
                z=0.04 + 0.004 * (k % 3), dress="peplos", female=True,
                extra=G.hold_phiale if k % 2 else G.hold_jug)
    G.human(R, Frame(3.05, GROUND, 1.0, face=-1), G.walk(0.2, sh_n=110, el_n=130), z=0.05, dress="himation",
            beard=True, extra=G.staff)
    G.human(R, Frame(3.55, GROUND, 1.0, face=-1), G.walk(0.2, sh_n=20, el_n=40), z=0.045, dress="himation",
            beard=True)
    _damage(R, seed, heads=[(1.14, 0.86, 0.05), (1.98, 0.86, 0.05), (3.55, 0.87, 0.05)],
            limbs=[(2.4, 0.55, 0.06, 0.04, 0)], joints=[0.92, 2.2, 3.3])
    return R.finish()


def two_riders(W=2.0, seed=7):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.horse(R, Frame(0.5, GROUND, 1.0), gait="gallop", z=0.036, rider=G.rider(z=0.044, hat=True))
    G.horse(R, Frame(1.25, GROUND, 1.0), gait="canter", z=0.05, rider=G.rider(z=0.06, beard=True))
    _damage(R, seed, joints=[1.0], chips=6)
    return R.finish()


def youth_and_horse(W=2.0, seed=8):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.horse(R, Frame(0.85, GROUND, 1.0), gait="stand", z=0.045, head_up=0.04)
    G.human(R, Frame(1.62, GROUND, 1.0, face=-1), G.walk(0.5, sh_n=55, el_n=75, sh_f=-20, el_f=10), z=0.056,
            dress="chlamys")
    _damage(R, seed, heads=[(1.62, 0.87, 0.05)], joints=[0.62], chips=6)
    return R.finish()


def elders(W=2.0, seed=9):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.human(R, Frame(0.6, GROUND, 1.0), G.walk(0.2, sh_n=70, el_n=110), z=0.05, dress="himation", beard=True,
            extra=G.staff)
    G.human(R, Frame(1.35, GROUND, 1.0, face=-1), G.walk(0.3, sh_n=20, el_n=60), z=0.048, dress="himation",
            beard=True)
    _damage(R, seed, joints=[1.0], chips=6)
    return R.finish()


def blank(W, seed=10):
    """A lost slab: the plain dressed face, chipped, with a few stumps."""
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    R.chips(int(6 * W), seed=seed, y_band=(0.02, 0.98), size=(0.02, 0.06))
    return R.finish()


SETS_4 = {"gr_frieze_4m": cavalcade, "gr_frieze_4m_b": preparation, "gr_frieze_4m_c": chariot_scene,
          "gr_frieze_4m_d": sacrifice, "gr_frieze_4m_e": carriers, "gr_frieze_4m_f": maidens}
SETS_2 = {"gr_frieze_2m": two_riders, "gr_frieze_2m_b": youth_and_horse, "gr_frieze_2m_c": elders}


# --------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------

def _slab_faces(p, x0, x1, y0, y1, z0, z1, front, other):
    """Box faces seen from the room (no back face against the wall); the
    front face (y = y0, toward the viewer) on its own slot."""
    from artlib.archkit import facing
    facing(p, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], front, (0, -1, 0))
    facing(p, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], other, (0, 0, 1))
    facing(p, [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], other, (0, 0, -1))


def band(name, W):
    p = Part(name)
    hw = W / 2
    # lower fillet and cavetto on the wall
    p.extrude([(0.0, 0.0), (-0.1, 0.0), (-0.1, 0.03), (-0.13, 0.045), (-0.13, Z0), (0.0, Z0)], -hw, hw, "marble",
              caps=False)
    _slab_faces(p, -hw, hw, -D, 0.0, Z0, Z0 + RELIEF_H, "relief", "marble")
    # crown: taenia, cyma reversa, projecting fillet
    top = Z0 + RELIEF_H
    p.extrude([(-D, top), (-D - 0.025, top), (-D - 0.025, top + 0.035), (-D - 0.04, top + 0.06),
               (-D - 0.06, top + 0.09), (-D - 0.06, top + 0.13), (0.0, top + 0.13)], -hw, hw, "marble", caps=False)
    return p


def _relief_fn(maps, W, seed):
    def fn(ctx):
        u = -ctx.p[:, 0] + W / 2          # the band is turned: the viewer's right is -x
        v = ctx.p[:, 2] - Z0
        return GK.relief_surface(ctx, maps, u, v, seed=seed)
    return fn


def _marble(ctx):
    return GK.pentelic(ctx, seed=411, center=7.0)


def build():
    out = []
    for W, sets, tag in ((4.0, SETS_4, "4m"), (2.0, SETS_2, "2m")):
        names = list(sets)
        maps = {n: sets[n](W) for n in names}
        base = names[0]
        m = kit(base, [band(base, W)], {"marble": _marble, "relief": _relief_fn(maps[base], W, 503)}, ppm=PPM,
                wall=True, ground=None, ao_dist=0.25, normal_strength=1.4,
                preview_extra=[("face", (0.0, 0.3, 0.6), 0.75, 0.0, 4.0)])
        m.variants = {n: {"marble": _marble, "relief": _relief_fn(maps[n], W, 503 + k)} for k, n in
                      enumerate(names[1:], start=1)}
        out.append(m)
    for W, tag in ((1.0, "1m"), (0.5, "05m")):
        name = "gr_frieze_" + tag
        out.append(kit(name, [band(name, W)], {"marble": _marble, "relief": _relief_fn(blank(W), W, 509)},
                       ppm=PPM, wall=True, ground=None, ao_dist=0.25, normal_strength=1.4, preview=False))
    return out
