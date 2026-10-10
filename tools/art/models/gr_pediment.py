"""Greek sculpture: the pediment figures of the Parthenon as they are shown
in the gallery - weathered, headless, arms lost - chunky clay sculpts in
statuary marble (112 px/m), the fractures bright and sugary. Each stands on
its own pediment-floor slab; put them on gr_plinth_low at both ends of the
Parthenon Gallery (the guardian's arena: cover from the javelins).

  gr_ped_reclining   a reclining youth (after "Dionysos" and the river god
                     "Ilissos"), propped on his left elbow on a rock spread
                     with his mantle, the right knee raised; head and right
                     arm lost. 2.2 x 1.1 x 0.9 m.
  gr_ped_goddesses   the three goddesses of the east pediment: one sits
                     upright on a rock, the second sits turned toward the
                     third, who reclines in her lap; clinging chitons in
                     ridged folds, mantles; all headless. 3.4 x 1.25 x 1.3 m.
  gr_ped_seated      two goddesses seated side by side on chests (after
                     "Demeter and Persephone"), one's arm round the other's
                     shoulders. 1.8 x 1.25 x 1.3 m.
  gr_ped_horse       the head of Selene's horse sinking below the pediment's
                     edge at the end of the night: flared nostrils, open
                     mouth, bulging eye, cut at the neck on its block.
                     1.3 x 1.05 x 0.6 m.
  gr_ped_torso       a colossal male torso (after "Poseidon"), broken at
                     neck, shoulders and hips, on an iron rod on a block.
                     0.8 x 1.95 x 0.7 m.

Origin = centre of the slab's underside; front = Godot -Z.
"""
import math

from mathutils import Matrix, Vector

from artlib import greek as GK
from artlib.archkit import kit
from artlib.geo import Part
from artlib.sculpt import blob, limb
from artlib.statue import fold, sculpt_into

PPM = 112
V = Vector


def _slab(p, w, d, h=0.12):
    p.box((0, 0, h / 2), (w, d, h), "slab", bevel=0.015)


class Pose:
    """Local figure space -> world: scale k, turn about z (degrees),
    translation, and an optional lean of everything above ``pivot_z``."""

    def __init__(self, cx, cy, cz=0.0, turn=0.0, k=1.0, lean=(0.0, 0.0), pivot_z=0.62):
        self.c = V((cx, cy, cz))
        self.turn = Matrix.Rotation(math.radians(turn), 3, 'Z')
        self.k = k
        self.lean = Matrix.Rotation(math.radians(lean[0]), 3, 'X') @ Matrix.Rotation(math.radians(lean[1]), 3, 'Y')
        self.pz = pivot_z

    def __call__(self, x, y, z):
        p = V((x, y, z))
        if z > self.pz:
            piv = V((0.0, 0.0, self.pz))
            p = piv + self.lean @ (p - piv)
        return tuple(self.c + self.turn @ (p * self.k))

    def b(self, c, semi, **kw):
        semi = semi if isinstance(semi, (tuple, list)) else (semi, semi, semi)
        rot = kw.pop("rot", (0.0, 0.0, 0.0))
        e = Matrix.Rotation(math.radians(rot[0]), 3, 'X') @ Matrix.Rotation(math.radians(rot[1]), 3, 'Y') \
            @ Matrix.Rotation(math.radians(rot[2]), 3, 'Z')
        full = self.turn @ (self.lean if c[2] > self.pz else Matrix.Identity(3)) @ e
        r = tuple(math.degrees(a) for a in full.to_euler('XYZ'))
        return blob(self(*c), tuple(v * self.k for v in semi), rot=r, **kw)

    def limb(self, pts, radii):
        return limb([self(*q) for q in pts], [r * self.k for r in radii])

    def fold(self, a, b, r, neg=False, stiff=2.0):
        return fold(self(*a), self(*b), r * self.k, neg=neg, stiff=stiff)


def seated_woman(T, arms="lap", mantle=True):
    """A seated, draped, headless woman (local: faces -Y, seat at 0.48).
    Returns (blobs, cuts)."""
    b = []
    # body
    b.append(T.b((0, 0.02, 0.56), (0.22, 0.2, 0.12)))
    b.append(T.b((0, 0.0, 0.76), (0.155, 0.125, 0.14)))
    b.append(T.b((0, 0.0, 0.96), (0.19, 0.135, 0.17)))
    for sx in (-1, 1):
        b.append(T.b((sx * 0.075, -0.11, 0.97), (0.07, 0.055, 0.065)))
        b.append(T.b((sx * 0.19, 0.0, 1.07), (0.085, 0.08, 0.07)))
    b.append(T.b((0, 0.0, 1.17), (0.06, 0.06, 0.08)))
    # arms
    wrists = {}
    for sx in (-1, 1):
        if arms == "lap" or (arms == "embrace" and sx < 0):
            el, wr = (sx * 0.27, -0.07, 0.83), (sx * 0.17, -0.34, 0.68)
        else:                                   # embrace: the right arm round the neighbour
            el, wr = (sx * 0.3, -0.02, 1.0), (sx * 0.55, 0.0, 1.06)
        b += T.limb([(sx * 0.2, 0.0, 1.07), el, wr], [0.08, 0.066, 0.052])
        wrists[sx] = (el, wr)
    # legs
    for sx in (-1, 1):
        b += T.limb([(sx * 0.1, -0.02, 0.56), (sx * 0.12, -0.46, 0.58), (sx * 0.13, -0.5, 0.13)], [0.13, 0.088, 0.06])
        b.append(T.b((sx * 0.12, -0.46, 0.58), 0.08))
        b += T.limb([(sx * 0.13, -0.5, 0.12), (sx * 0.14, -0.64, 0.05)], [0.048, 0.036])
    # chiton: lap, the skirt falling from the knees, the hem on the feet
    b.append(T.b((0, -0.24, 0.6), (0.23, 0.24, 0.075)))
    b.append(T.b((0, -0.53, 0.34), (0.27, 0.085, 0.28)))
    b.append(T.b((0, -0.56, 0.08), (0.3, 0.11, 0.07)))
    for k, x in enumerate((-0.21, -0.15, -0.1, -0.04, 0.03, 0.08, 0.14, 0.2)):
        b += T.fold((x, -0.575, 0.55), (x * 1.18, -0.59 - 0.01 * (k % 2), 0.07), 0.024 if k % 3 else 0.03)
    for k in range(5):
        x = -0.16 + 0.08 * k
        b += T.fold((x * 0.7, -0.06, 0.64), (x * 1.3, -0.46, 0.64), 0.02)
    for k in range(4):
        x = -0.1 + 0.066 * k
        b += T.fold((x * 0.8, -0.1, 0.9), (x * 1.2, -0.12, 0.8), 0.014)
    if mantle:
        b.append(T.b((0.03, 0.17, 0.82), (0.23, 0.08, 0.33)))
        b.append(T.b((0.18, 0.02, 1.12), (0.1, 0.13, 0.06)))
        b.append(T.b((0.28, 0.0, 0.8), (0.065, 0.11, 0.28)))
        b.append(T.b((0.0, -0.08, 0.66), (0.25, 0.1, 0.06)))     # the roll across the hips
        for k in range(4):
            b += T.fold((0.28, -0.06 + 0.04 * k, 1.05), (0.3, -0.08 + 0.05 * k, 0.55), 0.02)
    cuts = [(T(0, 0, 1.2), (0, 0, 1), 0.16 * T.k)]
    for sx, (el, wr) in wrists.items():
        if arms == "embrace" and sx > 0:
            continue
        m = tuple((V(el) + V(wr)) * 0.5)
        d = V(T(*wr)) - V(T(*el))
        cuts.append((T(*m), tuple(d.normalized()), 0.1 * T.k))
    return b, cuts


def reclining_woman(T):
    """Reclines on her right side into her companion's lap, legs to +x."""
    b = []
    b.append(T.b((0.0, 0.0, 0.32), (0.22, 0.2, 0.13)))                       # hips
    b.append(T.b((-0.25, 0.02, 0.48), (0.16, 0.13, 0.15), rot=(0, 40, 0)))      # waist
    b.append(T.b((-0.45, 0.02, 0.66), (0.17, 0.13, 0.17), rot=(0, 50, 0)))      # chest
    for sy in (-1, 1):
        b.append(T.b((-0.4, -0.1, 0.62 + sy * 0.05), (0.06, 0.05, 0.06)))
    b.append(T.b((-0.58, 0.0, 0.84), 0.085))
    b.append(T.b((-0.36, 0.0, 0.8), 0.085))
    b.append(T.b((-0.56, 0.0, 0.88), (0.06, 0.06, 0.08)))
    b += T.limb([(-0.36, 0.0, 0.79), (-0.1, -0.12, 0.66), (0.08, -0.22, 0.48)], [0.068, 0.055, 0.045])
    for sy, dy in ((-1, -0.1), (1, 0.08)):
        b += T.limb([(0.05, dy, 0.32), (0.48, dy - 0.04, 0.36 + (0.12 if sy < 0 else 0.0)),
                     (0.9, dy, 0.14)], [0.115, 0.078, 0.052])
        b.append(T.b((0.48, dy - 0.04, 0.36 + (0.12 if sy < 0 else 0.0)), 0.08))
    # the mantle over the legs in deep sweeping folds
    b.append(T.b((0.45, -0.04, 0.36), (0.45, 0.26, 0.12)))
    b.append(T.b((0.85, -0.02, 0.18), (0.22, 0.22, 0.1)))
    for k in range(8):
        y = -0.26 + 0.07 * k
        b += T.fold((0.02, y, 0.44 + 0.02 * (k % 2)), (0.95, y * 0.9, 0.2), 0.024)
    for k in range(5):
        b += T.fold((-0.5 + 0.05 * k, -0.13, 0.8 - 0.04 * k), (-0.28 + 0.05 * k, -0.16, 0.46), 0.017)
    cuts = [(T(-0.6, 0.0, 0.9), tuple(V((-0.6, 0.0, 0.8)).normalized()), 0.16 * T.k),
            (T(0.0, -0.18, 0.56), (0.6, -0.4, -0.6), 0.1 * T.k)]
    return b, cuts


def reclining_youth(T):
    """Nude youth propped on his left elbow, legs to -x, right knee up."""
    b = []
    b.append(T.b((0.0, 0.0, 0.5), (0.2, 0.17, 0.13), rot=(0, -35, 0)))         # pelvis
    b.append(T.b((0.17, 0.02, 0.66), (0.15, 0.13, 0.15), rot=(0, -35, 0)))      # abdomen
    b.append(T.b((0.32, 0.03, 0.83), (0.19, 0.14, 0.18), rot=(0, -40, 0)))      # rib cage
    for sz in (-1, 1):
        b.append(T.b((0.33 - sz * 0.05, -0.11, 0.86 + sz * 0.06), (0.08, 0.04, 0.065), rot=(0, -40, 0)))
    b.append(T.b((0.18, -0.12, 0.64), (0.07, 0.035, 0.1), rot=(0, -35, 0), stiff=1.6))
    b.append(T.b((0.48, 0.05, 0.84), (0.08, 0.08, 0.065), rot=(0, -40, 0)))  # left shoulder (low)
    b.append(T.b((0.3, 0.0, 1.0), (0.08, 0.08, 0.065), rot=(0, -40, 0)))     # right shoulder (up)
    b.append(T.b((0.43, 0.02, 0.99), (0.065, 0.065, 0.07)))                   # neck
    # left arm: down to the elbow on the rock, forearm along it
    b += T.limb([(0.5, 0.06, 0.82), (0.58, 0.14, 0.52), (0.82, 0.06, 0.47)], [0.075, 0.06, 0.048])
    b.append(T.b((0.9, 0.04, 0.46), (0.06, 0.05, 0.035)))
    # right arm: the stump of the upper arm
    b += T.limb([(0.27, 0.0, 1.05), (0.17, -0.14, 0.95)], [0.075, 0.068])
    # legs
    b += T.limb([(0.02, 0.03, 0.44), (-0.5, -0.06, 0.44), (-0.95, 0.0, 0.4)], [0.12, 0.08, 0.055])
    b.append(T.b((-0.5, -0.06, 0.44), 0.085))
    b += T.limb([(-0.95, 0.0, 0.4), (-1.06, -0.07, 0.38)], [0.05, 0.038])
    b += T.limb([(-0.06, -0.04, 0.55), (-0.42, -0.18, 0.78), (-0.72, 0.04, 0.48)], [0.12, 0.08, 0.055])
    b.append(T.b((-0.42, -0.18, 0.78), 0.085))
    b += T.limb([(-0.72, 0.04, 0.48), (-0.82, -0.04, 0.42)], [0.05, 0.038])
    # the mantle's end across the thighs
    b.append(T.b((-0.18, -0.06, 0.58), (0.2, 0.14, 0.09), rot=(0, -10, 0)))
    for k in range(4):
        b += T.fold((0.0, -0.16 + 0.03 * k, 0.62), (-0.35, -0.2 + 0.03 * k, 0.5), 0.022)
    cuts = [(T(0.45, 0.02, 1.03), (0.45, 0.0, 1.0), 0.13 * T.k),
            (T(0.19, -0.12, 0.96), (-0.5, -0.8, -0.3), 0.1 * T.k)]
    return b, cuts


def _rock(T, w=0.75, d=0.32, h=0.2, x=0.0):
    return [T.b((x, 0.06, h), (w, d, h)), T.b((x + w * 0.5, 0.1, h * 1.2), (w * 0.4, d * 0.8, h))]


def _mantle_over(T, x0, x1, top, y=-0.3):
    """A mantle spread over a rock, hanging down its front in folds."""
    b = [T.b(((x0 + x1) / 2, y + 0.06, top - 0.02), ((x1 - x0) / 2, 0.09, 0.06)),
         T.b(((x0 + x1) / 2, y + 0.02, top * 0.55), ((x1 - x0) / 2 * 0.9, 0.07, top * 0.45))]
    n = int((x1 - x0) / 0.14)
    for k in range(n + 1):
        x = x0 + (x1 - x0) * k / max(n, 1)
        b += T.fold((x, y - 0.01, top - 0.04), (x + 0.03, y - 0.02, 0.18), 0.032 if k % 2 else 0.026)
    return b


def reclining():
    p = Part("gr_ped_reclining")
    _slab(p, 2.2, 0.9)
    T = Pose(0.0, 0.05, 0.0, k=1.0)
    b, cuts = reclining_youth(T)
    sculpt_into(p, b, "marble", res=0.012, cuts=cuts, tris=5200, break_slot="break")
    rock = _rock(T, 0.8, 0.3, 0.2) + _rock(T, 0.55, 0.28, 0.17, x=-0.6)
    rock += _mantle_over(T, -0.95, 0.85, 0.4, y=-0.26)
    sculpt_into(p, rock, "rock", res=0.016, tris=1600)
    return p


def goddesses():
    p = Part("gr_ped_goddesses")
    _slab(p, 3.4, 1.25)
    blobs, cuts = [], []
    Tk = Pose(-1.2, 0.08, 0.0, turn=6, k=1.12)
    b, c = seated_woman(Tk)
    blobs += b
    cuts += c
    Tl = Pose(-0.2, 0.14, 0.0, turn=-14, k=1.12, lean=(0.0, 8.0))
    b, c = seated_woman(Tl, mantle=True)
    blobs += b
    cuts += c
    Tm = Pose(0.55, 0.05, 0.0, turn=0, k=1.1)
    b, c = reclining_woman(Tm)
    blobs += b
    cuts += c
    sculpt_into(p, blobs, "marble", res=0.013, cuts=cuts, tris=8400, break_slot="break")
    seats = _rock(Pose(-1.2, 0.12, 0.0, k=1.12), 0.32, 0.3, 0.26) + _rock(Pose(-0.2, 0.18, 0.0, k=1.12), 0.34, 0.3, 0.26)
    sculpt_into(p, seats, "rock", res=0.02, tris=700)
    return p


def seated_pair():
    p = Part("gr_ped_seated")
    _slab(p, 1.8, 1.25)
    for x in (-0.42, 0.42):
        p.box((x, 0.15, 0.12 + 0.26), (0.66, 0.6, 0.52), "rock", bevel=0.03)
    blobs, cuts = [], []
    for T, arms in ((Pose(-0.42, 0.08, 0.12, turn=4, k=1.05), "embrace"),
                    (Pose(0.42, 0.06, 0.12, turn=-6, k=1.05, lean=(0.0, -6.0)), "lap")):
        b, c = seated_woman(T, arms=arms)
        blobs += b
        cuts += c
    sculpt_into(p, blobs, "marble", res=0.012, cuts=cuts, tris=7000, break_slot="break")
    return p


def horse_head():
    p = Part("gr_ped_horse")
    p.box((0, 0.05, 0.2), (1.3, 0.55, 0.4), "slab", bevel=0.02)
    poll, muzzle = V((-0.02, 0.0, 0.93)), V((0.58, 0.0, 0.44))
    axis = (muzzle - poll).normalized()
    rot = tuple(math.degrees(x) for x in axis.to_track_quat('Z', 'Y').to_euler('XYZ'))

    def at(t, dz=0.0, dy=0.0):
        q = poll + (muzzle - poll) * t
        return (q.x, q.y + dy, q.z + dz)
    b = [blob((-0.18, 0.02, 0.62), (0.22, 0.17, 0.32), rot=(0, 25, 0)),      # neck, rising from the block
         blob((-0.06, 0.0, 0.88), (0.12, 0.09, 0.1)),                        # crest under the mane
         blob(at(0.12, -0.08), (0.17, 0.14, 0.16)),                          # jowl / cheek
         blob(at(0.42), (0.13, 0.11, 0.2), rot=rot),                         # face
         blob(at(0.75, -0.01), (0.1, 0.1, 0.12), rot=rot),                   # nose
         blob(at(0.95, -0.02), (0.085, 0.095, 0.09)),                        # muzzle
         blob(at(1.0, -0.09), (0.07, 0.07, 0.035), rot=rot),                 # lower jaw, hanging open
         blob(at(0.98, -0.055), (0.06, 0.065, 0.016), neg=True, stiff=1.2)]  # the open mouth
    for sy in (-1, 1):
        b.append(blob(at(0.97, 0.03, sy * 0.055), (0.032, 0.026, 0.03), neg=True, stiff=1.4))   # flared nostrils
        b.append(blob(at(0.95, 0.02, sy * 0.07), (0.03, 0.02, 0.04)))                           # nostril wings
        b.append(blob(at(0.28, 0.04, sy * 0.115), (0.045, 0.028, 0.04)))                        # bulging eyes
        b.append(blob(at(0.3, 0.075, sy * 0.1), (0.05, 0.02, 0.015)))                          # brows
        b.append(blob((poll.x - 0.04, sy * 0.06, poll.z + 0.1), (0.028, 0.03, 0.085), rot=(sy * 12, -15, 0)))  # ears
        b.append(blob(at(0.55, -0.02, sy * 0.1), (0.07, 0.015, 0.025), rot=rot))              # veins
    for k in range(8):                                                       # cropped mane
        t = k / 7
        b.append(blob((-0.3 + 0.28 * t, 0.0, 0.78 + 0.2 * t), (0.05, 0.045, 0.07), stiff=1.6))
    cuts = [((-0.3, 0.0, 0.0), (-1.0, 0.0, 0.25), 3.0)]
    sculpt_into(p, b, "marble", res=0.011, cuts=cuts, tris=4200, break_slot="break")
    return p


def torso():
    p = Part("gr_ped_torso")
    p.box((0, 0, 0.3), (0.7, 0.6, 0.6), "slab", bevel=0.02)
    p.lathe([(0.025, 0.6), (0.025, 0.95)], "iron", segments=8, cap_bottom=False)
    T = Pose(0.0, 0.0, 0.42, k=1.55)
    b = [T.b((0, 0.0, 0.5), (0.2, 0.16, 0.13)), T.b((0, 0.0, 0.7), (0.16, 0.13, 0.15)),
         T.b((0, 0.0, 0.92), (0.19, 0.14, 0.17))]
    for sx in (-1, 1):
        b.append(T.b((sx * 0.085, -0.11, 0.95), (0.085, 0.04, 0.068)))
        b.append(T.b((sx * 0.21, 0.0, 1.06), 0.1))
        b.append(T.b((sx * 0.07, -0.11, 0.7), (0.045, 0.03, 0.12), stiff=1.7))
        b.append(T.b((sx * 0.15, -0.08, 0.6), (0.05, 0.05, 0.11), stiff=1.7))   # obliques
        b += T.limb([(sx * 0.21, 0.0, 1.05), (sx * 0.28, 0.0, 0.88)], [0.085, 0.075])
        b += T.limb([(sx * 0.1, 0.0, 0.48), (sx * 0.12, -0.05, 0.3)], [0.13, 0.11])
    b.append(T.b((0, 0.0, 1.15), (0.075, 0.075, 0.08)))
    b.append(T.b((0, -0.12, 0.54), (0.12, 0.03, 0.03), neg=True, stiff=1.2))
    cuts = [(T(0, 0, 1.15), (0, 0.15, 1.0), 0.25), (T(0.27, 0, 0.95), (1.0, 0, -0.4), 0.2),
            (T(-0.27, 0, 0.95), (-1.0, 0, -0.35), 0.2), (T(0, 0, 0.36), (0.0, -0.2, -1.0), 0.5)]
    sculpt_into(p, b, "marble", res=0.013, cuts=cuts, tris=4200, break_slot="break")
    return p


def _marble(ctx):
    return GK.statuary(ctx, seed=1301, center=7.5, patina=1.2)


def _slab_paint(ctx):
    return GK.pentelic(ctx, seed=1303, center=7.0, veins=0.4, patina=1.3, ao=3.5)


def build():
    fns = {"marble": _marble, "break": GK.fracture, "rock": GK.rock, "slab": _slab_paint,
           "iron": lambda c: GK.grey_marble(c, seed=1305, center=1.5)}
    common = dict(ppm=PPM, ground=0.0, ao_dist=0.3, ao_rays=12)
    return [
        kit("gr_ped_reclining", [reclining()], fns, organic=("gr_ped_reclining",), **common),
        kit("gr_ped_goddesses", [goddesses()], fns, organic=("gr_ped_goddesses",), **common),
        kit("gr_ped_seated", [seated_pair()], fns, organic=("gr_ped_seated",), **common),
        kit("gr_ped_horse", [horse_head()], fns, organic=("gr_ped_horse",), **common),
        kit("gr_ped_torso", [torso()], fns, organic=("gr_ped_torso",), **common),
    ]
