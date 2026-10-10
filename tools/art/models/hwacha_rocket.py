"""Projectile: a singijeon fire-arrow in flight (what vm_hwacha shoots).
A flat forged iron point on a socket, a short twine-bound nose, the red
hanji-paper powder tube lashed to the bamboo shaft with twine, its clay
nozzle glowing (emission map: the charge is burning), the long split-bamboo
shaft with node rings, three barred pheasant vanes and a swollen nock.
0.5 m long, slightly fuller than the arrows sitting in the launcher so it
reads in flight.

Flies along +Y in Blender (Godot -Z), point forward; origin at the middle
of the shaft. Part / marker (Blender (x, y, z) -> Godot (x, z, -y)):
    hwacha_rocket  (0, 0, 0)            (0, 0, 0)          -      whole arrow (point at y = +0.25)
    Exhaust        (0, 0.108, 0)        (0, 0, -0.108)     root   the back of the powder tube (the
                                                                  glowing nozzle): flame and smoke
"""
from artlib import kit
from artlib.geo import Part
from artlib.model import Model
from models import _hwacha_parts as HP

L = 0.5
RT, RS = 0.0112, 0.0038           # powder tube and shaft radius
HEAD_LEN, NOSE, TUBE_LEN = 0.034, 0.011, 0.082
FLETCH_LEN, FLETCH_H = 0.08, 0.0135

FNS = dict(HP.ARROW_FNS, nozzle=lambda c: HP.nozzle(c, hot=True))


def build():
    p = Part("hwacha_rocket")
    _, yb = HP.arrow_full(p, kit.T(0, 0, 0), L=L, rt=RT, rs=RS, head_len=HEAD_LEN, nose=NOSE, tube_len=TUBE_LEN,
                          seg=10, fletch_len=FLETCH_LEN, fletch_h=FLETCH_H, nozzle_slot="nozzle")
    exhaust = (0.0, round(yb - 0.002, 4), 0.0)
    return Model("hwacha_rocket", [p], FNS, ppm=256, ground=None, ao_dist=0.02, ao_rays=8, ao_stride=1, front=1,
                 markers=[("Exhaust", exhaust, None)], preview_elevation=24.0,
                 preview_extra=[("head", (0.0, L / 2 - 0.08, 0.0), 0.1, -35.0, 30.0),
                                ("tail", (0.0, -L / 2 + 0.06, 0.0), 0.08, -35.0, 30.0)])
