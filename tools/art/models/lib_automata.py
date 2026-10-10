"""Enlightenment wing: the automata of the Clocks and Automata room
(decor that may come alive: the parts have joints).

  lib_automaton_writer  "the Writer": a boy automaton in a red velvet coat
                        and a powdered wig at a little mahogany desk, a quill
                        in his right hand over a sheet of paper. 1.15 m.
                        Kit convention (origin = centre of the base, front
                        -Z: the boy faces the visitor across his desk).
                        Parts: head (pivot in the neck, Godot (0, 0.86,
                        0.2): turn rotation.y, nod rotation.x), arm_r (pivot
                        in the right shoulder, Godot (0.14, 0.8, 0.2): the
                        writing hand and the quill; small rotation.x /
                        rotation.z make him write).
  lib_bird_cage         a gilt-brass domed cage on a mahogany pedestal, 1.6 m,
                        with a mechanical singing bird on its perch and a
                        winding key. Parts: bird (pivot at its feet on the
                        perch, Godot (0, 1.21, 0)), bird_head (child, pivot
                        in the neck: tilt and turn while it sings).
"""
import math
import os

import numpy as np
from mathutils import Matrix

from artlib import enl_materials as E
from artlib import kit as K
from artlib import materials as M
from artlib import sculpt
from artlib.archkit import kit
from artlib.enl_materials import P
from artlib.geo import Part
from artlib.materials import _dither, hexramp
from artlib.painter import Surface
from artlib.sculpt import blob

P.update({
    "enl_powder": hexramp("#5a5550", "#76716b", "#928d86", "#adaaa3", "#c6c3bd", "#dcdad5", "#eceae6"),
    "enl_robin": hexramp("#3a0f04", "#5c1a07", "#82280b", "#a63a12", "#c2521f", "#d86d33"),
    "enl_feather": hexramp("#1a120c", "#2b1e14", "#3e2c1d", "#523c28", "#684e35", "#7f6344", "#977a56"),
})


def writer():
    """Built facing -Y (the kit turns it)."""
    root = Part("lib_automaton_writer")
    # the little desk in front of him
    for sx in (-1, 1):
        for sy in (-1, 1):
            root.lathe([(0.025, 0.0), (0.02, 0.05), (0.016, 0.35), (0.024, 0.5), (0.026, 0.56)], "mahogany",
                       segments=8, center=(sx * 0.32, sy * 0.18 - 0.05, 0.0))
    root.box((0, -0.05, 0.585), (0.72, 0.44, 0.05), "mahogany", bevel=0.01)
    slope = root.box((0, 0, 0), (0.6, 0.36, 0.03), "baize_top", bevel=0.006)
    root.move(slope, Matrix.Translation((0, -0.06, 0.63)) @ Matrix.Rotation(math.radians(-8), 4, 'X'))
    sheet = root.box((0, 0, 0), (0.24, 0.32, 0.002), "paper_sheet")
    root.move(sheet, Matrix.Translation((0.02, -0.06, 0.648)) @ Matrix.Rotation(math.radians(-8), 4, 'X')
              @ Matrix.Rotation(math.radians(6), 4, 'Z'))
    root.lathe([(0.0, 0.0), (0.03, 0.0), (0.035, 0.03), (0.02, 0.05), (0.022, 0.06), (0.0, 0.06)], "ink_glass",
               segments=8, center=(0.24, -0.14, 0.61))
    # his stool
    root.lathe([(0.0, 0.4), (0.17, 0.4), (0.18, 0.43), (0.16, 0.46), (0.0, 0.46)], "velvet", segments=14,
               center=(0, 0.24, 0.0))
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        root.tube([(0.12 * math.cos(a), 0.24 + 0.12 * math.sin(a), 0.4), (0.15 * math.cos(a), 0.24 + 0.15 * math.sin(a), 0.0)],
                  0.016, "mahogany", sides=6)
    # body: legs under the desk, the coat, a lace jabot, the left arm resting
    for sx in (-1, 1):
        K.seg(root, (sx * 0.07, 0.22, 0.48), (sx * 0.08, 0.0, 0.47), [(0.05, 0.0), (0.045, 1.0)], "breeches", segments=8)
        K.seg(root, (sx * 0.08, 0.0, 0.47), (sx * 0.08, 0.02, 0.06), [(0.04, 0.0), (0.03, 0.6), (0.032, 1.0)],
              "stocking", segments=8)
        root.box((sx * 0.08, -0.03, 0.03), (0.07, 0.15, 0.06), "shoe", bevel=0.015)
        root.box((sx * 0.08, -0.07, 0.065), (0.04, 0.02, 0.02), "gilt", bevel=0.004)
    root.lathe([(0.12, 0.44), (0.15, 0.5), (0.14, 0.62), (0.15, 0.74), (0.12, 0.81), (0.05, 0.85)], "coat",
               segments=14, center=(0, 0.22, 0.0), squash=(1.0, 0.75))
    for k in range(4):
        K.sphere(root, (0.0, 0.22 - 0.105, 0.54 + 0.06 * k), 0.008, "gilt", segments=6, rings=4)
    jab = root.lathe([(0.0, -0.1), (0.035, -0.06), (0.045, 0.0), (0.0, 0.02)], "lace", segments=8,
                     squash=(1.0, 0.6))
    root.move(jab, Matrix.Translation((0, 0.115, 0.79)))
    K.seg(root, (-0.14, 0.2, 0.78), (-0.17, 0.06, 0.66), [(0.04, 0.0), (0.035, 1.0)], "coat", segments=8)
    K.seg(root, (-0.17, 0.06, 0.66), (-0.08, -0.08, 0.66), [(0.035, 0.0), (0.03, 1.0)], "coat", segments=8)
    K.sphere(root, (-0.06, -0.1, 0.665), 0.03, "face", segments=8, rings=5, squash=(1.0, 1.3), zscale=0.6)
    # the right arm writes
    arm = Part("arm_r", origin=(0.14, 0.2, 0.8), parent="lib_automaton_writer")
    K.seg(arm, (0.14, 0.2, 0.78), (0.17, 0.06, 0.67), [(0.04, 0.0), (0.035, 1.0)], "coat", segments=8)
    K.seg(arm, (0.17, 0.06, 0.67), (0.07, -0.1, 0.67), [(0.035, 0.0), (0.03, 1.0)], "coat", segments=8)
    K.seg(arm, (0.08, -0.08, 0.67), (0.06, -0.11, 0.672), [(0.036, 0.0), (0.03, 1.0)], "lace", segments=8)
    K.sphere(arm, (0.05, -0.13, 0.672), 0.03, "face", segments=8, rings=5, squash=(1.0, 1.3), zscale=0.6)
    arm.tube([(0.04, -0.15, 0.652), (0.06, -0.1, 0.74), (0.09, -0.04, 0.84)], lambda t: 0.003 + 0.012 * t, "quill",
             sides=4)
    # the head: porcelain face, glass eyes, a powdered wig with side curls and a queue
    head = Part("head", origin=(0.0, 0.2, 0.86), parent="lib_automaton_writer")
    b = [blob((0, 0.21, 0.95), (0.08, 0.085, 0.095)), blob((0, 0.17, 0.92), (0.07, 0.06, 0.07)),
         blob((0, 0.14, 0.9), (0.045, 0.04, 0.035)), blob((0, 0.125, 0.935), (0.012, 0.018, 0.02), stiff=2.4),
         blob((-0.04, 0.15, 0.92), (0.03, 0.025, 0.025)), blob((0.04, 0.15, 0.92), (0.03, 0.025, 0.025)),
         blob((0, 0.21, 0.87), (0.035, 0.035, 0.05))]
    me = sculpt.metaball_mesh(b, resolution=0.006)
    me = sculpt.decimate(me, 700)
    sculpt.into_part(head, me, "face")
    w = [blob((0, 0.23, 0.99), (0.088, 0.09, 0.075)), blob((0, 0.25, 0.95), (0.085, 0.08, 0.08))]
    for sx in (-1, 1):
        w += [blob((sx * 0.085, 0.21, 0.94), (0.03, 0.04, 0.025), stiff=1.8),
              blob((sx * 0.085, 0.215, 0.9), (0.03, 0.04, 0.025), stiff=1.8)]
    w += [blob((0, 0.31, 0.92), (0.025, 0.03, 0.06))]
    wme = sculpt.metaball_mesh(w, resolution=0.007)
    wme = sculpt.decimate(wme, 600)
    sculpt.into_part(head, wme, "wig")
    for sx in (-1, 1):
        K.sphere(head, (sx * 0.028, 0.128, 0.95), 0.013, "eye", segments=8, rings=5)
    head.box((0, 0.33, 0.88), (0.05, 0.01, 0.04), "ribbon", bevel=0.004)
    # modelled with the writing arm on +X (the boy's left as he faces -Y): mirror him so
    # he writes with his right hand (faces reversed to keep the normals outward)
    import bmesh
    flip = Matrix.Scale(-1.0, 4, (1.0, 0.0, 0.0))
    for part in (root, arm, head):
        bmesh.ops.transform(part.bm, matrix=flip, verts=part.bm.verts[:])
        bmesh.ops.reverse_faces(part.bm, faces=part.bm.faces[:])
        part.origin = (-part.origin[0], part.origin[1], part.origin[2])
    return [root, arm, head]


def bird_cage():
    root = Part("lib_bird_cage")
    root.lathe([(0.0, 0.0), (0.22, 0.0), (0.22, 0.04), (0.18, 0.07), (0.12, 0.1), (0.06, 0.14), (0.05, 0.75),
                (0.08, 0.8), (0.1, 0.85), (0.0, 0.86)], "mahogany", segments=14)
    root.box((0, 0, 0.92), (0.4, 0.4, 0.12), "gilt", bevel=0.02)
    root.lathe([(0.0, -0.01), (0.012, -0.01), (0.012, 0.03), (0.0, 0.03)], "brass", segments=6,
               center=(0.2, 0.0, 0.92))
    key = root.box((0, 0, 0), (0.012, 0.05, 0.035), "brass", bevel=0.004)
    root.move(key, Matrix.Translation((0.22, 0.0, 0.92)))
    zb, zt, r = 0.98, 1.3, 0.19
    root.lathe([(r, zb), (r + 0.01, zb), (r + 0.01, zb + 0.02), (r, zb + 0.02)], "brass", segments=24,
               cap_bottom=False, cap_top=False)
    for k in range(24):
        a = math.tau * k / 24
        ca, sa = math.cos(a), math.sin(a)
        pts = [(r * ca, r * sa, zb)]
        for j in range(5):
            t = math.radians(90 * j / 4)
            pts.append((r * math.cos(t) * ca, r * math.cos(t) * sa, zt + 0.22 * math.sin(t)))
        root.tube(pts, 0.004, "brass", sides=3, caps=False)
    for z in (1.08, zt):
        root.lathe([(r + 0.004, z - 0.006), (r + 0.004, z + 0.006)], "brass", segments=24, cap_bottom=False,
                   cap_top=False)
    root.lathe([(0.0, zt + 0.22), (0.03, zt + 0.22), (0.02, zt + 0.25), (0.0, zt + 0.26)], "brass", segments=8)
    root.tube([(0, 0, zt + 0.26), (0, 0, zt + 0.3), (0.03, 0, zt + 0.33), (0, 0, zt + 0.36), (-0.02, 0, zt + 0.33)],
              0.005, "brass", sides=4)
    K.seg(root, (-r, 0.0, 1.2), (r, 0.0, 1.2), [(0.006, 0.0), (0.006, 1.0)], "brass", segments=6)
    bird = Part("bird", origin=(0.0, 0.0, 1.21), parent="lib_bird_cage")
    body = K.sphere(bird, (0, 0, 0), 0.035, "feather", segments=10, rings=7, squash=(0.8, 1.25))
    bird.move(body, Matrix.Translation((0, 0.005, 1.245)) @ Matrix.Rotation(math.radians(-20), 4, 'X'))
    bird.tube([(0, 0.035, 1.24), (0, 0.075, 1.22)], lambda t: 0.014 * (1 - 0.5 * t), "feather", sides=4)
    for sx in (-1, 1):
        bird.tube([(sx * 0.01, 0.0, 1.215), (sx * 0.01, -0.003, 1.2)], 0.0025, "brass", sides=3)
    bh = Part("bird_head", origin=(0.0, -0.025, 1.27), parent="bird")
    K.sphere(bh, (0, -0.03, 1.285), 0.021, "feather", segments=8, rings=6)
    K.cone(bh, (0, -0.05, 1.285), (0, -1, -0.15), 0.02, 0.006, "gilt", segments=4)
    for sx in (-1, 1):
        K.sphere(bh, (sx * 0.015, -0.04, 1.29), 0.004, "eye", segments=6, rings=4)
    return [root, bird, bh]


def _sheet(ctx):
    s = E.paper(ctx, seed=1101, center=7.0)
    u, v = ctx.uvm[:, 0], ctx.uvm[:, 1]
    lines = (np.mod(np.floor(v / ctx.texel), 4) == 0) & (ctx.fbm(np.array([30.0, 1.0, 1.0]), 1, 1102) > -0.3)
    s.use_ramp(P["enl_ink"], mask=lines & (ctx.n[:, 2] > 0.5), shade=np.full(ctx.N, 2.0))
    return s


def _feather(ctx):
    """Brown back and wings with streaks, a robin-red breast below."""
    s = Surface(ctx.N)
    streak = ctx.fbm(np.array([60.0, 60.0, 12.0]), 2, 1103)
    s.use_ramp(P["enl_feather"], shade=4.0 + streak * 1.4 + _dither(ctx, 0.6, 1104) - (1.0 - ctx.ao) * 2.0)
    breast = (ctx.n[:, 1] < -0.3) & (ctx.n[:, 2] < 0.5)
    s.use_ramp(P["enl_robin"], mask=breast, shade=np.full(ctx.N, 4.0) + streak * 0.8)
    s.rough = np.full(ctx.N, 0.7)
    return s


def _face(ctx):
    """Painted porcelain: rosy cheeks, a small red mouth, thin brows and
    nostrils on the head (kit frame after the turn: the face looks to +Y)."""
    s = M.porcelain(ctx, seed=1107, center=6.4, craze=0.6)
    x, y, z = ctx.p[:, 0], ctx.p[:, 1] + 0.21, ctx.p[:, 2] - 0.95
    front = (ctx.n[:, 1] > 0.25) & (ctx.p[:, 2] > 0.85)
    blush = front & (np.hypot(np.abs(x) - 0.044, z + 0.037) < 0.017)
    s.use_ramp(P["wax_blush"], mask=blush, shade=np.full(ctx.N, 3.5) + _dither(ctx, 1.0, 1111))
    mouth = front & (np.abs(x) < 0.014 * (1.0 - ((z + 0.062) / 0.007) ** 2).clip(0, 1) ** 0.5) & (np.abs(z + 0.062) < 0.007)
    s.use_ramp(P["wax_lip"], mask=mouth, shade=np.full(ctx.N, 2.5))
    brow = front & (np.abs(np.abs(x) - 0.03) < 0.014) & (np.abs(z - 0.03 - 0.006 * (1 - ((np.abs(x) - 0.03) / 0.014) ** 2)) < ctx.texel * 0.8)
    nostril = front & (np.abs(np.abs(x) - 0.006) < ctx.texel * 0.8) & (np.abs(z + 0.03) < ctx.texel * 0.8)
    s.use_ramp(P["hair"], mask=brow | nostril, shade=np.full(ctx.N, 3.0))
    return s


def _eye(ctx):
    s = Surface(ctx.N)
    s.use_ramp(P["eye"], shade=np.where(ctx.n[:, 1] < -0.85, 0.0, 2.5))
    s.rough = np.full(ctx.N, 0.08)
    return s


def build():
    only = os.environ.get("ENL_ONLY", "").split(",")

    def want(n):
        return only == [""] or n in only

    fns = {"mahogany": E.mahogany, "baize_top": lambda c: E.baize(c, seed=1105, gilt_border=0.02),
           "paper_sheet": _sheet, "ink_glass": lambda c: E.glass_tint(c, ramp="enl_ink", center=2.5),
           "velvet": M.velvet, "breeches": M.cloth_white, "stocking": lambda c: M.cloth(c, "cloth_white", 7.0, 1106),
           "shoe": M.leather, "gilt": E.gilt, "coat": M.cloth_red, "lace": M.cloth_white,
           "face": _face,
           "wig": lambda c: M.cloth(c, "enl_powder", 4.6, 1108, weave=0.0, rough=0.9), "eye": _eye,
           "ribbon": lambda c: M.cloth(c, "enl_ink", 2.0, 1109), "quill": lambda c: E.paper(c, seed=1110, center=7.5),
           "brass": E.worn_brass, "feather": _feather}
    out = []
    if want("lib_automaton_writer"):
        out.append(kit("lib_automaton_writer", writer(), fns, ppm=256, ground=0.0, ao_dist=0.12, organic=("head",),
                       preview_yaws=(-30.0, 0.0, 30.0, 140.0), preview_elevation=12.0,
                       preview_extra=[("face", (0.0, -0.17, 0.93), 0.16, 0.0, 5.0)]))
    if want("lib_bird_cage"):
        out.append(kit("lib_bird_cage", bird_cage(), fns, ppm=256, ground=0.0, ao_dist=0.1,
                       preview_extra=[("bird", (0.0, 0.0, 1.25), 0.15, -30.0, 10.0)]))
    return out
