"""First-person fists: the guard's gloved hands in black leather, sleeves of
the navy uniform with a buttoned cuff, a wristwatch on the left wrist.

Viewmodel conventions (all vm_* models): faces +Y in Blender = -Z in Godot
(away from the camera), real-world scale, origin where the greybox model in
src/weapons/viewmodels.gd had its origin, so the models drop into the
existing REST / FIST_REST offsets. Parts:
    fist_l  (0, 0, 0)     left fist + forearm (the jabbing one)
    fist_r  (0.40, 0, 0)  right fist + forearm, mirrored
Each fist is a vertical fist (thumb on top, knuckles forward) with its
sleeve running back toward the camera, so a part can be moved on its own.

Upgrade "Twarde pięści" (hidden until bought, children of their fist):
    upg_wraps_l / upg_wraps_r        level 1: off-white cotton wraps over the
                                     glove, round the knuckles and the wrist
    upg_knuckles_l / upg_knuckles_r  level 2: brass knuckle-dusters (four
                                     rings round the fingers, a palm bar in
                                     the fist), worn over the wraps
Texture sets: vm_fists, and vm_fists_master (every upgrade maxed): polished
black leather with gold piping, clean wraps with a gold trim, polished
brass dusters with engraving.
"""
import math

import numpy as np
from mathutils import Vector

from artlib import hands
from artlib import materials as M
from artlib.geo import Part
from artlib.kit import S
from artlib.model import Model
from artlib.painter import Surface

RIGHT_X = 0.40


def watch(ctx):
    return M.steel(ctx, seed=331, center=8.6, dent=0.0, rust=0.0, polish=0.2, scratch=0.2)


FNS = {"glove": M.leather, "sleeve": M.uniform, "button": M.brass, "watch_band": M.leather, "watch": watch}


# --------------------------------------------------------------------------
# hand coordinates (a, y, z) of a fist, as in artlib/hands.py: a toward the
# back of the hand, y where the knuckles point, z up the thumb side
# --------------------------------------------------------------------------

def _hand_matrix(sx, x0):
    return hands.hand_matrix((x0, 0.0, 0.0), (0, 0, 1), (sx, -0.25, 0.2), sx=sx)


def _frame(sx, x0):
    """World matrix of the hand coordinates of a fist (mirrored for the left)."""
    return _hand_matrix(sx, x0) @ S(sx, 1, 1)


def _sleeve_dir(sx):
    return Vector((sx * 0.3, -1.0, -0.45)).normalized()


def _hand_coords(p, n=None):
    """Hand coordinates of world points (and normals), and the side (-1 left)."""
    side = np.where(p[:, 0] < RIGHT_X * 0.5, -1.0, 1.0)
    h = np.empty_like(p)
    hn = None if n is None else np.empty_like(n)
    for sx, x0 in ((-1, 0.0), (1, RIGHT_X)):
        H = np.array(_frame(sx, x0))
        inv = np.linalg.inv(H)
        m = side == sx
        h[m] = p[m] @ inv[:3, :3].T + inv[:3, 3]
        if n is not None:
            hn[m] = n[m] @ H[:3, :3]
    return h, side, hn


def _fist(p, sx, x0):
    m = _hand_matrix(sx, x0)
    wrist = hands.add_hand(p, m, sx=sx, tris=1000)
    hands.add_sleeve(p, wrist, (sx * 0.3, -1.0, -0.45), length=0.36, watch=sx < 0, sx=sx)
    return wrist


# --------------------------------------------------------------------------
# upgrades
# --------------------------------------------------------------------------

KNUCKLE_TILT = 14.0       # the second turn over the knuckles crosses the first
# turns of tape (y0, y1, tilt deg, offset off the glove); the second of each
# pair lies on top. Knuckles: in hand coordinates, across y; wrists: metres
# along the sleeve from where the glove cuff starts, by side (the left pair
# stops short of the watch)
KNUCKLE_BANDS = ((-0.009, 0.007, 0.0, 0.0015), (-0.002, 0.012, KNUCKLE_TILT, 0.0021))
WRIST_BANDS = {-1: ((-0.017, 0.003, 0.0, 0.0015), (-0.013, -0.002, 12.0, 0.0021)),
               1: ((-0.017, 0.033, 0.0, 0.0015), (-0.008, 0.005, 14.0, 0.0021))}
WRAP_DECIMATE = 0.4       # the wrap shells keep 40 % of the glove's facets


def _knuckle_normal(tilt):
    t = math.radians(tilt)
    return Vector((0.0, math.cos(t), -math.sin(t)))


def _wrist_frame(sx, x0):
    """Start of the glove cuff, the sleeve direction and the axis the wrist
    turns are tilted about."""
    d = _sleeve_dir(sx)
    wrist = _hand_matrix(sx, x0) @ Vector((sx * 0.004, -0.09, 0.0))
    return wrist - d * 0.012, d, d.cross(Vector((0.0, 0.0, 1.0))).normalized()


def _wrist_band(sx, x0, t0, t1, tilt):
    """Centre, axis and half width of a wrist turn."""
    from mathutils import Matrix
    a0, d, e1 = _wrist_frame(sx, x0)
    return a0 + d * ((t0 + t1) * 0.5), Matrix.Rotation(math.radians(tilt), 3, e1) @ d, (t1 - t0) * 0.5


def _wraps(part, fist, sx, x0):
    """Cotton wraps over the glove: two turns over the knuckles (down into the
    fist between palm and fingers) and two round the wrist."""
    from models import _upgrade_bits_a as hb
    H = _frame(sx, x0)
    R3 = H.to_3x3()

    def plane(pt, n):
        return H @ Vector(pt), (R3 @ Vector(n)).normalized()

    for y0, y1, tilt, off in KNUCKLE_BANDS:
        n = _knuckle_normal(tilt)
        hb.shell(part, fist, "wrap", [plane(n * y1, n), plane(n * y0, -n), plane((-0.004, 0, 0), (-1, 0, 0))],
                 off, ratio=WRAP_DECIMATE)
    a0, d, _ = _wrist_frame(sx, x0)

    def near_axis(c):
        r = c - a0
        return (r - d * r.dot(d)).length < 0.055

    for t0, t1, tilt, off in WRIST_BANDS[sx]:
        mid, dd, half = _wrist_band(sx, x0, t0, t1, tilt)
        hb.shell(part, fist, "wrap", [(mid + dd * half, dd), (mid - dd * half, -dd)], off, keep=near_axis,
                 ratio=WRAP_DECIMATE)


DUSTER_A = -0.010         # mid-plane of the duster (hand a): across the middle finger bones
FINGERS = ((0.03, 0.93, 0.92), (0.01, 1.0, 1.0), (-0.01, 1.0, 1.0), (-0.029, 0.93, 0.85))   # z, reach, size


def _duster(part, sx, x0):
    """Brass knuckle-duster: a ring round each finger (fused into one bar on
    the front of the fist) and a palm bar through the fist, bent forward at
    both ends into the end rings."""
    from models import _upgrade_bits_a as hb
    A = DUSTER_A

    def build(p):
        for z, reach, size in FINGERS:
            rz = 0.0106 * size
            hb.ring(p, (A, 0.026 * reach, z), (1, 0, 0), (0, 0, 1), rz, rz + 0.0028, 0.009, "knuckles",
                    segments=8, squash=1.15, chamfer=0.0)
        path = [(A, 0.021, 0.038), (A, 0.016, 0.0455), (A, 0.008, 0.0465), (A, 0.005, 0.040),
                (A, 0.005, -0.038), (A, 0.008, -0.0455), (A, 0.016, -0.0445), (A, 0.021, -0.036)]
        hb.oval_tube(p, path, 0.0042, 0.0042, (1, 0, 0), "knuckles", sides=6)

    hb.placed(part, _frame(sx, x0), build, mirror=sx < 0)


# --------------------------------------------------------------------------
# materials of the upgrades and the mastery set
# --------------------------------------------------------------------------

# cotton wrap, dark -> light (off-white; the darker steps are grime and shade)
WRAP = M.hexramp("#2e281c", "#463d2b", "#5e533d", "#776a50", "#8f8264", "#a69878", "#bbad8d", "#cec2a4",
                 "#ded5bc", "#ebe4d0")


def _wrap_axis(ctx, h, side):
    """Per texel: the axis the turns of tape run round (the tape's threads
    go across it)."""
    axis = np.empty((ctx.N, 3))
    knuckle = h[:, 1] > -0.035
    for sx, x0 in ((-1, 0.0), (1, RIGHT_X)):
        m = side == sx
        R3 = np.array(_frame(sx, x0).to_3x3())
        k_ax = R3 @ np.array(_knuckle_normal(KNUCKLE_TILT * 0.5))
        axis[m & knuckle] = k_ax / np.linalg.norm(k_ax)
        axis[m & ~knuckle] = np.array(_sleeve_dir(sx))
    return axis


def _turn_edge(ctx, h, side):
    """Metres from each wrap texel to the nearest edge of the turn of tape it
    lies on (where two turns overlap, the outer one), and whether that turn
    is the outer (second) one of its pair."""
    out = np.full(ctx.N, np.inf)
    outer = np.zeros(ctx.N, dtype=bool)
    knuckle = h[:, 1] > -0.035

    def edge_of(c, lo, hi):
        return np.minimum(c - lo, hi - c), (c >= lo) & (c <= hi)

    (a0, a1, at, _), (b0, b1, bt, _) = KNUCKLE_BANDS
    ea, _ = edge_of(h @ np.array(_knuckle_normal(at)), a0, a1)
    eb, on_b = edge_of(h @ np.array(_knuckle_normal(bt)), b0, b1)
    out = np.where(knuckle, np.where(on_b, eb, ea), out)
    outer |= knuckle & on_b
    for sx, x0 in ((-1, 0.0), (1, RIGHT_X)):
        m = (side == sx) & ~knuckle
        es = []
        for t0, t1, tilt, _ in WRIST_BANDS[sx]:
            mid, dd, half = _wrist_band(sx, x0, t0, t1, tilt)
            c = (ctx.p - np.array(mid)) @ np.array(dd)
            es.append(edge_of(c, -half, half))
        (ea, _), (eb, on_b) = es
        out = np.where(m, np.where(on_b, eb, ea), out)
        outer |= m & on_b
    return np.maximum(out, 0.0), outer


def wrap(ctx, seed=701, center=6.4, grime=0.7, trim=False):
    """Cotton boxing wrap: threads along the tape, a faint twill, a bright
    folded hem along the edge of every turn with a soft shadow inside it,
    grime from use (most on the striking face). ``trim``: a gold thread
    woven in just inside the hems of the outer turns (the mastery set)."""
    s = Surface(ctx.N)
    h, side, _ = _hand_coords(ctx.p)
    flow = np.cross(_wrap_axis(ctx, h, side), ctx.n)
    fib = M._streaks(ctx, flow, 22.0, 150.0, 2, seed)
    u = np.floor(ctx.uvm[:, 0] / ctx.texel)
    v = np.floor(ctx.uvm[:, 1] / ctx.texel)
    tw = ((u + v) % 4 < 2) * 0.25
    e, outer = _turn_edge(ctx, h, side)
    e = e / ctx.texel
    hem = e < 1.0
    inner = (e >= 1.0) & (e < 2.0)
    shade = center + fib * 0.5 + tw + M._dither(ctx, 0.35, seed + 1) + hem * 1.0 - inner * 0.6
    shade += np.clip(ctx.curv, 0, 1) * 1.2
    shade -= np.clip(-ctx.curv, 0, 1) * 1.4 + ctx.cavity(3.0) * 2.0 + (1.0 - ctx.ao) * 3.0
    dirt = M.smoothstep(0.1, 0.7, ctx.fbm(6.0, 3, seed + 2)) * 0.8 + (h[:, 1] > 0.0) * 0.5
    shade -= dirt * 1.2 * grime
    s.use_ramp(WRAP, shade=shade)
    s.rough = 0.92 + ctx.rand(seed + 3) * 0.05
    s.height = fib * 0.0002 + tw * 0.0004 + hem * 0.0003 - inner * 0.0002
    if trim:
        from models import _upgrade_bits_a as hb
        hb.merge_ramp(s, M.P["gold"], inner & outer, 7.0 + M._dither(ctx, 0.8, seed + 4) - (1.0 - ctx.ao) * 2.0,
                      metal=0.6, rough=0.3, height=0.0004)
    return s


def wrap_master(ctx):
    return wrap(ctx, seed=711, center=6.9, grime=0.0, trim=True)


def knuckles(ctx):
    """Brass dusters: tarnished, worn bright on the striking face."""
    s = M.brass(ctx, seed=705, tarnish_amount=1.6)
    h, _, _ = _hand_coords(ctx.p)
    s.shade += np.clip((h[:, 1] - 0.03) / 0.008, 0.0, 1.0) * 1.8
    return s


def knuckles_master(ctx):
    """Polished bright brass with a wriggle-cut zigzag engraved round every
    ring and along the palm bar."""
    from models import _upgrade_bits_a as hb
    h, _, hn = _hand_coords(ctx.p, ctx.n)
    along = np.where(ctx.long_u, ctx.uvm[:, 0], ctx.uvm[:, 1]) / ctx.texel
    zig = (2.0 * np.abs(np.mod(along / 4.0, 1.0) - 0.5) * 2.0 - 1.0) * 1.1
    cut = (np.abs((h[:, 0] - DUSTER_A) / ctx.texel - zig) < 0.5) & (np.abs(hn[:, 0]) < 0.5)
    return hb.polished_brass(ctx, 709, engrave=cut & (ctx.convex > ctx.texel * 1.2))


def _piping(ctx, h, hn):
    """Gold-thread stitching on the mastery gloves: three 'points' on the back
    of the hand, and a piped seam along the top of the index finger and of the
    thumb (seen from the player's eye)."""
    texel = ctx.texel
    on = np.zeros(ctx.N, dtype=bool)
    back = (hn[:, 0] > 0.55) & (h[:, 1] > -0.07) & (h[:, 1] < -0.02)
    dash = np.mod(h[:, 1] / 0.0052, 1.0) < 0.62
    for zk in (-0.013, 0.0, 0.013):
        on |= back & dash & (np.abs(h[:, 2] - zk) < 0.55 * texel)

    def seam(points, up):
        out = np.zeros(ctx.N, dtype=bool)
        P = np.asarray(points)
        for a, b in zip(P[:-1], P[1:]):
            ab = b - a
            t = np.clip(((h - a) @ ab) / (ab @ ab), 0.0, 1.0)
            w = h - (a + t[:, None] * ab)
            q = np.cross(ab / np.linalg.norm(ab), up)
            q /= np.linalg.norm(q)
            out |= (np.abs(w @ q) < 0.55 * texel) & (w @ up > 0.004) & (np.linalg.norm(w, axis=1) < 0.02) \
                & (t > 0.0) & (t < 1.0)
        return out

    on |= seam([(0.012, 0.004, 0.03), (0.004, 0.026, 0.03), (-0.026, 0.0223, 0.03)], np.array([0.0, 0.0, 1.0]))
    on |= seam([(-0.004, -0.045, 0.034), (-0.018, -0.012, 0.04), (-0.03, 0.012, 0.036), (-0.034, 0.03, 0.022)],
               np.array([0.0, 0.0, 1.0]))
    return on


def glove_master(ctx, seed=713):
    """Supple polished black leather with gold-thread piping."""
    from models import _upgrade_bits_a as hb
    s = Surface(ctx.N)
    shade = 3.3 + ctx.fbm(5.0, 3, seed) * 0.5 + M._dither(ctx, 0.5, seed)
    shade += ctx.edge_soft(2.0) * 2.4 + np.clip(ctx.curv, 0, 1) * 2.6
    shade -= ctx.cavity(3.0) * 1.5 + (1.0 - ctx.ao) * 2.5
    s.use_ramp(M.P["leather"], shade=shade)
    s.rough = 0.2 + np.clip(ctx.fbm(4.0, 3, seed + 1), 0, 1) * 0.12
    h, _, hn = _hand_coords(ctx.p, ctx.n)
    gold = _piping(ctx, h, hn)
    hb.merge_ramp(s, M.P["gold"], gold, 6.6 + M._dither(ctx, 1.0, seed + 2) - (1.0 - ctx.ao) * 2.0, metal=1.0,
                  rough=0.3, height=0.0003)
    return s


def _fns(master=False):
    """The bake slots of this model; the base set ignores the upgrade parts in
    its ambient occlusion (they may be hidden), the wraps ignore the dusters."""
    from models import _upgrade_bits_a as hb
    if master:
        return dict(FNS, glove=glove_master, wrap=wrap_master, knuckles=knuckles_master)
    base = {k: hb.ao_without(f, ("upg_",), rays=12, dist=0.04) for k, f in FNS.items()}
    return dict(base, wrap=hb.ao_without(wrap, ("upg_knuckles",), rays=12, dist=0.04), knuckles=knuckles)


def _parts():
    left = Part("fist_l", origin=(0, 0, 0))
    _fist(left, -1, 0.0)
    right = Part("fist_r", origin=(RIGHT_X, 0, 0))
    _fist(right, 1, RIGHT_X)
    parts = [left, right]
    for sx, x0, fist, tag in ((-1, 0.0, left, "l"), (1, RIGHT_X, right, "r")):
        H = _frame(sx, x0)
        wraps = Part(f"upg_wraps_{tag}", origin=tuple(H @ Vector((0.004, -0.045, 0.0))), parent=fist.name)
        _wraps(wraps, fist, sx, x0)
        duster = Part(f"upg_knuckles_{tag}", origin=tuple(H @ Vector((DUSTER_A, 0.02, 0.0))), parent=fist.name)
        _duster(duster, sx, x0)
        parts += [wraps, duster]
    return parts


def build():
    cam = (0.05, -0.62, 0.14)          # camera at the jab pose (FIST_HIT); at FIST_REST the fist is off-screen
    organic = ("fist_l", "fist_r", "upg_wraps_l", "upg_wraps_r")
    kw = dict(ppm=384, organic=organic, ao_dist=0.04, ao_rays=12, ao_stride=1, front=1,
              preview_yaws=(-30.0, 30.0, 150.0, 210.0), preview_fp=(cam, (0.0, 1.0, 0.0)),
              preview_extra=[("upg_front", (0.0, 0.0, 0.0), 0.075, -55.0, 20.0),
                             ("upg_top", (0.0, -0.02, 0.0), 0.075, 150.0, 55.0),
                             ("upg_inner", (0.40, -0.01, 0.0), 0.075, -120.0, 25.0)])
    return Model("vm_fists", _parts(), _fns(), variants={"vm_fists_master": _fns(master=True)}, **kw)
