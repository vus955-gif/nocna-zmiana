"""Floor I, Americas wing exhibits (Mexico): kit convention (origin = centre
of the base, front = Godot -Z, built facing Blender +Y). Respectful museum
stylisations in the manner of the cultures shown, not copies of any
object.

  turquoise_mask   a life-size face mask of turquoise mosaic: almond eyes
                   of shell with obsidian pupils, a broad nose, an open
                   mouth with red shell lips and white shell teeth, gold
                   and shell ear flares; on a small black stand. 256 px/m.
  mask_case        vitrine 2.4 x 1.6 x 1.0 m (the greybox "case" of the
                   halls): a black basalt-lacquer cabinet with a red base
                   band and a brass label "MASKI MOZAIKOWE / MEKSYK", a red
                   cloth deck and three masks on stands - turquoise, jade
                   with obsidian and gold bands, shell white with a red
                   spondylus band; parts mask_1..mask_3 (the masks, so the
                   game can float one out when the case is broken) and
                   mask_case_glass (panes). 192 px/m (masks 256 in look).
  serpent_mosaic   the double-headed serpent in turquoise mosaic, 1.1 m
                   wide (a W-shaped body, a head at each end with red
                   mouths and white teeth) on a rod over a black plinth
                   under a glass hood (part serpent_mosaic_glass); the
                   guardian's small herald. 256 px/m.
  clay_figures     a stepped red display plinth 1.6 x 0.9 x 0.9 m with four
                   burnished clay pieces of West Mexico: a plump dog, a
                   seated figure with ear spools, a standing warrior with a
                   club and helmet, a tripod bowl. 256 px/m.
  feather_case     wall vitrine 2.2 x 1.8 x 0.8 m: a round feathered shield
                   (a blue stepped fret on yellow, a red rim, a fringe of
                   green plumes and gold bells) and a fan of long green
                   plumes on a dark board; label "PIÓROPUSZE / MEKSYK"; part
                   feather_case_glass. 192 px/m.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import americas as AM
from artlib import americas_paint as AP
from artlib import clay
from artlib import kit as K
from artlib import materials as M
from artlib import pixelfont
from artlib import sculpt
from artlib import serpent_head as SH
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.materials import P, _dither, _select
from artlib.painter import Surface
from artlib.sculpt import blob, limb


def _orient_out(faces, centre):
    c = Vector(centre)
    for f in faces:
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - c) < 0:
            f.normal_flip()


# --------------------------------------------------------------------------
# vitrines
# --------------------------------------------------------------------------

def vitrine(name, w, d, base_h, top_h, deck="deck", back=False):
    """Cabinet (black lacquer on a red plinth band, a brass label on the
    front) with a bronze-edged glass box; returns [cabinet, glass]. Built
    facing -Y (kit() turns it); ``back`` closes the rear with a dark board."""
    p = Part(name)
    p.box((0.0, 0.0, 0.05), (w, d, 0.1), "band", bevel=0.008)
    p.box((0.0, 0.0, 0.1 + (base_h - 0.12) / 2), (w - 0.04, d - 0.04, base_h - 0.12), "cabinet", bevel=0.01)
    p.box((0.0, 0.0, base_h - 0.01), (w + 0.02, d + 0.02, 0.04), "cabinet", bevel=0.006)
    p.box((0.0, 0.0, base_h + 0.012), (w - 0.04, d - 0.04, 0.012), deck)
    p.box((0.0, -d / 2 + 0.008, base_h * 0.62), (0.56, 0.012, 0.16), "plaque", bevel=0.003)
    gx, gy, g0, g1 = w / 2 - 0.01, d / 2 - 0.01, base_h + 0.02, top_h
    e = 0.018
    for x in (-gx, gx):
        for y in (-gy, gy):
            p.box((x, y, (g0 + g1) / 2), (e, e, g1 - g0), "bronze", bevel=0.003)
    for z in (g0 + e / 2, g1 - e / 2):
        for y in (-gy, gy):
            p.box((0.0, y, z), (2 * gx, e, e), "bronze", bevel=0.003)
        for x in (-gx, gx):
            p.box((x, 0.0, z), (e, 2 * gy, e), "bronze", bevel=0.003)
    if back:
        p.box((0.0, gy - 0.02, (g0 + g1) / 2), (2 * gx - 0.03, 0.025, g1 - g0 - 0.03), "board", bevel=0.004)
    cull_floor([p])
    g = Part(name + "_glass")
    q = 0.004
    for sy in (-1, 1) if not back else (-1,):
        g.poly([(-gx, sy * (gy - q), g0), (gx, sy * (gy - q), g0), (gx, sy * (gy - q), g1), (-gx, sy * (gy - q), g1)],
               "glass")
    for sx in (-1, 1):
        g.poly([(sx * (gx - q), -gy, g0), (sx * (gx - q), gy, g0), (sx * (gx - q), gy, g1), (sx * (gx - q), -gy, g1)],
               "glass")
    g.poly([(-gx, -gy, g1 - q), (gx, -gy, g1 - q), (gx, gy, g1 - q), (-gx, gy, g1 - q)], "glass")
    _orient_out(g.bm.faces, (0.0, 0.0, (g0 + g1) / 2))
    return [p, g]


_TXT = {}


def plaque_paint(lines, seed=1601):
    def fn(ctx):
        s = M.brass(ctx, seed)
        front = ctx.n[:, 1] > 0.5
        key = tuple(lines)
        if key not in _TXT:
            _TXT[key] = pixelfont.trim(pixelfont.render(list(lines), line_gap=2))
        u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
        if front.any():
            cu, cv = np.median(u[front]), np.median(v[front])
            ink = pixelfont.stamp(ctx, _TXT[key], cu, cv, scale=1) & front
            s.use_ramp(P["am_obsidian"], mask=ink, shade=np.full(ctx.N, 1.0))
            s.metal = np.where(ink, 0.0, s.metal)
        return s
    return fn


def lacquer(ctx, seed=1603):
    """Black lacquered cabinet wood with a soft sheen."""
    s = AM.carved_wood(ctx, seed, ramp="am_obsidian", center=3.2, adze=0.0, oiled=0.0)
    s.rough = 0.32 + ctx.rand(seed + 1) * 0.04
    return s


def cloth_red(ctx, seed=1605):
    return M.cloth_red(ctx, seed)


CASE_FNS = {
    "band": lambda c: AM.red_plaster(c, 1607, center=4.0), "cabinet": lacquer, "deck": cloth_red,
    "bronze": lambda c: M.brass(c, 1609, tarnish_amount=2.6), "board": lambda c: AM.carved_wood(c, 1611, "am_wood_dark", 2.6, adze=0.0),
}


# --------------------------------------------------------------------------
# masks
# --------------------------------------------------------------------------

MW, MH = 0.1, 0.125      # half width, half height of a mask


def mask_front(x, z):
    """Front height (Blender +Y) of the mask surface at (x, z) (arrays): a
    gently curved shield carved with a straight brow, almond sockets, a
    broad flat nose, an open mouth between full lips, a firm chin."""
    u = np.clip(x / MW, -1.0, 1.0)
    v = np.clip(z / MH, -1.0, 1.0)
    y = 0.045 * (1.0 - u * u) ** 0.7 + 0.015 * (1.0 - v * v)

    def g(a, b):
        return np.exp(-(a * a + b * b))
    y = y + 0.012 * np.exp(-((z - 0.04) / 0.012) ** 2) * np.exp(-(x / 0.085) ** 6)          # brow
    for sx in (-1, 1):
        y = y - 0.011 * g((x - sx * 0.042) / 0.03, (z - 0.012) / 0.012)                     # sockets
        y = y + 0.008 * g((x - sx * 0.06) / 0.03, (z + 0.03) / 0.025)                       # cheekbones
        y = y + 0.01 * g((x - sx * 0.022) / 0.012, (z + 0.044) / 0.01)                      # nostril wings
    t = np.clip((0.03 - z) / 0.075, 0.0, 1.0)
    on = (z > -0.05) & (z < 0.035)
    y = y + np.where(on, 0.03 * (0.4 + 0.6 * t) * np.exp(-(x / (0.014 + 0.014 * t)) ** 4), 0.0)   # nose
    y = y + 0.009 * np.exp(-(x / 0.042) ** 6) * np.exp(-((np.abs(z + 0.072) - 0.011) / 0.006) ** 2)  # lips
    y = y - 0.03 * np.exp(-(x / 0.03) ** 6) * np.exp(-((z + 0.072) / 0.0055) ** 6)               # mouth
    y = y + 0.008 * np.exp(-(x / 0.035) ** 4) * np.exp(-((z + 0.105) / 0.012) ** 2)             # chin
    return y


def _mask_width(v):
    """Half-width factor of the outline by height (-1 chin .. 1 crown)."""
    return float(np.interp(v, [-1.0, -0.75, -0.3, 0.2, 0.7, 0.9, 1.0], [0.42, 0.68, 0.94, 1.0, 0.92, 0.75, 0.5]))


def mask_mesh(nu=20, nv=26):
    import bmesh
    import bpy
    bm = bmesh.new()
    front, back = [], []
    for j in range(nv + 1):
        v = -1.0 + 2.0 * j / nv
        w = _mask_width(v)
        rf, rb = [], []
        for i in range(nu + 1):
            u = (-1.0 + 2.0 * i / nu) * w
            x, z = u * MW, v * MH
            y = float(mask_front(np.array([x]), np.array([z]))[0])
            rf.append(bm.verts.new((x, y, z)))
            rb.append(bm.verts.new((x * 0.97, -0.012, z * 0.97)))
        front.append(rf)
        back.append(rb)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((front[j][i], front[j][i + 1], front[j + 1][i + 1], front[j + 1][i]))
            bm.faces.new((back[j][i], back[j + 1][i], back[j + 1][i + 1], back[j][i + 1]))
    idx = [(0, i) for i in range(nu + 1)] + [(j, nu) for j in range(1, nv + 1)] + \
        [(nv, i) for i in range(nu - 1, -1, -1)] + [(j, 0) for j in range(nv - 1, 0, -1)]
    for k in range(len(idx)):
        (j0, i0), (j1, i1) = idx[k], idx[(k + 1) % len(idx)]
        bm.faces.new((front[j0][i0], back[j0][i0], back[j1][i1], front[j1][i1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("mask")
    bm.to_mesh(me)
    bm.free()
    return me


def _almond(p, cx, cz, w, h, lift, slot, n=14):
    """A flat almond inlay lying on the mask surface (facing +Y), centre
    (cx, cz) in the mask's frame (origin at its centre)."""
    ring = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x = cx + w * math.cos(a)
        z = cz + h * math.sin(a) * (1.0 - 0.3 * math.cos(a) * (1 if cx > 0 else -1))
        ring.append(p.bm.verts.new((x, float(mask_front(np.array([x]), np.array([z]))[0]) + lift, z)))
    c = p.bm.verts.new((cx, float(mask_front(np.array([cx]), np.array([cz]))[0]) + lift * 1.3, cz))
    faces = []
    for k in range(n):
        f = p._face([ring[k], ring[(k + 1) % n], c], slot)
        f.normal_update()
        if f.normal.y < 0:
            f.normal_flip()
        faces.append(f)
    return faces


def mask_part(name, centre, parent=None):
    """A mask facing +Y (Blender), its centre at ``centre``, with inlays:
    slots tess (mosaic), eye (shell almonds), pupil (obsidian), tooth,
    flare_gold (ear flares)."""
    p = Part(name, origin=centre, parent=parent)
    clay.into_part(p, mask_mesh(), "tess", smooth=True)
    for sx in (-1, 1):
        _almond(p, sx * 0.042, 0.011, 0.024, 0.0085, 0.0025, "eye")
        _almond(p, sx * 0.042, 0.011, 0.0075, 0.0068, 0.0045, "pupil", n=10)
        fl = p.lathe([(0.0, 0.0), (0.03, 0.0), (0.032, 0.008), (0.026, 0.011), (0.012, 0.012)], "flare_gold",
                     segments=14, cap_bottom=False, cap_top=True)
        p.move(fl, Matrix.Translation(Vector((sx * 0.098, 0.004, 0.0))) @
               Matrix.Rotation(math.radians(sx * 60.0), 4, 'Y') @ Matrix.Rotation(math.radians(-90.0), 4, 'X'))
    for k in range(5):
        x = -0.02 + k * 0.01
        p.box((x, 0.034, -0.0685), (0.0075, 0.012, 0.007), "tooth", bevel=0.0012)
    p.move(list(p.bm.faces), Matrix.Translation(Vector(centre)))
    return p


def mask_paint(style):
    """Mosaic by style: 'turq', 'jade', 'shell'."""
    def fn(ctx):
        if style == "turq":
            return AM.mosaic(ctx, 1621, "am_turq", cell=0.02, center=5.8, mix=0.15, spread=1.6, gap_texels=0.7,
                             plane="xz")
        if style == "jade":
            return AM.mosaic(ctx, 1623, "am_jade", cell=0.02, center=5.2, mix=0.12, mix_ramp="am_turq_green",
                             spread=1.6, gap_texels=0.7, plane="xz")
        return AM.mosaic(ctx, 1625, "am_shell", cell=0.022, center=6.0, mix=0.0, spread=1.4, gap_texels=0.7,
                         plane="xz")
    return fn


def mask_overlay(style, centre):
    """Bands and lips over the mosaic, in the mask's local frame (the
    mask's front looks +Y when this is called)."""
    def fn(ctx):
        base = mask_paint(style)(ctx)
        lx = ctx.p[:, 0] - centre[0]
        lz = ctx.p[:, 2] - centre[2]
        front = ctx.n[:, 1] > 0.2
        lips = (np.abs(lx) < 0.047) & (lz > -0.092) & (lz < -0.052) & front
        red = AM.mosaic(ctx, 1627, "am_spondylus", cell=0.016, center=5.0, mix=0.0, spread=1.4, gap_texels=0.7,
                        plane="xz")
        if style == "jade":
            band = (np.abs(lz - 0.012) < 0.022) & front
            ob = AM.obsidian(ctx, 1629, center=2.8)
            base.merge(_select(ob, band), band)
            gold = (np.abs(np.abs(lz - 0.012) - 0.026) < 0.0045) & front
            g = M.gold(ctx, 1631)
            base.merge(_select(g, gold), gold)
        elif style == "shell":
            band = (np.abs(lz - 0.012) < 0.024) & front
            base.merge(_select(red, band), band)
        base.merge(_select(red, lips), lips)
        return base
    return fn


MASKS = [("mask_1", "turq", (-0.7, 0.0, 1.26)), ("mask_2", "jade", (0.0, 0.08, 1.34)), ("mask_3", "shell", (0.7, 0.0, 1.26))]


def mask_stand(p, centre, base_z):
    cx, cy, cz = centre
    p.box((cx, cy + 0.02, base_z + 0.015), (0.16, 0.12, 0.03), "stand", bevel=0.004)
    p.tube([(cx, cy + 0.02, base_z + 0.03), (cx, cy + 0.02, cz - 0.04)], 0.008, "stand", sides=6)


def mask_case():
    parts = vitrine("mask_case", 2.4, 1.0, 0.9, 1.6, deck="deck")
    case = parts[0]
    masks = []
    for name, style, (x, y, z) in MASKS:
        # pre-turn the masks face -Y: build facing +Y and turn them round
        m = mask_part(name, (x, -y, z - 0.0), parent=None)
        rot = Matrix.Translation(Vector((x, -y, z))) @ Matrix.Rotation(math.pi, 4, 'Z') @ \
            Matrix.Translation(-Vector((x, -y, z)))
        bmesh_rotate(m, rot)
        masks.append(m)
        mask_stand(case, (x, -y, z), 0.912)
    return parts + masks


def bmesh_rotate(part, m):
    import bmesh
    bmesh.ops.transform(part.bm, matrix=m, verts=part.bm.verts[:])


# --------------------------------------------------------------------------
# the double-headed serpent
# --------------------------------------------------------------------------

def serpent_path(n=24, w=1.1, h=0.34, z0=1.25):
    """The W of the body (x across, z up) between the two necks."""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = -0.4 * w + 0.8 * w * t
        z = z0 + h * 0.36 * math.cos(t * 4 * math.pi) + h * 0.15 * math.cos(t * 2 * math.pi)
        y = 0.03 * math.sin(t * 2 * math.pi)
        pts.append((x, y, z))
    return pts


def serpent_display():
    p = Part("serpent_mosaic")
    # black plinth with a red band and a brass label, a rod, the hood
    p.box((0.0, 0.0, 0.05), (1.3, 0.6, 0.1), "band", bevel=0.008)
    p.box((0.0, 0.0, 0.5), (1.26, 0.56, 0.8), "cabinet", bevel=0.01)
    p.box((0.0, 0.0, 0.91), (1.3, 0.6, 0.02), "cabinet", bevel=0.005)
    p.box((0.0, -0.288, 0.62), (0.5, 0.012, 0.13), "plaque", bevel=0.003)
    for x in (-0.25, 0.25):
        p.tube([(x, 0.03, 0.92), (x, 0.03, 1.13)], 0.009, "rod", sides=6)
    cull_floor([p])
    body = Part("serpent_body")
    pts = serpent_path()
    body.tube(pts, lambda t: 0.034 + 0.012 * math.sin(t * math.pi), "tess", sides=10, caps=False)
    # heads: built along +Y then turned to look outward along the body ends
    L = 0.2
    for end, sx in ((pts[0], -1), (pts[-1], 1)):
        rot = Matrix.Translation(Vector(end)) @ Matrix.Rotation(math.radians(-90 * sx), 4, 'Z') @ \
            Matrix.Rotation(math.radians(-12.0), 4, 'X')
        me = clay.clay_mesh(SH.upper(L) + SH.jaw(L, 28.0), resolution=0.006)
        me = sculpt.decimate(me, 1200)
        clay.into_part(body, me, "head_tess", transform=rot)
        (e1, e2), er, _ = SH.eyes(L)
        for e in (e1, e2):
            f = K.sphere(body, e, er, "eye", segments=8, rings=5)
            body.move(f, rot)
        for root, d, ln in SH.fangs(L, 28.0):
            f = K.cone(body, root, d, ln, 0.008, "tooth", segments=5, tip=0.002)
            body.move(f, rot)
        for root, d in SH.teeth(L, 4, 28.0):
            f = K.cone(body, root, d, 0.012, 0.004, "tooth", segments=4, tip=0.001)
            body.move(f, rot)
    # the glass hood
    g = Part("serpent_mosaic_glass")
    gx, gy, g0, g1 = 0.64, 0.29, 0.92, 1.75
    q = 0.004
    for sy in (-1, 1):
        g.poly([(-gx, sy * gy, g0), (gx, sy * gy, g0), (gx, sy * gy, g1), (-gx, sy * gy, g1)], "glass")
    for sx in (-1, 1):
        g.poly([(sx * gx, -gy, g0), (sx * gx, gy, g0), (sx * gx, gy, g1), (sx * gx, -gy, g1)], "glass")
    g.poly([(-gx, -gy, g1), (gx, -gy, g1), (gx, gy, g1), (-gx, gy, g1)], "glass")
    _orient_out(g.bm.faces, (0.0, 0.0, (g0 + g1) / 2))
    for x in (-gx, gx):
        for y in (-gy, gy):
            p.box((x, y, (g0 + g1) / 2), (0.016, 0.016, g1 - g0), "bronze", bevel=0.002)
    for y in (-gy, gy):
        p.box((0.0, y, g1), (2 * gx, 0.016, 0.016), "bronze", bevel=0.002)
    for x in (-gx, gx):
        p.box((x, 0.0, g1), (0.016, 2 * gy, 0.016), "bronze", bevel=0.002)
    return [p, body, g]


def serpent_tess(ctx):
    """Body: turquoise mosaic with a belly line of shell; heads: turquoise
    on top, the inside of the mouth red shell (faces looking down/into the
    open jaw)."""
    s = AM.mosaic(ctx, 1641, "am_turq", cell=0.028, center=5.8, mix=0.22, spread=1.8, gap_texels=0.6)
    return s


def serpent_head_tess(ctx):
    s = AM.mosaic(ctx, 1643, "am_turq", cell=0.024, center=5.8, mix=0.2, spread=1.8, gap_texels=0.6)
    mouth = ctx.n[:, 2] < -0.35
    red = AM.mosaic(ctx, 1645, "am_spondylus", cell=0.022, center=5.2, mix=0.0, spread=1.4, gap_texels=0.6)
    s.merge(_select(red, mouth), mouth)
    return s


# --------------------------------------------------------------------------
# clay figures
# --------------------------------------------------------------------------

def dog(c):
    x, y, z = c
    b = [blob((x, y, z + 0.17), (0.1, 0.17, 0.095)),            # plump body
         blob((x, y + 0.02, z + 0.21), (0.085, 0.12, 0.07)),
         blob((x, y + 0.17, z + 0.27), (0.06, 0.065, 0.058)),   # head
         blob((x, y + 0.235, z + 0.255), (0.032, 0.05, 0.03)),  # snout
         blob((x, y + 0.27, z + 0.255), (0.015, 0.012, 0.012))]  # nose
    for sx in (-1, 1):
        b += limb([(x + sx * 0.03, y + 0.16, z + 0.31), (x + sx * 0.04, y + 0.15, z + 0.37)], [0.022, 0.006], spacing=0.6)
        for sy in (-1, 1):
            b += limb([(x + sx * 0.06, y + sy * 0.1, z + 0.12), (x + sx * 0.065, y + sy * 0.11, z + 0.02)],
                      [0.032, 0.028], spacing=0.6)
    b += limb([(x, y - 0.15, z + 0.22), (x, y - 0.2, z + 0.29), (x, y - 0.17, z + 0.33)], [0.022, 0.016, 0.012],
              spacing=0.6)
    return b


def seated(c):
    x, y, z = c
    b = [blob((x, y, z + 0.08), (0.11, 0.08, 0.06)),            # crossed legs
         blob((x, y, z + 0.17), (0.075, 0.055, 0.09)),          # body
         blob((x, y + 0.005, z + 0.3), (0.06, 0.055, 0.07)),    # head
         blob((x, y + 0.05, z + 0.29), (0.015, 0.02, 0.022)),   # nose
         blob((x, y, z + 0.36), (0.065, 0.06, 0.025))]          # cap
    for sx in (-1, 1):
        b += limb([(x + sx * 0.07, y, z + 0.23), (x + sx * 0.09, y + 0.03, z + 0.15), (x + sx * 0.07, y + 0.05, z + 0.1)],
                  [0.02, 0.018, 0.018], spacing=0.6)
        b.append(blob((x + sx * 0.065, y, z + 0.3), (0.012, 0.025, 0.025)))   # ear spools
    return b


def warrior(c):
    x, y, z = c
    b = [blob((x, y, z + 0.27), (0.065, 0.045, 0.1)),            # body with armour
         blob((x, y, z + 0.17), (0.07, 0.05, 0.04)),
         blob((x, y + 0.005, z + 0.42), (0.05, 0.05, 0.055)),    # head
         blob((x, y, z + 0.47), (0.06, 0.06, 0.03)),             # helmet
         blob((x, y + 0.02, z + 0.5), (0.02, 0.05, 0.02)),       # helmet horn
         blob((x, y + 0.045, z + 0.42), (0.012, 0.015, 0.016))]
    for sx in (-1, 1):
        b += limb([(x + sx * 0.035, y, z + 0.15), (x + sx * 0.04, y, z + 0.02)], [0.025, 0.022], spacing=0.6)
        b += limb([(x + sx * 0.07, y, z + 0.34), (x + sx * 0.08, y + 0.02, z + 0.25), (x + sx * 0.06, y + 0.05, z + 0.22)],
                  [0.018, 0.016, 0.016], spacing=0.6)
    # the club held across the chest
    b += limb([(x - 0.07, y + 0.06, z + 0.2), (x + 0.07, y + 0.07, z + 0.36)], [0.012, 0.02], spacing=0.7)
    return b


def figures():
    p = Part("clay_figures")
    # stepped display plinth (red stucco steps), 1.6 x 0.9 m, built facing -Y
    p.box((0.0, 0.0, 0.2), (1.6, 0.9, 0.4), "plinth", bevel=0.012)
    p.box((0.0, 0.175, 0.55), (1.6, 0.55, 0.3), "plinth", bevel=0.012)
    p.box((0.0, 0.325, 0.8), (1.6, 0.25, 0.2), "plinth", bevel=0.012)
    p.box((0.0, -0.45 - 0.006, 0.22), (0.5, 0.012, 0.12), "plaque", bevel=0.003)
    cull_floor([p])
    fig = Part("clay_figures_pieces")
    # (blobs built facing +Y, turned to face the room, -Y before kit() turns the piece)
    for name, blobs, tris, base, at in (("dog", dog((0.0, 0.0, 0.0)), 1400, 0.4, (-0.45, -0.27)),
                                        ("seated", seated((0.0, 0.0, 0.0)), 1000, 0.7, (0.02, 0.03)),
                                        ("warrior", warrior((0.0, 0.0, 0.0)), 1000, 0.9, (0.42, 0.32))):
        me = sculpt.metaball_mesh(blobs, resolution=0.006)
        zmin = min(v.co.z for v in me.vertices)
        sculpt.cut(me, [((0.0, 0.0, zmin + 0.012), (0.0, 0.0, -1.0))])
        me = sculpt.decimate(me, tris)
        m = Matrix.Translation(Vector((at[0], at[1], base - zmin - 0.012))) @ Matrix.Rotation(math.pi, 4, 'Z')
        clay.into_part(fig, me, "buff" if name == "warrior" else "clay", transform=m)
    # tripod bowl on the lowest step
    fig.lathe([(0.0, 0.0), (0.09, 0.0), (0.13, 0.04), (0.14, 0.09), (0.12, 0.1), (0.11, 0.06), (0.0, 0.05)],
              "clay", segments=14, center=(0.5, -0.27, 0.47), cap_bottom=False, cap_top=False)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        K.cone(fig, (0.5 + 0.07 * math.cos(a), -0.27 + 0.07 * math.sin(a), 0.48), (0.4 * math.cos(a), 0.4 * math.sin(a), -1.0),
               0.08, 0.025, "clay", segments=6, tip=0.006)
    return [p, fig]


# --------------------------------------------------------------------------
# feather work
# --------------------------------------------------------------------------

_SH = {}


def shield_canvas():
    """The shield's feather mosaic: 120 px across (0.6 m at 192 px/m)... a
    blue stepped fret on yellow inside a red rim, shell-white dots."""
    if "s" in _SH:
        return _SH["s"]
    D = 116
    c = np.full((D, D), AP.INK["ochre"], np.int16)
    yy, xx = np.mgrid[0:D, 0:D]
    r = np.hypot(xx - (D - 1) / 2, yy - (D - 1) / 2)
    c[r > D / 2 - 9] = AP.INK["red"]
    m = AP.fret_unit(6)
    AP.paste(c, m, (D - 48) // 2, (D - 48) // 2, AP.INK["blue"])
    for k in range(16):
        a = 2 * math.pi * k / 16
        cx, cy = (D - 1) / 2 + math.cos(a) * (D / 2 - 4.5), (D - 1) / 2 + math.sin(a) * (D / 2 - 4.5)
        c[(xx - cx) ** 2 + (yy - cy) ** 2 < 4.5] = AP.INK["white"]
    _SH["s"] = c
    return c


def feather_case():
    parts = vitrine("feather_case", 2.2, 0.8, 0.8, 1.8, deck="deck", back=True)
    case = parts[0]
    sh = Part("feather_pieces")
    # round shield on a stand, its face to the room (-Y pre-turn)
    R = 0.3
    cz = 1.32
    cx = -0.45
    disc = sh.lathe([(0.0, 0.0), (R, 0.0), (R, 0.025), (0.0, 0.03)], "shield", segments=24, cap_bottom=False,
                    cap_top=False)
    sh.move(disc, Matrix.Translation(Vector((cx, 0.12, cz))) @ Matrix.Rotation(math.radians(90.0), 4, 'X'))
    # fringe of plumes hanging below the shield
    for k in range(13):
        t = (k - 6) / 6.0
        a = math.radians(-90 + t * 60)
        top = Vector((cx + math.cos(a) * R * 0.95, 0.1, cz + math.sin(a) * R * 0.95))
        tip = top + Vector((t * 0.06, -0.01, -0.2 - 0.04 * (1 - abs(t))))
        sh.tube([tuple(top), tuple((top + tip) / 2), tuple(tip)], lambda u: 0.022 * (1.0 - 0.6 * u) + 0.004,
                "plume", sides=5)
        if k % 3 == 1:
            K.sphere(sh, tuple(top + Vector((0, -0.01, -0.03))), 0.015, "bell", segments=6, rings=4)
    # the fan: long plumes radiating from a carved handle
    fx, fz = 0.45, 1.05
    sh.tube([(fx, 0.1, fz - 0.2), (fx, 0.1, fz + 0.05)], 0.02, "handle", sides=8)
    for k in range(15):
        t = (k - 7) / 7.0
        a = math.radians(90 + t * 55)
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        base = Vector((fx, 0.1 + 0.004 * k % 2, fz + 0.05))
        pts = [tuple(base + d * s + Vector((0, 0, -0.06 * s * s * abs(t)))) for s in (0.0, 0.25, 0.5, 0.62)]
        sh.tube(pts, lambda u: 0.026 * math.sin(math.pi * min(1.0, u * 1.1 + 0.08)) + 0.004, "fan", sides=4)
    sh.lathe([(0.0, 0.0), (0.05, 0.0), (0.05, 0.05), (0.0, 0.06)], "bell", segments=10, center=(fx, 0.1, fz + 0.02))
    # stands
    case.box((cx, 0.17, 0.95), (0.04, 0.04, 0.3), "bronze", bevel=0.004)
    case.box((fx, 0.15, 0.84), (0.12, 0.08, 0.06), "bronze", bevel=0.004)
    return parts + [sh]


def shield_paint(ctx):
    c = shield_canvas()
    D = c.shape[0]
    R = 0.3
    # painted after the case was turned: the shield sits at x = +0.45, its
    # face looking +Y (screen right = -X)
    u = R - (ctx.p[:, 0] - 0.45)
    v = ctx.p[:, 2] - 1.32 + R
    front = ctx.n[:, 1] > 0.5
    idx = AM.canvas_index(c.shape, u * (D / (2 * R)) * ctx.texel, v * (D / (2 * R)) * ctx.texel, ctx.texel)
    codes = AM.take(c, idx)
    s = AM.feathers(ctx, "am_feather_yellow", flow=(0.0, 0.0, -1.0), seed=1661, center=4.6)
    blue = codes == AP.INK["blue"]
    red = codes == AP.INK["red"]
    white = codes == AP.INK["white"]
    fb = AM.feathers(ctx, "am_feather_blue", flow=(0.0, 0.0, -1.0), seed=1663, center=4.2)
    fr = AM.feathers(ctx, "am_feather_red", flow=(0.0, 0.0, -1.0), seed=1665, center=4.4)
    s.merge(_select(fb, blue & front), blue & front)
    s.merge(_select(fr, red | ~front), red | ~front)
    sh = AM.shell(ctx, 1667)
    s.merge(_select(sh, white & front), white & front)
    return s


def build():
    out = []
    # the lone mask
    m = mask_part("turquoise_mask", (0.0, 0.0, 0.32))
    stand = Part("turquoise_mask_stand")
    stand.box((0.0, -0.02, 0.015), (0.16, 0.12, 0.03), "stand", bevel=0.004)
    stand.tube([(0.0, -0.02, 0.03), (0.0, -0.02, 0.27)], 0.008, "stand", sides=6)
    mfns = {"tess": mask_overlay("turq", (0.0, 0.0, 0.32)), "eye": lambda c: AM.shell(c, 1671),
            "pupil": lambda c: AM.obsidian(c, 1673), "tooth": lambda c: AM.shell(c, 1675, center=6.8),
            "flare_gold": lambda c: M.gold(c, 1677), "stand": lacquer}
    out.append(Model_("turquoise_mask", [m, stand], mfns, ppm=256, ground=0.0, ao_dist=0.05,
                      preview_closeup=((0.0, 0.03, 0.32), 0.16)))
    # the case of three
    parts = mask_case()
    fns = {**CASE_FNS, "plaque": plaque_paint(["MASKI MOZAIKOWE", "MEKSYK"]), "stand": lacquer,
           "eye": lambda c: AM.shell(c, 1681), "pupil": lambda c: AM.obsidian(c, 1683),
           "tooth": lambda c: AM.shell(c, 1685, center=6.8), "flare_gold": lambda c: M.gold(c, 1687)}

    def tess(ctx):
        out_s = Surface(ctx.N)
        for k, (name, style, (x, y, z)) in enumerate(MASKS):
            mk = ctx.part == 2 + k
            if mk.any():
                sub = ctx.subset(mk)
                # built at (x, -y, z) facing -Y, then turned with the case
                out_s.merge(mask_overlay(style, (-x, y, z))(sub), mk)
        return out_s
    fns["tess"] = tess
    out.append(kit("mask_case", parts, fns, kinds={"glass": "glass"}, ppm=192, ground=0.0, ao_dist=0.15,
                   preview_extra=[("masks", (0.0, 0.0, 1.3), 0.55, 0.0, 4.0)]))
    # the serpent
    parts = serpent_display()
    sfns = {**CASE_FNS, "plaque": plaque_paint(["WĄŻ DWUGŁOWY", "MOZAIKA TURKUSOWA"]),
            "rod": lambda c: M.brass(c, 1691, tarnish_amount=2.0), "tess": serpent_tess,
            "head_tess": serpent_head_tess, "eye": lambda c: AM.shell(c, 1693, center=6.0),
            "tooth": lambda c: AM.shell(c, 1695, center=6.8)}
    out.append(kit("serpent_mosaic", parts, sfns, kinds={"glass": "glass"}, ppm=256, ground=0.0, ao_dist=0.1,
                   organic=("serpent_body",), preview_extra=[("serpent", (0.0, 0.0, 1.3), 0.5, 0.0, 6.0)]))
    # clay figures
    parts = figures()
    out.append(kit("clay_figures", parts,
                   {"plinth": lambda c: AM.red_plaster(c, 1701, center=4.4), "plaque": plaque_paint(["GLINA", "ZACHODNI MEKSYK"]),
                    "clay": lambda c: AM.clay(c, 1703, center=5.2), "buff": lambda c: AM.clay(c, 1705, ramp="am_clay_buff", center=4.6)},
                   ppm=256, ground=0.0, ao_dist=0.1, organic=("clay_figures_pieces",),
                   preview_extra=[("pieces", (0.0, 0.0, 0.7), 0.6, 10.0, 15.0)]))
    # feather work
    parts = feather_case()
    ffns = {**CASE_FNS, "plaque": plaque_paint(["PIÓROPUSZE", "MEKSYK"]), "shield": shield_paint,
            "plume": lambda c: AM.feathers(c, "am_feather_green", flow=(0.0, 0.0, -1.0), seed=1711, center=4.4),
            "fan": lambda c: AM.feathers(c, "am_feather_green", flow=(0.0, 0.0, 1.0), seed=1713, center=4.6),
            "handle": lambda c: AM.carved_wood(c, 1715, "am_wood", 4.4), "bell": lambda c: M.gold(c, 1717)}
    out.append(kit("feather_case", parts, ffns, kinds={"glass": "glass"}, ppm=192, ground=0.0, ao_dist=0.15,
                   preview_extra=[("pieces", (0.0, 0.0, 1.25), 0.7, 0.0, 5.0)]))
    return out


def Model_(name, parts, fns, **kw):
    """A small exhibit in the kit convention without turning (built facing
    +Y already)."""
    return kit(name, parts, fns, built_final=True, **kw)
