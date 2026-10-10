"""The cast store (Magazyn odlewów, a haven): plaster casts made from the
marbles in the 19th century, stored on timber, crated, numbered. Warm and
dusty against the white galleries: chalky plaster with mould seams and
pencilled inventory numbers, pine, sacking, excelsior.

  cast_frieze_slab  a plaster cast of a slab of the Parthenon frieze (two
                    horsemen), 1.3 x 1.12 x 0.12 m, in a pine frame on two
                    feet; inventory number "GIPS 214" in black paint.
                    128 px/m. Origin = centre of the feet on the floor.
  cast_head         a cast of a helmeted head of Athena on a pine block,
                    mould seams down the sides, a paper label. 0.5 x 0.88 x
                    0.5 m. 192 px/m.
  cast_torso        a cast of a striding torso on a low pine pallet with an
                    iron armature rod sticking out of the neck. 0.75 x 1.55
                    x 0.6 m. 112 px/m.
  cast_shelf        a pine storage rack 2.0 x 2.2 x 0.6 m with casts of
                    fragments on its three shelves (a foot, a hand, a mask,
                    a capital's volute, a horse's head) and sacking.
                    Against a wall (back at z = 0). 96 px/m.
  cast_crate        an opened packing crate 1.2 x 0.9 x 0.8 m spilling
                    excelsior, a cast arm sticking out, stencilled "GIPS /
                    OSTROŻNIE". 112 px/m.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import font
from artlib import greek as GK
from artlib import kit as K
from artlib import materials as M
from artlib.archkit import facing, kit
from artlib.geo import Part
from artlib.sculpt import blob
from artlib.statue import sculpt_into
from models import gr_frieze
from models.gr_pediment import Pose

V = Vector


def frieze_slab():
    p = Part("cast_frieze_slab")
    W, H = 1.3, 1.0
    z0 = 0.12
    # the plaster slab (relief face) and its edges
    facing(p, [(-W / 2, -0.06, z0), (W / 2, -0.06, z0), (W / 2, -0.06, z0 + H), (-W / 2, -0.06, z0 + H)], "relief",
           (0, -1, 0))
    for sx in (-1, 1):
        facing(p, [(sx * W / 2, -0.06, z0), (sx * W / 2, 0.06, z0), (sx * W / 2, 0.06, z0 + H),
                   (sx * W / 2, -0.06, z0 + H)], "plaster", (sx, 0, 0))
    facing(p, [(-W / 2, -0.06, z0 + H), (W / 2, -0.06, z0 + H), (W / 2, 0.06, z0 + H), (-W / 2, 0.06, z0 + H)],
           "plaster", (0, 0, 1))
    facing(p, [(W / 2, 0.06, z0), (-W / 2, 0.06, z0), (-W / 2, 0.06, z0 + H), (W / 2, 0.06, z0 + H)], "back",
           (0, 1, 0))
    # pine frame round it and two feet
    for sx in (-1, 1):
        p.box((sx * (W / 2 + 0.03), 0.0, z0 + H / 2 - 0.04), (0.06, 0.14, H + 0.2), "pine", bevel=0.006)
        p.box((sx * (W / 2 - 0.1), 0.0, 0.05), (0.1, 0.6, 0.1), "pine", bevel=0.006)
    p.box((0, 0.0, z0 + H + 0.03), (W + 0.12, 0.14, 0.06), "pine", bevel=0.006)
    p.box((0, 0.0, z0 - 0.03), (W + 0.12, 0.14, 0.06), "pine", bevel=0.006)
    return p


def head():
    p = Part("cast_head")
    p.box((0, 0, 0.2), (0.4, 0.4, 0.4), "pine", bevel=0.01)
    T = Pose(0.0, 0.0, 0.4, k=1.0)
    b = [T.b((0, 0.01, 0.06), (0.12, 0.11, 0.06)),                         # the bust's foot
         T.b((0, 0.0, 0.16), (0.07, 0.07, 0.09)),                          # neck
         T.b((0, 0.0, 0.3), (0.105, 0.115, 0.12)),                         # skull
         T.b((0, -0.06, 0.27), (0.08, 0.06, 0.09)),                        # face
         T.b((0, -0.115, 0.28), (0.016, 0.022, 0.035), rot=(-12, 0, 0)),   # nose
         T.b((0, -0.105, 0.23), (0.035, 0.02, 0.015)),                     # lips
         T.b((0, -0.09, 0.2), (0.04, 0.03, 0.03))]                         # chin
    for sx in (-1, 1):
        b.append(T.b((sx * 0.04, -0.1, 0.3), (0.02, 0.014, 0.011), neg=True, stiff=1.5))
        b.append(T.b((sx * 0.1, 0.03, 0.22), (0.03, 0.06, 0.1)))           # hair falling to the neck
    # the Corinthian helmet pushed up on the head, its crest
    b += [T.b((0, 0.01, 0.4), (0.12, 0.13, 0.07)), T.b((0, -0.1, 0.38), (0.09, 0.05, 0.04)),
          T.b((0, 0.02, 0.48), (0.03, 0.15, 0.05)), T.b((0, 0.12, 0.42), (0.03, 0.08, 0.08))]
    sculpt_into(p, b, "plaster", res=0.007, tris=3200)
    return p


def torso():
    p = Part("cast_torso")
    p.box((0, 0, 0.06), (0.75, 0.6, 0.12), "pine", bevel=0.008)
    T = Pose(0.0, 0.0, 0.12, k=1.0)
    b = [T.b((0, 0.0, 0.62), (0.18, 0.14, 0.12)), T.b((0, -0.01, 0.82), (0.14, 0.11, 0.13)),
         T.b((0, -0.03, 1.02), (0.17, 0.12, 0.15))]
    for sx in (-1, 1):
        b.append(T.b((sx * 0.08, -0.12, 1.04), (0.075, 0.035, 0.06)))
        b.append(T.b((sx * 0.19, -0.02, 1.15), (0.08, 0.075, 0.065)))
        b += T.limb([(sx * 0.1, 0.0, 0.56), (sx * 0.12, -0.08 * sx, 0.12)], [0.11, 0.075])
    b.append(T.b((0, -0.02, 1.23), (0.06, 0.06, 0.06)))
    cuts = [(T(0, -0.02, 1.26), (0, 0, 1), 0.2), (T(0.28, 0, 1.12), (1, 0, -0.2), 0.15),
            (T(-0.28, 0, 1.12), (-1, 0, -0.2), 0.15), (T(0.12, 0.08, 0.2), (0.0, 0.0, -1.0), 0.15),
            (T(-0.12, -0.08, 0.2), (0.0, 0.0, -1.0), 0.15)]
    sculpt_into(p, b, "plaster", res=0.011, cuts=cuts, tris=3600, break_slot="plaster_break")
    p.lathe([(0.012, 1.3), (0.012, 1.48)], "iron", segments=6)
    return p


def shelf():
    p = Part("cast_shelf")
    W, D, H = 2.0, 0.6, 2.2
    y0 = -D
    for x in (-W / 2 + 0.04, 0.0, W / 2 - 0.04):
        for y in (y0 + 0.04, -0.04):
            p.box((x, y, H / 2), (0.07, 0.07, H), "pine", bevel=0.006)
    for z in (0.12, 0.85, 1.55, 2.15):
        p.box((0, y0 / 2, z), (W, D - 0.02, 0.03), "pine", bevel=0.004)
        p.box((0, y0 + 0.02, z - 0.05), (W, 0.03, 0.07), "pine", bevel=0.004)
    # diagonal brace at the back
    br = p.box((0, 0, 0), (2.3, 0.02, 0.06), "pine")
    p.move(br, Matrix.Translation((0.0, -0.02, 1.1)) @ Matrix.Rotation(math.radians(42), 4, 'Y'))
    # fragments on the shelves
    frag = []
    # a foot on the bottom shelf
    T = Pose(-0.6, -0.3, 0.135, k=1.0)
    frag += [T.b((0, 0, 0.04), (0.06, 0.13, 0.04)), T.b((0, 0.1, 0.1), (0.05, 0.05, 0.09))]
    frag += [T.b((dx, -0.12, 0.025), 0.018) for dx in (-0.04, -0.02, 0.0, 0.02, 0.04)]
    # a hand on the middle shelf
    T = Pose(-0.55, -0.3, 0.865, k=1.0)
    frag += [T.b((0, 0, 0.04), (0.05, 0.09, 0.03))] + T.limb([(0.0, -0.08, 0.04), (0.0, -0.16, 0.03)], [0.012, 0.01])
    frag += T.limb([(0.03, -0.06, 0.04), (0.05, -0.14, 0.03)], [0.011, 0.009])
    # a theatre mask
    T = Pose(0.45, -0.25, 0.865, k=1.0)
    frag += [T.b((0, 0, 0.15), (0.13, 0.05, 0.15)), T.b((0, -0.04, 0.16), (0.03, 0.03, 0.05)),
             T.b((0, -0.03, 0.08), (0.06, 0.03, 0.03), neg=True, stiff=1.4)]
    frag += [T.b((sx * 0.05, -0.04, 0.2), (0.025, 0.03, 0.015), neg=True, stiff=1.4) for sx in (-1, 1)]
    # a volute of an Ionic capital and a horse's head on the top shelf
    T = Pose(-0.5, -0.3, 1.565, k=1.0)
    frag += [T.b((0, 0, 0.12), (0.06, 0.12, 0.12)), T.b((0.04, 0, 0.12), (0.03, 0.12, 0.06))]
    T = Pose(0.5, -0.3, 1.565, k=1.0)
    frag += [T.b((0, 0.05, 0.14), (0.07, 0.08, 0.14), rot=(0, 30, 0)), T.b((0.1, 0.0, 0.1), (0.05, 0.06, 0.12),
                                                                          rot=(0, 50, 0))]
    sculpt_into(p, frag, "plaster", res=0.008, tris=3200)
    # sacking thrown over the middle of the top shelf
    sk = p.box((0.0, -0.3, 1.6), (0.6, 0.5, 0.06), "sacking", bevel=0.02)
    return p


def crate():
    p = Part("cast_crate")
    W, D, H = 1.2, 0.9, 0.8
    # four walls of boards, open top; the lid leaning against it
    for sy in (-1, 1):
        p.box((0, sy * (D / 2 - 0.012), H / 2), (W, 0.024, H), "boards", bevel=0.004)
    for sx in (-1, 1):
        p.box((sx * (W / 2 - 0.012), 0, H / 2), (0.024, D - 0.05, H), "boards", bevel=0.004)
    p.box((0, 0, 0.02), (W - 0.05, D - 0.05, 0.04), "boards")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), H / 2), (0.06, 0.06, H), "battens", bevel=0.005)
    for z in (0.08, H - 0.06):
        p.box((0, -D / 2 - 0.01, z), (W, 0.03, 0.09), "battens", bevel=0.005)
    # excelsior heaped inside and spilling over the rim
    T = Pose(0.0, 0.0, 0.0, k=1.0)
    wool = [T.b((x, y, H - 0.05), (0.22, 0.2, 0.09)) for x in (-0.3, 0.0, 0.3) for y in (-0.18, 0.18)]
    wool += [T.b((0.45, -0.46, H - 0.12), (0.12, 0.06, 0.1)), T.b((-0.5, 0.0, H - 0.08), (0.08, 0.2, 0.06))]
    sculpt_into(p, wool, "straw", res=0.03, tris=900)
    # a cast arm reaching up out of the straw
    arm = T.limb([(0.15, 0.05, H - 0.05), (0.25, -0.05, H + 0.3), (0.38, -0.1, H + 0.45)], [0.06, 0.05, 0.04])
    arm += [T.b((0.42, -0.12, H + 0.5), (0.04, 0.03, 0.06))]
    sculpt_into(p, arm, "plaster", res=0.01, tris=900)
    return p


# --------------------------------------------------------------------------

def _pine(ctx):
    s = M.wood_oak(ctx, seed=1901)
    s.shade += 1.2
    return s


def _plaster(ctx):
    s = GK.plaster_cast(ctx, seed=1903)
    # pencilled inventory numbers and grime where hands held it
    smudge = ctx.fbm(3.0, 3, 1905) > 0.45
    s.shade -= smudge * 0.8
    return s


def _plaster_seam(ctx, axis=0):
    """Plaster with the mould seam: a thin raised line where the piece
    moulds met (along the side of the head)."""
    s = _plaster(ctx)
    seam = np.abs(ctx.p[:, axis]) < ctx.texel * 0.8
    s.shade += seam * 1.0
    s.height = s.height + seam * 0.0015
    return s


def _relief_cast(maps, W):
    def fn(ctx):
        u = -ctx.p[:, 0] + W / 2
        v = ctx.p[:, 2] - 0.12
        s = GK.relief_surface(ctx, maps, u, v, seed=1907, material="plaster", paint=0.0)
        ink = font.text_mask(u, v, "GIPS 214", 1.1, 0.06, 3.0 / 128, align="center")
        s.use_ramp(M.P["leather"], mask=ink, shade=np.full(ctx.N, 1.0))
        return s
    return fn


def _back(ctx):
    s = _plaster(ctx)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    hessian = (np.mod(u * 64, 1.0) < 0.3) | (np.mod(v * 64, 1.0) < 0.3)   # scrim pressed in the back
    s.shade -= hessian * 0.6
    return s


def _crate_boards(ctx):
    s = _pine(ctx)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    front = ctx.n[:, 1] > 0.5
    ink = font.text_mask(u, v, "GIPS", 0.0, 0.45, 4.0 / 112, align="center")
    ink |= font.text_mask(u, v, "OSTROŻNIE", 0.0, 0.3, 3.0 / 112, align="center")
    s.use_ramp(M.P["leather"], mask=ink & front, shade=np.full(ctx.N, 1.2))
    return s


def _straw(ctx):
    return M.cloth(ctx, "excelsior", 4.0, 1911)


def _sacking(ctx):
    return M.cloth(ctx, "cardboard", 4.2, 1913)


def build():
    maps = gr_frieze.two_riders(W=1.3, seed=21)
    return [
        kit("cast_frieze_slab", [frieze_slab()], {"relief": _relief_cast(maps, 1.3), "plaster": _plaster,
                                                  "back": _back, "pine": _pine}, ppm=128, ground=0.0, ao_dist=0.2,
            preview_extra=[("face", (0.0, 0.0, 0.62), 0.7, 0.0, 4.0)]),
        kit("cast_head", [head()], {"plaster": lambda c: _plaster_seam(c, 0), "pine": _pine}, organic=("cast_head",),
            ppm=192, ground=0.0, ao_dist=0.1),
        kit("cast_torso", [torso()], {"plaster": _plaster, "plaster_break": _plaster, "pine": _pine,
                                      "iron": M.iron}, organic=("cast_torso",), ppm=112, ground=0.0, ao_dist=0.2),
        kit("cast_shelf", [shelf()], {"plaster": _plaster, "pine": _pine, "sacking": _sacking}, ppm=96, ground=0.0,
            ao_dist=0.25, wall=True),
        kit("cast_crate", [crate()], {"boards": _crate_boards, "battens": _pine, "straw": _straw,
                                      "plaster": _plaster}, ppm=112, ground=0.0, ao_dist=0.25),
    ]
