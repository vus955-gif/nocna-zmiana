"""Scarabs for the swarms (30-40 instances as one enemy): a 6 cm sacred
beetle, very low poly, iridescent green shifting to teal and gold at the
rims of its plates, black legs, the toothed head shield.

Faces +Y in Blender = -Z in Godot; origin on the ground under the body
centre. 512 px/m.

  scarab          crawling: closed elytra, legs out (one mesh, ~110 tris:
                  made for a MultiMesh)
  scarab_flying   in flight: the elytra raised and spread, the membrane
                  wings out, legs tucked (one mesh; alternate it with scarab
                  or flap it by scaling X for a buzzing swarm)
  scarab_debris   a squashed beetle: shell_l, shell_r (the two elytra),
                  body (head and thorax) as parts to scatter
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import egypt as E
from artlib import kit as K
from artlib.geo import Part
from artlib.materials import P, _dither
from artlib.model import Model
from artlib.painter import Surface


def _dome(p, c, r, slot, squash=(0.82, 1.0), zscale=0.6, segments=8, rings=4, side=0):
    """Upper half of an ellipsoid (a beetle's plate); ``side`` -1/+1 keeps
    only one half (an elytron)."""
    faces = K.sphere(p, c, r, slot, segments=segments, rings=rings, squash=squash, zscale=zscale, smooth=True)
    pred = (lambda v: v.z > c[2] - 1e-4) if side == 0 else (lambda v: v.z > c[2] - 1e-4 and v.x * side > c[0] * side - 1e-5)
    return K.keep(p, faces, pred)


def _head(p, y, z):
    pts = []
    n = 7
    for i in range(n * 2 + 1):
        a = math.pi * i / (n * 2)
        r = 0.011 if i % 2 == 0 else 0.0085
        pts.append((math.cos(a) * r, y + math.sin(a) * r * 0.75))
    pts.append((0.0, y - 0.002))
    p.ngon_prism([(x, yy) for x, yy in pts], z - 0.0015, z + 0.0015, "shell")


def _legs(p, tucked=False):
    for sx in (-1, 1):
        for k, (y, ang) in enumerate(((0.012, 35.0), (0.0, 80.0), (-0.012, 125.0))):
            a = math.radians(ang)
            ln = 0.012 if tucked else 0.022 + 0.004 * (k == 2)
            hip = Vector((sx * 0.009, y, 0.004))
            foot = hip + Vector((sx * math.sin(a) * ln, math.cos(a) * ln, -0.003 if tucked else -0.0035))
            p.tube([tuple(hip), tuple(foot)], 0.0012, "leg", sides=3, smooth=False, caps=False)


def crawler():
    p = Part("scarab")
    _dome(p, (0.0, -0.006, 0.004), 0.017, "shell", squash=(0.9, 1.2), zscale=0.62)
    _dome(p, (0.0, 0.014, 0.004), 0.011, "shell", squash=(1.0, 0.75), zscale=0.6, segments=6, rings=3)
    _head(p, 0.022, 0.0045)
    _legs(p)
    return p


def flyer():
    p = Part("scarab_flying")
    for sx in (-1, 1):
        f = _dome(p, (0.0, -0.006, 0.004), 0.017, "shell", squash=(0.9, 1.2), zscale=0.62, side=sx)
        p.move(f, Matrix.Translation((0.0, -0.006, 0.006)) @ Matrix.Rotation(math.radians(-sx * 55), 4, 'Y')
               @ Matrix.Translation((0.0, 0.006, -0.006)))
        wing = p.poly([(sx * 0.004, 0.004, 0.009), (sx * 0.034, -0.004, 0.012), (sx * 0.036, -0.016, 0.011),
                       (sx * 0.006, -0.01, 0.009)], "wing")[0]
        wing.normal_update()
        if wing.normal.z < 0:
            wing.normal_flip()
        back = p.poly([(sx * 0.004, 0.004, 0.009), (sx * 0.034, -0.004, 0.012), (sx * 0.036, -0.016, 0.011),
                       (sx * 0.006, -0.01, 0.009)], "wing")[0]
        back.normal_update()
        if back.normal.z > 0:
            back.normal_flip()
    # the abdomen under the raised elytra
    _dome(p, (0.0, -0.008, 0.004), 0.013, "body", squash=(0.8, 1.2), zscale=0.5, segments=6, rings=3)
    _dome(p, (0.0, 0.014, 0.004), 0.011, "shell", squash=(1.0, 0.75), zscale=0.6, segments=6, rings=3)
    _head(p, 0.022, 0.0045)
    _legs(p, tucked=True)
    return p


def debris():
    parts = []
    for sx, c in ((-1, (-0.018, -0.004, 0.0)), (1, (0.02, 0.006, 0.0))):
        p = Part("shell_l" if sx < 0 else "shell_r", origin=c)
        f = _dome(p, (0.0, -0.006, 0.0), 0.017, "shell", squash=(0.9, 1.2), zscale=0.62, side=sx)
        p.move(f, Matrix.Translation(Vector(c)) @ Matrix.Rotation(math.radians(sx * 25), 4, 'Z'))
        parts.append(p)
    b = Part("body", origin=(0.0, 0.02, 0.0))
    _dome(b, (0.0, 0.02, 0.0), 0.011, "shell", squash=(1.0, 0.75), zscale=0.6, segments=6, rings=3)
    _head(b, 0.028, 0.0015)
    _legs(b, tucked=True)
    parts.append(b)
    return parts


def leg(ctx, seed=1301):
    s = Surface(ctx.N)
    s.use_ramp(P["eg_black"], shade=1.6 + _dither(ctx, 0.8, seed))
    s.rough = np.full(ctx.N, 0.4)
    return s


def wing(ctx, seed=1303):
    """Membrane wing: smoky amber with dark veins."""
    s = Surface(ctx.N)
    ix, iy = E.px(ctx)
    vein = (np.mod(ix + iy // 2, 5) == 0)
    s.use_ramp(P["resin"], shade=4.6 - vein * 2.5 + _dither(ctx, 0.5, seed))
    s.rough = np.full(ctx.N, 0.25)
    return s


def body(ctx, seed=1305):
    s = E.scarab_shell(ctx, seed)
    s.shade -= 2.0
    return s


def build():
    fns = {"shell": E.scarab_shell, "leg": leg, "wing": wing, "body": body}
    kw = dict(ppm=512, ground=0.0, ao_dist=0.006, ao_rays=8, ao_stride=1, front=1, pad=2,
              preview_yaws=(-35.0, 35.0, 120.0, 210.0), preview_elevation=35.0)
    return [Model("scarab", [crawler()], fns, **kw),
            Model("scarab_flying", [flyer()], fns, **kw),
            Model("scarab_debris", debris(), fns, **kw)]
