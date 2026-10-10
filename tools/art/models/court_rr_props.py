"""Floor I: the Reading Room's furniture, the astrolabe and the temporary
exhibition "Wiek pary i stali" (the age of steam and steel).

  rr_desk            radial reading desk, 4 m along Z (Godot), 1.6 m wide:
                     oak end panels and stretcher, green leather writing
                     beds on both sides, a raised spine with book rests and
                     a brass rail, three green banker's lamps (markers
                     Light_1..3, under the shades) and six chairs pulled in
                     at odd angles. Origin = centre of the base; its long
                     axis runs along Z, so a desk at radius r on a radial
                     line k goes to (-sin(a) r, 0, -cos(a) r) with
                     rotation.y = a (a = k * 22.5 degrees).
  rr_catalogue_arc   70 degrees of the central catalogue ring (r 2.7 - 3.7,
                     1.2 m high): card drawers on both faces, a leather
                     lectern slope outside, an oak top. Origin = drum
                     centre; four copies at rotation.y = 45 + 90 k leave the
                     four door aisles open to the astrolabe.
  astrolabe          the finale's pedestal in the middle of the room: a
                     stepped verde base with a brass zodiac ring, a fluted
                     column, a yoke and a 2.4 m armillary sphere. Parts:
                     astrolabe (fixed: base, column, yoke, the horizon ring
                     with six shard cradles), ring_outer, ring_middle,
                     ring_inner (pivots at the sphere's centre; spin them
                     as the shards come home). Markers Shard_1..Shard_6 (the
                     cradles, every 60 degrees) and Core (the centre, where
                     the crystal forms).
  steam_banner       freestanding exhibition title board, double-sided:
                     "WIEK PARY I STALI / wystawa czasowa" with a cog.
  steam_podium       a riveted steel podium for an armour or a wax figure
                     (1.6 x 0.32 x 1.6) with a brass label plate.
  steam_engine       a table steam engine on a cast-iron bed: cylinder,
                     crosshead, crank, a 1.7 m flywheel (part flywheel,
                     turns about X) and a ball governor (part governor,
                     turns about Y): the hero of the exhibition.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import court as C
from artlib import court_materials as CM
from artlib import font, noise
from artlib import materials as M
from artlib.archkit import cull_floor, kit
from artlib.geo import Part
from artlib.painter import Surface

CM.P.update({
    "baize": CM.hexramp("#06120a", "#0a1d10", "#0f2917", "#15361f", "#1c4428", "#245232", "#2e613d"),
    "poster_red": CM.hexramp("#120304", "#200607", "#2f090b", "#3f0d10", "#501216", "#62181c"),
})


# --------------------------------------------------------------------------
# reading desk
# --------------------------------------------------------------------------

def _chair(p, x, y, yaw):
    """Oak reading chair with a round back, facing yaw (deg, 0 = +X)."""
    faces = []
    faces += p.box((0, 0, 0.45), (0.46, 0.44, 0.05), "oak", bevel=0.012)
    faces += p.box((0, 0, 0.475), (0.4, 0.38, 0.02), "leather", bevel=0.008)
    for sx in (-1, 1):
        for sy in (-1, 1):
            faces += p.box((sx * 0.19, sy * 0.18, 0.21), (0.045, 0.045, 0.42), "oak")
    faces += p.box((0, 0, 0.12), (0.04, 0.36, 0.03), "oak")
    arc = [(-0.21 + 0.03 * math.sin(t * math.pi), 0.2 * math.cos(t * math.pi), 0.85) for t in np.linspace(0, 1, 7)]
    faces += p.tube(arc, 0.025, "oak", sides=5)
    for t in (0.0, 0.5, 1.0):
        y0 = 0.2 * math.cos(t * math.pi)
        x0 = -0.21 + 0.03 * math.sin(t * math.pi)
        faces += p.box((x0, y0, 0.66), (0.035, 0.035, 0.4), "oak")
    p.move(faces, Matrix.Translation((x, y, 0.0)) @ Matrix.Rotation(math.radians(yaw), 4, 'Z'))
    return faces


def desk():
    p = Part("rr_desk")
    L, W = 4.0, 1.6
    top = 0.76
    for sy in (-1, 1):
        p.box((0, sy * (L / 2 - 0.1), top / 2), (W - 0.1, 0.08, top), "oak", bevel=0.012)
        p.box((0, sy * (L / 2 - 0.06), top / 2 - 0.05), (W - 0.3, 0.012, top - 0.3), "panel", bevel=0.004)
        p.box((0, sy * (L / 2 - 0.1), 0.04), (W, 0.14, 0.08), "oak_dark", bevel=0.01)
    p.box((0, 0, 0.18), (0.12, L - 0.2, 0.1), "oak", bevel=0.01)
    p.box((0, 0, top - 0.04), (0.5, L - 0.2, 0.08), "oak_dark")
    p.box((0, 0, top + 0.025), (W, L, 0.05), "oak", bevel=0.012)
    for sx in (-1, 1):
        p.box((sx * 0.48, 0, top + 0.052), (0.5, L - 0.3, 0.006), "baize")
    # the spine: book rests both sides, a shelf, a brass rail
    p.box((0, 0, top + 0.25), (0.26, L - 0.2, 0.4), "oak", bevel=0.012)
    p.box((0, 0, top + 0.47), (0.34, L - 0.1, 0.05), "oak_dark", bevel=0.012)
    for sx in (-1, 1):
        rest = p.box((0, 0, 0), (0.03, L - 0.4, 0.3), "oak", bevel=0.006)
        p.move(rest, Matrix.Translation((sx * 0.19, 0, top + 0.17)) @ Matrix.Rotation(math.radians(sx * 22), 4, 'Y'))
        p.box((sx * 0.25, 0, top + 0.05), (0.04, L - 0.4, 0.03), "oak_dark")
    p.tube([(0, -L / 2 + 0.15, top + 0.56), (0, L / 2 - 0.15, top + 0.56)], 0.012, "brass", sides=6)
    for y in np.linspace(-L / 2 + 0.15, L / 2 - 0.15, 5):
        p.box((0, y, top + 0.53), (0.02, 0.02, 0.06), "brass")
    markers = []
    for k, y in enumerate((-1.3, 0.0, 1.3)):
        # banker's lamp: brass stem and a green glass half-cylinder shade
        p.lathe([(0.0, top + 0.495), (0.07, top + 0.495), (0.07, top + 0.51), (0.02, top + 0.53), (0.0, top + 0.53)],
                "brass", segments=10, center=(0, y, 0))
        p.lathe([(0.012, top + 0.52), (0.012, top + 0.78)], "brass", segments=6, center=(0, y, 0), cap_bottom=False)
        p.box((0, y, top + 0.79), (0.03, 0.06, 0.02), "brass")
        shade = p.lathe([(0.0, -0.17), (0.06, -0.165), (0.085, -0.1), (0.09, 0.1), (0.085, 0.165), (0.0, 0.17)],
                        "shade", segments=12, squash=(1.0, 0.55))
        p.move(shade, Matrix.Translation((0, y, top + 0.86)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
        glow = p.lathe([(0.0, -0.15), (0.03, -0.15), (0.03, 0.15), (0.0, 0.15)], "lamp", segments=6)
        p.move(glow, Matrix.Translation((0, y, top + 0.805)) @ Matrix.Rotation(math.radians(90), 4, 'X'))
        markers.append((f"Light_{k + 1}", (0.0, y, top + 0.8), None))
    yaws = (172.0, 185.0, 178.0)
    for sx in (-1, 1):
        for i, y in enumerate((-1.3, 0.0, 1.3)):
            jitter = (i * 37 + (sx + 1) * 11) % 7 - 3
            yaw = (180.0 if sx > 0 else 0.0) + (yaws[i] - 180.0) * sx + jitter
            _chair(p, sx * (0.98 + (i % 2) * 0.12), y + jitter * 0.02, yaw)
    return p, markers


def _panel(ctx):
    s = M.wood_oak(ctx)
    s.shade -= 1.0
    return s


def _baize(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["baize"], shade=4.0 + ctx.fbm(6.0, 2, 3) * 0.6 + (ctx.rand(4) - 0.5) * 0.8)
    edge = ctx.edge_soft(2.0) > 0.4
    s.use_ramp(CM.P["gold"], mask=edge, shade=np.full(ctx.N, 4.5))
    s.rough = np.where(edge, 0.4, 0.75)
    return s


def _shade(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["green_glass"], shade=4.4 + ctx.fbm(8.0, 2, 3) * 0.5 + ctx.edge(1.0) * 2.0)
    s.rough = np.full(ctx.N, 0.1)
    s.emit = s.colors() * 0.4
    return s


def _lamp(ctx):
    return M.glow(ctx, "lamp_warm", 4.6, strength=1.0, rough=0.2)


DESK_FNS = {"oak": M.wood_oak, "oak_dark": M.wood_dark, "panel": _panel, "baize": _baize, "brass": M.brass,
            "leather": M.leather, "shade": _shade, "lamp": _lamp}


# --------------------------------------------------------------------------
# catalogue ring
# --------------------------------------------------------------------------

CAT_R0, CAT_R1, CAT_SPAN = 2.7, 3.7, math.radians(70.0)


def catalogue_arc():
    p = Part("rr_catalogue_arc")
    th0, th1 = -CAT_SPAN / 2, CAT_SPAN / 2
    n = 18
    r0, r1 = CAT_R0, CAT_R1
    sections = [
        ([(r1 + 0.04, 0.0), (r1 + 0.04, 0.12)], "plinth"),
        ([(r1 + 0.04, 0.12), (r1, 0.12)], "oak_dark"),
        ([(r1, 0.12), (r1, 0.92)], "drawers"),
        ([(r1, 0.92), (r1 + 0.06, 0.95), (r1 + 0.06, 0.99)], "oak"),
        ([(r1 + 0.06, 0.99), (r1 - 0.42, 1.2)], "leather"),
        ([(r1 - 0.42, 1.2), (r0 + 0.1, 1.2), (r0 - 0.02, 1.17), (r0 - 0.02, 1.12)], "oak"),
        ([(r0 - 0.02, 1.12), (r0, 1.1)], "oak"),
        ([(r0, 1.1), (r0, 0.12)], "drawers"),
        ([(r0, 0.12), (r0 - 0.04, 0.12), (r0 - 0.04, 0.0)], "plinth"),
    ]
    all_pts = []
    for prof, mat in sections:
        faces, _ = C.rev_strip(p, prof, th0, th1, n, mat)
        C.orient_section(faces, (r0 + r1) / 2, 0.6)
        all_pts += prof
    # end caps (seen in the aisles)
    cap = []
    for pt in all_pts:
        if not cap or (abs(cap[-1][0] - pt[0]) > 1e-6 or abs(cap[-1][1] - pt[1]) > 1e-6):
            cap.append(pt)
    for th, sgn in ((th0, -1.0), (th1, 1.0)):
        q = [(r * math.sin(th), r * math.cos(th), z) for r, z in cap]
        f = p.poly(q, "oak_dark")[0]
        f.normal_update()
        t = Vector((math.cos(th), -math.sin(th), 0.0)) * sgn
        if f.normal.dot(t) < 0:
            f.normal_flip()
    # brass label strip under the lectern, a reading lamp at the middle
    faces, _ = C.rev_strip(p, [(r1 + 0.065, 0.955), (r1 + 0.065, 0.985)], th0 + 0.05, th1 - 0.05, n, "brass")
    C.orient_section(faces, (r0 + r1) / 2, 0.6)
    return p


def _drawers(ctx):
    """Card-catalogue drawers: 0.16 x 0.1 m fronts, brass pulls, label
    frames with cream cards; v runs up the face from its foot."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    s = M.wood_oak(ctx)
    du = np.mod(u, 0.16)
    dv = np.mod(v, 0.1)
    joint = (du < tx) | (dv < tx)
    s.shade = np.where(joint, 1.0, s.shade)
    cu, cv = du - 0.08, dv - 0.05
    pull = (np.abs(cu) < 0.022) & (np.abs(cv + 0.018) < 0.006)
    card = (np.abs(cu) < 0.03) & (np.abs(cv - 0.016) < 0.012)
    frame = card & ((np.abs(np.abs(cu) - 0.03) < tx) | (np.abs(np.abs(cv - 0.016) - 0.012) < tx))
    s.use_ramp(CM.P["enamel_cream"], mask=card & ~frame, shade=np.full(ctx.N, 5.0) + (ctx.rand(3) - 0.5))
    s.use_ramp(CM.P["brass"], mask=pull | frame, shade=np.full(ctx.N, 6.5) + (ctx.rand(4) - 0.5))
    s.metal = np.where(pull | frame, 1.0, 0.0)
    s.rough = np.where(pull | frame, 0.3, s.rough)
    return s


def _plinth(ctx):
    return M.marble_dark(ctx)


# --------------------------------------------------------------------------
# astrolabe
# --------------------------------------------------------------------------

SPHERE_Z = 2.35        # centre of the armillary sphere
RING_R = 1.2


def _ring(p, r, axis_rot, mat, thick=0.035, n=48, ticks=False):
    faces = []
    for q in range(4):
        pts = [(r * math.cos(a), r * math.sin(a), 0.0)
               for a in np.linspace(q * math.pi / 2, (q + 1) * math.pi / 2, n // 4 + 1)]
        faces += p.tube(pts, thick, mat, sides=6, caps=False)
    p.move(faces, Matrix.Translation((0, 0, SPHERE_Z)) @ axis_rot)
    return faces


def _face_up(faces):
    for f in faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()


def astrolabe():
    base = Part("astrolabe")
    outer = Part("ring_outer", origin=(0, 0, SPHERE_Z))
    middle = Part("ring_middle", origin=(0, 0, SPHERE_Z))
    inner = Part("ring_inner", origin=(0, 0, SPHERE_Z))
    # stepped verde base with a brass zodiac ring inlaid in the top step
    for r, z0, z1 in ((2.2, 0.0, 0.16), (1.75, 0.16, 0.32), (1.3, 0.32, 0.48)):
        base.lathe([(r, z0), (r, z1 - 0.03), (r - 0.03, z1)], "verde", segments=32, cap_bottom=False)
        inner_r = 0.95 if r == 1.3 else 0.0
        if inner_r:
            ring, _ = C.rev_strip(base, [(inner_r, z1), (r - 0.03, z1)], 0.0, math.tau, 32, "zodiac", uv_break=1.6)
            _face_up(ring)
            _face_up(base.lathe([(inner_r, z1), (0.0, z1)], "verde", segments=32, cap_bottom=False, cap_top=False))
        else:
            _face_up(base.lathe([(r - 0.03, z1), (0.0, z1)], "verde", segments=32, cap_bottom=False, cap_top=False))
    # fluted column
    base.lathe([(0.42, 0.48), (0.42, 0.56), (0.36, 0.62), (0.34, 0.7)], "brass", segments=16, cap_bottom=False,
               cap_top=False)
    prof = [(0.3, 0.7), (0.27, 1.1)]
    base.lathe(prof, "column", segments=20, cap_bottom=False, cap_top=False, smooth=False,
               ring_scale=lambda i, j: 1.0 if i % 2 == 0 else 0.93)
    base.lathe([(0.27, 1.1), (0.34, 1.16), (0.36, 1.24), (0.2, 1.3), (0.12, 1.42), (0.1, 1.6)], "brass", segments=16,
               cap_bottom=False, cap_top=False)
    # the yoke: a half ring carrying the meridian
    yoke = [(0.0, (RING_R + 0.12) * math.cos(a), SPHERE_Z + (RING_R + 0.12) * math.sin(a))
            for a in np.linspace(math.pi * 1.08, math.pi * 1.92, 13)]
    base.tube([(0.0, 0.0, 1.6)] + [yoke[6]], 0.06, "brass", sides=8)
    base.tube(yoke, 0.05, "brass", sides=6)
    for sy in (-1, 1):
        base.lathe([(0.0, -0.06), (0.08, -0.05), (0.09, 0.0), (0.08, 0.05), (0.0, 0.06)], "brass", segments=8,
                   center=(0.0, sy * (RING_R + 0.12) * math.cos(math.pi * 0.08), SPHERE_Z
                           - (RING_R + 0.12) * math.sin(math.pi * 0.08)))
    # the horizon ring (fixed, on four struts) with the six shard cradles
    hr = RING_R + 0.3
    for q in range(4):
        base.tube([(hr * math.cos(a), hr * math.sin(a), SPHERE_Z)
                   for a in np.linspace(q * math.pi / 2, (q + 1) * math.pi / 2, 16)], 0.06, "brass", sides=6,
                  caps=False)
    flat, _ = C.rev_strip(base, [(hr - 0.1, SPHERE_Z + 0.055), (hr + 0.1, SPHERE_Z + 0.055)], 0.0, math.tau, 60,
                          "zodiac", uv_break=1.6)
    _face_up(flat)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        base.tube([(0.3 * math.cos(a), 0.3 * math.sin(a), 0.9), (hr * math.cos(a), hr * math.sin(a), SPHERE_Z - 0.04)],
                  0.03, "brass", sides=5)
    markers = []
    for k in range(6):
        a = math.radians(90 + 60 * k)
        cx, cy = hr * math.cos(a), hr * math.sin(a)
        base.lathe([(0.0, 0.0), (0.09, 0.0), (0.11, 0.05), (0.07, 0.07), (0.0, 0.065)], "brass", segments=10,
                   center=(cx, cy, SPHERE_Z + 0.06))
        for j in range(3):
            b = a + j * math.tau / 3
            base.tube([(cx + 0.06 * math.cos(b), cy + 0.06 * math.sin(b), SPHERE_Z + 0.1),
                       (cx + 0.1 * math.cos(b), cy + 0.1 * math.sin(b), SPHERE_Z + 0.3)], 0.012, "brass", sides=4)
        markers.append((f"Shard_{k + 1}", (cx, cy, SPHERE_Z + 0.22), None))
    markers.append(("Core", (0.0, 0.0, SPHERE_Z), None))
    # moving rings: the meridian (vertical, N-S), the equator and the
    # ecliptic (23.4 degrees off it), each with engraved ticks
    _ring(outer, RING_R, Matrix.Rotation(math.radians(90), 4, 'X'), "ring", thick=0.06)
    _ring(outer, RING_R, Matrix.Rotation(math.radians(90), 4, 'Y'), "ring", thick=0.04)
    _ring(middle, RING_R * 0.86, Matrix.Rotation(math.radians(23.4), 4, 'X'), "ring", thick=0.055)
    _ring(middle, RING_R * 0.86, Matrix.Identity(4), "ring", thick=0.035)
    _ring(inner, RING_R * 0.6, Matrix.Rotation(math.radians(66.6), 4, 'X'), "ring", thick=0.04)
    _ring(inner, RING_R * 0.6, Matrix.Rotation(math.radians(66.6), 4, 'X') @ Matrix.Rotation(math.radians(90), 4, 'Y'),
          "ring", thick=0.025)
    # polar axis through the sphere and a small cradle for the core
    inner.tube([(0, 0, SPHERE_Z - RING_R * 0.6), (0, 0, SPHERE_Z + RING_R * 0.6)], 0.02, "brass", sides=6)
    inner.lathe([(0.0, -0.12), (0.12, -0.08), (0.15, 0.0), (0.13, 0.03), (0.1, 0.0), (0.0, -0.06)], "brass",
                segments=12, center=(0, 0, SPHERE_Z - 0.2))
    return [base, outer, middle, inner], markers


ZODIAC = "BARAN BYK BLIZNIETA RAK LEW PANNA WAGA SKORPION STRZELEC KOZIOROZEC WODNIK RYBY"


def _zodiac(ctx):
    """Brass with engraved degree ticks round the axis (by angle)."""
    s = M.brass(ctx)
    a = np.mod(np.arctan2(ctx.p[:, 1], ctx.p[:, 0]), math.tau)
    r = np.hypot(ctx.p[:, 0], ctx.p[:, 1])
    tick = np.abs(np.mod(a * r, 0.06) - 0.03) > 0.03 - ctx.texel * 0.6
    long = np.abs(np.mod(a, math.pi / 6)) < ctx.texel / np.maximum(r, 0.1) * 1.5
    s.shade = np.where(tick | long, s.shade - 3.0, s.shade + 0.5)
    return s


def _ring_brass(ctx):
    s = M.brass(ctx)
    v = ctx.uvm[:, 1]
    tick = np.abs(np.mod(v, 0.05) - 0.025) > 0.025 - ctx.texel * 0.6
    s.shade = np.where(tick, s.shade - 2.5, s.shade)
    return s


def _column(ctx):
    return M.marble_dark(ctx)


ASTRO_FNS = {"zodiac": _zodiac, "brass": M.brass, "column": _column, "ring": _ring_brass}


# --------------------------------------------------------------------------
# the exhibition "Wiek pary i stali"
# --------------------------------------------------------------------------

def banner():
    p = Part("steam_banner")
    W, H = 2.4, 2.4
    z0 = 0.55
    # riveted iron frame, board both sides
    p.box((0, 0, z0 + H / 2), (W, 0.06, H), "board", bevel=0.004)
    for sx in (-1, 1):
        p.box((sx * (W / 2 + 0.04), 0, (z0 + H) / 2 + 0.05), (0.08, 0.12, z0 + H + 0.1), "frame", bevel=0.01)
        p.box((sx * (W / 2 + 0.04), 0, 0.03), (0.3, 0.6, 0.06), "frame", bevel=0.01)
        p.lathe([(0.0, 0.0), (0.06, 0.0), (0.05, 0.05), (0.0, 0.08)], "brass", segments=8,
                center=(sx * (W / 2 + 0.04), 0, z0 + H + 0.1))
    for z in (z0 - 0.04, z0 + H + 0.04):
        p.box((0, 0, z), (W + 0.04, 0.1, 0.08), "frame", bevel=0.01)
    return p


def _poster(ctx):
    """Victorian poster on both faces: deep red ground, cream double rule,
    the title in big letters, a cog, the subtitle."""
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    tx = ctx.texel
    n = ctx.N
    s = Surface(n)
    s.use_ramp(CM.P["poster_red"], shade=3.6 + ctx.fbm(3.0, 3, 5) * 0.8 + (ctx.rand(6) - 0.5) * 0.6)
    face = np.abs(ctx.n[:, 1]) > 0.9
    # box-projected UVs read left to right on both faces already
    uu = u
    z0, W, H = 0.55, 2.4, 2.4
    ink = np.zeros(n, dtype=bool)
    for inset in (0.08, 0.11):
        ink |= ((np.abs(np.abs(uu) - (W / 2 - inset)) < tx) & (np.abs(v - (z0 + H / 2)) < H / 2 - inset)) | \
               ((np.abs(np.abs(v - (z0 + H / 2)) - (H / 2 - inset)) < tx) & (np.abs(uu) < W / 2 - inset))
    px = 3 * tx
    ink |= font.text_mask(uu, v, "WIEK PARY", 0.0, z0 + 1.75, px)
    ink |= font.text_mask(uu, v, "I STALI", 0.0, z0 + 1.38, px)
    ink |= font.text_mask(uu, v, "wystawa czasowa", 0.0, z0 + 0.25, 2 * tx)
    # cog
    cx, cz = 0.0, z0 + 0.82
    r = np.hypot(uu - cx, v - cz)
    a = np.arctan2(v - cz, uu - cx)
    teeth = 0.27 + 0.05 * (np.cos(a * 12) > 0.2)
    cog = (r < teeth) & (r > 0.12) & ~((r > 0.17) & (r < 0.21) & (np.abs(np.mod(a, math.pi / 3) - math.pi / 6) < 0.35))
    gold = cog
    s.use_ramp(CM.P["enamel_cream"], mask=ink & face, shade=np.full(n, 6.5) + (ctx.rand(7) - 0.5) * 0.6)
    s.use_ramp(CM.P["gold"], mask=gold & face, shade=np.full(n, 6.0) + (ctx.rand(8) - 0.5))
    s.metal = np.where(gold & face, 1.0, 0.0)
    s.rough = np.where(gold & face, 0.35, 0.75)
    return s


def podium():
    p = Part("steam_podium")
    p.box((0, 0, 0.1), (1.6, 1.6, 0.2), "steel_paint", bevel=0.02)
    p.box((0, 0, 0.26), (1.44, 1.44, 0.12), "steel_paint", bevel=0.015)
    # rivets on the faces (as small studs)
    for k in range(9):
        t = -0.7 + 1.4 * k / 8
        for (x, y, rx) in ((t, -0.805, 'X'), (t, 0.805, 'X'), (-0.805, t, 'Y'), (0.805, t, 'Y')):
            stud = p.lathe([(0.0, 0.0), (0.018, 0.0), (0.012, 0.01), (0.0, 0.014)], "rivet", segments=6)
            rot = {(0, -1): Matrix.Rotation(math.radians(90), 4, 'X'), (0, 1): Matrix.Rotation(math.radians(-90), 4, 'X'),
                   (-1, 0): Matrix.Rotation(math.radians(-90), 4, 'Y'), (1, 0): Matrix.Rotation(math.radians(90), 4, 'Y')}
            key = (0, -1 if y < 0 else 1) if rx == 'X' else (-1 if x < 0 else 1, 0)
            p.move(stud, Matrix.Translation((x, y, 0.1)) @ rot[key])
    p.box((0, -0.73, 0.26), (0.5, 0.012, 0.09), "plate", bevel=0.003)
    return p


def _steel_paint(ctx):
    return CM.cast_iron(ctx, center=3.6)


def _plate(ctx):
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    s = M.brass(ctx)
    s.shade += 0.6
    ink = font.text_mask(u, v, "WIEK PARY I STALI", 0.0, 0.26 - 0.012, 2.0 / 256)
    s.use_ramp(CM.P["leather"], mask=ink, shade=np.full(ctx.N, 1.0))
    return s


def engine():
    p = Part("steam_engine")
    fly = Part("flywheel", origin=(0.0, 1.0, 1.15))
    gov = Part("governor", origin=(0.0, -0.2, 1.3))
    # cast-iron bed on a stepped plinth
    p.box((0, 0, 0.12), (1.3, 3.6, 0.24), "plinth", bevel=0.02)
    p.box((0, 0, 0.27), (1.1, 3.4, 0.06), "plinth", bevel=0.01)
    p.box((0, -0.2, 0.5), (0.5, 2.6, 0.4), "iron_bed", bevel=0.03)
    for sx in (-1, 1):
        p.box((sx * 0.3, -0.2, 0.36), (0.12, 2.8, 0.12), "iron_bed", bevel=0.02)
    # cylinder with brass bands, valve chest, piston rod and crosshead guides
    cyl = p.lathe([(0.0, 0.0), (0.26, 0.0), (0.3, 0.04), (0.3, 0.08), (0.26, 0.1), (0.26, 0.62), (0.3, 0.64),
                   (0.3, 0.68), (0.26, 0.72), (0.0, 0.72)], "cylinder", segments=16)
    p.move(cyl, Matrix.Translation((0, -1.4, 0.98)) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    p.box((0.32, -1.04, 0.98), (0.2, 0.5, 0.36), "iron_bed", bevel=0.02)
    p.tube([(0, -0.68, 0.98), (0, 0.1, 0.98)], 0.035, "steel", sides=8)
    for sx in (-1, 1):
        p.box((sx * 0.16, -0.25, 0.98), (0.04, 0.75, 0.08), "steel", bevel=0.006)
    p.box((0, 0.1, 0.98), (0.26, 0.16, 0.16), "steel", bevel=0.01)
    # connecting rod to the crank, main bearings, the crankshaft
    p.tube([(0, 0.1, 0.98), (0.0, 0.85, 1.25)], 0.04, "steel", sides=8)
    for sx in (-1, 1):
        p.box((sx * 0.35, 1.0, 0.82), (0.16, 0.3, 0.7), "iron_bed", bevel=0.02)
    p.tube([(-0.6, 1.0, 1.15), (0.6, 1.0, 1.15)], 0.06, "steel", sides=8)
    # flywheel: rim, hub and six spokes (its own part, turns about X)
    rim_out = [(0.0, 0.85 * math.cos(a), 0.85 * math.sin(a)) for a in np.linspace(0, math.tau, 33)]
    fly.tube(rim_out, 0.07, "flywheel", sides=6, caps=False)
    hub = fly.lathe([(0.0, -0.1), (0.13, -0.1), (0.13, 0.1), (0.0, 0.1)], "flywheel", segments=10)
    fly.move(hub, Matrix.Rotation(math.radians(90), 4, 'Y'))
    for k in range(6):
        a = math.tau * k / 6
        fly.tube([(0.0, 0.12 * math.cos(a), 0.12 * math.sin(a)), (0.0, 0.8 * math.cos(a), 0.8 * math.sin(a))],
                 lambda t: 0.045 - 0.02 * t, "flywheel", sides=5)
    fly.move(list(fly.bm.faces), Matrix.Translation((-0.62, 1.0, 1.15)))
    fly.origin = Vector((-0.62, 1.0, 1.15))
    # ball governor on a column, driven by a belt from the shaft
    p.lathe([(0.05, 0.7), (0.05, 1.3)], "brass", segments=8, center=(0.0, -0.2, 0.0), cap_bottom=False)
    gov.lathe([(0.0, 1.3), (0.04, 1.3), (0.04, 1.62), (0.06, 1.66), (0.0, 1.7)], "brass", segments=8,
              center=(0.0, -0.2, 0.0))
    for sx in (-1, 1):
        gov.tube([(0.0, -0.2, 1.64), (sx * 0.22, -0.2, 1.42)], 0.012, "brass", sides=4)
        gov.lathe([(0.0, -0.07), (0.05, -0.05), (0.07, 0.0), (0.05, 0.05), (0.0, 0.07)], "brass", segments=10,
                  center=(sx * 0.24, -0.2, 1.4))
    # copper steam pipe from the floor to the valve chest, a gauge
    p.tube([(0.5, -1.6, 0.3), (0.5, -1.6, 1.4), (0.5, -1.2, 1.5), (0.42, -1.04, 1.2)], 0.045, "copper", sides=8)
    p.lathe([(0.0, 0.0), (0.09, 0.0), (0.09, 0.04), (0.0, 0.04)], "gauge", segments=12,
            center=(0.5, -1.45, 1.47))
    return [p, fly, gov]


def _gauge(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["enamel_white"], shade=np.full(ctx.N, 6.0))
    up = ctx.n[:, 2] > 0.9
    x, y = ctx.p[:, 0] - 0.5, ctx.p[:, 1] + 1.45
    needle = up & (np.abs(x * 0.6 - y * 0.8) < 0.005) & (np.hypot(x, y) < 0.07)
    s.use_ramp(CM.P["cloth_red"], mask=needle, shade=np.full(ctx.N, 5.0))
    rim = ~up
    s.use_ramp(CM.P["brass"], mask=rim, shade=np.full(ctx.N, 6.0))
    s.rough = np.full(ctx.N, 0.25)
    return s


def _cylinder(ctx):
    s = CM.cast_iron(ctx)
    s.use_ramp(CM.P["paint_green"], shade=4.5 + ctx.fbm(4.0, 2, 3) * 0.5 + ctx.edge(1.0) * 2.0)
    return s


def _flywheel(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["cloth_red"], shade=3.6 + ctx.fbm(5.0, 2, 3) * 0.5 + ctx.edge(1.0) * 2.0 - (1 - ctx.ao) * 2.0)
    s.rough = np.full(ctx.N, 0.45)
    return s


ENGINE_FNS = {"plinth": M.marble_dark, "iron_bed": lambda c: CM.cast_iron(c, center=4.6), "cylinder": _cylinder,
              "steel": M.steel, "brass": M.brass, "copper": lambda c: M.brass(c, ramp="copper"),
              "flywheel": _flywheel, "gauge": _gauge}


def build():
    d, dm = desk()
    parts, am = astrolabe()
    cull_floor([d])
    return [
        kit("rr_desk", [d], DESK_FNS, built_final=True, ppm=112, ao_dist=0.25, markers=dm,
            preview_extra=[("lamp", (0.0, 0.0, 1.1), 0.9, 30.0, 15.0)]),
        kit("rr_catalogue_arc", [catalogue_arc()], {"plinth": _plinth, "oak": M.wood_oak, "oak_dark": M.wood_dark,
                                                    "drawers": _drawers, "leather": _baize, "brass": M.brass},
            built_final=True, ppm=128, ao_dist=0.3, preview_yaws=(150.0, 180.0, 210.0, 0.0), preview_elevation=20.0),
        kit("astrolabe", parts, ASTRO_FNS, kinds={"verde": "tile:marble_dark"}, built_final=True, ppm=160,
            ao_dist=0.25, markers=am,
            preview_elevation=12.0, preview_extra=[("rings", (0.0, 0.0, SPHERE_Z), 1.6, 20.0, 15.0)]),
        kit("steam_banner", [banner()], {"board": _poster, "frame": CM.cast_iron, "brass": M.brass}, built_final=True,
            ppm=128, ao_dist=0.2),
        kit("steam_podium", [podium()], {"steel_paint": _steel_paint, "rivet": M.brass, "plate": _plate},
            built_final=True, ppm=128, ao_dist=0.2),
        kit("steam_engine", engine(), ENGINE_FNS, built_final=True, ppm=128, ao_dist=0.3,
            preview_extra=[("closeup", (0.0, 0.0, 1.0), 1.6, 40.0, 20.0)]),
    ]
