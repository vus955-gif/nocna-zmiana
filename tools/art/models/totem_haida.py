"""Floor I, the Great Court: a 12 m carved cedar pole in the style of the
Northwest Coast (Haida) carvers. A respectful stylisation, not a copy of any
real pole: five creatures stacked as the tradition stacks crests, carved as
chunky masses and painted in the formline palette (black primary lines, red
secondary, blue-green tertiary in the eye sockets) on weathered, silvered
cedar.

From the foot: Bear holding its belly (snout, open mouth, round ears),
Killer Whale upside down with its dorsal fin thrust forward, Raven with a
long straight beak and folded wings, a Watchman in a hat crowned by four
potlatch rings, and Thunderbird on top with a hooked beak, curled crest and
wide-spread wings (4.6 m span).

  totem_haida   origin = centre of the foot, front = Godot -Z; 12.3 m tall,
                4.6 x 2.4 m footprint of the wings and beaks at height (the
                pole itself is 1.2 m across). One part; a stone collar at
                the foot.
"""
import math

import numpy as np
from mathutils import Matrix, Vector

from artlib import court_materials as CM
from artlib import materials as M
from artlib.archkit import front_prism, kit
from artlib.geo import Part
from artlib.painter import Surface

# pole radius by height: bulges for the heads, waists between the figures
RADII = [(0.0, 0.6), (0.6, 0.6), (1.0, 0.56), (1.8, 0.6), (2.6, 0.62), (3.1, 0.55), (3.3, 0.52), (3.9, 0.56),
         (4.6, 0.57), (5.3, 0.52), (5.5, 0.5), (6.2, 0.53), (7.0, 0.54), (7.6, 0.48), (8.0, 0.46), (8.5, 0.48),
         (9.0, 0.45), (9.15, 0.38), (10.05, 0.38), (10.2, 0.44), (10.8, 0.47), (11.4, 0.44), (11.9, 0.38),
         (12.05, 0.3)]


def radius_at(z):
    zs = [a for a, _ in RADII]
    rs = [b for _, b in RADII]
    return float(np.interp(z, zs, rs))


def pole(p):
    prof = [(r, z) for z, r in RADII]
    p.lathe(prof, "pole", segments=20, cap_bottom=False, cap_top=True)
    # stone collar
    p.lathe([(0.0, 0.0), (0.78, 0.0), (0.78, 0.22), (0.7, 0.28), (0.62, 0.3)], "stone", segments=20,
            cap_bottom=False, cap_top=False)


def blob(p, center, radii, mat, segments=10, front_squash=1.0):
    """An ellipsoid (lathe of a half circle) with radii (rx, ry, rz)."""
    rx, ry, rz = radii
    prof = [(math.sin(t) * 1.0, -math.cos(t) * rz) for t in np.linspace(0.0, math.pi, 7)]
    prof[0] = (0.0, -rz)
    prof[-1] = (0.0, rz)
    faces = p.lathe([(r, z) for r, z in prof], mat, segments=segments, squash=(rx, ry))
    p.move(faces, Matrix.Translation(center))
    return faces


def slab(p, outline_xz, y0, depth, mat, bevel=0.02):
    """A carved plank: outline in the x-z plane pushed from y0 toward +Y."""
    faces = p.ngon_prism([(x, z) for x, z in outline_xz], 0.0, depth, mat, bevel=bevel)
    # prism built along +Z with the outline in x-y: turn y -> z, z -> +y
    p.move(faces, Matrix.Translation((0.0, y0, 0.0)) @ Matrix.Rotation(math.radians(-90), 4, 'X'))
    return faces


def bear(p):
    r = radius_at(2.4)
    blob(p, (0.0, r - 0.05, 2.25), (0.3, 0.32, 0.26), "snout")
    # mouth: a dark slot with a red tongue
    p.box((0.0, r + 0.05, 1.93), (0.5, 0.2, 0.08), "mouth", bevel=0.02)
    p.box((0.0, r + 0.12, 1.86), (0.2, 0.12, 0.06), "tongue", bevel=0.02)
    for sx in (-1, 1):
        ear = p.lathe([(0.0, 0.0), (0.15, 0.0), (0.16, 0.12), (0.12, 0.24), (0.0, 0.26)], "ear", segments=8)
        p.move(ear, Matrix.Translation((sx * 0.38, 0.12, 3.02)) @ Matrix.Rotation(math.radians(sx * -15), 4, 'Y'))
        # forearms across the belly, paws meeting in front
        pts = [(sx * 0.58, 0.05, 1.45), (sx * 0.56, 0.42, 1.2), (sx * 0.3, 0.68, 1.0), (sx * 0.1, 0.72, 0.98)]
        p.tube(pts, lambda t: 0.17 - 0.03 * t, "limb", sides=8)
        blob(p, (sx * 0.12, 0.74, 0.98), (0.13, 0.1, 0.11), "paw", segments=8)
        # squat feet
        blob(p, (sx * 0.3, 0.52, 0.25), (0.2, 0.22, 0.2), "limb", segments=8)


def orca(p):
    r = radius_at(4.4)
    # dorsal fin thrust forward and up from the forehead
    outline = [(0.0, 0.0), (0.95, 0.15), (1.25, 0.7), (1.1, 0.78), (0.45, 0.5), (0.0, 0.45)]
    # outline in (forward, up): build in the y-z plane as a thick plank
    pts = [(0.0, f + r - 0.1, 4.75 + u) for f, u in outline]
    vt = [p.bm.verts.new((x - 0.07, y, z)) for x, y, z in pts]
    vb = [p.bm.verts.new((x + 0.07, y, z)) for x, y, z in pts]
    n = len(pts)
    faces = [p._face(vt, "fin"), p._face(list(reversed(vb)), "fin")]
    for i in range(n):
        j = (i + 1) % n
        faces.append(p._face([vt[i], vt[j], vb[j], vb[i]], "fin"))
    centre = Vector((0.0, r + 0.5, 5.1))
    for f in faces:
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - centre) < 0:
            f.normal_flip()
    # wide lips of the upside-down head
    p.box((0.0, r + 0.02, 3.55), (0.72, 0.16, 0.1), "lips", bevel=0.03)
    p.box((0.0, r - 0.02, 3.68), (0.66, 0.12, 0.08), "teeth", bevel=0.02)
    # pectoral fins on the sides, flat against the pole
    for sx in (-1, 1):
        fin2 = [(sx * (r - 0.05), 0.15, 3.9), (sx * (r + 0.2), 0.3, 3.6), (sx * (r + 0.25), 0.55, 3.75),
                (sx * (r - 0.02), 0.4, 4.2)]
        f = p.poly(fin2, "fin")[0]
        f.normal_update()
        if f.normal.x * sx < 0:
            f.normal_flip()


def raven(p):
    r = radius_at(6.8)
    # the long straight beak, slightly downturned at the tip
    beak = p.lathe([(0.0, 0.0), (0.17, 0.0), (0.15, 0.4), (0.1, 0.8), (0.05, 1.05), (0.0, 1.12)], "beak",
                   segments=8, squash=(1.0, 0.75))
    p.move(beak, Matrix.Translation((0.0, r - 0.12, 6.6)) @ Matrix.Rotation(math.radians(-98), 4, 'X'))
    # brow ridge
    p.box((0.0, r - 0.04, 7.1), (0.7, 0.16, 0.1), "brow", bevel=0.03)


def watchman(p):
    r = radius_at(8.3)
    blob(p, (0.0, r - 0.02, 8.15), (0.1, 0.1, 0.09), "nose", segments=8)
    p.box((0.0, r - 0.02, 7.95), (0.3, 0.1, 0.05), "lips", bevel=0.015)
    # hat and four potlatch rings
    p.lathe([(0.0, 8.9), (0.56, 8.9), (0.56, 8.98), (0.44, 9.06), (0.38, 9.15)], "hat", segments=20, cap_top=False)
    for k in range(4):
        z = 9.18 + k * 0.22
        rr = 0.42 - k * 0.025
        p.lathe([(rr - 0.06, z), (rr, z + 0.03), (rr + 0.01, z + 0.1), (rr, z + 0.17), (rr - 0.06, z + 0.2)],
                "rings", segments=20, cap_bottom=False, cap_top=False)


def thunderbird(p):
    r = radius_at(10.8)
    # hooked beak
    pts = [(0.0, r - 0.15, 10.95), (0.0, r + 0.25, 10.98), (0.0, r + 0.55, 10.85), (0.0, r + 0.68, 10.6),
           (0.0, r + 0.6, 10.42)]
    p.tube(pts, lambda t: 0.16 * (1.0 - 0.75 * t), "beak", sides=8)
    p.box((0.0, r, 10.62), (0.3, 0.3, 0.06), "lips", bevel=0.02)
    # curled crest (two horns curling back)
    for sx in (-1, 1):
        crest = []
        for t in np.linspace(0.0, 1.0, 9):
            a = t * math.pi * 1.3
            crest.append((sx * (0.18 + 0.1 * t), -0.05 - 0.25 * math.sin(a), 11.85 + 0.35 * t + 0.2 * (1 - math.cos(a))))
        p.tube(crest, lambda t: 0.08 * (1.0 - 0.6 * t), "crest", sides=6)
    # wings: thick carved planks spread wide, tilted up and forward
    for sx in (-1, 1):
        outline = [(0.0, 0.0), (1.0, 0.1), (1.9, 0.35), (2.35, 0.75), (2.3, 0.95), (1.7, 1.05), (0.9, 1.0),
                   (0.0, 0.95)]
        vt, vb = [], []
        for u, w in outline:
            x = sx * (r - 0.1 + u)
            z = 10.15 + w + u * 0.18
            y = 0.1 + u * 0.08
            vt.append(p.bm.verts.new((x, y + 0.07, z)))
            vb.append(p.bm.verts.new((x, y - 0.07, z)))
        n = len(outline)
        faces = [p._face(vt, "wing"), p._face(list(reversed(vb)), "wing_back")]
        for i in range(n):
            j = (i + 1) % n
            faces.append(p._face([vt[i], vt[j], vb[j], vb[i]], "wing_edge"))
        centre = Vector((sx * (r + 1.0), 0.14, 10.8))
        for f in faces:
            f.normal_update()
            if f.normal.dot(f.calc_center_median() - centre) < 0:
                f.normal_flip()


# --------------------------------------------------------------------------
# paint: formline masks in "face space": s = arc length round the pole from
# the front (+Y), z = height
# --------------------------------------------------------------------------

def _face_space(ctx):
    x, y, z = ctx.p[:, 0], ctx.p[:, 1], ctx.p[:, 2]
    a = np.arctan2(x, y)
    r = np.hypot(x, y)
    return a * np.maximum(r, 0.3), z, a


def ovoid(s, z, cs, cz, w, h, k=2.6):
    """Formline ovoid: a rounded rectangle, flatter at the bottom."""
    dx = np.abs(s - cs) / w
    dz = (z - cz) / h
    dz = np.where(dz < 0, dz * 1.25, dz)
    return dx ** k + np.abs(dz) ** k < 1.0


def u_form(s, z, cs, cz, w, h, t=0.05):
    """A U-form opening upward: outer U minus inner U."""
    outer = ovoid(s, z, cs, cz, w, h, 3.0) & (z < cz + h * 0.6)
    inner = ovoid(s, z, cs, cz + t * 1.5, w - t, h - t, 3.0)
    return outer & ~inner


def eye(s, z, cs, cz, w=0.23, h=0.14):
    """(black formline ring + pupil, teal socket) masks of one eye."""
    outer = ovoid(s, z, cs, cz, w, h)
    ring = outer & ~ovoid(s, z, cs, cz, w - 0.035, h - 0.035)
    pupil = ovoid(s, z, cs, cz, w * 0.45, h * 0.6)
    socket = ovoid(s, z, cs, cz, w + 0.1, h + 0.09) & ~outer
    return ring | pupil, socket


FACES = [  # (eye height, eye spacing, brow height): bear, orca, raven, watchman, thunderbird
    (2.62, 0.31, 2.88), (4.25, 0.29, 4.5), (6.95, 0.27, 7.22), (8.42, 0.2, 8.62), (11.2, 0.23, 11.44)]


def _pole_paint(ctx):
    s_, z, a = _face_space(ctx)
    n = ctx.N
    s = CM.cedar_pole(ctx)
    front = np.abs(a) < 1.6
    black = np.zeros(n, dtype=bool)
    red = np.zeros(n, dtype=bool)
    teal = np.zeros(n, dtype=bool)
    for ez, sp, bz in FACES:
        for sx in (-1, 1):
            b, t = eye(s_, z, sx * sp, ez)
            black |= b & front
            teal |= t & front
            # eyelid lines and a thick black brow above the carved ridge
            brow = ovoid(s_, z, sx * sp, bz, 0.27, 0.09, 2.2) & ~ovoid(s_, z, sx * sp, bz - 0.05, 0.25, 0.07, 2.2)
            black |= brow & front
            lid = ovoid(s_, z, sx * sp, ez, 0.34, 0.2) & ~ovoid(s_, z, sx * sp, ez, 0.31, 0.17) & (z > ez)
            black |= lid & front
    # bear: nostrils, cheek U-forms; orca: blowhole face; raven: folded wings
    for sx in (-1, 1):
        red |= u_form(s_, z, sx * 0.45, 2.2, 0.16, 0.2) & front
        red |= ovoid(s_, z, sx * 0.4, 4.85, 0.1, 0.07) & front
        wing = (np.abs(s_ - sx * 0.62) < 0.35) & (z > 5.6) & (z < 6.5)
        feather = wing & (np.mod(z * 6.0 + np.abs(s_) * 2.0, 1.0) < 0.22)
        black |= feather
        red |= wing & ovoid(s_, z, sx * 0.62, 6.25, 0.14, 0.12) & ~feather
        # thunderbird breast: red U-forms
        red |= u_form(s_, z, sx * 0.2, 10.3, 0.14, 0.16) & front
        # orca pectoral joint, watchman cheeks
        black |= ovoid(s_, z, sx * 0.36, 3.95, 0.12, 0.08) & ~ovoid(s_, z, sx * 0.36, 3.95, 0.07, 0.04) & front
        red |= ovoid(s_, z, sx * 0.16, 8.1, 0.06, 0.05) & front
    # body designs between the faces: a central ovoid (black ring, red
    # core) flanked by split U-forms, the formline grammar of the crests
    for cz, w, h in ((1.3, 0.24, 0.2), (3.0, 0.16, 0.1), (5.95, 0.2, 0.18), (7.8, 0.15, 0.1), (10.0, 0.18, 0.13)):
        ring = ovoid(s_, z, 0.0, cz, w, h) & ~ovoid(s_, z, 0.0, cz, w - 0.05, h - 0.05)
        black |= ring & front
        red |= ovoid(s_, z, 0.0, cz, w * 0.5, h * 0.5) & front
        for sx in (-1, 1):
            uf = u_form(s_, z, sx * (w + 0.2), cz - h * 0.2, w * 0.7, h * 1.1, t=0.045)
            black |= uf & front
            teal |= ovoid(s_, z, sx * (w + 0.2), cz - h * 0.1, w * 0.35, h * 0.5) & front
    # mouths: the raven's under its beak, the thunderbird's tongue line
    red |= ovoid(s_, z, 0.0, 6.42, 0.22, 0.04) & front
    black |= ovoid(s_, z, 0.0, 6.47, 0.25, 0.015) & front
    red |= ovoid(s_, z, 0.0, 5.05, 0.12, 0.05) & front
    # the dark recess of the mouths
    s.use_ramp(CM.P["formline_teal"], mask=teal & ~black, shade=np.full(n, 4.2) + (ctx.rand(31) - 0.5) * 0.8)
    s.use_ramp(CM.P["formline_red"], mask=red & ~black, shade=np.full(n, 4.4) + (ctx.rand(32) - 0.5) * 0.8)
    s.use_ramp(CM.P["formline_black"], mask=black, shade=np.full(n, 2.4) + (ctx.rand(33) - 0.5) * 0.8)
    # weathered paint: worn through on the raised edges, a little
    worn = (black | red | teal) & (ctx.fbm(14.0, 2, 34) > 0.45)
    s.shade[worn] += 0.8
    s.rough = np.where(black | red | teal, 0.6, s.rough)
    s.height = s.height - (black | red | teal) * 0.0008
    return s


def _paint(ramp, center):
    def fn(ctx):
        s = CM.cedar_pole(ctx, grey=0.3)
        s.use_ramp(CM.P[ramp], shade=np.full(ctx.N, center) + ctx.fbm(6.0, 2, 41) * 0.6 + (ctx.rand(42) - 0.5) * 0.6
                   - (1.0 - ctx.ao) * 2.0 + ctx.edge(1.0) * 1.2)
        s.rough = np.full(ctx.N, 0.62)
        return s
    return fn


def _snout(ctx):
    """Carved muzzle in bare cedar: black nostril ovoids, a red upper lip."""
    s = CM.cedar_pole(ctx, grey=0.2)
    z = ctx.p[:, 2]
    x = ctx.p[:, 0]
    nostril = ovoid(x, z, 0.11, 2.3, 0.08, 0.06) | ovoid(x, z, -0.11, 2.3, 0.08, 0.06)
    lip = np.abs(z - 2.06) < 0.035
    s.use_ramp(CM.P["formline_black"], mask=nostril, shade=np.full(ctx.N, 2.0))
    s.use_ramp(CM.P["formline_red"], mask=lip & ~nostril, shade=np.full(ctx.N, 4.4))
    return s


def _teeth(ctx):
    s = Surface(ctx.N)
    s.use_ramp(CM.P["ivory"], shade=np.full(ctx.N, 5.0) + (ctx.rand(3) - 0.5))
    gap = np.abs(np.mod(ctx.p[:, 0] * 14.0, 1.0) - 0.5) > 0.42
    s.use_ramp(CM.P["formline_black"], mask=gap, shade=np.full(ctx.N, 1.0))
    s.rough = np.full(ctx.N, 0.6)
    return s


def _wing(ctx):
    """Front of a wing: formline feathers (black U-forms) along the plank,
    red ovoid joints, teal fills between."""
    x, z = ctx.p[:, 0], ctx.p[:, 2]
    u = np.abs(x) - 0.45
    w = z - (10.15 + u * 0.18)
    s = CM.cedar(ctx, center=5.0, grey=0.6)
    n = ctx.N
    black = np.zeros(n, dtype=bool)
    red = np.zeros(n, dtype=bool)
    teal = np.zeros(n, dtype=bool)
    # outer formline border
    black |= (w < 0.07) | (w > 0.88)
    # feathers: U-forms every 0.32 m along the wing's lower half
    for k in range(7):
        cu = 0.3 + k * 0.3
        uf = u_form(u, w, cu, 0.3, 0.13, 0.22, t=0.045)
        black |= uf
        teal |= ovoid(u, w, cu, 0.33, 0.08, 0.12) & ~uf
    # joint ovoid near the body, red split U above
    black |= ovoid(u, w, 0.25, 0.68, 0.2, 0.15) & ~ovoid(u, w, 0.25, 0.68, 0.15, 0.1)
    red |= ovoid(u, w, 0.25, 0.68, 0.08, 0.06)
    for k in range(3):
        red |= u_form(u, w, 0.75 + k * 0.45, 0.62, 0.17, 0.18, t=0.05)
    s.use_ramp(CM.P["formline_teal"], mask=teal & ~black, shade=np.full(n, 4.0) + (ctx.rand(51) - 0.5) * 0.8)
    s.use_ramp(CM.P["formline_red"], mask=red & ~black, shade=np.full(n, 4.4) + (ctx.rand(52) - 0.5) * 0.8)
    s.use_ramp(CM.P["formline_black"], mask=black, shade=np.full(n, 2.4) + (ctx.rand(53) - 0.5) * 0.8)
    s.rough = np.where(black | red | teal, 0.6, s.rough)
    return s


def _rings(ctx):
    s = _paint("formline_black", 2.4)(ctx)
    band = np.mod(ctx.p[:, 2] - 9.18, 0.22) < 0.07
    s.use_ramp(CM.P["formline_red"], mask=band, shade=np.full(ctx.N, 4.2) + (ctx.rand(5) - 0.5))
    return s


FNS = {
    "pole": _pole_paint, "stone": M.stone,
    "snout": _snout, "mouth": _paint("formline_black", 1.2), "tongue": _paint("formline_red", 4.2),
    "ear": _paint("formline_red", 4.0), "limb": lambda c: CM.cedar_pole(c, grey=0.25),
    "paw": _paint("formline_black", 2.6),
    "fin": _paint("formline_black", 2.8), "lips": _paint("formline_red", 4.4), "teeth": _teeth,
    "beak": _paint("formline_black", 2.6), "brow": _paint("formline_black", 2.4),
    "nose": _paint("formline_red", 4.2), "hat": _paint("formline_black", 2.4), "rings": _rings,
    "crest": _paint("formline_teal", 4.6), "wing": _wing, "wing_back": lambda c: CM.cedar(c, center=4.6, grey=0.7),
    "wing_edge": _paint("formline_black", 2.0),
}


def brows(p):
    """A raised ridge over each eye, following the pole's surface."""
    for ez, sp, bz in FACES:
        r = radius_at(bz)
        for sx in (-1, 1):
            pts = []
            for t in np.linspace(-1.0, 1.0, 7):
                s_ = sx * sp + t * 0.26
                a = s_ / r
                pts.append(((r + 0.02) * math.sin(a), (r + 0.02) * math.cos(a), bz - 0.05 + 0.06 * (1 - t * t)))
            p.tube(pts, 0.045, "brow", sides=6)


def build():
    p = Part("totem_haida")
    brows(p)
    pole(p)
    bear(p)
    orca(p)
    raven(p)
    watchman(p)
    thunderbird(p)
    return kit("totem_haida", [p], FNS, built_final=True, ppm=128, ao_dist=0.4,
               preview_yaws=(-25.0, 25.0, 90.0, 180.0), preview_elevation=6.0,
               preview_extra=[("bear", (0.0, 0.5, 2.2), 1.6, 15.0, 8.0),
                              ("top", (0.0, 0.5, 10.8), 2.6, 15.0, 6.0),
                              ("middle", (0.0, 0.5, 6.0), 2.2, 20.0, 5.0)])
