"""Emergency cabinet in the diorama: a red enamelled steel wall box with a
glass front, the flare pistol hanging inside on two hooks, two spare
flares on the floor of the box, the stencil "W RAZIE POŻARU / ZBIĆ
SZYBKĘ" in white on the red header (real letters, artlib/pixelfont.py) and
a little red hammer on a chain at its right side. 0.46 x 0.15 x 0.64 m.

Origin on the wall plane (y = 0) at the bottom centre; the cabinet sticks
out toward -Y (Godot +Z), like pistol_locker. Parts:
    emergency_cabinet  (0, 0, 0)                box, frame, header, hooks, spare flares, hammer
    glass              (0, -0.146, 0.285)       the pane (glass material, casts no shadow);
                                                hide it when smashed
    flare_gun          (0, -0.07, 0.29)         the flare pistol on its hooks (muzzle to the
                                                left, label side out); hide it when taken
"""
import numpy as np
from mathutils import Vector

from artlib import kit, pixelfont
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import R, T
from artlib.model import Model
from models import vm_flare

W, H, D, TH = 0.46, 0.64, 0.15, 0.014
FS, BR, TB = 0.04, 0.05, 0.13          # frame stiles, bottom rail, top header
OPEN_Z0, OPEN_Z1 = BR, H - TB
GUN_C = Vector((0.0, -0.07, 0.29))
TEXT = pixelfont.render(["W RAZIE POŻARU", "ZBIĆ SZYBKĘ"], bold=True, line_gap=2)
TEXT_Z = H - TB / 2 + 0.002


def red(ctx):
    return M.enamel(ctx, "paint_red", 5.3, seed=531, chip=0.5, gloss=0.32, under="steel")


def header(ctx):
    """Red header with the white stencil, a few specks of the paint missing."""
    s = M.enamel(ctx, "paint_red", 5.3, seed=531, chip=0.25, gloss=0.32, under="steel")
    front = ctx.n[:, 1] < -0.7
    txt = pixelfont.stamp(ctx, TEXT, 0.0, TEXT_Z) & front & (ctx.rand(533) > 0.02)
    s.use_ramp(M.P["enamel_white"], mask=txt,                # stencilled after the chips
               shade=np.full(ctx.N, 6.0) + ctx.fbm(30.0, 2, 535) * 0.5 + M._dither(ctx, 0.8, 537))
    s.height = s.height + txt * 0.0002
    s.rough = np.where(txt, 0.45, s.rough)
    return s


def inside(ctx):
    return M.enamel(ctx, "enamel_white", 6.0, seed=539, chip=0.15, gloss=0.45, under="steel")


FNS = dict(vm_flare.FNS, red=red, header=header, inside=inside,
           steel=lambda c: M.steel(c, seed=541, center=7.2, dent=0.1, rust=0.6),
           hull=lambda c: M.plastic(c, "paint_red", 4.4, seed=543, rough=0.7, scuff=0.5),
           handle=lambda c: M.plastic(c, "paint_red", 5.0, seed=545, rough=0.4, scuff=1.0))


def _flare(p, a, b):
    """A spare flare cartridge lying from a (brass base) to b (red cap)."""
    a, b = Vector(a), Vector(b)
    kit.seg(p, a, a + (b - a) * 0.12, [(0.0155, 0.0), (0.0155, 1.0)], "brass", segments=10)
    kit.seg(p, a + (b - a) * 0.12, b, [(0.0138, 0.0), (0.0138, 0.9), (0.009, 1.0)], "hull", segments=10)


def _chain(p, top, links=5, pitch=0.016):
    pts = []
    for k in range(links):
        c = Vector(top) + Vector((0, 0, -k * pitch))
        loop = []
        for j in range(8):
            a = 2 * np.pi * j / 8
            if k % 2 == 0:
                loop.append((c.x + 0.0045 * np.cos(a), c.y, c.z + 0.009 * np.sin(a)))
            else:
                loop.append((c.x, c.y + 0.0045 * np.cos(a), c.z + 0.009 * np.sin(a)))
        p.tube(loop + [loop[0]], 0.0014, "steel", sides=4, caps=False)
        pts.append(c)
    return Vector(top) + Vector((0, 0, -links * pitch))


def build():
    body = Part("emergency_cabinet")
    body.box((0, -TH / 2, H / 2), (W, TH, H), "inside")                                   # back
    for sx in (-1, 1):
        body.box((sx * (W / 2 - TH / 2), -D / 2, H / 2), (TH, D, H), "red", bevel=0.004)  # sides
    body.box((0, -D / 2, TH / 2), (W, D, TH), "red", bevel=0.004)                         # bottom
    body.box((0, -D / 2, H - TH / 2), (W, D, TH), "red", bevel=0.004)                     # top
    for sx in (-1, 1):
        body.box((sx * (W / 2 - FS / 2), -D + 0.002, H / 2), (FS, 0.014, H), "red", bevel=0.004)   # stiles
    body.box((0, -D + 0.002, BR / 2), (W, 0.014, BR), "red", bevel=0.004)                 # bottom rail
    body.box((0, -D + 0.001, H - TB / 2), (W, 0.016, TB), "header", bevel=0.004)          # header with the stencil
    # rubber gasket round the opening, inner walls lined white
    for z in (OPEN_Z0 + 0.003, OPEN_Z1 - 0.003):
        body.box((0, -D + 0.009, z), (W - 2 * FS, 0.006, 0.006), "black")
    for sx in (-1, 1):
        body.box((sx * (W / 2 - FS + 0.003), -D + 0.009, (OPEN_Z0 + OPEN_Z1) / 2), (0.006, 0.006, OPEN_Z1 - OPEN_Z0),
                 "black")
    # hooks for the pistol (grip hook and barrel hook), spare flares on the floor
    # (one through the trigger guard, one under the barrel; arms run out past
    # the gun and turn up in front of it)
    for x, z in ((0.012, GUN_C.z + 0.012), (-0.08, GUN_C.z + 0.069 - vm_flare.R_OUT * 1.1 - 0.004)):
        body.tube([(x, -TH, z), (x, -0.1, z), (x, -0.106, z + 0.006), (x, -0.107, z + 0.016)], 0.0032, "black",
                  sides=5)
    # two spare flares in spring clips on the back wall under the pistol
    for z in (0.115, 0.155):
        _flare(body, (-0.12, -TH - 0.02, z), (0.0, -TH - 0.02, z))
        for x in (-0.085, -0.03):
            body.box((x, -TH - 0.01, z), (0.008, 0.022, 0.036), "black", bevel=0.002)
    # the hammer on its chain at the right side
    hook = Vector((W / 2 + 0.006, -0.05, H - 0.1))
    body.tube([(W / 2, -0.05, hook.z + 0.012), (hook.x + 0.008, -0.05, hook.z + 0.012), (hook.x + 0.01, -0.05, hook.z)],
              0.003, "steel", sides=5)
    end = _chain(body, hook + Vector((0.01, 0, -0.012)), links=5)
    handle = body.box((0, 0, 0), (0.014, 0.014, 0.13), "handle", bevel=0.003)
    head = body.box((0, 0, 0), (0.016, 0.06, 0.02), "steel", bevel=0.003)
    body.move(head, T(0, 0, -0.07))
    body.move(handle + head, T(end.x, end.y, end.z - 0.065))
    # the pane
    glass = Part("glass", origin=(0.0, -D + 0.004, (OPEN_Z0 + OPEN_Z1) / 2))
    x0, x1 = -W / 2 + FS - 0.004, W / 2 - FS + 0.004
    f = glass.poly([(x0, -D + 0.004, OPEN_Z0 - 0.004), (x1, -D + 0.004, OPEN_Z0 - 0.004),
                    (x1, -D + 0.004, OPEN_Z1 + 0.004), (x0, -D + 0.004, OPEN_Z1 + 0.004)], "glass")[0]
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    # the flare pistol: muzzle to the left, its labelled left side toward the glass
    gun = Part("flare_gun", origin=tuple(GUN_C))
    vm_flare.build_frame(gun)
    vm_flare.build_barrel(gun)
    gun.move(list(gun.bm.faces), T(*GUN_C) @ R('Z', 90) @ T(0, -0.01, 0.055))
    return Model("emergency_cabinet", [body, glass, gun], FNS, kinds={"glass": "glass"}, ppm=256, ground=None,
                 ao_dist=0.08, ao_rays=12, ao_stride=1, preview_elevation=10.0,
                 preview_yaws=(-25.0, 20.0, 60.0, 0.0),
                 preview_extra=[("front", (0.0, -0.1, 0.35), 0.36, 0.0, 4.0)])
