"""Projectile: the whaling harpoon in flight (and stuck in a wall or an
exhibit). The same forged harpoon the harpoon gun is loaded with
(vm_harpoon part head): a 0.9 m iron shank with a long slot for the
sliding line ring, a stop collar, a heavy two-flued head 12 cm long and
9 cm across, and at the back the line ring (slid back to the end of the
slot by the pull of the line) against a forged end button.

Flies along +Y in Blender (Godot -Z), head forward; origin at the middle
of the shank, so the game can spin it and bury the tip in a wall. The
flues lie in the horizontal plane (Godot X); the loaded harpoon in
vm_harpoon is rolled 40 degrees about its axis toward the player's eye.

Part / marker   Blender (x, y, z)     Godot (x, y, z)       parent
harpoon_bolt    (0, 0, 0)             (0, 0, 0)             -             shank, head, ring
barbs           (0, 0.33, 0)          (0, 0, -0.33)         harpoon_bolt  upgrade "Zadziory" (hide when
                                                                          not bought), same as vm upg_barbs
Tail            (0, -0.405, 0)        (0, 0, 0.405)         root          the line ring: attach the line here
Tip             (0, 0.45, 0)          (0, 0, -0.45)         root          the point (bury this in the wall)
"""
import math

import numpy as np

from artlib import kit
from artlib.geo import Part
from artlib.kit import T
from artlib.model import Model
from models import _harpoon_parts as H

TIP_Y = 0.45
TAIL_Y = -0.445
RING_Y = -0.405
HEAD_S = 1.3
SHANK_R = 0.0085


def harpoon_iron(ctx):
    """Forged iron with the long slot down both sides of the shank."""
    s = H.forged(ctx, seed=721, center=4.6, rust=0.8)
    side = np.abs(ctx.n[:, 0]) > 0.75
    y = ctx.p[:, 1]
    slot = side & (y > RING_Y - 0.012) & (y < 0.2) & (np.abs(ctx.p[:, 2]) < 0.0022) & \
        (np.hypot(ctx.p[:, 0], ctx.p[:, 2]) < SHANK_R * 1.15)
    s.use_ramp(H.TAR, mask=slot, shade=np.full(ctx.N, 0.4) + (np.abs(ctx.p[:, 2]) > 0.0012) * 1.2)
    s.height = s.height - slot * 0.0008
    s.metal = np.where(slot, 0.2, s.metal)
    s.rough = np.where(slot, 0.8, s.rough)
    return s


FNS = {"harpoon": harpoon_iron}


def build():
    p = Part("harpoon_bolt")
    frame = T(0, TIP_Y, 0)
    H.head(p, frame, s=HEAD_S)
    H.shank(p, frame, TAIL_Y + 0.008 - TIP_Y, -0.104, r=SHANK_R)
    collar = TIP_Y - 0.212
    kit.seg(p, (0, collar - 0.006, 0), (0, collar + 0.006, 0),
            [(0.0086, 0.0), (0.0114, 0.3), (0.0114, 0.7), (0.0086, 1.0)], "harpoon", segments=10)
    kit.seg(p, (0, TAIL_Y, 0), (0, TAIL_Y + 0.02, 0),
            [(0.0062, 0.0), (0.0108, 0.25), (0.0112, 0.6), (0.0088, 1.0)], "harpoon", segments=10)  # end button
    H.torus(p, (0, RING_Y, 0), (0.12, 1.0, 0.08), 0.016, 0.0031, "harpoon", segments=14, ring=6)
    barbs = Part("barbs", origin=(0, TIP_Y - 0.12, 0), parent="harpoon_bolt")
    H.barbs(barbs, frame, s=HEAD_S, spurs=(-0.152, -0.188))
    return Model("harpoon_bolt", [p, barbs], FNS, ppm=256, ground=None, ao_dist=0.02, ao_rays=8, ao_stride=1,
                 front=1, markers=[("Tail", (0.0, RING_Y, 0.0), None), ("Tip", (0.0, TIP_Y, 0.0), None)],
                 preview_elevation=24.0,
                 preview_extra=[("head", (0.0, TIP_Y - 0.08, 0.0), 0.12, -35.0, 35.0)])
