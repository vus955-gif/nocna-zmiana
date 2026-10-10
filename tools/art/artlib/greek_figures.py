"""Figures for Greek reliefs (Parthenon frieze, metopes, Bassae, the Nereid
Monument), drawn into a relief.Relief through a relief.Frame.

Local units are metres of a frieze figure at scale 1 (a standing man is
0.9 tall, a horse 0.5 at the withers: the frieze's small horses and
isocephaly, every head near the top of the band). Figures face +x; the
frame mirrors them. ``z`` is the height of a figure's nearest plane above
the background (metres at scale 1): far limbs sit at about half of it, the
body a little lower than the near limbs.

Angles of limbs are absolute in the figure's frame, degrees from straight
down, positive toward the front (+x). The torso lean is degrees from
straight up, positive forward.
"""
import math

import numpy as np

from .relief import BG, CATTLE, CLOTH, HAIR, HORSE, METAL, SHIELD, SKIN, TACK, WOOD, Frame  # noqa: F401


def bone(o, ang, L):
    """End of a bone of length ``L`` from ``o`` at ``ang`` degrees from
    straight down (+ toward the front)."""
    a = math.radians(ang)
    return (o[0] + math.sin(a) * L, o[1] - math.cos(a) * L)


def up(o, ang, L):
    """End of a bone pointing up, ``ang`` degrees from straight up (+ forward)."""
    a = math.radians(ang)
    return (o[0] + math.sin(a) * L, o[1] + math.cos(a) * L)


def pitched(F, hx, hy, deg):
    """F turned ``deg`` degrees (counter-clockwise in the figure's sense)
    about its local point (hx, hy)."""
    B = F.sub(0.0, 0.0, rot=deg)
    px, py = F.p(hx, hy)
    qx, qy = B.p(hx, hy)
    B.ox += px - qx
    B.oy += py - qy
    return B


class Fig:
    """Draws primitives of one figure through a frame (local -> relief)."""

    def __init__(self, R, F, z):
        self.R, self.F, self.z = R, F, z * F.s

    def P(self, p):
        return self.F.p(*p)

    def cap(self, a, b, ra, rb=None):
        rb = ra if rb is None else rb
        return self.R.cap(self.P(a), self.P(b), self.F.r(ra), self.F.r(rb))

    def ell(self, c, rx, ry, rot=0.0):
        return self.R.ell(self.P(c), self.F.r(rx), self.F.r(ry), self.F.ang(rot))

    def poly(self, pts):
        return self.R.poly([self.P(p) for p in pts])

    def tube(self, pts, r0, r1=None, n=12):
        return self.R.tube([self.P(p) for p in pts], self.F.r(r0), self.F.r(r1 if r1 is not None else r0), n=n)

    def union(self, *s, k=0.0):
        return self.R.union(*s, k=self.F.r(k))

    def layer(self, shape, k, tag, edge=0.008, bulge=0.25, bulge_w=0.05):
        """``k``: fraction of the figure's depth; ``bulge``: fraction of the
        layer height swelling toward the middle."""
        top = self.z * k
        return self.R.layer(shape, top * (1.0 - bulge), tag, edge=self.F.r(edge) * 1.0 + 0.002,
                            bulge=top * bulge, bulge_w=self.F.r(bulge_w))

    def groove(self, pts, depth, width, on, n=None, sharp=False):
        self.R.groove([self.P(p) for p in pts], depth * self.F.s, self.F.r(width) + 0.0015, on=on, n=n,
                      sharp=sharp)

    def bump(self, shape, amp, width, on):
        self.R.bump(shape, amp * self.F.s, self.F.r(width), on=on)


# ---------------------------------------------------------------------------
# people
# ---------------------------------------------------------------------------

STAND = dict(root=(0.0, 0.46), lean=0.0, head=0.0,
             hip_n=4, knee_n=0, hip_f=-4, knee_f=-2,
             sh_n=6, el_n=10, sh_f=-6, el_f=-4)


def walk(stride=1.0, **kw):
    p = dict(STAND)
    p.update(hip_n=22 * stride, knee_n=8 * stride, hip_f=-18 * stride, knee_f=-26 * stride,
             root=(0.0, 0.445), sh_n=-14 * stride, el_n=12, sh_f=16 * stride, el_f=30)
    p.update(kw)
    return p


def skeleton(pose):
    """Joint positions of a pose (local units)."""
    r = pose["root"]
    lean = pose.get("lean", 0.0)
    neck = up(r, lean, 0.26)
    head = up(neck, lean + pose.get("head", 0.0), 0.085)
    j = {"root": r, "neck": neck, "head": head}
    for side in ("n", "f"):
        hip = (r[0] + (0.01 if side == "n" else -0.01), r[1])
        knee = bone(hip, pose["hip_" + side], 0.215)
        ankle = bone(knee, pose["knee_" + side], 0.205)
        toe_ang = pose.get("foot_" + side, 90.0)
        toe = bone(ankle, toe_ang, 0.075)
        sh = up(r, lean, 0.235)
        sh = (sh[0] + (0.015 if side == "n" else -0.015), sh[1])
        el = bone(sh, pose["sh_" + side], 0.145)
        wr = bone(el, pose["el_" + side], 0.135)
        hand = bone(wr, pose.get("hand_" + side, pose["el_" + side]), 0.045)
        j.update({"hip_" + side: hip, "knee_" + side: knee, "ankle_" + side: ankle, "toe_" + side: toe,
                  "sh_" + side: sh, "el_" + side: el, "wr_" + side: wr, "hand_" + side: hand})
    return j


def _leg(f, j, s, fat=1.0):
    return f.union(f.cap(j["hip_" + s], j["knee_" + s], 0.06 * fat, 0.038 * fat),
                   f.cap(j["knee_" + s], j["ankle_" + s], 0.04 * fat, 0.023 * fat),
                   f.cap(j["ankle_" + s], j["toe_" + s], 0.022, 0.015), k=0.014)


def _arm(f, j, s, fat=1.0):
    return f.union(f.cap(j["sh_" + s], j["el_" + s], 0.042 * fat, 0.031 * fat),
                   f.cap(j["el_" + s], j["wr_" + s], 0.031 * fat, 0.021 * fat),
                   f.cap(j["wr_" + s], j["hand_" + s], 0.024, 0.017), k=0.012)


def _torso(f, j, pose, broad=1.0):
    r, neck = j["root"], j["neck"]
    lean = pose.get("lean", 0.0)
    chest = up(r, lean, 0.17)
    belly = up(r, lean, 0.07)
    return f.union(f.ell(chest, 0.1 * broad, 0.118, 90 - lean),
                   f.ell(belly, 0.08, 0.09, 90 - lean),
                   f.ell(r, 0.085, 0.065, -lean),
                   f.cap(neck, j["head"], 0.034, 0.03), k=0.035)


def _head(f, j, pose, hair=True, beard=False, helmet=None):
    h = j["head"]
    lean = pose.get("lean", 0.0) + pose.get("head", 0.0)
    skull = f.ell(h, 0.056, 0.064, 90 - lean * 0.5)
    face = f.ell(up(h, lean + 95, 0.03), 0.03, 0.04, 90 - lean)
    nose = f.cap(up(h, lean + 80, 0.045), up(h, lean + 120, 0.058), 0.009, 0.007)
    parts = [skull, face, nose]
    if beard:
        parts.append(f.ell(up(h, lean + 150, 0.055), 0.035, 0.03, -lean))
    return f.union(*parts, k=0.012)


def human(R, F, pose, z=0.05, dress="nude", hair=True, beard=False, helmet=None, broad=1.0, female=False,
          headless=False, extra=None):
    """A person in relief. ``dress``: nude, chlamys (cloak from the
    shoulders, flowing back), chiton (tunic to the knees), long (chiton to
    the feet), himation (mantle wrapped from the far shoulder), peplos
    (girl's dress with overfold), armour (cuirass with pteruges).
    ``helmet``: None, "crest" (hoplite), "cap" (Phrygian, Amazons).
    Returns {name: layer id} and the joints."""
    f = Fig(R, F, z)
    j = skeleton(pose)
    lids = {}
    # far limbs
    lids["leg_f"] = f.layer(_leg(f, j, "f"), 0.5, SKIN)
    lids["arm_f"] = f.layer(_arm(f, j, "f"), 0.55, SKIN)
    # body and head
    lids["body"] = f.layer(_torso(f, j, pose, broad), 0.8, SKIN, bulge=0.35, bulge_w=0.07)
    if not headless:
        lids["head"] = f.layer(_head(f, j, pose, beard=beard), 0.82, SKIN, bulge=0.4, bulge_w=0.04)
        h = j["head"]
        lean = pose.get("lean", 0.0) + pose.get("head", 0.0)
        if helmet == "crest":
            cap = f.union(f.ell(up(h, lean - 10, 0.012), 0.06, 0.055, 90 - lean),
                          f.cap(up(h, lean - 60, 0.05), up(h, lean + 40, 0.075), 0.02, 0.015), k=0.01)
            lids["helmet"] = f.layer(cap, 0.86, METAL, bulge=0.3)
            crest = f.tube([up(h, lean + 40, 0.075), up(h, lean, 0.11), up(h, lean - 60, 0.1),
                            up(h, lean - 110, 0.075)], 0.018, 0.012, n=10)
            lids["crest"] = f.layer(crest, 0.84, HAIR, bulge=0.3)
            f.R.texture([lids["crest"]], 0.0015 * F.s, 120.0 / F.s, seed=3, kind="mane")
        elif helmet == "cap":
            cap = f.union(f.ell(up(h, lean - 15, 0.015), 0.058, 0.058, 90 - lean),
                          f.tube([up(h, lean - 20, 0.05), up(h, lean + 20, 0.085), up(h, lean + 60, 0.07)],
                                 0.02, 0.01, n=8), k=0.015)
            lids["helmet"] = f.layer(cap, 0.85, CLOTH, bulge=0.3)
        elif hair and female:
            hr = f.union(f.ell(up(h, lean - 25, 0.014), 0.06, 0.054, 90 - lean),
                         f.ell(up(h, lean - 110, 0.03), 0.045, 0.05, -lean),
                         f.ell(up(h, lean - 135, 0.062), 0.03, 0.028, -lean), k=0.012)
            lids["hair"] = f.layer(hr, 0.84, HAIR, bulge=0.3)
            f.groove([up(h, lean - 60, 0.05), up(h, lean - 10, 0.06), up(h, lean + 40, 0.05)], 0.003, 0.008,
                     [lids["hair"]], n=6)
            f.R.texture([lids["hair"]], 0.001 * F.s, 120.0 / F.s, seed=int(h[0] * 100), kind="mane")
        elif hair:
            hr = f.union(f.ell(up(h, lean - 25, 0.012), 0.056, 0.05, 90 - lean),
                         f.ell(up(h, lean - 120, 0.02), 0.04, 0.045, -lean), k=0.01)
            lids["hair"] = f.layer(hr, 0.84, HAIR, bulge=0.3)
            f.R.texture([lids["hair"]], 0.0014 * F.s, 160.0 / F.s, seed=int(h[0] * 100), kind="curls")
        if beard:
            lids["beard"] = lids.get("hair", lids["head"])
    # garments over the body
    r, neck = j["root"], j["neck"]
    lean = pose.get("lean", 0.0)
    sh_n, sh_f = j["sh_n"], j["sh_f"]
    if dress in ("chiton", "long", "peplos", "armour", "himation"):
        hem_y = {"chiton": 0.25, "armour": 0.3, "long": 0.03, "peplos": 0.03, "himation": 0.1}[dress]
        knee_x = (j["knee_n"][0] + j["knee_f"][0]) / 2
        foot_x = (j["ankle_n"][0] + j["ankle_f"][0]) / 2
        hx = knee_x if hem_y > 0.2 else foot_x
        spread = 0.1 + abs(j["knee_n"][0] - j["knee_f"][0]) * 0.6
        top = up(r, lean, 0.24)
        pts = [(top[0] - 0.08, top[1]), (top[0] + 0.08, top[1]), (r[0] + 0.1, r[1] + 0.02),
               (hx + spread, hem_y), (hx - spread, hem_y - 0.01), (r[0] - 0.1, r[1] + 0.02)]
        if dress == "himation":
            # the mantle leaves the near shoulder bare: start under the near arm
            pts = [(top[0] - 0.08, top[1] + 0.01), (top[0] - 0.01, top[1] - 0.02), (r[0] + 0.1, r[1] + 0.12),
                   (r[0] + 0.12, r[1]), (hx + spread, hem_y), (hx - spread * 0.8, hem_y - 0.01),
                   (r[0] - 0.11, r[1] + 0.05)]
        shape = f.poly(pts)
        tag = METAL if dress == "armour" else CLOTH
        lids["dress"] = f.layer(f.union(shape, k=0.0), 0.86, tag, bulge=0.35, bulge_w=0.06)
        on = [lids["dress"]]
        if dress == "armour":
            # cuirass rim, pteruges (leather strips) below
            f.groove([up(r, lean, 0.02), (r[0] + 0.1, r[1] + 0.02)], 0.004, 0.006, on)
            for k in range(5):
                x = r[0] - 0.08 + k * 0.04
                f.groove([(x, r[1] - 0.02), (x + 0.01, hem_y + 0.01)], 0.004, 0.006, on, sharp=True)
        else:
            # folds: from the shoulders and the belt down to the hem
            rng = np.random.default_rng(int(abs(F.ox) * 1000 + F.oy * 100) % 9999)
            for k in range(6 if dress != "chiton" else 4):
                t = (k + 0.5) / (6 if dress != "chiton" else 4)
                x0 = top[0] - 0.07 + 0.14 * t
                x1 = hx - spread + 2 * spread * t + rng.uniform(-0.02, 0.02)
                f.groove([(x0, top[1] - 0.02), ((x0 + x1) / 2 + rng.uniform(-0.02, 0.02), (top[1] + hem_y) / 2),
                          (x1, hem_y + 0.01)], 0.0045, 0.009, on, n=8)
            if dress == "himation":
                for k in range(4):
                    a = (top[0] - 0.06 + k * 0.03, top[1] - 0.01 - k * 0.01)
                    b = (r[0] + 0.11, r[1] + 0.08 - k * 0.04)
                    f.groove([a, b], 0.004, 0.008, on, sharp=False)
            if dress == "peplos":
                f.groove([(top[0] - 0.09, r[1] + 0.06), (top[0] + 0.09, r[1] + 0.07)], 0.004, 0.007, on)
    if dress == "chlamys":
        from .relief import bezier
        s0 = (sh_f[0] - 0.02, sh_f[1] + 0.01)
        tail = pose.get("cloak", (-0.28, 0.12))
        tip = (s0[0] + tail[0], s0[1] - tail[1])
        upper = bezier([(sh_n[0] + 0.03, sh_n[1] + 0.01), (s0[0] + tail[0] * 0.35, s0[1] + 0.06), tip], 8)
        lower = bezier([tip, (s0[0] + tail[0] * 0.55, s0[1] - tail[1] - 0.09), (sh_n[0] - 0.03, sh_n[1] - 0.11)], 8)
        edge = []
        for k, q in enumerate(lower):
            jag = 0.012 if k % 2 else -0.012
            edge.append((q[0], q[1] + jag * (1 - k / len(lower))))
        pts = [tuple(q) for q in upper] + edge[1:]
        lids["cloak"] = f.layer(f.poly(pts), 0.9, CLOTH, bulge=0.35, bulge_w=0.04)
        for k in range(4):
            t = (k + 1) / 5
            a0 = (sh_n[0] - 0.01, sh_n[1] - 0.02)
            a1 = (tip[0] * t + (sh_n[0] - 0.03) * (1 - t), tip[1] * t + (sh_n[1] - 0.11) * (1 - t) - 0.03)
            f.groove([a0, ((a0[0] + a1[0]) / 2, (a0[1] + a1[1]) / 2 + 0.015), a1], 0.004, 0.009, [lids["cloak"]], n=6)
    # near limbs on top
    if dress in ("long", "peplos"):
        lids["leg_n"] = f.layer(f.cap(j["ankle_n"], j["toe_n"], 0.02, 0.013), 0.88, SKIN)
    elif dress == "himation":
        lids["leg_n"] = f.layer(f.union(f.cap(j["knee_n"], j["ankle_n"], 0.03, 0.02),
                                        f.cap(j["ankle_n"], j["toe_n"], 0.02, 0.013), k=0.01), 0.9, SKIN)
    else:
        lids["leg_n"] = f.layer(_leg(f, j, "n"), 0.95, SKIN, bulge=0.3)
        f.bump(f.ell(j["knee_n"], 0.03, 0.03), 0.004, 0.02, [lids["leg_n"]])
    lids["arm_n"] = f.layer(_arm(f, j, "n"), 1.0, SKIN, bulge=0.3)
    if dress == "nude" or dress == "chlamys":
        # anatomy: pectorals, the abdominal arch
        ch = up(r, lean, 0.18)
        f.bump(f.ell((ch[0] + 0.03, ch[1]), 0.045, 0.03), 0.005, 0.025, [lids["body"]])
        f.groove([up(r, lean - 30, 0.1), up(r, lean, 0.13), up(r, lean + 40, 0.1)], 0.003, 0.008,
                  [lids["body"]], n=6)
    if extra:
        extra(f, j, lids)
    return lids, j


# ---------------------------------------------------------------------------
# equipment
# ---------------------------------------------------------------------------

def round_shield(R, F, c, r=0.13, z=0.06, device=None):
    """Aspis seen from the outside: rim, dished face, a device in low relief."""
    f = Fig(R, F, z)
    lid = f.layer(f.ell(c, r, r * 0.97), 1.0, SHIELD, bulge=0.15, bulge_w=0.06)
    f.groove([(c[0] + r * 0.86 * math.cos(a), c[1] + r * 0.86 * math.sin(a))
              for a in np.linspace(0, math.tau, 25)], 0.004, 0.008, [lid])
    if device == "boss":
        f.bump(f.ell(c, r * 0.25, r * 0.25), 0.006, r * 0.2, [lid])
    return lid


def pelta(R, F, c, r=0.1, z=0.06):
    """Amazon's crescent shield."""
    f = Fig(R, F, z)
    sh = R.subtract(f.ell(c, r, r * 0.9), f.ell((c[0], c[1] + r * 0.75), r * 0.55, r * 0.5))
    return f.layer(sh, 1.0, SHIELD, bulge=0.2, bulge_w=0.04)


def spear(R, F, a, b, z=0.06, r=0.006):
    f = Fig(R, F, z)
    lid = f.layer(f.cap(a, b, r, r * 0.8), 1.0, WOOD, edge=0.004, bulge=0.1)
    return lid


# ---------------------------------------------------------------------------
# horses
# ---------------------------------------------------------------------------

# leg angles per gait: (forearm, cannon, pastern) for fore legs, (gaskin,
# cannon, pastern) for hind legs; near / far. Absolute, degrees from
# straight down (+ forward). Hind legs of a pitched (rearing) horse are
# measured in the ground frame, so they stay planted.
GAITS = {
    "stand": {"fn": (2, 0, 28), "ff": (-6, -2, 24), "hn": (-32, 2, 24), "hf": (-22, 8, 28)},
    "walk": {"fn": (35, -12, 8), "ff": (-10, 4, 26), "hn": (-42, -8, 14), "hf": (-14, 14, 34)},
    "canter": {"fn": (82, -30, -45), "ff": (38, 12, 32), "hn": (-58, -32, -12), "hf": (-8, 16, 40)},
    "gallop": {"fn": (88, 25, 45), "ff": (62, -22, -55), "hn": (-68, -48, -30), "hf": (-32, -18, 12)},
    "rear": {"fn": (118, 30, -15), "ff": (100, -10, -40), "hn": (8, 22, 40), "hf": (22, 30, 48)},
}

FORE_START = (0.15, 0.3)
HIND_START = (-0.13, 0.31)
HIP = (-0.17, 0.4)
POLL = (0.265, 0.7)
MUZZLE = (0.345, 0.53)


def _leg_chain(fig, start, angs, lens, rads):
    pts = [start]
    for a, L in zip(angs, lens):
        pts.append(bone(pts[-1], a, L))
    shapes = [fig.cap(pts[i], pts[i + 1], rads[i], rads[i + 1]) for i in range(len(pts) - 1)]
    shapes.append(fig.ell(bone(pts[-1], angs[-1], 0.01), 0.024, 0.019, 90 - angs[-1]))
    # knee / hock and fetlock knobs
    shapes.append(fig.ell(pts[1], rads[1] * 1.25, rads[1] * 1.15))
    shapes.append(fig.ell(pts[2], rads[2] * 1.3, rads[2] * 1.2))
    return fig.union(*shapes, k=0.01), pts


def _horse_legs(R, F, B, z, legs, tag, side, k_fore, k_hind):
    """One side's fore leg (body frame) and hind leg (ground frame)."""
    fb, fg = Fig(R, B, z), Fig(R, F, z)
    a = legs["f" + side]
    shape, _ = _leg_chain(fb, FORE_START, a, [0.135, 0.12, 0.05], [0.048, 0.025, 0.019, 0.018])
    lf = fb.layer(shape, k_fore, tag, bulge=0.3, bulge_w=0.03)
    a = legs["h" + side]
    start = F.inv(*B.p(*HIND_START)) if B is not F else HIND_START
    shape, _ = _leg_chain(fg, start, a, [0.15, 0.125, 0.05], [0.055, 0.028, 0.019, 0.018])
    lh = fg.layer(shape, k_hind, tag, bulge=0.3, bulge_w=0.03)
    return lf, lh


def _horse_trunk(f, neck=True, head_up=0.0):
    """Barrel, chest, quarters, thigh and (optionally) the arched neck."""
    parts = [f.ell((0.0, 0.37), 0.2, 0.118),
             f.ell((0.165, 0.375), 0.105, 0.128, 75),
             f.ell((-0.175, 0.4), 0.128, 0.13),
             f.ell((-0.02, 0.455), 0.17, 0.05),
             f.ell((-0.165, 0.33), 0.075, 0.115, 100),
             f.ell((0.13, 0.41), 0.075, 0.11, 105)]
    if neck:
        poll = (POLL[0] - head_up * 0.3, POLL[1] + head_up)
        parts.append(f.tube([(0.13, 0.43), (0.215, 0.555), (poll[0] - 0.012, poll[1] - 0.03)], 0.105, 0.064, n=8))
        parts.append(f.ell((0.19, 0.6), 0.1, 0.05, 58))
    return f.union(*parts, k=0.035)


def horse(R, F, gait="canter", z=0.045, pitch=0.0, head_up=0.0, rider=None, tag=HORSE, tail_up=0.0, mane=True):
    """A horse of the frieze (small, deep-chested, arched neck, head tucked
    toward the chest, cropped upright mane, open mouth). ``pitch`` tilts the
    body (rearing) about the hind hip. ``rider`` = callable(R, frame) drawing
    the rider on the horse's frame (seat at local (-0.01, 0.5)). Returns
    (layer ids, body frame)."""
    legs = GAITS[gait]
    B = pitched(F, HIP[0], HIP[1], pitch) if pitch else F
    f = Fig(R, B, z)
    lids = {}
    lids["leg_ff"], lids["leg_hf"] = _horse_legs(R, F, B, z, legs, tag, "f", 0.5, 0.48)
    lids["body"] = f.layer(_horse_trunk(f, True, head_up), 0.75, tag, bulge=0.45, bulge_w=0.09)
    poll = (POLL[0] - head_up * 0.3, POLL[1] + head_up)
    muzzle = (MUZZLE[0] + head_up * 0.8, MUZZLE[1] + head_up * 1.4)
    hv = np.array(muzzle) - np.array(poll)
    hn = np.array([-hv[1], hv[0]]) / max(np.linalg.norm(hv), 1e-9)      # toward the forehead side
    if hn[0] > 0:
        hn = -hn
    head = f.union(f.cap(poll, muzzle, 0.05, 0.035),
                   f.ell(tuple(np.array(poll) + hv * 0.3 - hn * 0.03), 0.06, 0.048, math.degrees(math.atan2(hv[1], hv[0]))),
                   f.poly([tuple(np.array(poll) + hn * 0.012 - hv * 0.08), tuple(np.array(poll) + np.array([-0.035, 0.07])),
                           tuple(np.array(poll) + hv * 0.1 + hn * 0.03)]), k=0.014)
    lids["head"] = f.layer(head, 0.82, tag, bulge=0.35, bulge_w=0.03)
    on = [lids["head"]]
    eye = np.array(poll) + hv * 0.3 + hn * 0.012
    f.bump(f.ell(tuple(eye), 0.012, 0.009), 0.004, 0.008, on)
    f.groove([tuple(eye + hn * 0.012 - hv * 0.05), tuple(eye + hn * 0.014 + hv * 0.05)], 0.002, 0.004, on)
    mouth0 = np.array(poll) + hv * 0.98 - hn * 0.02
    f.groove([tuple(mouth0), tuple(mouth0 - hv * 0.25 - hn * 0.005)], 0.005, 0.007, on)
    f.bump(f.ell(tuple(np.array(poll) + hv * 0.9 + hn * 0.008), 0.011, 0.009), -0.003, 0.006, on)
    # musculature: shoulder, haunch, belly line, the veined neck
    on = [lids["body"]]
    f.bump(f.ell((0.12, 0.42), 0.065, 0.05, 70), 0.0025, 0.03, on)
    f.bump(f.ell((-0.17, 0.41), 0.1, 0.075, 20), 0.003, 0.05, on)
    f.groove([(0.08, 0.27), (-0.02, 0.26), (-0.11, 0.28)], 0.003, 0.012, on, n=6)
    f.groove([(0.17, 0.45), (0.23, 0.53), (0.25, 0.6)], 0.002, 0.009, on, n=6)
    f.groove([(0.05, 0.47), (0.07, 0.4), (0.06, 0.32)], 0.0025, 0.01, on, n=6)
    if mane:
        crest = f.tube([(0.1, 0.49), (0.17, 0.56), (0.22, 0.64), (poll[0] - 0.02, poll[1] + 0.01)],
                       0.024, 0.02, n=10)
        lids["mane"] = f.layer(crest, 0.8, HAIR, bulge=0.3, bulge_w=0.02, edge=0.005)
        R.texture([lids["mane"]], 0.0022 * F.s, 150.0 / F.s, seed=int(abs(F.ox) * 50), kind="mane")
    tail = f.tube([(-0.29, 0.47), (-0.39, 0.47 + tail_up), (-0.43, 0.35 + tail_up), (-0.41, 0.2 + tail_up * 0.5)],
                  0.03, 0.022, n=10)
    lids["tail"] = f.layer(tail, 0.6, HAIR, bulge=0.3)
    R.texture([lids["tail"]], 0.0018 * F.s, 120.0 / F.s, seed=5, kind="mane")
    # bridle straps (the bronze reins were fixed in drill holes)
    on = [lids["head"]]
    f.groove([tuple(np.array(poll) + hv * 0.15 + hn * 0.03), tuple(np.array(poll) + hv * 0.2 - hn * 0.04)], 0.002, 0.005, on)
    f.groove([tuple(np.array(poll) + hv * 0.7 + hn * 0.03), tuple(np.array(poll) + hv * 0.75 - hn * 0.035)], 0.002, 0.005, on)
    lids["leg_fn"], lids["leg_hn"] = _horse_legs(R, F, B, z, legs, tag, "n", 0.95, 0.92)
    if rider is not None:
        rider(R, B)
    return lids, B


def rider(pose_kw=None, dress="chlamys", z=0.06, hat=False, headless=False, beard=False, arm_up=False):
    """A rider sitting the horse bareback, legs hanging, holding the reins."""
    def draw(R, B):
        p = dict(STAND)
        p.update(root=(-0.015, 0.52), lean=-4, hip_n=62, knee_n=-6, foot_n=35, hip_f=52, knee_f=-12, foot_f=30,
                 sh_n=28, el_n=78, sh_f=18, el_f=70, cloak=(-0.22, 0.05))
        if arm_up:
            p.update(sh_f=160, el_f=140)
        if pose_kw:
            p.update(pose_kw)
        human(R, B, p, z=z, dress=dress, headless=headless, beard=beard,
              helmet=None, extra=_petasos if hat else None)
    return draw


def _petasos(f, j, lids):
    h = j["head"]
    brim = f.ell((h[0] - 0.005, h[1] + 0.035), 0.08, 0.016, 0)
    f.layer(brim, 0.92, SKIN, bulge=0.2)


# ---------------------------------------------------------------------------
# cattle, chariot, centaur
# ---------------------------------------------------------------------------

def cow(R, F, z=0.045, head_up=False, tag=CATTLE):
    """A sacrificial heifer: heavy barrel, dewlap, short stocky legs, horns."""
    f = Fig(R, F, z)
    lids = {}

    def leg(x, a, k, fat=1.0):
        top = (x, 0.3)
        knee = bone(top, a, 0.14)
        foot = bone(knee, a * 0.3, 0.12)
        sh = f.union(f.cap(top, knee, 0.05 * fat, 0.03), f.cap(knee, foot, 0.03, 0.025),
                     f.ell((foot[0] + 0.005, foot[1] + 0.012), 0.028, 0.018), k=0.01)
        return f.layer(sh, k, tag, bulge=0.3)

    lids["legs_f"] = [leg(0.2, -10, 0.5), leg(-0.22, 12, 0.5)]
    hx, hy = (0.42, 0.47) if not head_up else (0.44, 0.58)
    body = f.union(f.ell((0.0, 0.4), 0.3, 0.14), f.ell((0.2, 0.43), 0.13, 0.15),
                   f.ell((-0.23, 0.42), 0.12, 0.13),
                   f.tube([(0.24, 0.45), (0.33, 0.47), (hx - 0.04, hy)], 0.11, 0.08, n=6),
                   f.poly([(0.22, 0.36), (0.36, 0.38), (0.32, 0.24), (0.26, 0.27)]), k=0.04)
    lids["body"] = f.layer(body, 0.75, tag, bulge=0.45, bulge_w=0.1)
    ang = 25 if head_up else -40
    head = f.union(f.ell((hx, hy), 0.06, 0.05), f.cap((hx, hy), up((hx, hy), 90 + ang + 30, 0.1), 0.05, 0.035),
                   k=0.015)
    lids["head"] = f.layer(head, 0.8, tag, bulge=0.35, bulge_w=0.03)
    horn = f.tube([(hx - 0.02, hy + 0.03), (hx - 0.03, hy + 0.08), (hx + 0.02, hy + 0.11)], 0.012, 0.006, n=6)
    f.layer(horn, 0.85, tag, bulge=0.2, edge=0.004)
    f.bump(f.ell((0.18, 0.44), 0.08, 0.06), 0.005, 0.04, [lids["body"]])
    f.groove([(0.2, 0.28), (0.0, 0.27), (-0.18, 0.29)], 0.003, 0.012, [lids["body"]], n=6)
    tail = f.tube([(-0.33, 0.46), (-0.36, 0.38), (-0.35, 0.2)], 0.012, 0.01, n=6)
    tl = f.layer(tail, 0.6, tag)
    tuft = f.ell((-0.35, 0.18), 0.02, 0.035)
    f.layer(tuft, 0.62, HAIR)
    lids["legs_n"] = [leg(0.17, 8, 0.95, 1.05), leg(-0.2, -10, 0.92, 1.1)]
    return lids


def wheel(R, F, c, r=0.17, z=0.05):
    f = Fig(R, F, z)
    rim = R.subtract(f.ell(c, r, r), f.ell(c, r * 0.8, r * 0.8))
    lid = f.layer(rim, 1.0, WOOD, bulge=0.2, bulge_w=0.02)
    spokes = [f.cap(c, (c[0] + r * 0.82 * math.cos(a), c[1] + r * 0.82 * math.sin(a)), 0.009)
              for a in np.linspace(0, math.pi, 4, endpoint=False)]
    spokes += [f.cap(c, (c[0] - r * 0.82 * math.cos(a), c[1] - r * 0.82 * math.sin(a)), 0.009)
               for a in np.linspace(0, math.pi, 4, endpoint=False)]
    f.layer(f.union(*spokes, f.ell(c, 0.03, 0.03)), 0.85, WOOD, bulge=0.2)
    return lid


def chariot(R, F, z=0.055):
    """Quadriga: four horses in depth (each nearer one a little further on),
    the car with its wheel, the charioteer leaning forward, the apobates
    (armed, round shield) stepping down from the back."""
    # horses far -> near
    for k, (dx, kz) in enumerate(((0.12, 0.35), (0.08, 0.5), (0.04, 0.7), (0.0, 0.95))):
        horse(R, F.sub(0.45 + dx, 0.0), gait="canter" if k % 2 == 0 else "gallop", z=z * kz, head_up=0.02 * k,
              mane=True)
    f = Fig(R, F, z)
    # car: box and rail
    car = f.poly([(-0.06, 0.2), (0.16, 0.2), (0.2, 0.42), (0.14, 0.44), (0.12, 0.3), (-0.04, 0.32)])
    f.layer(car, 0.75, WOOD, bulge=0.2)
    pole = f.cap((0.14, 0.3), (0.5, 0.42), 0.012)
    f.layer(pole, 0.7, WOOD)
    # charioteer in a long chiton, leaning into the reins
    p = walk(0.4, root=(0.06, 0.66), lean=22, sh_n=70, el_n=80, sh_f=60, el_f=75)
    human(R, F, p, z=z * 0.85, dress="long")
    # apobates leaping off the back, helmet and shield
    p2 = walk(1.0, root=(-0.18, 0.46), lean=-8, hip_n=35, knee_n=-10, hip_f=-40, knee_f=-50, sh_n=-30, el_n=-60,
              sh_f=110, el_f=90)
    lids, j = human(R, F, p2, z=z * 1.05, dress="armour", helmet="crest")
    round_shield(R, F, (j["el_f"][0] + 0.02, j["el_f"][1] + 0.02), r=0.12, z=z * 1.15)
    wheel(R, F, (0.06, 0.17), r=0.165, z=z * 1.1)


def centaur(R, F, z=0.06, pose="rear", arm_up=True, headless=False, tag=HORSE, arm_kw=None):
    """A centaur: horse body without neck, a bearded man's torso rising
    from the withers. Returns the body frame and the man's joints."""
    gait = {"rear": "rear", "stand": "stand", "charge": "gallop", "walk": "walk"}[pose]
    pitch = 24 if pose == "rear" else 0
    legs = GAITS[gait]
    B = pitched(F, HIP[0], HIP[1], pitch) if pitch else F
    f = Fig(R, B, z)
    _horse_legs(R, F, B, z, legs, tag, "f", 0.5, 0.48)
    lid = f.layer(_horse_trunk(f, neck=False), 0.72, tag, bulge=0.45, bulge_w=0.09)
    f.bump(f.ell((-0.175, 0.42), 0.08, 0.07), 0.005, 0.04, [lid])
    f.groove([(0.08, 0.27), (-0.02, 0.26), (-0.11, 0.28)], 0.003, 0.012, [lid], n=6)
    tail = f.tube([(-0.29, 0.47), (-0.42, 0.5), (-0.48, 0.38), (-0.45, 0.22)], 0.03, 0.022, n=10)
    lt = f.layer(tail, 0.6, HAIR, bulge=0.3)
    R.texture([lt], 0.0018 * F.s, 120.0 / F.s, seed=5, kind="mane")
    # the man: hips merge into the horse's chest
    p = dict(STAND)
    p.update(root=(0.17, 0.5), lean=12 if pose != "rear" else -8, hip_n=90, knee_n=90, hip_f=90, knee_f=90,
             sh_n=140 if arm_up else 40, el_n=175 if arm_up else 70, sh_f=-50, el_f=-20)
    if arm_kw:
        p.update(arm_kw)
    j = skeleton(p)
    lids = {}
    lids["arm_f"] = f.layer(_arm(f, j, "f", 1.1), 0.6, SKIN)
    lids["body"] = f.layer(f.union(_torso(f, j, p, 1.15), f.ell((0.16, 0.47), 0.09, 0.08), k=0.03), 0.86, SKIN,
                           bulge=0.35, bulge_w=0.07)
    if not headless:
        lids["head"] = f.layer(_head(f, j, p, beard=True), 0.9, SKIN, bulge=0.4, bulge_w=0.04)
        h = j["head"]
        lean = p["lean"]
        hr = f.union(f.ell(up(h, lean - 25, 0.012), 0.06, 0.054, 90), f.ell(up(h, lean + 150, 0.05), 0.042, 0.036, 0),
                     k=0.01)
        lh = f.layer(hr, 0.92, HAIR, bulge=0.3)
        R.texture([lh], 0.0016 * B.s, 150.0 / B.s, seed=9, kind="curls")
    ch = up(p["root"], p["lean"], 0.18)
    f.bump(f.ell((ch[0] + 0.03, ch[1]), 0.05, 0.035), 0.006, 0.03, [lids["body"]])
    f.groove([up(p["root"], p["lean"] - 30, 0.1), up(p["root"], p["lean"], 0.13), up(p["root"], p["lean"] + 40, 0.1)],
             0.003, 0.008, [lids["body"]], n=6)
    _horse_legs(R, F, B, z, legs, tag, "n", 0.95, 0.92)
    lids["arm_n"] = f.layer(_arm(f, j, "n", 1.1), 1.0, SKIN, bulge=0.3)
    return B, j, lids


# ---------------------------------------------------------------------------
# things carried
# ---------------------------------------------------------------------------

def vase_shape(f, base, h=0.14, w=0.07, tilt=0.0):
    """A hydria / amphora silhouette standing on ``base`` (local), ``tilt``
    degrees (carried on the shoulder: on its side)."""
    F = f.F.sub(base[0], base[1], rot=tilt)
    g = Fig(f.R, F, f.z / f.F.s)
    body = g.union(g.ell((0.0, h * 0.42), w * 0.5, h * 0.36), g.cap((0.0, h * 0.7), (0.0, h * 0.92), w * 0.18, w * 0.2),
                   g.cap((0.0, 0.0), (0.0, h * 0.15), w * 0.22, w * 0.18), g.ell((0.0, h * 0.95), w * 0.28, w * 0.06),
                   k=0.008)
    handle = g.tube([(w * 0.42, h * 0.5), (w * 0.62, h * 0.62), (w * 0.4, h * 0.7)], 0.008, 0.008, n=6)
    return g.union(body, handle)


def carry_vase(f, j, lids):
    """Hydria carried on the near shoulder (the water carriers): lying on
    its side, mouth forward, steadied by the raised hand."""
    sh = j["sh_n"]
    shape = vase_shape(f, (sh[0] - 0.1, sh[1] - 0.005), h=0.18, w=0.1, tilt=10)
    f.layer(shape, 1.06, TACK, bulge=0.35, bulge_w=0.04)


def hold_phiale(f, j, lids):
    h = j["hand_n"]
    f.layer(f.ell((h[0] + 0.02, h[1] + 0.01), 0.05, 0.012), 1.02, TACK, bulge=0.2)


def hold_jug(f, j, lids):
    h = j["hand_f"]
    f.layer(vase_shape(f, (h[0] + 0.01, h[1] - 0.09), h=0.1, w=0.055), 0.6, TACK, bulge=0.3)


def kithara(f, j, lids):
    """Lyre held against the far side of the chest, plectrum hand in front."""
    c = up(j["root"], 0, 0.17)
    c = (c[0] + 0.1, c[1])
    box = f.union(f.ell((c[0], c[1] - 0.04), 0.065, 0.055), f.cap((c[0] - 0.06, c[1] - 0.02), (c[0] + 0.06, c[1] - 0.02), 0.03))
    arms = f.union(f.tube([(c[0] - 0.05, c[1] - 0.01), (c[0] - 0.09, c[1] + 0.1), (c[0] - 0.05, c[1] + 0.19)], 0.018, 0.013, n=6),
                   f.tube([(c[0] + 0.05, c[1] - 0.01), (c[0] + 0.09, c[1] + 0.1), (c[0] + 0.05, c[1] + 0.19)], 0.018, 0.013, n=6),
                   f.cap((c[0] - 0.07, c[1] + 0.17), (c[0] + 0.07, c[1] + 0.17), 0.011))
    lid = f.layer(f.union(box, arms), 1.08, WOOD, bulge=0.25)
    for k in range(5):
        x = c[0] - 0.03 + k * 0.015
        f.groove([(x, c[1] - 0.05), (x, c[1] + 0.16)], 0.002, 0.003, [lid], sharp=True)


def staff(f, j, lids):
    h = j["hand_n"]
    f.layer(f.cap((h[0], h[1] + 0.2), (h[0] + 0.01, 0.02), 0.009), 1.04, WOOD, edge=0.004, bulge=0.1)


def reins(f, j, lids):
    """Hands holding the reins (fixed in bronze, lost: only the fist)."""
    return None
