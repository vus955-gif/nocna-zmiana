"""The armoury exhibit: the Gatling (vm_gatling.build_gun, without hands)
on a museum tripod on a low walnut plinth, a sloping brass plaque at the
front engraved "Kartaczownica, 1871" / "system Gatlinga" (real letters),
and a galvanised security chain wound round the barrels and the tripod
head, closed with a brass padlock. Plinth 1.2 x 0.9 m, gun axis ~0.97 m
up; the muzzle points to the viewer's right and a little toward them, the
crank side faces the visitor.

Origin on the floor at the plinth centre; faces -Y (Godot +Z) like props.
Parts:
    gatling_display  (0, 0, 0)       plinth, plaque, tripod (stays when the gun is taken)
    gun              trunnions       the whole Gatling (hide it once picked up)
    chain            padlock         chain + padlock (shoot it or punch it off: hide it,
                                     or drop it as debris)
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import vm_gatling as G

PW, PD, PH = 1.2, 0.9, 0.12            # plinth
GUN_Z = 0.97                            # gun axis height
TRUNNION = Vector((0.0, -0.04, 0.0))    # gun-space balance point held by the yoke
HEAD = Vector((0.0, 0.08, GUN_Z - 0.16))
PLACE = T(0.0, 0.08, GUN_Z) @ R('Z', -112) @ R('X', 4) @ T(*(-TRUNNION))
PLAQUE_C = Vector((0.0, -PD / 2 + 0.1, PH + 0.035))
PLAQUE_TILT = 35.0                      # the plate leans back, facing up toward the visitor
PLATE_C = PLAQUE_C + R('X', -PLAQUE_TILT) @ Vector((0.0, -0.069, 0.0))
PLATE_W, PLATE_H = 0.4, 0.12
TEXT = pixelfont.trim(pixelfont.render(["Kartaczownica, 1871", "system Gatlinga"], line_gap=1))


def plaque(ctx):
    """Brass plate with black-filled engraved letters and a ruled border."""
    s = M.brass(ctx, seed=621, tarnish_amount=1.2)
    face = ctx.n[:, 1] < -0.6
    # the plate is box-projected along Y: u = x, v = z (heights foreshortened)
    c_v = PLATE_C.z
    txt = face & pixelfont.stamp(ctx, TEXT, 0.0, c_v)
    s.use_ramp(M.P["hair"], mask=txt, shade=np.full(ctx.N, 1.4) + M._dither(ctx, 0.6, 3))
    s.height = s.height - txt * 0.0003
    s.rough = np.where(txt, 0.8, s.rough)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    hw, hh = PLATE_W / 2 - 0.012, (PLATE_H / 2 - 0.01) * math.cos(math.radians(PLAQUE_TILT))
    border = face & (np.abs(np.maximum(np.abs(u) / hw, np.abs(v - c_v) / hh) - 1.0) < ctx.texel * 0.7 / hh)
    s.shade[border] -= 3.0
    return s


def chain_steel(ctx):
    return M.steel(ctx, seed=623, center=7.8, dent=0.0, rust=0.2, polish=0.22, scratch=0.3)


FNS = dict(G.GUN_FNS, brass=lambda c: M.brass(c, seed=625, tarnish_amount=1.8), plinth=M.wood_dark,
           trim=lambda c: M.brass(c, seed=627, tarnish_amount=2.4), plaque=plaque, oak=lambda c: M.walnut_stock(c, seed=631), iron=M.iron,
           chain=chain_steel, lock=lambda c: M.brass(c, seed=629, tarnish_amount=2.0))


def _plinth(p):
    p.box((0, 0, PH / 2), (PW, PD, PH), "plinth", bevel=0.012)
    p.box((0, 0, 0.012), (PW + 0.03, PD + 0.03, 0.024), "plinth", bevel=0.008)          # skirting
    for sy in (-1, 1):
        p.box((0, sy * (PD / 2 + 0.002), PH - 0.012), (PW - 0.02, 0.006, 0.012), "trim", bevel=0.002)
    for sx in (-1, 1):
        p.box((sx * (PW / 2 + 0.002), 0, PH - 0.012), (0.006, PD - 0.02, 0.012), "trim", bevel=0.002)
    # sloping plaque block at the front
    blk = p.box((0, 0, 0), (0.46, 0.13, 0.14), "plinth", bevel=0.008)
    plate = p.box((0, -0.066, 0.0), (PLATE_W, 0.006, PLATE_H), "plaque", bevel=0.002)
    p.move(blk + plate, T(*PLAQUE_C) @ R('X', -PLAQUE_TILT))


def _tripod(p):
    h = HEAD
    kit.seg(p, h + Vector((0, 0, -0.05)), h + Vector((0, 0, 0.03)), [(0.05, 0), (0.055, 0.2), (0.05, 1.0)],
            "brass", segments=14)                                                          # head
    kit.seg(p, h + Vector((0, 0, 0.03)), h + Vector((0, 0, 0.1)), [(0.022, 0), (0.02, 1.0)], "iron", segments=10)
    # yoke: a cross bar under the gun and two arms up to the trunnion pins
    base = h + Vector((0, 0, 0.1))
    for sx in (-1, 1):
        tw = PLACE @ (TRUNNION + Vector((sx * 0.1, 0, 0)))
        p.tube([base, Vector((tw.x, tw.y, base.z + 0.01)), tw + Vector((0, 0, -0.012))], 0.011, "iron", sides=6,
               smooth=False)
        kit.seg(p, PLACE @ (TRUNNION + Vector((sx * 0.078, 0, 0))), PLACE @ (TRUNNION + Vector((sx * 0.106, 0, 0))),
                [(0.016, 0), (0.016, 1)], "iron", segments=8)                          # trunnion pin + cap
    # three legs to the plinth top, iron shoes, brass ferrules
    for k, ang in enumerate((90.0, 210.0, 330.0)):
        a = math.radians(ang)
        foot = Vector((0.42 * math.cos(a), 0.08 + 0.42 * math.sin(a), PH))
        top = h + Vector((0.05 * math.cos(a), 0.05 * math.sin(a), -0.02))
        kit.seg(p, top, foot + Vector((0, 0, 0.05)), [(0.022, 0), (0.024, 0.3), (0.02, 1.0)], "oak", segments=8)
        kit.seg(p, top, top + (foot - top).normalized() * 0.06, [(0.027, 0), (0.027, 1.0)], "brass",
                segments=8)                                                               # ferrule
        kit.seg(p, foot + Vector((0, 0, 0.07)), foot, [(0.021, 0), (0.016, 0.8), (0.03, 0.85), (0.03, 1.0)], "iron",
                segments=8)                                                               # shoe + foot plate


def _chain_path():
    """Chain centre line in model space: from the padlock up to the barrels,
    1.3 turns round them, down to the tripod head, once round the pintle
    and back down to the padlock."""
    lock = HEAD + Vector((0.0, -0.09, -0.16))
    pts = [lock + Vector((0.012, 0, 0.03))]
    start = PLACE @ Vector((0.0, 0.47, -0.07))
    pts.append(lock.lerp(start, 0.5) + Vector((0.0, -0.04, 0.0)))
    turns = 1.3
    n = 22
    for i in range(n + 1):
        t = i / n
        a = -math.pi / 2 + math.tau * turns * t
        y = 0.47 - 0.1 * t
        pts.append(PLACE @ Vector((0.074 * math.cos(a), y, 0.074 * math.sin(a))))
    pintle = HEAD + Vector((0, 0, 0.06))
    pts.append(pts[-1].lerp(pintle, 0.5) + Vector((0, -0.03, 0)))
    for i in range(13):
        a = math.pi * 1.5 + math.tau * i / 12
        pts.append(pintle + Vector((0.055 * math.cos(a), 0.055 * math.sin(a), -0.01 * i / 12)))
    pts.append(pintle.lerp(lock, 0.5) + Vector((-0.02, -0.03, 0.0)))
    pts.append(lock + Vector((-0.012, 0, 0.03)))
    return pts, lock


def _chain(p):
    pts, lock = _chain_path()
    acc = [0.0]
    for a, b in zip(pts[:-1], pts[1:]):
        acc.append(acc[-1] + (b - a).length)
    pitch = 0.041
    count = int(acc[-1] / pitch)
    for k in range(count + 1):
        s = min(k * pitch, acc[-1] - 1e-6)
        i = int(np.clip(np.searchsorted(acc, s) - 1, 0, len(pts) - 2))
        t = (s - acc[i]) / max(acc[i + 1] - acc[i], 1e-9)
        c = pts[i].lerp(pts[i + 1], t)
        d = (pts[i + 1] - pts[i]).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        nrm = d.cross(ref).normalized()
        if k % 2:
            nrm = d.cross(nrm).normalized()
        loop = [c + d * (0.026 * math.cos(a)) + nrm * (0.015 * math.sin(a)) for a in np.linspace(0, math.tau, 7)[:-1]]
        p.tube(loop + [loop[0]], 0.0056, "chain", sides=4, caps=False, smooth=True)
    # padlock: brass body, steel shackle through both chain ends
    p.box(lock + Vector((0, 0, -0.035)), (0.056, 0.024, 0.062), "lock", bevel=0.006)
    arc = [lock + Vector((0.018 * math.cos(a), 0.0, 0.018 * math.sin(a) - 0.004)) for a in np.linspace(0, math.pi, 8)]
    p.tube(arc, 0.0045, "chain", sides=6)
    p.box(lock + Vector((0, -0.0125, -0.045)), (0.006, 0.002, 0.014), "iron")            # keyhole


def build():
    base = Part("gatling_display")
    _plinth(base)
    _tripod(base)
    gun = Part("gun", origin=tuple(PLACE @ TRUNNION))
    G.build_gun({"body": gun, "barrels": gun, "crank": gun, "belt": gun}, place=PLACE)
    chain = Part("chain", origin=tuple(_chain_path()[1]))
    _chain(chain)
    return Model("gatling_display", [base, gun, chain], FNS, ppm=320, ground=0.0, ao_dist=0.12, ao_rays=12,
                 ao_stride=2, preview_elevation=16.0, preview_yaws=(-30.0, 25.0, 150.0, 210.0),
                 preview_extra=[("plaque", tuple(PLATE_C), 0.25, 0.0, 35.0),
                                ("chain", tuple(PLACE @ Vector((0, 0.3, 0)) + Vector((0, -0.05, -0.1))), 0.45,
                                 -20.0, 15.0)])
