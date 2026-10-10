"""Lobby kit, main hall: the balcony (y = 6, slab 5.6-6.0, 4 m deep).

  balcony_fascia_{4m,2m,1m}  the slab's edge toward the hall: an
                        entablature 0.8 m tall (two fasciae, frieze, cornice
                        lip) with a 0.15 m beam returning under the slab.
                        Origin at its TOP on the slab edge (datum = the
                        balcony floor, y = 6); decoration on -Z (the hall).
  balcony_fascia_end    0.25 m of the same with closed ends: put it where
                        a fascia run stops in the air (the stair tops).
  balustrade_{2m,1m}    stone balustrade 1.1 m: moulded base rail, vase
                        balusters every 0.25 m, handrail. Symmetric; origin
                        = centre of the base on the railing's centre line.
  balustrade_pedestal   0.46 m pier with a ball finial (1.5 m): at run ends
                        and every 4 m.
  balcony_pier          the posts under the balcony edge (kit id
                        "balcony_post", 0.6 x 5.6): base, panelled shaft,
                        moulded capital with a console. Origin = base centre.
"""
from artlib import arch_materials as A
from artlib import materials as M
from artlib.archkit import kit, moulding
from artlib.geo import Part

FASCIA = [(0.15, -0.4), (0.15, -0.8), (-0.03, -0.8), (-0.03, -0.64), (-0.05, -0.62), (-0.05, -0.47),
          (-0.08, -0.44), (-0.08, -0.4), (-0.05, -0.38), (-0.05, -0.18), (-0.08, -0.16), (-0.12, -0.12),
          (-0.16, -0.1), (-0.16, -0.04), (-0.13, -0.02), (-0.1, 0.0), (0.0, 0.0)]
BALUSTER = [(0.0, 0.0), (0.06, 0.0), (0.06, 0.04), (0.045, 0.06), (0.05, 0.1), (0.068, 0.2), (0.07, 0.28),
            (0.06, 0.38), (0.042, 0.48), (0.034, 0.56), (0.04, 0.6), (0.052, 0.63), (0.052, 0.68),
            (0.06, 0.7), (0.06, 0.75), (0.0, 0.75)]


def fascia(W, caps=False):
    p = Part("balcony_fascia")
    if caps:
        p.extrude(FASCIA, -W / 2, W / 2, "limestone", caps=True)
    else:
        moulding(p, FASCIA, W, "limestone")
    # small drops under the lower fascia (guttae), one per 0.5 m
    n = max(1, int(round(W / 0.5)))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        p.box((x, -0.06, -0.415), (0.1, 0.045, 0.05), "limestone", bevel=0.01)
    return p


def balustrade(W):
    p = Part("balustrade")
    p.box((0, 0, 0.07), (W, 0.28, 0.14), "limestone", bevel=0.02)
    p.box((0, 0, 0.16), (W, 0.22, 0.05), "limestone", bevel=0.012)
    n = int(round(W / 0.25))
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        p.lathe(BALUSTER, "limestone", segments=8, center=(x, 0.0, 0.18), cap_bottom=False)
    p.box((0, 0, 0.955), (W, 0.2, 0.05), "limestone", bevel=0.012)
    p.box((0, 0, 1.03), (W, 0.26, 0.12), "limestone", bevel=0.035)
    return p


def pedestal():
    p = Part("balustrade_pedestal")
    p.box((0, 0, 0.1), (0.5, 0.5, 0.2), "limestone", bevel=0.02)
    p.box((0, 0, 0.6), (0.44, 0.44, 0.8), "limestone", bevel=0.02)
    p.box((0, 0, 0.62), (0.46, 0.46, 0.5), "panel", bevel=0.015)
    p.box((0, 0, 1.06), (0.52, 0.52, 0.12), "limestone", bevel=0.03)
    p.lathe([(0.0, 1.12), (0.14, 1.12), (0.14, 1.15), (0.08, 1.18), (0.07, 1.22), (0.1, 1.26), (0.13, 1.32),
             (0.13, 1.38), (0.1, 1.44), (0.05, 1.47), (0.0, 1.48)], "limestone", segments=12, cap_bottom=False)
    return p


def pier():
    p = Part("balcony_pier")
    p.box((0, 0, 0.1), (0.78, 0.78, 0.2), "marble_dark", bevel=0.015)
    p.box((0, 0, 0.35), (0.72, 0.72, 0.3), "limestone", bevel=0.02)
    p.box((0, 0, 0.52), (0.66, 0.66, 0.05), "limestone", bevel=0.012)
    p.box((0, 0, 2.7), (0.6, 0.6, 4.3), "limestone", bevel=0.015)
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        w = (0.04 if sx else 0.42, 0.04 if sy else 0.42, 3.6)
        p.box((sx * 0.3, sy * 0.3, 2.65), w, "panel", bevel=0.01)
    p.box((0, 0, 4.9), (0.7, 0.7, 0.06), "limestone", bevel=0.015)
    p.box((0, 0, 5.02), (0.64, 0.64, 0.18), "limestone", bevel=0.015)
    p.box((0, 0, 5.2), (0.78, 0.78, 0.18), "limestone", bevel=0.03)
    p.box((0, 0, 5.47), (0.9, 0.9, 0.26), "limestone", bevel=0.03)
    return p


def _panel(ctx):
    s = A.limestone(ctx)
    s.shade -= 0.7
    return s


def build():
    fns = {"limestone": A.limestone, "marble_dark": M.marble_dark, "panel": _panel}
    out = []
    for W, tag in ((4.0, "4m"), (2.0, "2m"), (1.0, "1m")):
        out.append(kit(f"balcony_fascia_{tag}", [fascia(W)], fns, ground=None, wall=True, preview=tag == "4m"))
    out.append(kit("balcony_fascia_end", [fascia(0.25, caps=True)], fns, ground=None, wall=True, preview=False))
    out.append(kit("balustrade_2m", [balustrade(2.0)], fns, ao_dist=0.3))
    out.append(kit("balustrade_1m", [balustrade(1.0)], fns, ao_dist=0.3, preview=False))
    out.append(kit("balustrade_pedestal", [pedestal()], fns, ao_dist=0.3, preview=False))
    out.append(kit("balcony_pier", [pier()], fns, ao_dist=0.4))
    return out
