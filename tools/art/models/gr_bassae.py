"""Greek kit: the frieze of the temple of Apollo at Bassae (Bassae room, on
the mezzanine): deeper, wilder relief than the Parthenon's - Greeks fight
Amazons, Lapiths fight centaurs, cloaks whirl. A wall band like
gr_frieze_* (relief baked into the face at 128 px/m with its height in the
normal map), 0.64 m of relief.

  gr_bassae_2m        2 m module; texture sets gr_bassae_2m (Amazonomachy:
                      a hoplite lunges at an Amazon, a mounted Amazon wheels
                      round), _b (an Amazon falls from her horse, a Greek
                      drags another down), _c (Centauromachy: a centaur
                      rears over a Lapith behind his shield, another bites
                      a Lapith's shoulder)
  gr_bassae_1m  1 m plain slab for fitting runs

Run convention: x = -W/2 .. W/2, wall plane z = 0, room side -Z; origin =
bottom edge of the band (place it at ~1.2 m above the mezzanine floor).
Band 0.78 m: fillet 0..0.05, relief 0.05..0.69, crown to 0.78.
"""
from artlib import greek as GK
from artlib import greek_figures as G
from artlib import relief as RL
from artlib.archkit import facing, kit
from artlib.geo import Part
from artlib.relief import Frame

PPM = 128
RELIEF_H = 0.64
Z0 = 0.05
D = 0.1
S = 0.64          # figure scale
GR = 0.03         # ground line in the relief
ZD = 0.085        # relief depth at scale 1 (deeper than the Parthenon)


def _warrior(R, x, pose, face=1, shield=True, helmet="crest", dress="chiton", z=ZD):
    F = Frame(x, GR, S, face=face)
    lids, j = G.human(R, F, pose, z=z, dress=dress, helmet=helmet)
    if shield:
        G.round_shield(R, F, (j["el_f"][0] + 0.03, j["el_f"][1] + 0.02), r=0.15, z=z * 1.15)
    return j, F


def _amazon(R, x, pose, face=1, pelta=True, z=ZD):
    F = Frame(x, GR, S, face=face)
    lids, j = G.human(R, F, pose, z=z, dress="chiton", helmet="cap", female=True)
    if pelta:
        G.pelta(R, F, (j["el_f"][0] + 0.02, j["el_f"][1] + 0.02), r=0.12, z=z * 1.12)
    # the axe (sagaris) in the near hand
    G.spear(R, F, j["hand_n"], (j["hand_n"][0] + 0.02, j["hand_n"][1] + 0.22), z=z * 1.1)
    return j, F


def _cut(R, seed):
    R.chips(5, seed=seed, y_band=(0.05, 0.6), size=(0.01, 0.03))
    R.joints([1.0], seed=seed)


def amazons(W=2.0, seed=41):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.horse(R, Frame(0.32, GR, S), gait="rear", pitch=24, z=ZD * 0.8,
            rider=G.rider(z=ZD * 0.95, dress="chiton", arm_up=True))
    _warrior(R, 0.95, G.walk(1.6, lean=18, sh_n=100, el_n=95, sh_f=80, el_f=120, hip_n=50, hip_f=-45, knee_f=-40),
             face=1)
    _amazon(R, 1.55, G.walk(1.3, lean=-14, sh_n=150, el_n=170, sh_f=70, el_f=110), face=-1)
    _cut(R, seed)
    return R.finish()


def amazon_falls(W=2.0, seed=42):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.horse(R, Frame(0.45, GR, S), gait="gallop", z=ZD * 0.8)
    F = Frame(0.42, 0.28, S, face=1, rot=-55, pivot=(0.0, 0.46))
    G.human(R, F, G.walk(0.8, sh_n=150, el_n=150, sh_f=120, el_f=140), z=ZD, dress="chiton", helmet="cap",
            female=True)
    _warrior(R, 1.2, G.walk(1.3, lean=12, sh_n=60, el_n=40, sh_f=110, el_f=130), face=1, dress="chlamys")
    _amazon(R, 1.72, G.walk(1.0, lean=-25, sh_n=170, el_n=200, sh_f=40, el_f=60, hip_n=20, hip_f=-50), face=-1,
            pelta=False)
    _cut(R, seed)
    return R.finish()


def centaurs(W=2.0, seed=43):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    G.centaur(R, Frame(0.35, GR, S), z=ZD * 0.9, pose="rear", arm_up=True,
              arm_kw=dict(sh_n=130, el_n=160, sh_f=110, el_f=150))
    _warrior(R, 0.95, G.walk(1.2, lean=20, sh_n=40, el_n=20, sh_f=100, el_f=110, hip_n=60, knee_n=-10,
                              hip_f=-30, knee_f=-60), face=-1, helmet=None, dress="nude")
    G.centaur(R, Frame(1.62, GR, S, face=-1), z=ZD * 0.95, pose="walk", arm_up=False,
              arm_kw=dict(sh_n=70, el_n=100, sh_f=60, el_f=110, lean=30))
    G.human(R, Frame(1.15, GR, S, face=1), G.walk(1.1, lean=-20, sh_n=140, el_n=180, sh_f=-30, el_f=10), z=ZD * 1.05,
            dress="chlamys")
    _cut(R, seed)
    return R.finish()


def blank(W=1.0, seed=44):
    R = RL.Relief(W, RELIEF_H, PPM, seed=seed)
    R.chips(8, seed=seed, y_band=(0.02, 0.62), size=(0.02, 0.05))
    return R.finish()


SETS = {"gr_bassae_2m": amazons, "gr_bassae_2m_b": amazon_falls, "gr_bassae_2m_c": centaurs}


def band(name, W):
    p = Part(name)
    hw = W / 2
    p.extrude([(0.0, 0.0), (-0.08, 0.0), (-0.08, 0.025), (-0.11, 0.04), (-0.11, Z0), (0.0, Z0)], -hw, hw, "marble",
              caps=False)
    facing(p, [(-hw, -D, Z0), (hw, -D, Z0), (hw, -D, Z0 + RELIEF_H), (-hw, -D, Z0 + RELIEF_H)], "relief", (0, -1, 0))
    facing(p, [(-hw, -D, Z0), (hw, -D, Z0), (hw, 0.0, Z0), (-hw, 0.0, Z0)], "marble", (0, 0, -1))
    top = Z0 + RELIEF_H
    p.extrude([(-D, top), (-D - 0.02, top), (-D - 0.02, top + 0.03), (-D - 0.045, top + 0.06),
               (-D - 0.045, top + 0.09), (0.0, top + 0.09)], -hw, hw, "marble", caps=False)
    return p


def _relief_fn(maps, W, seed):
    def fn(ctx):
        u = -ctx.p[:, 0] + W / 2
        v = ctx.p[:, 2] - Z0
        return GK.relief_surface(ctx, maps, u, v, seed=seed, blue=0.5)
    return fn


def _marble(ctx):
    # Bassae was built of grey local limestone, the frieze of marble:
    # the band's mouldings in the warmer stone
    return GK.pentelic(ctx, seed=1101, center=7.0, veins=0.4, patina=1.3)


def build():
    maps = {n: fn() for n, fn in SETS.items()}
    names = list(SETS)
    m = kit(names[0], [band(names[0], 2.0)], {"marble": _marble, "relief": _relief_fn(maps[names[0]], 2.0, 1103)},
            ppm=PPM, wall=True, ground=None, ao_dist=0.2, normal_strength=1.5,
            preview_extra=[("face", (0.0, 0.2, 0.37), 0.55, 0.0, 4.0)])
    m.variants = {n: {"marble": _marble, "relief": _relief_fn(maps[n], 2.0, 1103 + k)}
                  for k, n in enumerate(names[1:], start=1)}
    return [m, kit("gr_bassae_1m", [band("gr_bassae_1m", 1.0)],
                   {"marble": _marble, "relief": _relief_fn(blank(), 1.0, 1109)}, ppm=PPM, wall=True, ground=None,
                   ao_dist=0.2, normal_strength=1.5, preview=False)]
