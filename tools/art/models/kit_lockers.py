"""Lobby kit: staff lockers.

  locker_05m  one steel locker 0.5 x 2.0 x 0.5 m (kit id "lockers" is a row:
              tile it along X, 4 for the 2 m row in the staff corridor, 5 for
              the 2.5 m row in the security room; scale Z to the row's
              depth). Olive stove enamel, louvres top and bottom, a brass
              number plate, a lift handle with a padlock hasp. Parts: locker
              (body) and door (pivot on its hinge at -X, swings about Y).
"""
import numpy as np

from artlib import arch_materials as A
from artlib import font
from artlib import materials as M
from artlib.archkit import kit
from artlib.geo import Part


def locker():
    body = Part("locker")
    W, H, D = 0.5, 2.0, 0.5
    body.box((0, 0, 0.05), (W - 0.02, D - 0.04, 0.1), "dark", bevel=0.005)                 # plinth
    body.box((0, 0.02, H / 2 + 0.05), (W, D - 0.04, H - 0.1), "enamel", bevel=0.006)     # carcass
    body.box((0, 0.02, H + 0.005), (W + 0.004, D - 0.02, 0.012), "enamel", bevel=0.003)
    hx = -W / 2 + 0.02
    door = Part("door", origin=(hx, -D / 2 + 0.02, 0.1), parent="locker")
    y = -D / 2 + 0.012
    door.box((0, y, H / 2 + 0.05), (W - 0.03, 0.02, H - 0.14), "enamel", bevel=0.005)
    for z0 in (0.25, 1.72):
        for k in range(6):
            door.box((0, y - 0.011, z0 + k * 0.03), (W - 0.2, 0.004, 0.012), "dark", bevel=0.001)
    door.box((0.0, y - 0.012, 1.55), (0.1, 0.004, 0.05), "plate", bevel=0.002)
    door.box((W / 2 - 0.08, y - 0.02, 1.05), (0.03, 0.02, 0.14), "steel", bevel=0.004)
    door.box((W / 2 - 0.08, y - 0.035, 0.98), (0.04, 0.012, 0.02), "steel", bevel=0.003)
    for z in (0.35, 1.8):
        body.box((hx - 0.004, y - 0.004, z), (0.014, 0.02, 0.08), "steel", bevel=0.003)
    return [body, door]


def _plate(ctx):
    s = M.brass(ctx)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    ink = font.text_mask(u, v, "17", 0.0, 1.55 - 0.014, ctx.texel * 1.0, align="center")
    s.use_ramp(A.P["leather"], mask=ink, shade=np.full(ctx.N, 1.0))
    return s


def build():
    fns = {"enamel": lambda c: M.enamel(c, "paint_olive", 5.6), "dark": lambda c: A.paint(c, "iron", 1.5),
           "plate": _plate, "steel": M.steel}
    return [kit("locker_05m", locker(), fns, ppm=256, ao_dist=0.12)]
