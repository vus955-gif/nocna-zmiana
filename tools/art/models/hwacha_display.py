"""The Korean room's centrepiece: a full-size Joseon hwacha, the fire-arrow
cart (munjong hwacha) - two spoked wheels on an axle, a long frame with
handles to the back, the launch box of 10 x 10 holes tilted up at the
enemy, loaded with singijeon (iron points out of the front, red powder
tubes and fletched bamboo shafts out of the back) - behind a low lacquered
dais with a brocade cushion where the guard's own fire chest (the weapon,
vm_hwacha) waits under a spotlight: marker weapon_spot on the cushion (the
pickup floats 0.35 m above it). A brass plaque on the dais: "HWACHA / WÓZ
OGNISTYCH STRZAŁ / KOREA, XV W.".

Origin = centre of the whole display on the floor; front = +Y (Godot -Z):
the dais in front, the cart behind it. Footprint about 1.4 x 3.6 m.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import asia as A
from artlib import asia_paint as AP
from artlib import kit as K
from artlib import materials as M
from artlib import pixelfont
from artlib.archkit import kit
from artlib.geo import Part
from artlib.kit import R, T
from artlib.materials import P, _dither
from artlib.painter import Surface

CART_Y = -0.7           # axle line of the cart (behind the dais)
WHEEL_R = 0.48
AXLE_Z = WHEEL_R + 0.02
TILT = 28.0             # the launch box's angle above level
BOX = (0.86, 0.62, 0.6)  # width, depth (along the arrows), height of the launch box
DAIS = (1.3, 0.8, 0.72)  # width, depth, height
DAIS_Y = 0.9


def wheel(p, x):
    """A spoked wooden wheel with an iron tyre, centred on (x, CART_Y, AXLE_Z)."""
    rim = p.lathe([(WHEEL_R - 0.07, -0.04), (WHEEL_R, -0.045), (WHEEL_R + 0.012, 0.0), (WHEEL_R, 0.045),
                   (WHEEL_R - 0.07, 0.04), (WHEEL_R - 0.075, 0.0)], "wood", segments=24, cap_bottom=False,
                  cap_top=False, smooth=False)
    tyre = p.lathe([(WHEEL_R - 0.002, -0.04), (WHEEL_R + 0.014, -0.04), (WHEEL_R + 0.014, 0.04), (WHEEL_R - 0.002, 0.04)],
                   "iron", segments=24, cap_bottom=False, cap_top=False, smooth=False)
    hub = p.lathe([(0.0, -0.11), (0.08, -0.11), (0.1, -0.06), (0.1, 0.06), (0.08, 0.11), (0.0, 0.11)], "wood",
                  segments=10)
    spokes = []
    for k in range(12):
        f = p.box((0.0, 0.0, (WHEEL_R - 0.07 + 0.09) / 2), (0.025, 0.035, WHEEL_R - 0.16), "wood")
        p.move(f, R('X', 30 * k))
        spokes += f
    # rim and hub were built around Z: turn the axis to X
    for faces in (rim, tyre, hub):
        p.move(faces, R('Y', 90))
    p.move(rim + tyre + hub + spokes, T(x, CART_Y, AXLE_Z))


def cart():
    p = Part("hwacha_display")
    # axle and frame
    K.seg(p, (-0.62, CART_Y, AXLE_Z), (0.62, CART_Y, AXLE_Z), [(0.035, 0.0), (0.035, 1.0)], "iron", segments=8)
    for sx in (-1, 1):
        wheel(p, sx * 0.52)
        # side rails running back into the handles
        f = p.box((0.0, 0.0, 0.0), (0.07, 1.9, 0.07), "wood", bevel=0.01)
        p.move(f, T(sx * 0.36, CART_Y - 0.55, AXLE_Z + 0.12) @ R('X', 9))
        p.box((sx * 0.36, CART_Y - 1.4, AXLE_Z - 0.06), (0.05, 0.05, 0.12), "wood", bevel=0.008)   # stand-leg
    for y in (CART_Y + 0.25, CART_Y - 0.25):
        p.box((0.0, y, AXLE_Z + 0.12), (0.8, 0.06, 0.06), "wood", bevel=0.008)
    # the launch box on a tilted cradle
    W, D, H = BOX
    cr = T(0.0, CART_Y + 0.05, AXLE_Z + 0.2) @ R('X', TILT)
    f = p.box((0.0, 0.0, H / 2), (W, D, H), "box", bevel=0.015)
    p.move(f, cr)
    for z in (0.08, H - 0.08):
        f = p.box((0.0, 0.0, z), (W + 0.02, D + 0.02, 0.05), "iron", bevel=0.004)
        p.move(f, cr)
    for sx in (-1, 1):
        f = p.box((sx * (W / 2 + 0.03), 0.0, H * 0.45), (0.05, 0.2, H * 0.9), "wood", bevel=0.008)
        p.move(f, cr)
        p.box((sx * 0.34, CART_Y + 0.05, AXLE_Z + 0.12 + 0.12), (0.06, 0.06, 0.24), "wood", bevel=0.008)
    # loaded fire-arrows: points out of the front, shafts out of the back
    rng = np.random.default_rng(3)
    for i in range(10):
        for j in range(10):
            if rng.random() > 0.35:
                continue
            x = -W / 2 + 0.08 + i * (W - 0.16) / 9
            z = 0.07 + j * (H - 0.14) / 9
            a = T(0.0, D / 2, z) @ T(x, 0.0, 0.0)
            # iron point
            f = p.lathe([(0.008, 0.0), (0.012, 0.01), (0.0045, 0.06)], "iron", segments=4, cap_top=True)
            p.move(f, cr @ a @ R('X', -90))
            # paper powder tube and shaft out of the back
            f = K.seg(p, (x, -D / 2 + 0.02, z), (x, -D / 2 - 0.12, z), [(0.012, 0.0), (0.012, 1.0)], "paper",
                      segments=5)
            p.move(f, cr)
            f = K.seg(p, (x, -D / 2 - 0.12, z), (x, -D / 2 - 0.62, z), [(0.006, 0.0), (0.006, 1.0)], "bamboo",
                      segments=4)
            p.move(f, cr)
            f = p.box((x, -D / 2 - 0.57, z), (0.002, 0.08, 0.03), "feather")
            p.move(f, cr)
    return p


def dais(p):
    W, D, H = DAIS
    y = DAIS_Y
    p.box((0.0, y, 0.05), (W + 0.08, D + 0.08, 0.1), "lacquer_black", bevel=0.015)
    p.box((0.0, y, H / 2 + 0.05), (W, D, H - 0.1), "lacquer", bevel=0.012)
    p.box((0.0, y, H + 0.01), (W + 0.06, D + 0.06, 0.04), "lacquer_black", bevel=0.01)
    # brocade cushion
    p.box((0.0, y, H + 0.07), (0.7, 0.5, 0.08), "brocade", bevel=0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.lathe([(0.0, 0.0), (0.012, 0.0), (0.008, -0.08), (0.0, -0.09)], "tassel", segments=6,
                    center=(sx * 0.34, y + sy * 0.24, H + 0.05))
    # plaque on the front
    p.box((0.0, y + D / 2 + 0.006, H * 0.55), (1.04, 0.012, 0.3), "plaque", bevel=0.004)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.02), y + sy * (D / 2 - 0.02), H * 0.5), (0.06, 0.06, H * 0.9), "gilt", bevel=0.005)
    return H + 0.11


_TXT = {}


def plaque_text(ctx, seed=1701):
    s = M.brass(ctx, seed, tarnish_amount=1.2)
    if "t" not in _TXT:
        _TXT["t"] = pixelfont.trim(pixelfont.render(["HWACHA", "WÓZ OGNISTYCH STRZAŁ", "KOREA, XV W."], line_gap=2))
        _TXT["b"] = pixelfont.trim(pixelfont.render(["HWACHA"], bold=True))
    front = ctx.n[:, 1] > 0.8
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    zc = DAIS[2] * 0.55
    txt = pixelfont.stamp(ctx, _TXT["t"], 0.0, 0.0, scale=1, u=-x, v=z - zc)
    m = front & txt
    s.use_ramp(P["brass_tarnish"], mask=m, shade=np.full(ctx.N, 1.0))
    s.height = s.height - m * 0.0006
    return s


def box_paint(ctx, seed=1711):
    """The launch box: oiled pine, the front face drilled 10 x 10 (dark
    holes with a scorched ring), red lacquer on the iron-bound edges."""
    s = A.wood(ctx, seed, ramp="hinoki", center=4.4, contrast=1.0)
    # the hole grid on the face the arrows leave by (normal along the tilt)
    ny = ctx.n[:, 1] * math.cos(math.radians(TILT)) + ctx.n[:, 2] * math.sin(math.radians(TILT))
    face = ny > 0.9
    W, D, H = BOX
    # local coordinates on that face
    ca, sa = math.cos(math.radians(TILT)), math.sin(math.radians(TILT))
    q = ctx.p - np.array((0.0, CART_Y + 0.05, AXLE_Z + 0.2))
    lz = -q[:, 1] * sa + q[:, 2] * ca
    lx = q[:, 0]
    gx = (lx + W / 2 - 0.08) / ((W - 0.16) / 9)
    gz = (lz - 0.07) / ((H - 0.14) / 9)
    d = np.hypot(gx - np.round(gx), gz - np.round(gz))
    inside = (np.round(gx) >= 0) & (np.round(gx) <= 9) & (np.round(gz) >= 0) & (np.round(gz) <= 9)
    hole = face & inside & (d < 0.22)
    ring = face & inside & (d >= 0.22) & (d < 0.34)
    s.use_ramp(P["pig_black"], mask=hole, shade=np.full(ctx.N, 0.5))
    s.shade[ring] -= 2.0
    s.height = s.height - hole * 0.004
    return s


def build():
    p = cart()
    spot_z = dais(p)
    fns = {"wood": lambda c: A.wood(c, 1721, ramp="hinoki", center=4.0, contrast=1.1),
           "box": box_paint, "iron": M.iron,
           "paper": lambda c: A.paper(c, 1723, "silk_red", 4.0),
           "bamboo": lambda c: A.wood(c, 1725, ramp="tatami", center=5.0),
           "feather": lambda c: A.silk(c, "lacing_white", 4.0, 1727),
           "lacquer": lambda c: A.lacquer(c, 1731, wear=0.3),
           "lacquer_black": lambda c: A.lacquer(c, 1733, ramp="lacquer_black", center=3.0, wear=0.2),
           "brocade": lambda c: _brocade(c), "tassel": lambda c: A.silk(c, "silk_red", 4.0, 1735),
           "gilt": lambda c: A.gilt(c, 1737, worn=0.3, under="lacquer_black"), "plaque": plaque_text}
    return kit("hwacha_display", [p], fns, ppm=128, ao_dist=0.2, built_final=True,
               markers=[("weapon_spot", (0.0, DAIS_Y, spot_z), None)],
               preview_yaws=(-30.0, 30.0, 100.0, 200.0),
               preview_extra=[("plaque", (0.0, DAIS_Y + 0.4, DAIS[2] * 0.55), 0.5, 0.0, 5.0)])


def _brocade(ctx):
    from models.kit_asia_fixtures import brocade
    return brocade(ctx, 1739)
